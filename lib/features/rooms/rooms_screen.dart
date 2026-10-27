import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../core/cat_ui.dart';
import '../../core/temps.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import 'today_board.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'checkin_dialogs.dart';
import 'checkout_flow.dart';
import 'hotel_supply_dialog.dart';
import 'room_card.dart';
import 'room_edit_dialog.dart';
import 'today_band.dart';

/// Catégorie sélectionnée dans le bandeau du jour. `null` = tout voir.
///
/// Un provider plutôt qu'un état de widget : la sélection survit à un
/// rafraîchissement du flux des chambres, qui arrive à chaque check-in.
final _taskFilterProvider = StateProvider.autoDispose<RoomTask?>((ref) => null);

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roomsStreamProvider);
    final perms = ref.watch(permsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'rooms_screen')),
      data: (rooms) {
        final counts = {
          for (final s in DbRoomStatus.values)
            s: rooms.where((r) => r.status == s).length,
        };

        // Les réservations alimentent les arrivées du jour. On ne bloque
        // JAMAIS le plan des chambres dessus : si le flux n'est pas
        // encore arrivé, la journée s'affiche sans les arrivées plutôt
        // que de laisser la réception devant un écran vide.
        final board = TodayBoard.from(
          rooms: rooms,
          reservations:
              ref.watch(upcomingReservationsProvider).valueOrNull ?? const [],
          now: DateTime.now(),
        );
        final selected = ref.watch(_taskFilterProvider);
        final visible = selected == null
            ? rooms
            : rooms
                .where((r) => board.roomNumbersFor(selected).contains(r.number))
                .toList();

        // Un seul défilement en slivers : la grille ne construit que les
        // cartes à l'écran. Avant, `GridView(shrinkWrap: true)` dans un
        // `SingleChildScrollView` les construisait toutes, à chaque
        // mise à jour des chambres.
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                eyebrow: 'Chambres',
                title: "Plan d'occupation",
                subtitle:
                    '${counts[DbRoomStatus.occupee]} occupées · ${counts[DbRoomStatus.libre]} libres · ${counts[DbRoomStatus.nettoyage]} en nettoyage',
                actions: [
                  // Reception + admin + super admin peuvent demander un
                  // ravitaillement pour l'hotel (chambre = besoin en
                  // eau, cafe, savon, kits accueil, etc.).
                  if (perms.canRooms)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.forward_to_inbox, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BsColors.sunrise,
                        side: const BorderSide(color: BsColors.sunrise),
                      ),
                      onPressed: () => showHotelSupplyRequest(context, ref),
                      label: const Text('Demander ravitaillement'),
                    ),
                  if (perms.canRooms) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.group_add, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BsColors.sky,
                        side: const BorderSide(color: BsColors.sky),
                      ),
                      onPressed: () => showGroupCheckIn(context, ref, rooms),
                      label: const Text('Check-in groupé'),
                    ),
                  ],
                  if (perms.canEditRooms) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () =>
                          showRoomDialog(context, ref, existing: null),
                      label: const Text('Nouvelle chambre'),
                    ),
                  ],
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    BsSpace.xl, 0, BsSpace.xl, BsSpace.md),
                child: TodayBand(
                  board: board,
                  selected: selected,
                  onSelect: (t) =>
                      ref.read(_taskFilterProvider.notifier).state = t,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Row(
                  children: DbRoomStatus.values.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('${s.label} · ${counts[s]}',
                            style: BsType.body(12, color: BsColors.slate)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: BsSpace.md)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
              sliver: _GrilleChambres(
                chambres: visible,
                canManage: perms.canEditRooms,
                carte: (room) => RoomCard(
                  room: room,
                  canManage: perms.canEditRooms,
                  onCheckIn: () => showCheckIn(context, ref, room),
                  onCheckOut: () =>
                      confirmCheckOutWithInvoice(context, ref, room),
                  onSetStatus: (s) =>
                      ref.read(roomsRepoProvider).setStatus(room.number, s),
                  onEdit: () => showRoomDialog(context, ref, existing: room),
                  onDelete: () => confirmDeleteRoom(context, ref, room),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: BsSpace.xxl)),
          ],
        );
      },
    );
  }
}

/// La grille des chambres.
///
/// Chaque carte n'est reconstruite QUE si sa chambre a changé. Le flux des
/// chambres renvoie toute la liste à chaque check-in, check-out ou
/// changement de statut : sans ce cache, les vingt cartes se
/// redessinaient pour une seule chambre modifiée. Une carte dont la
/// chambre est identique (même numéro, même client, même statut…) est
/// rendue telle quelle, et Flutter n'y touche pas.
class _GrilleChambres extends StatefulWidget {
  final List<Room> chambres;
  final bool canManage;
  final Widget Function(Room) carte;

  const _GrilleChambres({
    required this.chambres,
    required this.canManage,
    required this.carte,
  });

  @override
  State<_GrilleChambres> createState() => _GrilleChambresState();
}

class _GrilleChambresState extends State<_GrilleChambres> {
  final _cartes = <String, (Room, bool, DateTime, Widget)>{};

  Widget _carte(Room room, DateTime jour) {
    final deja = _cartes[room.number];
    // Le jour fait partie de la clé : une carte dit « en retard » ou
    // « départ aujourd'hui » selon la date. Passé minuit, elle doit être
    // refaite même si sa chambre n'a pas bougé.
    if (deja != null &&
        deja.$1 == room &&
        deja.$2 == widget.canManage &&
        deja.$3 == jour) {
      return deja.$4;
    }
    final carte = KeyedSubtree(
      key: ValueKey(room.number),
      child: widget.carte(room),
    );
    _cartes[room.number] = (room, widget.canManage, jour, carte);
    return carte;
  }

  @override
  void didUpdateWidget(_GrilleChambres old) {
    super.didUpdateWidget(old);
    // Une chambre supprimée ne garde pas sa carte en mémoire.
    final numeros = {for (final r in widget.chambres) r.number};
    _cartes.removeWhere((n, _) => !numeros.contains(n));
  }

  @override
  Widget build(BuildContext context) {
    final jour = debutDeJourneeLubumbashi(DateTime.now());
    return SliverLayoutBuilder(builder: (context, c) {
      final cross = (c.crossAxisExtent / 260).floor().clamp(1, 5);
      return SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          // 0.88 : la carte est plus HAUTE que large.
          // À 1.15 le bouton « Check-in » était coupé par la
          // rangée suivante — visible sur l'écran Chambres.
          childAspectRatio: 0.88,
        ),
        itemCount: widget.chambres.length,
        itemBuilder: (_, i) => _carte(widget.chambres[i], jour),
      );
    });
  }
}
