import '../../core/temps.dart';
import '../../data/database.dart';
import '../../data/repos.dart';
import '../../data/schema.dart';

// Ce que la réception a à faire aujourd'hui.
//
// L'écran Chambres montrait un état : 19 cartes, triées par numéro, et
// un bandeau pour les retards. Il fallait le lire en entier pour savoir
// quoi faire, et aller dans l'onglet Réservations pour savoir qui
// arrivait. La journée était éclatée sur deux écrans.
//
// Ce fichier calcule la journée en une passe, sans interface, pour que
// la règle « qu'est-ce qui demande une action maintenant » soit testable
// et ne dépende pas d'un widget.

/// Les quatre choses qui appellent une action dans une journée d'hôtel.
enum RoomTask {
  /// Réservations attendues aujourd'hui, pas encore arrivées.
  arrivees,

  /// Chambres occupées dont le départ est prévu aujourd'hui.
  departs,

  /// Départ dépassé : le client aurait dû partir hier ou avant.
  retards,

  /// Chambres libérées qui attendent le ménage.
  nettoyage,
}

extension RoomTaskX on RoomTask {
  String get label => switch (this) {
        RoomTask.arrivees => 'Arrivées',
        RoomTask.departs => 'Départs',
        RoomTask.retards => 'En retard',
        RoomTask.nettoyage => 'À nettoyer',
      };

  /// Ce qu'on affiche quand il n'y a rien à faire dans cette catégorie —
  /// un compteur à zéro doit rassurer, pas rester muet.
  String get emptyLabel => switch (this) {
        RoomTask.arrivees => 'Aucune arrivée prévue',
        RoomTask.departs => 'Aucun départ prévu',
        RoomTask.retards => 'Aucun retard',
        RoomTask.nettoyage => 'Rien à nettoyer',
      };

  /// Une tâche urgente se signale, les autres informent.
  bool get isUrgent => this == RoomTask.retards;
}

/// L'état de la journée, calculé en une fois à partir des chambres et
/// des réservations.
class TodayBoard {
  /// Réservations attendues aujourd'hui, pas encore arrivées.
  final List<ReservationWithRooms> arrivees;

  /// Chambres dont le départ est prévu aujourd'hui.
  final List<Room> departs;

  /// Chambres dont le départ est dépassé.
  final List<Room> retards;

  /// Chambres en attente de ménage.
  final List<Room> nettoyage;

  const TodayBoard({
    required this.arrivees,
    required this.departs,
    required this.retards,
    required this.nettoyage,
  });

  static const empty =
      TodayBoard(arrivees: [], departs: [], retards: [], nettoyage: []);

  int count(RoomTask t) => switch (t) {
        RoomTask.arrivees => arrivees.length,
        RoomTask.departs => departs.length,
        RoomTask.retards => retards.length,
        RoomTask.nettoyage => nettoyage.length,
      };

  /// Vrai quand la journée ne demande aucune action.
  bool get isClear => RoomTask.values.every((t) => count(t) == 0);

  /// Calcule la journée.
  ///
  /// [now] est injecté plutôt que lu de l'horloge : c'est ce qui rend la
  /// règle testable, et ça évite qu'un calcul à cheval sur minuit dépende
  /// du moment où le widget se reconstruit.
  static TodayBoard from({
    required List<Room> rooms,
    required List<ReservationWithRooms> reservations,
    required DateTime now,
  }) {
    final today = _day(now);

    final arrivees = <ReservationWithRooms>[];
    for (final r in reservations) {
      // Une réservation déjà honorée ou annulée n'attend plus personne.
      final s = r.reservation.status;
      if (s == DbReservationStatus.checkedIn ||
          s == DbReservationStatus.cancelled ||
          s == DbReservationStatus.noShow) {
        continue;
      }
      if (_day(r.reservation.checkinDate) == today) arrivees.add(r);
    }

    final departs = <Room>[];
    final retards = <Room>[];
    final nettoyage = <Room>[];
    for (final room in rooms) {
      if (room.status == DbRoomStatus.nettoyage) {
        nettoyage.add(room);
        continue;
      }
      if (room.status != DbRoomStatus.occupee) continue;
      final out = room.checkoutDate;
      if (out == null) continue;
      final day = _day(out);
      if (day.isBefore(today)) {
        retards.add(room);
      } else if (day == today) {
        departs.add(room);
      }
    }

    // Les retards d'abord les plus anciens : c'est l'ordre dans lequel
    // la réception doit les traiter.
    retards.sort((a, b) => a.checkoutDate!.compareTo(b.checkoutDate!));
    departs.sort((a, b) => a.number.compareTo(b.number));
    nettoyage.sort((a, b) => a.number.compareTo(b.number));
    arrivees.sort((a, b) =>
        a.reservation.guestFullName.compareTo(b.reservation.guestFullName));

    return TodayBoard(
      arrivees: arrivees,
      departs: departs,
      retards: retards,
      nettoyage: nettoyage,
    );
  }

  /// Les numéros de chambre concernés par [task] — sert à filtrer la
  /// grille quand la réception clique sur un compteur.
  ///
  /// Pour les arrivées, ce sont les chambres réservées : elles sont
  /// encore libres, et ce sont celles qu'il faut préparer.
  Set<String> roomNumbersFor(RoomTask task) => switch (task) {
        RoomTask.arrivees => {
            for (final r in arrivees)
              for (final room in r.rooms) room.roomNumber,
          },
        RoomTask.departs => {for (final r in departs) r.number},
        RoomTask.retards => {for (final r in retards) r.number},
        RoomTask.nettoyage => {for (final r in nettoyage) r.number},
      };

  /// La journée commerciale de Lubumbashi contenant [d].
  ///
  /// Pas la journée de l'horloge du poste : un poste mal réglé n'a
  /// pas le droit de déplacer la frontière entre deux jours.
  static DateTime _day(DateTime d) => debutDeJourneeLubumbashi(d);
}
