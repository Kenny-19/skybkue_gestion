import 'dart:async';
import 'dart:convert';

import 'package:blue_sky/core/identite.dart';
import 'package:blue_sky/core/session_serveur.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/connexion_service.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:blue_sky/services/operations_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Les réservations ne quittaient pas le poste qui les prenait. Elles
// passent désormais par le serveur, qui refuse un chevauchement.

void main() {
  late AppDatabase db;
  late ConnexionService cx;
  final envoyees = <Map<String, dynamic>>[];
  var reponse = <String, dynamic>{'status': 'ok'};
  var coupe = false;

  Future<Map<String, dynamic>> appel(
      String type, Map<String, dynamic> p, String op, String s) async {
    if (coupe) throw TimeoutException('coupure');
    envoyees.add((p['reservation'] as Map).cast<String, dynamic>());
    return reponse;
  }

  ReservationsRepo repo() => ReservationsRepo(db,
      operations: OperationsService(db, appel: appel, connexion: cx));

  setUp(() async {
    db = newTestDb();
    cx = ConnexionService(db: db, envoyer: (_) async {});
    envoyees.clear();
    reponse = {'status': 'ok'};
    coupe = false;
    await SessionServeur.ouvrir(db, 'recep', 'jeton');
  });
  tearDown(() async {
    SessionServeur.quitter();
    await db.close();
  });

  Future<int> creer({String nom = 'Kabila'}) => repo().create(
        rooms: [(number: '15', pricePerNightCents: 230000)],
        guestFullName: nom,
        checkinDate: DateTime(2026, 12, 1, 14),
        checkoutDate: DateTime(2026, 12, 4, 11),
      );

  test('en ligne : le serveur reçoit la réservation complète', () async {
    final id = await creer();
    final r = await (db.select(db.reservations)..where((x) => x.id.equals(id)))
        .getSingle();
    expect(envoyees.single['uid'], r.uid);
    expect(envoyees.single['guest_full_name'], 'Kabila');
    expect((envoyees.single['rooms'] as List).single['number'], '15');
    expect(await db.select(db.operations).get(), isEmpty);
  });

  test('chevauchement refusé par le serveur : rien n\'est créé ici',
      () async {
    reponse = {
      'status': 'refuse',
      'motif': 'CHAMBRE_RESERVEE',
      'chambre': '15',
      'occupant': 'Mwamba'
    };
    await expectLater(creer(),
        throwsA(isA<OperationRefusee>()
            .having((e) => e.message, 'message', contains('déjà réservée'))));
    expect(await db.select(db.reservations).get(), isEmpty);
  });

  test('hors ligne : créée ici, envoyée au retour', () async {
    coupe = true;
    await creer();
    expect(await db.select(db.reservations).get(), hasLength(1));
    expect(await db.select(db.operations).get(), hasLength(1));
    coupe = false;
    await cx.signalerEnLigne();
    await OperationsService(db, appel: appel, connexion: cx).rejouer();
    expect(envoyees, hasLength(1));
  });

  test('annulation : l\'état complet part, statut annulé', () async {
    final id = await creer();
    await repo().cancel(id, 'client malade');
    expect(envoyees.last['status'], DbReservationStatus.cancelled.index);
    expect(envoyees.last['cancel_reason'], 'client malade');
  });

  group('relecture du serveur', () {
    Map<String, dynamic> serveur(String uid, String nom,
            {int statut = 1, String? supprimee}) =>
        {
          'uid': uid,
          'reservation_number': 'RSV-X',
          'created_at': '2026-11-20T10:00:00Z',
          'checkin_date': '2026-12-01T12:00:00Z',
          'checkout_date': '2026-12-04T09:00:00Z',
          'guest_full_name': nom,
          'status': statut,
          'deposit_cents': 0,
          'supprimee_le': supprimee,
        };
    Map<String, dynamic> chambre(String uid, String n) => {
          'uid': nouvelUid(),
          'reservation_uid': uid,
          'room_number': n,
          'price_per_night_cents': 230000,
        };

    test('une réservation prise ailleurs arrive, puis suit ses changements',
        () async {
      const u = 'resa-autre-poste';
      await MirrorService.appliquerReservationsDuServeur(
          db, [serveur(u, 'Ilunga')], [chambre(u, '16')]);
      var r = await db.select(db.reservations).getSingle();
      expect(r.guestFullName, 'Ilunga');
      expect((await db.select(db.reservationRooms).getSingle()).roomNumber,
          '16');

      await MirrorService.appliquerReservationsDuServeur(db,
          [serveur(u, 'Ilunga', statut: 3)], [chambre(u, '17')]);
      r = await db.select(db.reservations).getSingle();
      expect(r.status, DbReservationStatus.cancelled);
      expect((await db.select(db.reservationRooms).getSingle()).roomNumber,
          '17', reason: 'chambres remplacées');

      await MirrorService.appliquerReservationsDuServeur(db,
          [serveur(u, 'Ilunga', supprimee: '2026-11-21T10:00:00Z')], []);
      expect(await db.select(db.reservations).get(), isEmpty,
          reason: 'supprimée sur un autre poste');
    });

    test('une réservation qui attend au journal n\'est pas écrasée', () async {
      coupe = true;
      final id = await creer(nom: 'Local');
      final uid = (await (db.select(db.reservations)
                ..where((x) => x.id.equals(id)))
              .getSingle())
          .uid!;
      await MirrorService.appliquerReservationsDuServeur(
          db, [serveur(uid, 'Ancienne version')], []);
      expect((await db.select(db.reservations).getSingle()).guestFullName,
          'Local');
    });

    test('les réservations d\'avant le partage partent une seule fois',
        () async {
      await db.into(db.reservations).insert(ReservationsCompanion.insert(
            reservationNumber: 'RSV-ANCIENNE',
            checkinDate: DateTime(2026, 12, 10),
            checkoutDate: DateTime(2026, 12, 12),
            guestFullName: 'Ancien client',
          ));
      expect(await MirrorService.envoyerReservationsManquantes(db, {}), 1);
      expect(await MirrorService.envoyerReservationsManquantes(db, {}), 0,
          reason: 'déjà au journal');
      final op = await db.select(db.operations).getSingle();
      expect(jsonDecode(op.payload)['reservation']['guest_full_name'],
          'Ancien client');
    });
  });

  test('identité des fiches : mêmes formules que le serveur', () {
    // Valeurs calculées par PostgreSQL (sql/2026_11_identite_clients_payeurs.sql).
    expect(uidClient('Jean Kabila', null),
        '5a7bb48a-c0a5-3ff6-33da-9b4b0a2d615a');
    expect(uidClient('x', ' +243 99 '), '61462f7e-a8a8-9ca4-87df-4c75f5fb8502');
    expect(uidPayeur(' Gécamines'), '3f5b76b8-f867-48ab-3eff-41e5d18ed439');
    expect(uidClient('Élodie', ''), 'cf87aa90-7860-dae9-46b5-ad35347335e7');
    expect(uidPayeur('ÉCOLE ÇA'), '692b95e9-9213-f304-f3c0-aa1f99132401');
  });

  test('un client créé ici reçoit son identité tout de suite', () async {
    final c = await ClientsRepo(db).findOrCreate(fullName: 'Jean Kabila');
    expect(c.uid, uidClient('Jean Kabila', null));
  });
}
