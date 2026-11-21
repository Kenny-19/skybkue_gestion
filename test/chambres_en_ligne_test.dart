import 'dart:async';
import 'dart:convert';

import 'package:blue_sky/core/session_serveur.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/connexion_service.dart';
import 'package:blue_sky/services/operations_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// En ligne d'abord : le serveur valide arrivées, départs et statuts avant
// qu'ils soient appliqués ici. Hors ligne, ils sont appliqués ici, notés au
// journal, et renvoyés au retour du réseau.

/// Un serveur simulé : il tient l'occupation des chambres comme le vrai.
class _Serveur {
  final occupees = <String, String>{}; // chambre → heure d'arrivée
  final recues = <String>[];
  var coupe = false;

  Future<Map<String, dynamic>> appel(String type, Map<String, dynamic> p,
      String opId, String session) async {
    if (coupe) throw TimeoutException('coupure');
    recues.add(type);
    final chambres = (p['chambres'] as List).cast<Map>();
    for (final c in chambres) {
      final n = c['number'] as String;
      if (type == 'chambres:arrivee' && occupees.containsKey(n)) {
        return {'status': 'refuse', 'motif': 'CHAMBRE_OCCUPEE', 'chambre': n};
      }
      if (type == 'chambres:depart' &&
          occupees.containsKey(n) &&
          occupees[n] != c['checkin_at']) {
        return {'status': 'refuse', 'motif': 'AUTRE_OCCUPANT', 'chambre': n};
      }
    }
    for (final c in chambres) {
      final n = c['number'] as String;
      if (type == 'chambres:arrivee') occupees[n] = c['checkin_at'] as String;
      if (type == 'chambres:depart') occupees.remove(n);
    }
    return {'status': 'ok'};
  }
}

void main() {
  late AppDatabase db;
  late _Serveur serveur;
  late ConnexionService cx;
  late RoomsRepo chambres;

  setUp(() async {
    db = newTestDb();
    serveur = _Serveur();
    cx = ConnexionService(db: db, envoyer: (_) async {});
    chambres = RoomsRepo(db,
        operations:
            OperationsService(db, appel: serveur.appel, connexion: cx));
    await db.batch((b) {
      for (final n in ['15', '16']) {
        b.insert(
            db.rooms,
            RoomsCompanion.insert(
                number: n,
                type: 'Standard',
                pricePerNightCents: 230000,
                status: DbRoomStatus.libre));
      }
    });
    await SessionServeur.ouvrir(db, 'recep', 'jeton');
  });
  tearDown(() async {
    SessionServeur.quitter();
    await db.close();
  });

  Future<Room> chambre(String n) =>
      (db.select(db.rooms)..where((r) => r.number.equals(n))).getSingle();
  Future<List<Operation>> journal() => db.select(db.operations).get();
  final depart = DateTime.now().add(const Duration(days: 2));

  test('en ligne : validée par le serveur, appliquée ici, rien au journal',
      () async {
    await chambres.checkIn('15', 'Kabila', depart);
    expect(serveur.recues, ['chambres:arrivee']);
    expect((await chambre('15')).status, DbRoomStatus.occupee);
    expect(await journal(), isEmpty);
  });

  test('chambre prise sur un autre poste : refusée, RIEN ne change ici',
      () async {
    serveur.occupees['15'] = '2026-11-21T08:00:00.000Z';
    await expectLater(chambres.checkIn('15', 'Mwamba', depart),
        throwsA(isA<OperationRefusee>()
            .having((e) => e.message, 'message', contains('déjà occupée'))));
    final c = await chambre('15');
    expect(c.status, DbRoomStatus.libre);
    expect(c.currentStayId, isNull, reason: 'pas de séjour ouvert');
    expect(await db.select(db.stays).get(), isEmpty);
  });

  test('arrivée groupée : une seule opération, tout ou rien', () async {
    serveur.occupees['16'] = 'x';
    await expectLater(
        chambres.groupCheckIn(
            numbers: ['15', '16'], guest: 'Groupe', checkout: depart),
        throwsA(isA<OperationRefusee>()));
    expect((await chambre('15')).status, DbRoomStatus.libre,
        reason: 'la 16 refusée : la 15 non plus');
  });

  test('hors ligne : appliquée ici, notée, protégée, puis rejouée', () async {
    cx.signalerHorsLigne();
    await chambres.checkIn('15', 'Kabila', depart);
    final c = await chambre('15');
    expect(c.status, DbRoomStatus.occupee, reason: "l'hôtel ne s'arrête pas");
    expect(c.pendingSince, isNotNull,
        reason: 'la relecture du serveur ne doit pas l\'effacer');
    expect(serveur.recues, isEmpty);
    expect((await journal()).single.libelle, contains('Kabila'));

    await cx.signalerEnLigne();
    await OperationsService(db, appel: serveur.appel, connexion: cx).rejouer();
    expect(serveur.recues, ['chambres:arrivee']);
    expect((await journal()).single.envoyeeLe, isNotNull);
    expect((await chambre('15')).pendingSince, isNull);
    expect(serveur.occupees['15'], isoDe(c.checkinAt!));
  });

  test('hors ligne, prise ailleurs entre-temps : refus gardé « à régler »',
      () async {
    cx.signalerHorsLigne();
    await chambres.checkIn('15', 'Kabila', depart);
    serveur.occupees['15'] = 'autre poste';
    await cx.signalerEnLigne();
    final ops = OperationsService(db, appel: serveur.appel, connexion: cx);
    await ops.rejouer();
    final a = await ops.watchARegler().first;
    expect(a.single.motif, contains('déjà occupée'));
    expect((await chambre('15')).pendingSince, isNull,
        reason: "le serveur reprend la main sur l'état de la chambre");
    await ops.marquerReglee(a.single.opId);
    expect(await ops.watchARegler().first, isEmpty);
  });

  test('coupure PENDANT l\'appel : relais local, et poste marqué hors ligne',
      () async {
    serveur.coupe = true;
    await chambres.checkIn('15', 'Kabila', depart);
    expect(cx.estHorsLigne, isTrue);
    expect((await chambre('15')).status, DbRoomStatus.occupee);
    expect(await journal(), hasLength(1));
  });

  test('sans session serveur : relais local, en attente d\'une connexion',
      () async {
    SessionServeur.quitter();
    await chambres.checkIn('15', 'Kabila', depart);
    expect(serveur.recues, isEmpty);
    expect(await journal(), hasLength(1));
  });

  test('le départ présente l\'heure d\'arrivée exacte : accepté', () async {
    await chambres.checkIn('15', 'Kabila', depart);
    await chambres.checkOut('15');
    expect(serveur.recues, ['chambres:arrivee', 'chambres:depart']);
    expect((await chambre('15')).status, DbRoomStatus.nettoyage);
    expect(serveur.occupees, isEmpty);
  });

  test('l\'ordre du journal est respecté : arrivée puis départ', () async {
    cx.signalerHorsLigne();
    await chambres.checkIn('15', 'Kabila', depart);
    await chambres.checkOut('15');
    final j = await journal();
    expect(j.map((o) => o.type), ['chambres:arrivee', 'chambres:depart']);
    final p = jsonDecode(j.last.payload) as Map;
    expect((p['chambres'] as List).single['checkin_at'], isNotNull);
    await cx.signalerEnLigne();
    await OperationsService(db, appel: serveur.appel, connexion: cx).rejouer();
    expect(serveur.recues, ['chambres:arrivee', 'chambres:depart']);
    expect(serveur.occupees, isEmpty);
  });
}

String isoDe(DateTime d) => d.toUtc().toIso8601String();
