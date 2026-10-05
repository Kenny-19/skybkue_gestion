import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Robustesse : la relecture du serveur (toutes les 15 s) n'écrase plus un
// changement fait ici et pas encore confirmé.
//
// Avant : un serveur en retard de quelques secondes — ou un envoi échoué
// au retour du réseau — remettait « libre » une chambre qu'on venait
// d'occuper, et supprimait une chambre créée ici qui n'était pas encore
// arrivée là-bas.

Map<String, dynamic> serveur(String n, {int statut = 0, String? client}) => {
      'number': n,
      'type': 'standard',
      'price_per_night_cents': 125000,
      'price_usd_cents': 5000,
      'status': statut,
      'current_guest': client,
    };

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final n in ['101', '102']) {
      await db.into(db.rooms).insert(RoomsCompanion.insert(
          number: n,
          type: 'standard',
          pricePerNightCents: 125000,
          status: DbRoomStatus.libre));
    }
  });
  tearDown(() => db.close());

  Future<Room> chambre(String n) =>
      (db.select(db.rooms)..where((r) => r.number.equals(n))).getSingle();
  Future<void> occuperIci(String n) =>
      (db.update(db.rooms)..where((r) => r.number.equals(n))).write(
          RoomsCompanion(
              status: const Value(DbRoomStatus.occupee),
              currentGuest: const Value('M. Kabila'),
              pendingSince: Value(DateTime.now())));

  test('une arrivée pas encore confirmée n\'est pas effacée', () async {
    await occuperIci('101');
    // Le serveur, en retard, dit encore « libre ».
    await MirrorService.appliquerChambresDuServeur(
        db, [serveur('101'), serveur('102')]);
    final r = await chambre('101');
    expect(r.status, DbRoomStatus.occupee);
    expect(r.currentGuest, 'M. Kabila');
  });

  test('une chambre non modifiée ici suit le serveur', () async {
    await MirrorService.appliquerChambresDuServeur(db, [
      serveur('101'),
      serveur('102', statut: DbRoomStatus.occupee.index, client: 'Autre poste'),
    ]);
    final r = await chambre('102');
    expect(r.status, DbRoomStatus.occupee);
    expect(r.currentGuest, 'Autre poste');
  });

  test('une chambre créée ici, pas encore envoyée, n\'est pas supprimée',
      () async {
    await db.into(db.rooms).insert(RoomsCompanion.insert(
        number: '201',
        type: 'suite',
        pricePerNightCents: 250000,
        status: DbRoomStatus.libre,
        pendingSince: Value(DateTime.now())));
    await MirrorService.appliquerChambresDuServeur(
        db, [serveur('101'), serveur('102')]);
    expect(
        await (db.select(db.rooms)..where((r) => r.number.equals('201')))
            .getSingleOrNull(),
        isNotNull);
  });

  test('une chambre supprimée sur le serveur disparaît ici', () async {
    await MirrorService.appliquerChambresDuServeur(db, [serveur('101')]);
    expect(
        await (db.select(db.rooms)..where((r) => r.number.equals('102')))
            .getSingleOrNull(),
        isNull);
  });

  test('une réponse vide ne touche à rien', () async {
    await MirrorService.appliquerChambresDuServeur(db, []);
    expect(await db.select(db.rooms).get(), hasLength(2));
  });
}
