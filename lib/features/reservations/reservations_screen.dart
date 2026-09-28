import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/repos.dart';
import '../../data/schema.dart';
import '../../services/pdf_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../rooms/stay_helpers.dart';
import '../../core/temps.dart';
import '../../core/devise.dart';

/// Écran "Réservations" : liste des séjours à venir + création + actions
/// (arrivée, annulation, modification).
class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permsProvider);
    final asyncAll = ref.watch(allReservationsProvider);

    return asyncAll.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => BsErrorView(
          error: handleError(e, st, context: 'reservations_screen')),
      data: (all) {
        final now = DateTime.now();
        final today = debutDeJourneeLubumbashi(now);
        final upcoming = all.where((r) {
          final s = r.reservation.status;
          if (s == DbReservationStatus.cancelled ||
              s == DbReservationStatus.checkedIn) return false;
          return !r.reservation.checkinDate.isBefore(today);
        }).toList();
        final past = all.where((r) => !upcoming.contains(r)).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Réservations',
                title: 'Séjours à venir',
                subtitle:
                    '${upcoming.length} à venir · ${past.length} archivées',
                actions: [
                  if (perms.canReservations)
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => _showCreateDialog(context, ref),
                      label: const Text('Nouvelle réservation'),
                    ),
                ],
              ),
              if (upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BsSpace.xl, vertical: BsSpace.md),
                  child: Container(
                    padding: const EdgeInsets.all(BsSpace.xl),
                    decoration: BoxDecoration(
                      color: BsColors.paper,
                      border: Border.all(color: BsColors.line),
                      borderRadius: BorderRadius.circular(BsRadius.md),
                    ),
                    child: Column(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 40, color: BsColors.slateSoft),
                      const SizedBox(height: 10),
                      Text('Aucune réservation à venir',
                          style: BsType.body(13, w: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          'Clique "Nouvelle réservation" pour enregistrer un séjour futur.',
                          style: BsType.body(11, color: BsColors.slate)),
                    ]),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final r in upcoming)
                        _ReservationCard(
                          data: r,
                          canManage: perms.canReservations,
                        ),
                    ],
                  ),
                ),
              if (past.isNotEmpty) ...[
                const SizedBox(height: BsSpace.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                  child: Text('ARCHIVE', style: BsType.eyebrow()),
                ),
                const SizedBox(height: BsSpace.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                  child: Column(
                    children: [
                      for (final r in past)
                        _ReservationCard(
                          data: r,
                          canManage: perms.canReservations,
                          archived: true,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (_) => const _ReservationDialog(),
    );
  }
}

/// Regénère la confirmation PDF pour une réservation persistée.
/// Récupère le type de chambre depuis la table Rooms courante.
Future<void> previewReservationPdf(
    WidgetRef ref, ReservationWithRooms r) async {
  final allRooms =
      ref.read(roomsStreamProvider).asData?.value ?? const <Room>[];
  final byNumber = {for (final x in allRooms) x.number: x};
  Payer? payer;
  if (r.reservation.payerId != null) {
    payer = await ref.read(payersRepoProvider).byId(r.reservation.payerId!);
  }
  final data = ReservationInvoiceData(
    reservationNumber: r.reservation.reservationNumber,
    generatedAt: r.reservation.createdAt,
    checkinDate: r.reservation.checkinDate,
    checkoutDate: r.reservation.checkoutDate,
    guestFullName: r.reservation.guestFullName,
    guestPhone: r.reservation.guestPhone,
    guestEmail: r.reservation.guestEmail,
    payerName: payer?.name,
    payerTaxId: payer?.taxId,
    payerAddress: payer?.address,
    payerContact: payer?.contact,
    depositCents: r.reservation.depositCents,
    note: r.reservation.note,
    serverLogin: r.reservation.createdByLogin,
    rooms: [
      for (final rr in r.rooms)
        ReservationInvoiceRoom(
          number: rr.roomNumber,
          type: byNumber[rr.roomNumber]?.type ?? 'Standard',
          pricePerNightCents: rr.pricePerNightCents,
        priceUsdCents: fcVersUsd(rr.pricePerNightCents),
        ),
    ],
  );
  await PdfService.previewReservationConfirmation(data);
}

class _ReservationCard extends ConsumerWidget {
  final ReservationWithRooms data;
  final bool canManage;
  final bool archived;
  const _ReservationCard({
    required this.data,
    required this.canManage,
    this.archived = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = data.reservation;
    final rooms = data.rooms;
    final now = DateTime.now();
    final today = debutDeJourneeLubumbashi(now);
    final isToday = r.checkinDate.year == today.year &&
        r.checkinDate.month == today.month &&
        r.checkinDate.day == today.day;
    final overdue = r.status != DbReservationStatus.checkedIn &&
        r.status != DbReservationStatus.cancelled &&
        r.checkinDate.isBefore(today);

    final (statusColor, statusLabel) = switch (r.status) {
      DbReservationStatus.pending => (BsColors.slateSoft, 'EN ATTENTE'),
      DbReservationStatus.confirmed => (BsColors.sky, 'CONFIRMÉE'),
      DbReservationStatus.checkedIn => (BsColors.success, 'ARRIVÉE'),
      DbReservationStatus.cancelled => (BsColors.danger, 'ANNULÉE'),
      DbReservationStatus.noShow => (BsColors.danger, 'NO-SHOW'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(
          color: overdue
              ? BsColors.danger
              : (isToday ? BsColors.sunrise : BsColors.line),
          width: overdue || isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Bloc gauche : dates
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: (isToday ? BsColors.sunrise : BsColors.inkSoft)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(BsRadius.sm),
              ),
              child: Column(children: [
                Text(
                    DateFormat("d MMM", 'fr_FR')
                        .format(aLubumbashi(r.checkinDate))
                        .toUpperCase(),
                    style: BsType.body(11,
                        w: FontWeight.w800,
                        color: isToday ? BsColors.sunrise : BsColors.slate)),
                const SizedBox(height: 2),
                Text('→', style: BsType.body(10, color: BsColors.slateSoft)),
                Text(
                    DateFormat("d MMM", 'fr_FR')
                        .format(aLubumbashi(r.checkoutDate))
                        .toUpperCase(),
                    style: BsType.body(11,
                        w: FontWeight.w600, color: BsColors.slate)),
                const SizedBox(height: 2),
                Text('${data.nights()}n',
                    style: BsType.mono(9, color: BsColors.slate)),
              ]),
            ),
            const SizedBox(width: 12),
            // Bloc central : nom + chambres
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(r.guestFullName,
                        style: BsType.body(14, w: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(statusLabel,
                          style: BsType.body(9,
                              w: FontWeight.w800, color: statusColor)),
                    ),
                    if (overdue) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber,
                          size: 14, color: BsColors.danger),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      'Ch. ${rooms.map((x) => x.roomNumber).join(", ")}'
                      ' · ${rooms.length} chambre(s)',
                      style: BsType.body(11, color: BsColors.slate)),
                  const SizedBox(height: 2),
                  Text(r.reservationNumber,
                      style: BsType.mono(10, color: BsColors.slateSoft)),
                  // Icône plutôt qu'emoji : même famille que le reste de
                  // l'application, et une couleur qu'on maîtrise.
                  if (r.guestPhone != null && r.guestPhone!.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: BsColors.slate),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(r.guestPhone!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BsType.body(10, color: BsColors.slate)),
                      ),
                    ]),
                  if (r.note != null && r.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('« ${r.note} »',
                          // Une note libre peut être longue : deux lignes
                          // au plus, puis on coupe proprement.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BsType.body(10,
                              color: BsColors.slate, w: FontWeight.w500)),
                    ),
                ],
              ),
            ),
            // Bloc droite : total + actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(moneyCents(data.estimatedTotalCents()),
                    style: BsType.body(13, w: FontWeight.w800)),
                if (r.depositCents > 0)
                  Text('acompte ${moneyCents(r.depositCents)}',
                      style: BsType.body(10,
                          color: BsColors.success, w: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Aperçu confirmation PDF',
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => previewReservationPdf(ref, data),
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        color: BsColors.sunrise),
                  ),
                  if (canManage && !archived) ...[
                    const SizedBox(width: 6),
                    if (r.status == DbReservationStatus.confirmed ||
                        r.status == DbReservationStatus.pending) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.login, size: 14),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BsColors.success,
                          side: const BorderSide(color: BsColors.success),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        onPressed: () => _markArrival(context, ref),
                        label: const Text('Marquer arrivée',
                            style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      tooltip: 'Annuler',
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => _confirmCancel(context, ref),
                      icon: const Icon(Icons.cancel_outlined,
                          color: BsColors.danger),
                    ),
                  ],
                ]),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  void _markArrival(BuildContext ctx, WidgetRef ref) async {
    // Chaque chambre de la réservation est check-in-ée avec le nom du
    // client. On garde l'id du 1er stay créé pour lien reservation.stayId.
    final r = data.reservation;
    final rooms = data.rooms;
    final roomsRepo = ref.read(roomsRepoProvider);
    final clientsRepo = ref.read(clientsRepoProvider);

    // Fidélité : find-or-create par nom + tél
    final client = await clientsRepo.findOrCreate(
      fullName: r.guestFullName,
      phone: r.guestPhone,
    );
    for (var i = 0; i < rooms.length; i++) {
      await clientsRepo.recordVisit(client.id);
    }
    // Check-in de chaque chambre — groupé si >1.
    if (rooms.length > 1) {
      await roomsRepo.groupCheckIn(
        numbers: rooms.map((x) => x.roomNumber).toList(),
        guest: r.guestFullName,
        checkout: r.checkoutDate,
        note: r.note,
        payerId: r.payerId,
      );
    } else {
      await roomsRepo.checkIn(
        rooms.first.roomNumber,
        r.guestFullName,
        r.checkoutDate,
        note: r.note,
        payerId: r.payerId,
      );
    }
    await ref.read(reservationsRepoProvider).markCheckedIn(r.id);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        backgroundColor: BsColors.success,
        content: Text(
            '${rooms.length} chambre(s) enregistrée(s) pour ${r.guestFullName}.',
            style: BsType.body(13, w: FontWeight.w600, color: Colors.white)),
      ));
    }
  }

  Future<void> _confirmCancel(BuildContext ctx, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: BsColors.paper,
        title: Text('Annuler la réservation ?',
            style: BsType.display(16, w: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${data.reservation.guestFullName} · ${data.rooms.length} chambre(s)',
                style: BsType.body(12)),
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                  hintText: 'Motif (facultatif)', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Retour')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Annuler la résa')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(reservationsRepoProvider).cancel(data.reservation.id,
        reason.text.trim().isEmpty ? null : reason.text.trim());
  }
}

/// Dialog de création d'une réservation.
class _ReservationDialog extends ConsumerStatefulWidget {
  const _ReservationDialog();
  @override
  ConsumerState<_ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends ConsumerState<_ReservationDialog> {
  final _guest = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _deposit = TextEditingController();
  DateTime _checkin = DateTime.now().add(const Duration(days: 1));
  DateTime _checkout = DateTime.now().add(const Duration(days: 2));
  final Set<String> _pickedRooms = {};
  Payer? _payer;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _guest.dispose();
    _phone.dispose();
    _note.dispose();
    _deposit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms =
        ref.watch(roomsStreamProvider).asData?.value ?? const <Room>[];
    final sorted = [...rooms]..sort((a, b) => a.number.compareTo(b.number));

    return Dialog(
      backgroundColor: BsColors.paper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BsRadius.md)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('NOUVELLE RÉSERVATION',
                    style: BsType.eyebrow(color: BsColors.sunrise)),
                const SizedBox(height: 6),
                Text('Enregistrer un séjour futur',
                    style: BsType.display(18, w: FontWeight.w700)),
                const SizedBox(height: 16),
                ClientLookupField(
                  nameCtrl: _guest,
                  phoneCtrl: _phone,
                  autofocusName: true,
                ),
                const SizedBox(height: 12),
                PayerPickerSection(
                  initial: _payer,
                  onChanged: (p) => setState(() => _payer = p),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DATE D'ARRIVÉE", style: BsType.eyebrow()),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: _checkin,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (p != null) {
                              setState(() {
                                _checkin = p;
                                if (!_checkout.isAfter(p)) {
                                  _checkout = p.add(const Duration(days: 1));
                                }
                              });
                            }
                          },
                          label: Text(
                              DateFormat("d MMM y", 'fr_FR').format(aLubumbashi(_checkin)),
                              style: BsType.body(12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE DE DÉPART', style: BsType.eyebrow()),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: _checkout,
                              firstDate: _checkin.add(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (p != null) setState(() => _checkout = p);
                          },
                          label: Text(
                              DateFormat("d MMM y", 'fr_FR').format(aLubumbashi(_checkout)),
                              style: BsType.body(12)),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                    'CHAMBRES (${_pickedRooms.length} sélectionnée${_pickedRooms.length > 1 ? "s" : ""})',
                    style: BsType.eyebrow()),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: BsColors.line),
                    borderRadius: BorderRadius.circular(BsRadius.sm),
                  ),
                  child: sorted.isEmpty
                      ? Center(
                          child: Text('Aucune chambre configurée.',
                              style:
                                  BsType.body(11, color: BsColors.slateSoft)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: sorted.length,
                          itemBuilder: (_, i) {
                            final r = sorted[i];
                            final on = _pickedRooms.contains(r.number);
                            // Note : on autorise même les chambres en
                            // occupée aujourd'hui — la réservation est
                            // pour PLUS TARD, elles seront libres au
                            // moment du check-in. La reception peut
                            // arbitrer visuellement.
                            return CheckboxListTile(
                              dense: true,
                              value: on,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _pickedRooms.add(r.number);
                                } else {
                                  _pickedRooms.remove(r.number);
                                }
                              }),
                              title: Text('Ch. ${r.number} · ${r.type}',
                                  style: BsType.body(12, w: FontWeight.w600)),
                              subtitle: Text(
                                  '${moneyCents(r.pricePerNightCents)} / nuit',
                                  style:
                                      BsType.body(10, color: BsColors.slate)),
                              secondary: r.status == DbRoomStatus.occupee
                                  ? const Icon(Icons.circle,
                                      size: 8, color: BsColors.danger)
                                  : null,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACOMPTE REÇU (FC)', style: BsType.eyebrow()),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _deposit,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: '0', suffixText: 'FC'),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('NOTE / DEMANDES SPÉCIALES', style: BsType.eyebrow()),
                const SizedBox(height: 6),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Ex : arrivée tardive, allergie, VIP…'),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 10),
                  Text(_err!, style: BsType.body(12, color: BsColors.danger)),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BsColors.sunrise,
                      side: const BorderSide(color: BsColors.sunrise),
                    ),
                    onPressed: _busy ? null : () => _preview(sorted),
                    label: const Text('Aperçu', style: TextStyle(fontSize: 12)),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    style: FilledButton.styleFrom(
                        backgroundColor: BsColors.sunrise),
                    onPressed: _busy ? null : () => _save(sorted),
                    label: const Text('Enregistrer'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aperçu PDF de la confirmation avant enregistrement — pratique
  /// pour vérifier les infos ou imprimer directement sans sauvegarder.
  Future<void> _preview(List<Room> allRooms) async {
    if (_guest.text.trim().isEmpty || _pickedRooms.isEmpty) {
      setState(() => _err = 'Nom du client et chambres requis pour l\'aperçu');
      return;
    }
    final byNumber = {for (final r in allRooms) r.number: r};
    final rooms = _pickedRooms.map((n) {
      final r = byNumber[n]!;
      return ReservationInvoiceRoom(
        number: r.number,
        type: r.type,
        pricePerNightCents: r.pricePerNightCents,
        priceUsdCents: fcVersUsd(r.pricePerNightCents),
      );
    }).toList();
    final now = DateTime.now();
    final tempRef =
        'RSV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-APERCU';
    final deposit = int.tryParse(_deposit.text.trim().replaceAll(' ', '')) ?? 0;
    final me = ref.read(authProvider).user;
    final data = ReservationInvoiceData(
      reservationNumber: tempRef,
      generatedAt: now,
      checkinDate: _checkin,
      checkoutDate: _checkout,
      guestFullName: _guest.text.trim(),
      guestPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      payerName: _payer?.name,
      payerTaxId: _payer?.taxId,
      payerAddress: _payer?.address,
      payerContact: _payer?.contact,
      depositCents: deposit,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      serverLogin: me?.login,
      rooms: rooms,
    );
    await PdfService.previewReservationConfirmation(data);
  }

  Future<void> _save(List<Room> allRooms) async {
    if (_guest.text.trim().isEmpty) {
      setState(() => _err = 'Nom du client requis');
      return;
    }
    if (_pickedRooms.isEmpty) {
      setState(() => _err = 'Sélectionne au moins une chambre');
      return;
    }
    if (!_checkout.isAfter(_checkin)) {
      setState(() => _err = 'Le départ doit être après l\'arrivée');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final byNumber = {for (final r in allRooms) r.number: r};
    final rooms = _pickedRooms.map((n) {
      final r = byNumber[n]!;
      return (number: n, pricePerNightCents: r.pricePerNightCents);
    }).toList();
    final me = ref.read(authProvider).user;
    try {
      final depositCents =
          int.tryParse(_deposit.text.trim().replaceAll(' ', '')) ?? 0;
      // Fidélité : find-or-create le client dès la réservation.
      await ref.read(clientsRepoProvider).findOrCreate(
            fullName: _guest.text.trim(),
            phone: _phone.text.trim(),
          );
      await ref.read(reservationsRepoProvider).create(
            rooms: rooms,
            guestFullName: _guest.text.trim(),
            guestPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            payerId: _payer?.id,
            checkinDate: _checkin,
            checkoutDate: _checkout,
            depositCents: depositCents,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            createdByLogin: me?.login,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: BsColors.success,
        content: Text('Réservation enregistrée pour ${_guest.text.trim()}.',
            style: BsType.body(13, w: FontWeight.w600, color: Colors.white)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = 'Échec : $e';
      });
    }
  }
}
