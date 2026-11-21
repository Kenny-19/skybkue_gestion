@Tags(['perf'])
library;

import 'dart:io';

import 'package:blue_sky/core/temps.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Banc d'essai TEMPORAIRE : deux ans d'activité dans une base sur DISQUE,
// et le temps de chaque opération que l'application répète.

Future<void> main() async {
  final dossier = await Directory.systemTemp.createTemp('bench');
  final db =
      AppDatabase.forTesting(NativeDatabase(File('${dossier.path}/b.db')));
  await semerCatalogueDeTest(db);
  final arts = await db.select(db.articles).get();
  final maintenant = DateTime.now();

  final sw = Stopwatch()..start();
  await db.batch((b) {
    for (var i = 0; i < 40000; i++) {
      final quand =
          maintenant.subtract(Duration(minutes: (40000 - i) * 26)); // ~2 ans
      b.insert(
          db.sales,
          SalesCompanion.insert(
            id: Value(i + 1),
            uid: Value('v$i'),
            soldAt: quand,
            payment: DbPayment.cash,
            location: const Value(DbLocation.restaurant),
            onCredit: Value(i % 40 == 0),
            roomNumber: Value(i % 40 == 0 ? '${i % 20}' : null),
            syncedAt: Value(i > 39990 ? null : quand),
          ));
      for (var k = 0; k < 3; k++) {
        b.insert(
            db.saleLines,
            SaleLinesCompanion.insert(
              saleId: i + 1,
              uid: Value('l$i-$k'),
              articleId: Value(arts[(i + k) % arts.length].id),
              articleName: arts[(i + k) % arts.length].name,
              qty: 1 + k,
              unitPriceCents: 3000,
            ));
      }
    }
    for (var i = 0; i < 2000; i++) {
      b.insert(
          db.stays,
          StaysCompanion.insert(
            id: Value(i + 1),
            uid: Value('s$i'),
            receiptNumber: 'FCT$i',
            generatedAt: Value(maintenant.subtract(Duration(hours: i * 8))),
            checkinAt: maintenant.subtract(Duration(hours: i * 8 + 30)),
            checkoutAt: maintenant.subtract(Duration(hours: i * 8)),
            guestFullName: 'Client $i',
            subtotalCents: 230000,
            statut: const Value(DbStayStatus.facture),
          ));
      b.insert(
          db.stayRooms,
          StayRoomsCompanion.insert(
            stayId: i + 1,
            roomNumber: '${i % 20}',
            roomType: 'Standard',
            checkinAt: maintenant.subtract(Duration(hours: i * 8 + 30)),
            checkoutAt: maintenant.subtract(Duration(hours: i * 8)),
            pricePerNightCents: 230000,
            nights: 1,
          ));
    }
    for (var i = 0; i < 1000; i++) {
      b.insert(
          db.clients,
          ClientsCompanion.insert(
              fullName: 'Client $i', phone: Value('+243 $i')));
    }
  });
  // ignore: avoid_print
  print('remplissage : ${sw.elapsedMilliseconds} ms');

  Future<void> mesure(String nom, Future<Object?> Function() f,
      {int fois = 5}) async {
    await f(); // à chaud
    final s = Stopwatch()..start();
    for (var i = 0; i < fois; i++) {
      await f();
    }
    // ignore: avoid_print
    print(
        '${nom.padRight(52)} ${(s.elapsedMicroseconds / fois / 1000).toStringAsFixed(1).padLeft(8)} ms');
  }

  final ventes = SalesRepo(db);
  final sejours = StaysRepo(db);
  test('banc', () async {
    await mesure('historique : ventes des 7 jours (+ lignes)',
        () => ventes.watchRecent().first);
    await mesure('tableau de bord : 7 derniers jours',
        () => MetricsRepo(db).watchLast7Days().first);
    await mesure('dettes en cours', () => ventes.watchOutstandingDebts().first);
    await mesure('historique hôtel : séjours 90 jours',
        () => sejours.watchRecent().first);
    await mesure('file des ventes : compte en attente (15 s)', () async {
      final s = db.sales;
      final q = db.selectOnly(s)
        ..addColumns([s.id.count()])
        ..where(s.syncedAt.isNull());
      return q.getSingle();
    });
    await mesure(
        'file des ventes : 40 plus anciennes en attente (15 s)',
        () => (db.select(db.sales)
              ..where((s) => s.syncedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.soldAt)])
              ..limit(40))
            .get());
    await mesure('synchro séjours : relit tous les séjours locaux (15 s)',
        () => db.select(db.stays).get());
    await mesure('synchro clients : 1000 fiches identiques (15 s)', () async {
      final rows = [
        for (final c in await db.select(db.clients).get())
          {
            'full_name': c.fullName,
            'phone': c.phone,
            'visits_count': c.visitsCount,
            'total_spent_cents': c.totalSpentCents,
            'last_seen_at': isoServeur(c.lastSeenAt),
          }
      ];
      return MirrorService.appliquerClientsDuServeur(db, rows);
    });
    await mesure(
        'consommations à facturer (départ)',
        () => ventes.unpaidForStay(
            sejourId: null,
            roomNumbers: ['3'],
            since: maintenant.subtract(const Duration(days: 30))));
  });

  tearDownAll(() async {
    await db.close();
    await dossier.delete(recursive: true);
  });
}
