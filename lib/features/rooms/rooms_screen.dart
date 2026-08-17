import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth.dart';
import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Une chambre est "en retard" si elle est occupée et sa date de départ
/// est antérieure à aujourd'hui (dépassement à 00h le lendemain).
bool _isOverdue(Room r) {
  if (r.status != DbRoomStatus.occupee || r.checkoutDate == null) return false;
  final today = DateTime.now();
  final tDay = DateTime(today.year, today.month, today.day);
  final cDay = DateTime(r.checkoutDate!.year, r.checkoutDate!.month,
      r.checkoutDate!.day);
  return cDay.isBefore(tDay);
}

int _daysLate(Room r) {
  final today = DateTime.now();
  final tDay = DateTime(today.year, today.month, today.day);
  final cDay = DateTime(r.checkoutDate!.year, r.checkoutDate!.month,
      r.checkoutDate!.day);
  return tDay.difference(cDay).inDays;
}

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roomsStreamProvider);
    final perms = ref.watch(permsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (rooms) {
        final counts = {
          for (final s in DbRoomStatus.values)
            s: rooms.where((r) => r.status == s).length,
        };
        final overdue = rooms.where(_isOverdue).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Chambres',
                title: "Plan d'occupation",
                subtitle:
                    '${counts[DbRoomStatus.occupee]} occupées · ${counts[DbRoomStatus.libre]} libres · ${counts[DbRoomStatus.nettoyage]} en nettoyage',
                actions: [
                  if (perms.canEditRooms)
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () =>
                          _showRoomDialog(context, ref, existing: null),
                      label: const Text('Nouvelle chambre'),
                    ),
                ],
              ),
              if (overdue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      BsSpace.xl, 0, BsSpace.xl, BsSpace.md),
                  child: _OverdueBanner(
                    rooms: overdue,
                    onCheckOut: (r) =>
                        ref.read(roomsRepoProvider).checkOut(r.number),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Row(
                  children: DbRoomStatus.values.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('${s.label} · ${counts[s]}',
                            style: BsType.body(12, color: BsColors.slate)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: BsSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: LayoutBuilder(builder: (ctx, c) {
                  final cross = (c.maxWidth / 260).floor().clamp(1, 5);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: rooms.length,
                    itemBuilder: (_, i) => _RoomCard(
                      room: rooms[i],
                      canManage: perms.canEditRooms,
                      onCheckIn: () => _showCheckIn(context, ref, rooms[i]),
                      onCheckOut: () =>
                          ref.read(roomsRepoProvider).checkOut(rooms[i].number),
                      onSetStatus: (s) => ref
                          .read(roomsRepoProvider)
                          .setStatus(rooms[i].number, s),
                      onEdit: () =>
                          _showRoomDialog(context, ref, existing: rooms[i]),
                      onDelete: () => _confirmDelete(context, ref, rooms[i]),
                    ),
                  );
                }),
              ),
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }

  void _showCheckIn(BuildContext ctx, WidgetRef ref, Room room) {
    final guest = TextEditingController();
    DateTime checkout = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CHECK-IN CHAMBRE ${room.number}', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text('${room.type} · ${moneyCents(room.pricePerNightCents, decimals: 0)}/nuit',
                      style: BsType.body(13, color: BsColors.slate)),
                  const SizedBox(height: 20),
                  Text('NOM DU CLIENT', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: guest,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'ex. M. Kabongo'),
                  ),
                  const SizedBox(height: 12),
                  Text('DATE DE DÉPART', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: checkout,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSt(() => checkout = picked);
                    },
                    label: Text(
                        '${checkout.day}/${checkout.month}/${checkout.year}',
                        style: BsType.body(13)),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: guest.text.trim().isEmpty
                          ? null
                          : () async {
                              await ref.read(roomsRepoProvider).checkIn(
                                    room.number,
                                    guest.text.trim(),
                                    checkout,
                                  );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      child: const Text('Enregistrer'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showRoomDialog(BuildContext ctx, WidgetRef ref, {Room? existing}) {
    final number = TextEditingController(text: existing?.number ?? '');
    final type = TextEditingController(text: existing?.type ?? '');
    final price = TextEditingController(
        text: existing == null ? '' : (existing.pricePerNightCents / 100).toStringAsFixed(0));
    String? err;
    final isEdit = existing != null;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEdit ? 'ÉDITER CHAMBRE' : 'NOUVELLE CHAMBRE',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text(isEdit ? 'Chambre ${existing.number}' : 'Ajouter au plan',
                      style: BsType.display(22, w: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Text('NUMÉRO', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: number,
                    enabled: !isEdit, // PK non modifiable
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      hintText: 'ex. 204 ou B3',
                      helperText: isEdit
                          ? 'Le numéro ne peut pas être modifié.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('TYPE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: type,
                    decoration: const InputDecoration(
                        hintText: 'Simple / Double / Suite / Bungalow'),
                  ),
                  const SizedBox(height: 12),
                  Text('PRIX / NUIT (\$)', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '50'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        final p = double.tryParse(price.text.replaceAll(',', '.'));
                        if (number.text.trim().isEmpty ||
                            type.text.trim().isEmpty ||
                            p == null ||
                            p < 0) {
                          setSt(() => err = 'Tous les champs sont requis');
                          return;
                        }
                        final cents = (p * 100).round();
                        try {
                          if (isEdit) {
                            await ref.read(roomsRepoProvider).updateInfo(
                                  number: existing.number,
                                  type: type.text.trim(),
                                  pricePerNightCents: cents,
                                );
                          } else {
                            await ref.read(roomsRepoProvider).create(
                                  number: number.text.trim(),
                                  type: type.text.trim(),
                                  pricePerNightCents: cents,
                                );
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (_) {
                          setSt(() =>
                              err = 'Ce numéro de chambre existe déjà');
                        }
                      },
                      child: Text(isEdit ? 'Enregistrer' : 'Créer'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, WidgetRef ref, Room room) async {
    if (room.status != DbRoomStatus.libre) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
              'Impossible de supprimer la chambre ${room.number} : elle est ${room.status.label.toLowerCase()}.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Supprimer la chambre ${room.number} ?'),
        content: const Text(
            'Cette action est définitive. La chambre disparaîtra du plan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(roomsRepoProvider).delete(room.number);
    }
  }
}

class _OverdueBanner extends StatelessWidget {
  final List<Room> rooms;
  final ValueChanged<Room> onCheckOut;
  const _OverdueBanner({required this.rooms, required this.onCheckOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BsSpace.md),
      decoration: BoxDecoration(
        color: BsColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: BsColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(BsRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active,
                size: 18, color: BsColors.danger),
            const SizedBox(width: 8),
            Text(
                'RAPPEL — ${rooms.length} CHECK-OUT EN RETARD',
                style: BsType.eyebrow(color: BsColors.danger)),
          ]),
          const SizedBox(height: 6),
          Text(
              "Ces client(e)s auraient dû partir. Fais le check-out pour libérer la chambre (elle passera automatiquement en nettoyage).",
              style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in rooms)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BsColors.danger.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(BsRadius.sm),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Ch. ${r.number}',
                      style: BsType.body(12, w: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('· ${r.currentGuest ?? "—"}',
                      style: BsType.body(12, color: BsColors.slate)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BsColors.danger,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                        _daysLate(r) == 0
                            ? "aujourd'hui"
                            : '+${_daysLate(r)} j',
                        style: BsType.body(10,
                            w: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 14),
                    onPressed: () => onCheckOut(r),
                    label: const Text('Check-out'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
                ]),
              ),
          ]),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final bool canManage;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final ValueChanged<DbRoomStatus> onSetStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoomCard({
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
    final overdue = _isOverdue(room);
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
                decoration:
                    BoxDecoration(color: room.status.color, shape: BoxShape.circle),
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
          Text('${room.type} · ${moneyCents(room.pricePerNightCents, decimals: 0)}/nuit',
              style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (overdue ? BsColors.danger : room.status.color)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
                overdue ? 'DÉPART EN RETARD' : room.status.label,
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
                      ? "aurait dû partir le ${DateFormat("d MMM", 'fr_FR').format(room.checkoutDate!)}"
                      : "départ ${DateFormat("d MMM", 'fr_FR').format(room.checkoutDate!)}",
                  style: BsType.body(11,
                      w: overdue ? FontWeight.w700 : FontWeight.normal,
                      color:
                          overdue ? BsColors.danger : BsColors.slate)),
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
