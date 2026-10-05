import 'dart:io';

import 'package:blue_sky/core/identite.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Sprint de refonte, priorité 2 : le séjour existe dès l'arrivée.
//
// Avant : le séjour n'était créé qu'au départ. Pendant le séjour, tout
// tenait dans des colonnes de la chambre, vidées au départ ; « Libérer
// sans facture » ne laissait aucune trace ; les consommations étaient
// retrouvées par numéro de chambre tapé.

void main() {
  late AppDatabase db;
  late RoomsRepo chambres;
  late StaysRepo sejours;
  late SalesRepo ventes;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    chambres = RoomsRepo(db);
    sejours = StaysRepo(db);
    ventes = SalesRepo(db);
    for (final n in ['101', '102', '103']) {
      await db.into(db.rooms).insert(RoomsCompanion.insert(
          number: n,
          type: 'standard',
          pricePerNightCents: 125000,
          priceUsdCents: const Value(5000),
          status: DbRoomStatus.libre));
    }
  });
  tearDown(() => db.close());

  Future<Room> chambre(String n) =>
      (db.select(db.rooms)..where((r) => r.number.equals(n))).getSingle();
  Future<Stay> sejour(int id) =>
      (db.select(db.stays)..where((s) => s.id.equals(id))).getSingle();
  Future<List<StayRoom>> chambresDu(int id) =>
      (db.select(db.stayRooms)..where((r) => r.stayId.equals(id))).get();
  Future<int> venteSurChambre(String n) async {
    final article = await db.into(db.articles).insert(ArticlesCompanion.insert(
        name: 'Simba $n', priceCents: 5000, category: DbCategory.boissons));
    return ventes.createSale(
      articleQuantities: {article: 2},
      payment: DbPayment.cash,
      location: DbLocation.hotel,
      serverUserId: null,
      roomNumber: n,
      onCredit: true,
    );
  }

  Future<int> fermer(int? sejourId, List<Room> cibles) => sejours.cloturer(
        sejourId: sejourId,
        chambres: cibles.map((r) => r.number).toList(),
        receiptNumber: 'FCT1/10/2026',
        generatedAt: DateTime.now(),
        checkinAt: cibles.first.checkinAt!,
        checkoutAt: DateTime.now(),
        guestFullName: cibles.first.currentGuest!,
        subtotalCents: 250000,
        rooms: [
          for (final r in cibles)
            (
              number: r.number,
              type: r.type,
              checkinAt: r.checkinAt!,
              checkoutAt: DateTime.now(),
              pricePerNightCents: 125000,
              listPriceCents: 125000,
              nights: 2,
            )
        ],
      );

  test('l\'arrivée crée le séjour, en cours, relié à la chambre', () async {
    final id = await chambres.checkIn(
        '101', 'M. Kabila', DateTime.now().add(const Duration(days: 2)));
    final s = await sejour(id);
    expect(s.statut, DbStayStatus.enCours);
    expect(s.guestFullName, 'M. Kabila');
    expect((await chambre('101')).currentStayId, id);
    expect(await chambresDu(id), hasLength(1));
    // Pas encore de facture : absent de l'historique de l'hôtel.
    expect(await sejours.allRecent(), isEmpty);
  });

  test('une consommation sur la chambre est rattachée au séjour', () async {
    final id = await chambres.checkIn(
        '101', 'M. Kabila', DateTime.now().add(const Duration(days: 2)));
    final venteId = await venteSurChambre('101');
    final v = await (db.select(db.sales)..where((s) => s.id.equals(venteId)))
        .getSingle();
    expect(v.stayId, id);
    final dues = await ventes.unpaidForStay(
        sejourId: id, roomNumbers: ['101'], since: DateTime(2000));
    expect(dues.map((e) => e.sale.id), [venteId]);
  });

  test('la note du client précédent n\'est pas reprise', () async {
    // Premier client : consomme, part SANS régler sa note.
    final premier = await chambres.checkIn(
        '101', 'Premier', DateTime.now().add(const Duration(days: 1)));
    final ancienne = await venteSurChambre('101');
    await sejours.libererSansFacture(
        sejourId: premier, chambres: [await chambre('101')]);
    await chambres.checkOut('101');
    // Second client dans la même chambre.
    final second = await chambres.checkIn(
        '101', 'Second', DateTime.now().add(const Duration(days: 1)));
    final dues = await ventes.unpaidForStay(
        sejourId: second, roomNumbers: ['101'], since: DateTime(2000));
    expect(dues.map((e) => e.sale.id), isNot(contains(ancienne)));
  });

  test('le départ clôture le séjour existant, sans en créer un autre',
      () async {
    final id = await chambres.checkIn(
        '101', 'M. Kabila', DateTime.now().add(const Duration(days: 2)));
    final ferme = await fermer(id, [await chambre('101')]);
    expect(ferme, id);
    final s = await sejour(id);
    expect(s.statut, DbStayStatus.facture);
    expect(s.receiptNumber, 'FCT1/10/2026');
    expect(s.subtotalCents, 250000);
    expect((await chambresDu(id)).single.nights, 2);
    expect(await db.select(db.stays).get(), hasLength(1));
    expect(await sejours.allRecent(), hasLength(1));
  });

  test('départ d\'une chambre d\'un groupe : sa facture, le reste en cours',
      () async {
    final groupe = await chambres.groupCheckIn(
        numbers: ['101', '102'],
        guest: 'ONG Espoir',
        checkout: DateTime.now().add(const Duration(days: 3)));
    expect((await chambre('101')).currentStayId, groupe);
    expect((await chambre('102')).currentStayId, groupe);
    final venteA = await venteSurChambre('101');

    final ferme = await fermer(groupe, [await chambre('101')]);
    expect(ferme, isNot(groupe), reason: 'détachée dans son propre séjour');
    expect((await sejour(ferme)).statut, DbStayStatus.facture);
    expect((await chambresDu(ferme)).map((r) => r.roomNumber), ['101']);
    expect((await sejour(groupe)).statut, DbStayStatus.enCours);
    expect((await chambresDu(groupe)).map((r) => r.roomNumber), ['102']);
    // La consommation de la 101 part avec sa chambre.
    final v = await (db.select(db.sales)..where((s) => s.id.equals(venteA)))
        .getSingle();
    expect(v.stayId, ferme);
  });

  test('« libérer sans facture » laisse une trace', () async {
    final id = await chambres.checkIn(
        '101', 'M. Kabila', DateTime.now().add(const Duration(days: 2)));
    await sejours
        .libererSansFacture(sejourId: id, chambres: [await chambre('101')]);
    await chambres.checkOut('101');
    final s = await sejour(id);
    expect(s.statut, DbStayStatus.sansFacture);
    expect((await chambre('101')).currentStayId, isNull);
    expect(await sejours.allRecent(), isEmpty,
        reason: 'pas de facture à réimprimer');
  });

  test('départ fait sur un autre poste : seule CETTE chambre est clôturée',
      () async {
    final groupe = await chambres.groupCheckIn(
        numbers: ['101', '102'],
        guest: 'ONG Espoir',
        checkout: DateTime.now().add(const Duration(days: 3)));
    // La 101 a été libérée sur un autre poste : la synchronisation l'a
    // remise libre ici, sans toucher au séjour local.
    await (db.update(db.rooms)..where((r) => r.number.equals('101'))).write(
        const RoomsCompanion(
            status: Value(DbRoomStatus.libre), currentStayId: Value(null)));
    // Nouveau client dans la 101.
    final nouveau = await chambres.checkIn(
        '101', 'Nouveau', DateTime.now().add(const Duration(days: 1)));
    expect((await sejour(groupe)).statut, DbStayStatus.enCours,
        reason: 'la 102 est toujours occupée');
    expect((await chambresDu(groupe)).map((r) => r.roomNumber), ['102']);
    final enCours101 = await (db.select(db.stays)
          ..where((s) => s.statut.equals(DbStayStatus.enCours.index)))
        .get();
    expect(enCours101.map((s) => s.id), containsAll([groupe, nouveau]));
    expect(enCours101, hasLength(2));
  });

  test('migration : une chambre occupée avant la v27 reçoit son séjour',
      () async {
    final dir = Directory.systemTemp.createTempSync('bs_v26');
    final path = '${dir.path}/v26.db';
    // Une base au schéma v26 complet, avec une chambre occupée « à
    // l'ancienne » : l'occupant dans la chambre, aucun séjour.
    final ancienne = AppDatabase.forTesting(NativeDatabase(File(path)));
    await ancienne.into(ancienne.rooms).insert(RoomsCompanion.insert(
        number: '201',
        type: 'suite',
        pricePerNightCents: 250000,
        status: DbRoomStatus.occupee,
        currentGuest: const Value('Mme Lumumba'),
        checkinAt: Value(DateTime(2026, 10, 3, 14)),
        checkoutDate: Value(DateTime(2026, 10, 6, 11))));
    // Remet la base dans l'état v26 : séjour absent, version 26.
    await ancienne.customStatement('DELETE FROM stay_rooms');
    await ancienne.customStatement('DELETE FROM stays');
    await ancienne.customStatement('UPDATE rooms SET current_stay_id = NULL');
    await ancienne.customStatement('PRAGMA user_version = 26');
    await ancienne.close();

    final migree = AppDatabase.forTesting(NativeDatabase(File(path)));
    final r = await (migree.select(migree.rooms)
          ..where((x) => x.number.equals('201')))
        .getSingle();
    expect(r.currentStayId, isNotNull);
    final s = await (migree.select(migree.stays)
          ..where((x) => x.id.equals(r.currentStayId!)))
        .getSingle();
    expect(s.statut, DbStayStatus.enCours);
    expect(s.guestFullName, 'Mme Lumumba');
    await migree.close();
    dir.deleteSync(recursive: true);
  });

  test('séjour hérité : même uid que le serveur', () {
    // Valeurs calculées par PostgreSQL avec sql/2026_10_identite_sejours.sql.
    final u = uidSejourHerite(
        7, DateTime.fromMillisecondsSinceEpoch(1790572508 * 1000));
    expect(u, '10d3bd48-9da2-4e8c-fa20-e74e6feba2ed');
    expect(uidLigneHerite(u, 20), '5158fa6a-55c0-b98c-97c7-2081b35c9e24');
  });

  test('une ancienne base sans les colonnes v27 s\'ouvre', () async {
    // Garde-fou : la v26 ne connaît ni statut ni current_stay_id.
    final dir = Directory.systemTemp.createTempSync('bs_v26b');
    final raw = sqlite3.open('${dir.path}/b.db');
    raw.execute('''
      CREATE TABLE rooms (number TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,
        price_per_night_cents INTEGER NOT NULL, status INTEGER NOT NULL,
        current_guest TEXT, checkout_date INTEGER, checkin_at INTEGER);
      INSERT INTO rooms VALUES ('301', 'standard', 100000, 1, 'Client', NULL, NULL);
    ''');
    raw.execute('PRAGMA user_version = 26');
    raw.dispose();
    final d = AppDatabase.forTesting(NativeDatabase(File('${dir.path}/b.db')));
    final r = await (d.select(d.rooms)..where((x) => x.number.equals('301')))
        .getSingle();
    expect(r.currentStayId, isNotNull);
    await d.close();
    dir.deleteSync(recursive: true);
  });
}
