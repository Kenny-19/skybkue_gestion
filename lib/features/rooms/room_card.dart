import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cat_ui.dart';
import '../../data/database.dart';
import '../../core/temps.dart';
import '../../data/schema.dart';
import 'today_board.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/devise.dart';

// La carte d'une chambre dans le plan d'occupation, et l'aperçu de sa photo.

class RoomCard extends StatelessWidget {
  final Room room;
  final bool canManage;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final ValueChanged<DbRoomStatus> onSetStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const RoomCard({
    super.key,
    required this.room,
    required this.canManage,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onSetStatus,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = isOverdue(room);
    return Container(
      padding: const EdgeInsets.all(BsSpace.md),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(
          color: overdue ? BsColors.danger : BsColors.line,
          width: overdue ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (room.imagePath != null && room.imagePath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BsRadius.sm),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RoomImagePreview(path: room.imagePath),
                ),
              ),
            ),
          Row(children: [
            Text(room.number, style: BsType.display(28, w: FontWeight.w700)),
            const Spacer(),
            if (overdue)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.notifications_active,
                    size: 16, color: BsColors.danger),
              ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: room.status.color, shape: BoxShape.circle),
              ),
              onSelected: (v) {
                if (v == '__edit') {
                  onEdit();
                } else if (v == '__delete') {
                  onDelete();
                } else {
                  onSetStatus(
                      DbRoomStatus.values.firstWhere((s) => s.name == v));
                }
              },
              itemBuilder: (_) => [
                for (final s in DbRoomStatus.values)
                  PopupMenuItem(
                    value: s.name,
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Statut : ${s.label}'),
                    ]),
                  ),
                if (canManage) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: '__edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Éditer'),
                      ])),
                  const PopupMenuItem(
                      value: '__delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: BsColors.danger),
                        SizedBox(width: 8),
                        Text('Supprimer',
                            style: TextStyle(color: BsColors.danger)),
                      ])),
                ],
              ],
            ),
          ]),
          // Tarif du séjour en cours : si un tarif négocié a été consenti
          // au check-in, on l'affiche à la place du catalogue (barré).
          if (room.negotiatedPriceCents != null &&
              room.negotiatedPriceCents! > 0) ...[
            Row(children: [
              Flexible(
                child: Text(
                    '${room.type} · '
                    '${moneyUsdCourt(fcVersUsd(room.negotiatedPriceCents!))}/nuit',
                    overflow: TextOverflow.ellipsis,
                    style: BsType.body(12,
                        w: FontWeight.w600, color: BsColors.success)),
              ),
              const SizedBox(width: 4),
              // Le tarif catalogue barré, en dollars lui aussi : comparer
              // un prix négocié en dollars à un catalogue en francs ne
              // dirait rien à personne.
              Text(moneyUsdCourt(room.priceUsdCents),
                  style: BsType.body(10,
                      color: BsColors.slateSoft,
                      d: TextDecoration.lineThrough)),
            ]),
          ] else
            Text('${room.type} · ${montantHotelCourt(room.priceUsdCents)}/nuit',
                style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (overdue ? BsColors.danger : room.status.color)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(overdue ? 'DÉPART EN RETARD' : room.status.label,
                style: BsType.body(11,
                    w: FontWeight.w700,
                    color: overdue ? BsColors.danger : room.status.color)),
          ),
          if (room.currentGuest != null) ...[
            const SizedBox(height: 8),
            Text(room.currentGuest!,
                style: BsType.body(12, w: FontWeight.w600)),
            if (room.checkoutDate != null)
              Text(
                  overdue
                      ? "aurait dû partir le ${DateFormat("d MMM", 'fr_FR').format(aLubumbashi(room.checkoutDate!))}"
                      : "départ ${DateFormat("d MMM", 'fr_FR').format(aLubumbashi(room.checkoutDate!))}",
                  style: BsType.body(11,
                      w: overdue ? FontWeight.w700 : FontWeight.normal,
                      color: overdue ? BsColors.danger : BsColors.slate)),
            // Note check-in (saisie au moment du check-in — repère visuel).
            if (room.checkinNote != null && room.checkinNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: BsColors.papyrus,
                  borderRadius: BorderRadius.circular(BsRadius.sm),
                ),
                child: Row(children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 12, color: BsColors.slate),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(room.checkinNote!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BsType.body(10,
                            color: BsColors.slate, w: FontWeight.w500)),
                  ),
                ]),
              ),
            ],
          ],
          const Spacer(),
          if (room.status == DbRoomStatus.libre)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.login, size: 14),
                onPressed: onCheckIn,
                label: const Text('Check-in'),
              ),
            )
          else if (room.status == DbRoomStatus.occupee)
            SizedBox(
              width: double.infinity,
              child: overdue
                  ? FilledButton.icon(
                      icon: const Icon(Icons.logout, size: 14),
                      onPressed: onCheckOut,
                      style: FilledButton.styleFrom(
                        backgroundColor: BsColors.danger,
                      ),
                      label: const Text('Check-out urgent'),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.logout, size: 14),
                      onPressed: onCheckOut,
                      label: const Text('Check-out'),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Aperçu de la photo d'une chambre (fichier local OU URL http). Fallback
/// icône générique si vide/erreur.
class RoomImagePreview extends StatelessWidget {
  final String? path;

  /// Largeur maximale de DÉCODAGE, en pixels.
  ///
  /// Ce n'est pas la taille d'affichage : la photo reste entière et
  /// remplit son cadre. On limite seulement la résolution décodée en
  /// mémoire — une photo de 3000×2000 occupe ~24 Mo une fois décodée,
  /// et l'écran en affiche 19 d'un coup.
  ///
  /// 400 px suffit pour une carte de 260 px ; l'aperçu du formulaire,
  /// bien plus grand, demande davantage sous peine d'être flou.
  final int decodeWidth;

  const RoomImagePreview(
      {super.key, required this.path, this.decodeWidth = 400});

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return const Center(
        child: Icon(Icons.hotel_outlined, size: 30, color: BsColors.slateSoft),
      );
    }
    if (path!.startsWith('http')) {
      return Image.network(
        path!,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 22, color: BsColors.slateSoft)),
      );
    }
    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined,
              size: 22, color: BsColors.slateSoft)),
    );
  }
}
