import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/features/rooms/today_board.dart';
import 'package:flutter_test/flutter_test.dart';

// La journée de la réception est une règle métier, pas une affaire
// d'affichage. Elle se teste donc sans widget et sans base.

/// L'instant où l'horloge de LUBUMBASHI affiche cette heure-là.
///
/// Indispensable pour que ces tests disent la même chose partout : la
/// machine de développement est réglée sur UTC−5, les postes du terrain
/// sur UTC+2. Écrire `DateTime(2026, 9, 15, 23, 59)` désignerait deux
/// instants différents — et à 23 h 59 sur UTC−5, il est déjà le 16 à
/// Lubumbashi, donc la journée de réception a bel et bien tourné.
DateTime _lushi(int jour, [int h = 0, int min = 0]) =>
    DateTime.utc(2026, 9, jour, h, min)
        .subtract(const Duration(hours: 2))
        .toLocal();

final _now = _lushi(15, 9, 30); // un mardi, 9 h 30
DateTime _jour(int d) => _lushi(d);

Room _room(
  String number, {
  DbRoomStatus status = DbRoomStatus.libre,
  DateTime? checkout,
}) =>
    Room(
      number: number,
      type: 'Standard',
      // 26 USD, soit 60 000 FC au taux par défaut. Le dollar est la
      // source du tarif depuis que l'hôtel facture dans cette devise.
      priceUsdCents: 2600,
      pricePerNightCents: 60000,
      status: status,
      currentGuest: status == DbRoomStatus.occupee ? 'Client' : null,
      checkoutDate: checkout,
      checkinNote: null,
      checkinAt: null,
      stayGroup: null,
      payerId: null,
      imagePath: null,
      negotiatedPriceCents: null,
    );

ReservationWithRooms _resa(
  String guest, {
  required DateTime checkin,
  DbReservationStatus status = DbReservationStatus.confirmed,
  List<String> rooms = const ['1'],
}) =>
    ReservationWithRooms(
      Reservation(
        id: guest.hashCode.abs() % 9999,
        reservationNumber: 'R-$guest',
        createdAt: _jour(1),
        checkinDate: checkin,
        checkoutDate: checkin.add(const Duration(days: 2)),
        guestFullName: guest,
        guestPhone: null,
        guestEmail: null,
        payerId: null,
        status: status,
        depositCents: 0,
        note: null,
        createdByLogin: null,
        cancelledAt: null,
        cancelReason: null,
        stayId: null,
      ),
      [
        for (final r in rooms)
          ReservationRoom(
            id: r.hashCode.abs() % 9999,
            reservationId: 1,
            roomNumber: r,
            pricePerNightCents: 60000,
          ),
      ],
    );

TodayBoard _board({
  List<Room> rooms = const [],
  List<ReservationWithRooms> resas = const [],
  DateTime? now,
}) =>
    TodayBoard.from(rooms: rooms, reservations: resas, now: now ?? _now);

void main() {
  group('Arrivées du jour', () {
    test('une réservation qui commence aujourd\'hui est attendue', () {
      final b = _board(resas: [_resa('Mwamba', checkin: _jour(15))]);
      expect(b.count(RoomTask.arrivees), 1);
    });

    test('une réservation de demain ne pollue pas la journée', () {
      final b = _board(resas: [_resa('Mwamba', checkin: _jour(16))]);
      expect(b.count(RoomTask.arrivees), 0);
    });

    test('une réservation déjà arrivée n\'attend plus personne', () {
      final b = _board(resas: [
        _resa('Mwamba',
            checkin: _jour(15), status: DbReservationStatus.checkedIn),
      ]);
      expect(b.count(RoomTask.arrivees), 0);
    });

    test('annulée et no-show sont écartées', () {
      final b = _board(resas: [
        _resa('A', checkin: _jour(15), status: DbReservationStatus.cancelled),
        _resa('B', checkin: _jour(15), status: DbReservationStatus.noShow),
      ]);
      expect(b.count(RoomTask.arrivees), 0);
    });

    test('une réservation en attente compte quand même', () {
      // Non confirmée mais attendue : la réception doit la voir arriver.
      final b = _board(resas: [
        _resa('C', checkin: _jour(15), status: DbReservationStatus.pending),
      ]);
      expect(b.count(RoomTask.arrivees), 1);
    });

    test('l\'heure de la journée ne change rien', () {
      // Piège classique : comparer des DateTime complets au lieu des
      // jours. À 23 h 59 comme à 00 h 01, l\'arrivée du jour est la même.
      for (final h in [0, 9, 23]) {
        final b = _board(
          resas: [_resa('Mwamba', checkin: _lushi(15, 14))],
          now: _lushi(15, h, 59),
        );
        expect(b.count(RoomTask.arrivees), 1, reason: 'à ${h}h');
      }
    });
  });

  group('Départs et retards', () {
    test('un départ prévu aujourd\'hui est un départ, pas un retard', () {
      final b = _board(rooms: [
        _room('12', status: DbRoomStatus.occupee, checkout: _jour(15)),
      ]);
      expect(b.count(RoomTask.departs), 1);
      expect(b.count(RoomTask.retards), 0);
    });

    test('un départ dépassé bascule en retard', () {
      final b = _board(rooms: [
        _room('12', status: DbRoomStatus.occupee, checkout: _jour(13)),
      ]);
      expect(b.count(RoomTask.retards), 1);
      expect(b.count(RoomTask.departs), 0);
    });

    test('les retards sortent du plus ancien au plus récent', () {
      final b = _board(rooms: [
        _room('5', status: DbRoomStatus.occupee, checkout: _jour(14)),
        _room('3', status: DbRoomStatus.occupee, checkout: _jour(10)),
        _room('9', status: DbRoomStatus.occupee, checkout: _jour(12)),
      ]);
      expect(b.retards.map((r) => r.number), ['3', '9', '5']);
    });

    test('une chambre libre n\'a ni départ ni retard', () {
      final b = _board(rooms: [_room('1', checkout: _jour(10))]);
      expect(b.count(RoomTask.departs), 0);
      expect(b.count(RoomTask.retards), 0);
    });

    test('une chambre occupée sans date de départ est ignorée', () {
      // Séjour ouvert : rien à réclamer tant qu'aucune date n\'est posée.
      final b = _board(
          rooms: [_room('7', status: DbRoomStatus.occupee, checkout: null)]);
      expect(b.count(RoomTask.departs), 0);
      expect(b.count(RoomTask.retards), 0);
    });
  });

  group('Ménage', () {
    test('les chambres en nettoyage sont listées', () {
      final b = _board(rooms: [
        _room('2', status: DbRoomStatus.nettoyage),
        _room('4', status: DbRoomStatus.nettoyage),
        _room('6', status: DbRoomStatus.maintenance),
      ]);
      expect(b.count(RoomTask.nettoyage), 2);
      expect(b.nettoyage.map((r) => r.number), ['2', '4']);
    });

    test('une chambre en nettoyage ne compte pas deux fois', () {
      // Elle porte encore une ancienne date de départ dépassée : elle ne
      // doit pas apparaître aussi en retard.
      final b = _board(rooms: [
        _room('2', status: DbRoomStatus.nettoyage, checkout: _jour(10)),
      ]);
      expect(b.count(RoomTask.nettoyage), 1);
      expect(b.count(RoomTask.retards), 0);
    });
  });

  group('Journée vide', () {
    test('sans rien à faire, le tableau le dit', () {
      final b = _board(rooms: [_room('1'), _room('2')]);
      expect(b.isClear, true);
    });

    test('un seul retard suffit à réveiller la journée', () {
      final b = _board(rooms: [
        _room('1'),
        _room('12', status: DbRoomStatus.occupee, checkout: _jour(13)),
      ]);
      expect(b.isClear, false);
    });
  });

  group('Filtrage de la grille', () {
    test('cliquer sur Arrivées cible les chambres réservées', () {
      final b = _board(resas: [
        _resa('Mwamba', checkin: _jour(15), rooms: ['3', '4']),
        _resa('Kalala', checkin: _jour(15), rooms: ['7']),
      ]);
      expect(b.roomNumbersFor(RoomTask.arrivees), {'3', '4', '7'});
    });

    test('cliquer sur En retard cible les chambres en retard', () {
      final b = _board(rooms: [
        _room('5', status: DbRoomStatus.occupee, checkout: _jour(14)),
        _room('8', status: DbRoomStatus.occupee, checkout: _jour(15)),
      ]);
      expect(b.roomNumbersFor(RoomTask.retards), {'5'});
      expect(b.roomNumbersFor(RoomTask.departs), {'8'});
    });

    test('une catégorie vide ne filtre rien du tout', () {
      expect(TodayBoard.empty.roomNumbersFor(RoomTask.arrivees), isEmpty);
    });
  });

  group('Urgence', () {
    test('seul le retard est signalé comme urgent', () {
      expect(RoomTask.retards.isUrgent, true);
      expect(RoomTask.arrivees.isUrgent, false);
      expect(RoomTask.departs.isUrgent, false);
      expect(RoomTask.nettoyage.isUrgent, false);
    });

    test('chaque catégorie sait quoi dire quand elle est vide', () {
      for (final t in RoomTask.values) {
        expect(t.emptyLabel, isNotEmpty);
        expect(t.label, isNotEmpty);
      }
    });
  });
}
