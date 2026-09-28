import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/features/rooms/today_board.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// La chaîne complète du compteur « Arrivées » : requête en base, puis
// calcul de la journée.
//
// `today_board_test.dart` couvre déjà le calcul à partir de listes en
// mémoire. Ce qui n'était PAS testé, c'est `watchUpcoming()` — la
// requête qui alimente le bandeau. Un compteur bloqué à zéro viendrait
// de là, et personne ne le verrait : sur la base de production il n'y a
// aucune arrivée du jour, donc zéro est la bonne réponse et masque un
// éventuel défaut.

void main() {
  late AppDatabase db;
  late ReservationsRepo repo;

  setUp(() {
    db = newTestDb();
    repo = ReservationsRepo(db);
  });
  tearDown(() => db.close());

  Future<int> creerResa({
    required String client,
    required DateTime arrivee,
    DbReservationStatus statut = DbReservationStatus.confirmed,
  }) async {
    final id = await db.into(db.reservations).insert(
          ReservationsCompanion.insert(
            reservationNumber: 'R-$client-${arrivee.millisecondsSinceEpoch}',
            checkinDate: arrivee,
            checkoutDate: arrivee.add(const Duration(days: 2)),
            guestFullName: client,
            status: Value(statut),
          ),
        );
    await db.into(db.reservationRooms).insert(
          ReservationRoomsCompanion.insert(
            reservationId: id,
            roomNumber: '12',
            pricePerNightCents: 60000,
          ),
        );
    return id;
  }

  DateTime aujourdhui() {
    final n = DateTime.now();
    // 14 h : au milieu de la journée, pour ne pas basculer sur un
    // fuseau ou un passage de minuit pendant le test.
    return DateTime(n.year, n.month, n.day, 14);
  }

  group("Le compteur « Arrivées » du bandeau du jour", () {
    test('une réservation du jour est comptée', () async {
      await creerResa(client: 'Mwamba', arrivee: aujourdhui());
      final resas = await repo.watchUpcoming().first;
      final board = TodayBoard.from(
          rooms: const [], reservations: resas, now: DateTime.now());
      expect(board.count(RoomTask.arrivees), 1,
          reason: 'la chaîne requête → bandeau doit la faire remonter');
      expect(board.arrivees.single.reservation.guestFullName, 'Mwamba');
    });

    test('la chambre réservée sert à filtrer la grille', () async {
      await creerResa(client: 'Kalala', arrivee: aujourdhui());
      final resas = await repo.watchUpcoming().first;
      final board = TodayBoard.from(
          rooms: const [], reservations: resas, now: DateTime.now());
      expect(board.roomNumbersFor(RoomTask.arrivees), {'12'});
    });

    test('une réservation annulée n\'est jamais comptée', () async {
      // Le cas réel de la base de production : la seule réservation
      // existante est annulée, et datée du 3 septembre.
      await creerResa(
          client: 'Lionel',
          arrivee: aujourdhui(),
          statut: DbReservationStatus.cancelled);
      final resas = await repo.watchUpcoming().first;
      final board = TodayBoard.from(
          rooms: const [], reservations: resas, now: DateTime.now());
      expect(board.count(RoomTask.arrivees), 0);
    });

    test('une réservation déjà arrivée ne compte plus', () async {
      await creerResa(
          client: 'Grace',
          arrivee: aujourdhui(),
          statut: DbReservationStatus.checkedIn);
      final resas = await repo.watchUpcoming().first;
      final board = TodayBoard.from(
          rooms: const [], reservations: resas, now: DateTime.now());
      expect(board.count(RoomTask.arrivees), 0);
    });

    test('une réservation passée ne remonte pas', () async {
      await creerResa(
          client: 'Ancien',
          arrivee: aujourdhui().subtract(const Duration(days: 18)));
      final resas = await repo.watchUpcoming().first;
      expect(resas, isEmpty,
          reason: 'watchUpcoming ne renvoie que le présent et le futur');
    });

    test('une réservation de demain est chargée mais pas comptée', () async {
      // Elle doit remonter de la base (l'écran Réservations la montre)
      // sans polluer le compteur du jour.
      await creerResa(
          client: 'Demain', arrivee: aujourdhui().add(const Duration(days: 1)));
      final resas = await repo.watchUpcoming().first;
      expect(resas.length, 1);
      final board = TodayBoard.from(
          rooms: const [], reservations: resas, now: DateTime.now());
      expect(board.count(RoomTask.arrivees), 0);
    });
  });
}
