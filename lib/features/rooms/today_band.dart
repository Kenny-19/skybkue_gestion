import 'package:flutter/material.dart';

import '../../widgets/bs_widgets.dart';
import 'today_board.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Le bandeau « aujourd'hui » en tête du plan des chambres.
///
/// Remplace l'ancienne bannière de retards, qui ne montrait qu'un quart
/// du problème. Quatre compteurs cliquables qui filtrent la grille en
/// dessous : la réception voit ce qu'il y a à faire avant de voir l'état
/// des 19 chambres.
class TodayBand extends StatelessWidget {
  final TodayBoard board;
  final RoomTask? selected;
  final ValueChanged<RoomTask?> onSelect;

  const TodayBand({
    super.key,
    required this.board,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return BsCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text("AUJOURD'HUI", style: BsType.eyebrow(color: BsColors.sky)),
            const SizedBox(width: 10),
            if (board.isClear)
              Text('rien à signaler',
                  style: BsType.body(11, color: BsColors.slateSoft)),
            const Spacer(),
            if (selected != null)
              TextButton(
                onPressed: () => onSelect(null),
                child: const Text('Tout afficher'),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in RoomTask.values)
                BsStatTile(
                  value: board.count(t),
                  label: t.label,
                  urgent: t.isUrgent,
                  selected: selected == t,
                  // Recliquer sur la catégorie active la désélectionne :
                  // on ne veut pas piéger la réception dans un filtre.
                  onTap: () => onSelect(selected == t ? null : t),
                ),
            ],
          ),
          if (selected == RoomTask.retards && board.retards.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              board.retards
                  .map((r) => 'Ch. ${r.number} · ${daysLate(r)} j')
                  .join('   —   '),
              style:
                  BsType.body(12, w: FontWeight.w600, color: BsColors.danger),
            ),
          ],
          if (selected == RoomTask.arrivees && board.arrivees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              board.arrivees
                  .map((r) => '${r.reservation.guestFullName} · ch. '
                      '${r.rooms.map((x) => x.roomNumber).join(", ")}')
                  .join('   —   '),
              style: BsType.body(12, color: BsColors.slate),
            ),
          ],
          if (selected != null && board.count(selected!) == 0) ...[
            const SizedBox(height: 12),
            Text(selected!.emptyLabel,
                style: BsType.body(12, color: BsColors.slateSoft)),
          ],
        ],
      ),
    );
  }
}
