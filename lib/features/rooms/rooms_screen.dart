import 'dart:convert' show jsonEncode;
import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../core/cat_ui.dart';
import '../../core/discount.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../core/temps.dart';
import '../../data/schema.dart';
import '../../services/cloud_service.dart';
import '../../services/pdf_service.dart';
import '../../services/supply_requests_service.dart';
import 'stay_helpers.dart';
import 'today_board.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/devise.dart';

/// Une chambre est "en retard" si elle est occupée et sa date de départ
/// est antérieure à aujourd'hui (dépassement à 00h le lendemain).
bool _isOverdue(Room r) {
  if (r.status != DbRoomStatus.occupee || r.checkoutDate == null) return false;
  final today = DateTime.now();
  final tDay = debutDeJourneeLubumbashi(today);
  final cDay = debutDeJourneeLubumbashi(r.checkoutDate!);
  return cDay.isBefore(tDay);
}

int _daysLate(Room r) {
  final today = DateTime.now();
  final tDay = debutDeJourneeLubumbashi(today);
  final cDay = debutDeJourneeLubumbashi(r.checkoutDate!);
  return tDay.difference(cDay).inDays;
}

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
                      onPressed: () => _showHotelSupplyRequest(context, ref),
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
                      onPressed: () => _showGroupCheckIn(context, ref, rooms),
                      label: const Text('Check-in groupé'),
                    ),
                  ],
                  if (perms.canEditRooms) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () =>
                          _showRoomDialog(context, ref, existing: null),
                      label: const Text('Nouvelle chambre'),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    BsSpace.xl, 0, BsSpace.xl, BsSpace.md),
                child: _TodayBand(
                  board: board,
                  selected: selected,
                  onSelect: (t) =>
                      ref.read(_taskFilterProvider.notifier).state = t,
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
                      // 0.88 : la carte est plus HAUTE que large.
                      // À 1.15 le bouton « Check-in » était coupé par la
                      // rangée suivante — visible sur l'écran Chambres.
                      childAspectRatio: 0.88,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => _RoomCard(
                      room: visible[i],
                      canManage: perms.canEditRooms,
                      onCheckIn: () => _showCheckIn(context, ref, visible[i]),
                      onCheckOut: () =>
                          _confirmCheckOutWithInvoice(context, ref, visible[i]),
                      onSetStatus: (s) => ref
                          .read(roomsRepoProvider)
                          .setStatus(visible[i].number, s),
                      onEdit: () =>
                          _showRoomDialog(context, ref, existing: visible[i]),
                      onDelete: () => _confirmDelete(context, ref, visible[i]),
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

  /// Check-in groupé : sélection multi-chambres libres + un seul
  /// formulaire (payeur, date départ, note commune). Toutes les chambres
  /// choisies partagent un même `stayGroup`.
  void _showGroupCheckIn(BuildContext ctx, WidgetRef ref, List<Room> allRooms) {
    final free = allRooms.where((r) => r.status == DbRoomStatus.libre).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    if (free.length < 2) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text(
              'Il faut au moins 2 chambres libres pour un check-in groupé.')));
      return;
    }

    final picked = <String>{};
    final guest = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    DateTime checkout = DateTime.now().add(const Duration(days: 1));
    Payer? payer;
    bool busy = false;
    String? err;
    // Remise groupe en centièmes de % — appliquée au tarif catalogue de
    // chaque chambre sélectionnée pour produire un tarif négocié.
    int groupDiscount = 0;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        final selected = free.where((r) => picked.contains(r.number)).toList();
        // Les totaux en dollars, calculés depuis `priceUsdCents` et non
        // reconvertis depuis les francs : un aller-retour ferait
        // apparaître « $44,99 » là où le tarif affiché est $45.
        final listNightlyUsd =
            selected.fold<int>(0, (s, r) => s + r.priceUsdCents);
        // Tarif négocié par chambre = catalogue − remise groupe.
        //
        // La remise s'applique aux DOLLARS, puis on convertit : c'est
        // dans cette monnaie que la remise a été accordée, et un seul
        // arrondi vaut mieux que deux.
        int negotiatedFor(Room r) =>
            usdVersFc(_remise(r.priceUsdCents, groupDiscount));
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('CHECK-IN GROUPÉ',
                        style: BsType.eyebrow(color: BsColors.sky)),
                    const SizedBox(height: 6),
                    Text('Loger plusieurs chambres pour un même payeur',
                        style: BsType.display(18, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        'Entreprise, tour opérateur ou groupe familial : toutes les chambres partagent le nom du payeur et une facture consolidée à la fin.',
                        style: BsType.body(11, color: BsColors.slateSoft)),
                    const SizedBox(height: 16),
                    Text(
                        'CHAMBRES LIBRES (${picked.length} sélectionnée${picked.length > 1 ? "s" : ""})',
                        style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: BsColors.line),
                        borderRadius: BorderRadius.circular(BsRadius.sm),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: free.length,
                        itemBuilder: (_, i) {
                          final r = free[i];
                          final on = picked.contains(r.number);
                          return CheckboxListTile(
                            dense: true,
                            value: on,
                            onChanged: (v) => setSt(() {
                              if (v == true) {
                                picked.add(r.number);
                              } else {
                                picked.remove(r.number);
                              }
                            }),
                            title: Text('Ch. ${r.number} · ${r.type}',
                                style: BsType.body(13, w: FontWeight.w600)),
                            subtitle: Text(
                                '${montantHotelCourt(r.priceUsdCents)} / nuit',
                                style: BsType.body(11, color: BsColors.slate)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClientLookupField(
                      nameCtrl: guest,
                      phoneCtrl: phone,
                    ),
                    const SizedBox(height: 12),
                    PayerPickerSection(
                      initial: payer,
                      onChanged: (p) => setSt(() => payer = p),
                    ),
                    const SizedBox(height: 12),
                    Text('DATE DE DÉPART INITIALE', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: checkout,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (p != null) setSt(() => checkout = p);
                      },
                      label: Text(
                          '${checkout.day}/${checkout.month}/${checkout.year}',
                          style: BsType.body(13)),
                    ),
                    const SizedBox(height: 4),
                    Text('Chaque chambre pourra sortir séparément si besoin.',
                        style: BsType.body(11, color: BsColors.slateSoft)),
                    const SizedBox(height: 12),
                    Text('NOTE COMMUNE (optionnel)', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          hintText: 'Bon de commande, événement, VIP…'),
                    ),
                    const SizedBox(height: 12),
                    Text('TARIF NÉGOCIÉ GROUPE (optionnel)',
                        style: BsType.eyebrow()),
                    const SizedBox(height: 2),
                    Text(
                        'Applique la même remise au tarif/nuit de chaque chambre sélectionnée. Le catalogue reste inchangé.',
                        style: BsType.body(10, color: BsColors.slateSoft)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      ChoiceChip(
                        label: const Text('Tarif catalogue'),
                        selected: groupDiscount == 0,
                        onSelected: (_) => setSt(() => groupDiscount = 0),
                      ),
                      for (final p in Discount.quickPercents)
                        ChoiceChip(
                          label: Text('-${Discount.formatPercent(p)}'),
                          selected: groupDiscount == p,
                          onSelected: (_) => setSt(() => groupDiscount = p),
                        ),
                    ]),
                    if (picked.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BsColors.sky.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(BsRadius.sm),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: BsColors.sky),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                groupDiscount == 0
                                    ? '${picked.length} chambre(s) · '
                                        '${montantHotelCourt(listNightlyUsd)} / nuit au total'
                                    : '${picked.length} chambre(s) · '
                                        '${moneyUsdCourt(_remise(listNightlyUsd, groupDiscount))} / nuit au lieu de '
                                        '${moneyUsdCourt(listNightlyUsd)} '
                                        '(−${moneyUsdCourt(listNightlyUsd - _remise(listNightlyUsd, groupDiscount))} / nuit)',
                                style: BsType.body(11,
                                    w: FontWeight.w600, color: BsColors.sky)),
                          ),
                        ]),
                      ),
                    ],
                    if (err != null) ...[
                      const SizedBox(height: 10),
                      Text(err!,
                          style: BsType.body(12, color: BsColors.danger)),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      TextButton(
                        onPressed:
                            busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 16),
                        style: FilledButton.styleFrom(
                            backgroundColor: BsColors.sky),
                        onPressed: (picked.isEmpty ||
                                guest.text.trim().isEmpty ||
                                busy)
                            ? null
                            : () async {
                                setSt(() {
                                  busy = true;
                                  err = null;
                                });
                                try {
                                  // 1. Fidélité : trouve ou crée le client
                                  //    du groupe, compte 1 visite par chambre.
                                  final clients = ref.read(clientsRepoProvider);
                                  final c = await clients.findOrCreate(
                                    fullName: guest.text.trim(),
                                    phone: phone.text.trim(),
                                  );
                                  for (var i = 0; i < picked.length; i++) {
                                    await clients.recordVisit(c.id);
                                  }
                                  // 2. Check-in groupé avec payerId optionnel.
                                  await ref
                                      .read(roomsRepoProvider)
                                      .groupCheckIn(
                                        numbers: picked.toList(),
                                        guest: guest.text.trim(),
                                        checkout: checkout,
                                        note: note.text.trim().isEmpty
                                            ? null
                                            : note.text.trim(),
                                        payerId: payer?.id,
                                        negotiatedPrices: groupDiscount == 0
                                            ? const {}
                                            : {
                                                for (final r in selected)
                                                  r.number: negotiatedFor(r),
                                              },
                                      );
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            backgroundColor: BsColors.success,
                                            content: Text(
                                                '${picked.length} chambres logées pour ${guest.text.trim()}.',
                                                style: BsType.body(13,
                                                    w: FontWeight.w600,
                                                    color: Colors.white))));
                                  }
                                } catch (e) {
                                  setSt(() {
                                    busy = false;
                                    err = 'Échec : $e';
                                  });
                                }
                              },
                        label: Text(picked.isEmpty
                            ? 'Sélectionne des chambres'
                            : 'Loger ${picked.length} chambre(s)'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Check-out : propose de générer une facture avant de libérer. Si la
  /// chambre fait partie d'un séjour groupé, propose au choix "cette
  /// chambre seulement" ou "tout le groupe encore présent".
  Future<void> _confirmCheckOutWithInvoice(
      BuildContext ctx, WidgetRef ref, Room room) async {
    if (room.status != DbRoomStatus.occupee) return;

    final rooms = ref.read(roomsRepoProvider);
    final isGroup = room.stayGroup != null;
    final groupMembers =
        isGroup ? await rooms.membersOfGroup(room.stayGroup!) : <Room>[room];
    if (!ctx.mounted) return;

    final choice = await showDialog<String>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: BsColors.paper,
        title: Text('Check-out chambre ${room.number}',
            style: BsType.display(18, w: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client : ${room.currentGuest ?? "—"}',
                style: BsType.body(12)),
            if (isGroup)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Séjour groupé : ${groupMembers.length} chambre(s) encore présente(s).',
                    style: BsType.body(11,
                        color: BsColors.sky, w: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            const Text('Que veux-tu faire ?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, 'cancel'),
              child: const Text('Annuler')),
          if (isGroup && groupMembers.length > 1)
            TextButton(
                onPressed: () => Navigator.pop(dctx, 'invoice_group'),
                child: const Text('Facturer tout le groupe')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, 'invoice_solo'),
              child: const Text('Facturer cette chambre')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BsColors.slate),
              onPressed: () => Navigator.pop(dctx, 'no_invoice'),
              child: const Text('Libérer sans facture')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel' || !ctx.mounted) return;

    // Cible : liste des chambres à inclure dans la facture ET à libérer.
    final targets = choice == 'invoice_group' ? groupMembers : <Room>[room];

    // Résout le payeur (société / tiers) si présent — l'id peut différer
    // entre chambres d'un même groupe si Pamela a saisi différemment ;
    // on prend le payeur de la chambre cliquée en source de vérité.
    Payer? payer;
    if (room.payerId != null) {
      payer = await ref.read(payersRepoProvider).byId(room.payerId!);
    }

    if (choice != 'no_invoice') {
      final sales = ref.read(salesRepoProvider);
      final earliest = targets
          .map((r) => r.checkinAt ?? DateTime.now())
          .reduce((a, b) => a.isBefore(b) ? a : b);
      // Uniquement les consommations MISES SUR LA NOTE. Celles déjà
      // réglées au bar ne doivent pas réapparaître ici : le client les
      // paierait deux fois.
      final extrasDisponibles = await sales.unpaidForStay(
          sejourId: room.currentStayId,
          roomNumbers: targets.map((r) => r.number).toList(),
          since: earliest);
      final now = DateTime.now();

      // Fidélité : retrouve le client par nom pour afficher le badge et
      // ajouter le montant dépensé après facturation.
      Client? client;
      if (room.currentGuest != null && room.currentGuest!.isNotEmpty) {
        final matches = await ref
            .read(clientsRepoProvider)
            .search(room.currentGuest!, limit: 1);
        if (matches.isNotEmpty &&
            matches.first.fullName.toLowerCase() ==
                room.currentGuest!.toLowerCase()) {
          client = matches.first;
        }
      }

      // Calcul du sous-total pour afficher un preview au serveur.
      // Prix effectif = tarif négocié au check-in si présent, sinon le
      // tarif catalogue. L'écart est tracé pour l'afficher sur la facture.
      int effectivePrice(Room r) =>
          (r.negotiatedPriceCents != null && r.negotiatedPriceCents! > 0)
              ? r.negotiatedPriceCents!
              : r.pricePerNightCents;
      final accommodation = targets.fold<int>(
          0,
          (s, r) =>
              s + effectivePrice(r) * _nightsBetween(r.checkinAt ?? now, now));
      final negotiatedSaving = targets.fold<int>(0, (s, r) {
        final saving = r.pricePerNightCents - effectivePrice(r);
        return saving <= 0
            ? s
            : s + saving * _nightsBetween(r.checkinAt ?? now, now);
      });
      final extrasTotal =
          extrasDisponibles.fold<int>(0, (s, e) => s + e.totalCents);
      final subtotal = accommodation + extrasTotal;

      // Dialog de saisie des infos de paiement (acompte, remise, mode).
      if (!ctx.mounted) return;
      final billing = await _showBillingDetailsDialog(
        ctx,
        accommodationCents: accommodation,
        extrasCents: extrasTotal,
        negotiatedSavingCents: negotiatedSaving,
        canDiscount: ref.read(permsProvider).canDiscount,
        defaultClient: client,
      );
      if (billing == null || !ctx.mounted) return;

      // Ce que la réception a décidé de facturer. Décoché, les notes ne
      // sont ni imprimées ni soldées : elles restent dues.
      final extras = billing.inclureConsommations
          ? extrasDisponibles
          : extrasDisponibles.sublist(0, 0);

      // Numéros du reçu au format demandé — FCT{seq}/{mois}/{année}.
      // Ici seq = compte des chiffres du timestamp pour un identifiant
      // court, unique et lisible (à défaut d'un vrai séquenceur SQL).
      final seq = (now.millisecondsSinceEpoch % 1000).toString();
      final receiptNumber = 'FCT$seq/${now.month}/${now.year}';
      final reservationNumber = 'RSV$seq/${now.month}/${now.year}';
      final me = ref.read(authProvider).user;

      final data = StayInvoiceData(
        receiptNumber: receiptNumber,
        reservationNumber: reservationNumber,
        stayGroup: room.stayGroup,
        guestFullName: room.currentGuest ?? 'Client',
        guestNationality: billing.nationality,
        guestPhone: billing.phone,
        guestEmail: billing.email,
        note: room.checkinNote,
        payerName: payer?.name,
        payerTaxId: payer?.taxId,
        payerAddress: payer?.address,
        payerContact: payer?.contact,
        clientVisitsCount: client?.visitsCount ?? 0,
        serverLogin: me?.login,
        paymentMode: billing.paymentMode,
        acompteFcCents: billing.acompteFcCents,
        acompteUsdCents: billing.acompteUsdCents,
        // Le taux du jour, figé sur la facture comme il l'est sur le
        // séjour. Réimprimée dans six mois, elle annoncera le montant
        // que le client a réellement payé.
        fcPerUsdCents: tauxCourantEnCents(),
        remiseCents: billing.remiseCents,
        remiseLabel: billing.discount.invoiceLabel,
        rooms: [
          for (final r in targets)
            StayInvoiceRoom(
              number: r.number,
              type: r.type,
              checkinAt: r.checkinAt ?? now,
              checkoutAt: now,
              pricePerNightCents: effectivePrice(r),
              // Le prix facturé, exprimé dans la devise où il a été
              // négocié. Reconverti depuis les francs, un tarif de $45
              // ressortirait « $44,99 ».
              priceUsdCents: fcVersUsd(effectivePrice(r)),
              listPriceCents: r.pricePerNightCents,
              nights: _nightsBetween(r.checkinAt ?? now, now),
            ),
        ],
        extras: extras,
        generatedAt: now,
      );
      // Le séjour existe depuis l'arrivée : on le CLÔTURE avec sa facture
      // (et on le détache du groupe si seules ces chambres partent).
      await ref.read(staysRepoProvider).cloturer(
        sejourId: room.currentStayId,
        chambres: targets.map((r) => r.number).toList(),
        receiptNumber: receiptNumber,
        reservationNumber: reservationNumber,
        generatedAt: now,
        checkinAt: earliest,
        checkoutAt: now,
        guestFullName: room.currentGuest ?? 'Client',
        guestNationality: billing.nationality,
        guestPhone: billing.phone,
        guestEmail: billing.email,
        payerName: payer?.name,
        payerTaxId: payer?.taxId,
        payerAddress: payer?.address,
        payerContact: payer?.contact,
        subtotalCents: subtotal,
        remiseCents: billing.remiseCents,
        discount: billing.discount,
        acompteFcCents: billing.acompteFcCents,
        acompteUsdCents: billing.acompteUsdCents,
        paymentMode: billing.paymentMode.index,
        stayGroup: room.stayGroup,
        serverLogin: me?.login,
        note: room.checkinNote,
        extrasJson: jsonEncode([
          for (final s in extras)
            {
              'sale_id': s.sale.id,
              'sold_at': isoServeur(s.sale.soldAt),
              'room_number': s.sale.roomNumber,
              'total_cents': s.totalCents,
              'lines': [
                for (final l in s.lines)
                  {
                    'name': l.articleName,
                    'qty': l.qty,
                    'unit_price_cents': l.unitPriceCents,
                  }
              ],
            }
        ]),
        clientVisitsAtCheckout: client?.visitsCount ?? 0,
        rooms: [
          for (final r in targets)
            (
              number: r.number,
              type: r.type,
              checkinAt: r.checkinAt ?? now,
              checkoutAt: now,
              pricePerNightCents: effectivePrice(r),
              listPriceCents: r.pricePerNightCents,
              nights: _nightsBetween(r.checkinAt ?? now, now),
            )
        ],
      );

      await PdfService.previewStayInvoice(data);

      // Les consommations facturées viennent d'être payées avec le
      // séjour : on les solde. Sans ça, elles restaient « à recouvrer »
      // pour toujours dans les rapports et chez Pamela, alors que
      // l'argent était bien rentré. Si la réception les a décochées,
      // `extras` est vide et elles restent dues — c'est voulu.
      for (final e in extras) {
        await ref
            .read(salesRepoProvider)
            .settleDebt(e.sale.id, _paiementVersDbPayment(billing.paymentMode));
      }

      // Comptabilise la dépense sur le fichier fidélité de l'occupant
      // (total après remise, montant réellement facturé).
      if (client != null) {
        await ref
            .read(clientsRepoProvider)
            .addSpending(client.id, data.totalCents);
      }
    }

    // Sans facture : le séjour est clôturé « sans facture » au lieu de
    // disparaître. Il en reste une trace sur ce poste.
    if (choice == 'no_invoice') {
      await ref
          .read(staysRepoProvider)
          .libererSansFacture(sejourId: room.currentStayId, chambres: targets);
    }

    // Libère les chambres facturées.
    for (final r in targets) {
      await rooms.checkOut(r.number);
    }
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          backgroundColor: BsColors.success,
          content: Text(
              targets.length == 1
                  ? 'Chambre ${targets.first.number} libérée.'
                  : '${targets.length} chambres libérées.',
              style:
                  BsType.body(13, w: FontWeight.w600, color: Colors.white))));
    }
  }

  /// Traduit le mode de paiement de la facture de séjour vers celui des
  /// ventes, pour solder les consommations avec le bon moyen.
  static DbPayment _paiementVersDbPayment(InvoicePayment p) => switch (p) {
        InvoicePayment.card => DbPayment.card,
        InvoicePayment.mobileMoney => DbPayment.mobileMoney,
        _ => DbPayment.cash,
      };

  /// Nombre de nuits arrondi au supérieur, minimum 1.
  static int _nightsBetween(DateTime checkin, DateTime checkout) {
    if (!checkout.isAfter(checkin)) return 1;
    final hours = checkout.difference(checkin).inHours;
    final n = (hours / 24).ceil();
    return n < 1 ? 1 : n;
  }

  /// Dialog de saisie des détails de facturation au check-out :
  /// coordonnées client (nationalité, tél, email — pré-remplis depuis
  /// la fiche client si dispo), acompte reçu (FC + USD séparément
  /// comme sur le reçu papier), remise consentie, mode de paiement.
  ///
  /// La remise se saisit en **pourcentage** (chips rapides ou valeur
  /// libre) ou en **montant fixe**, avec une assiette de calcul
  /// (hébergement seul / total avec les consommations) et un motif qui
  /// sera imprimé sur la facture. Tout le calcul vit dans [Discount] —
  /// l'aperçu ci-dessous et le PDF donnent donc le même chiffre.
  ///
  /// Retourne `null` si l'utilisateur annule.
  Future<_BillingDraft?> _showBillingDetailsDialog(
    BuildContext ctx, {
    required int accommodationCents,
    required int extrasCents,
    required int negotiatedSavingCents,

    /// Faux pour une serveuse : la section remise est alors masquée ET
    /// la remise forcée à zéro. Masquer sans forcer laisserait passer
    /// une valeur saisie avant un changement de compte.
    required bool canDiscount,
    Client? defaultClient,
  }) {
    final subtotalCents = accommodationCents + extrasCents;
    final nationality = TextEditingController();
    final phone = TextEditingController(text: defaultClient?.phone ?? '');
    final email = TextEditingController(text: defaultClient?.email ?? '');
    final acompteFc = TextEditingController();
    final acompteUsd = TextEditingController();
    final remiseAmount = TextEditingController();
    final remisePercent = TextEditingController();
    final remiseReason = TextEditingController();
    InvoicePayment mode = InvoicePayment.cash;
    // Par défaut : pourcentage sur l'hébergement — c'est la remise que
    // la réception accorde le plus souvent (on n'offre pas le bar).
    DiscountKind kind = DiscountKind.percent;
    DiscountBase base = DiscountBase.accommodation;
    // Par défaut on facture tout : c'est le cas courant, et l'oubli
    // coûterait de l'argent à l'hôtel.
    bool inclureConsommations = true;

    return showDialog<_BillingDraft>(
      context: ctx,
      builder: (dctx) => StatefulBuilder(builder: (context, setSt) {
        int parseInt(TextEditingController c) =>
            int.tryParse(c.text.trim().replaceAll(' ', '')) ?? 0;
        final aFc = parseInt(acompteFc);
        final aUsd = parseInt(acompteUsd);
        final aUsdInFc = (aUsd * Currency.rate / 100).round();

        // Sans le droit, aucune remise ne peut sortir d'ici — quoi qu'il
        // y ait dans les champs.
        // Les consommations sortent du calcul si elles sont décochées.
        final extrasRetenus = inclureConsommations ? extrasCents : 0;
        final discount = !canDiscount
            ? Discount.none
            : Discount(
                kind: kind,
                // Une remise en montant se saisit en DOLLARS : c'est la
                // devise dans laquelle le tarif a été annoncé, et donc
                // celle dans laquelle le geste commercial se négocie.
                value: kind == DiscountKind.percent
                    ? Discount.parsePercent(remisePercent.text)
                    : _usdEnCents(remiseAmount.text),
                base: base,
                reason: remiseReason.text,
              );
        final rem = discount.amountCents(
          accommodationCents: accommodationCents,
          extrasCents: extrasRetenus,
        );
        // Sous-total recalculé : l'hébergement plus les consommations
        // SEULEMENT si elles sont facturées.
        final sousTotal = accommodationCents + extrasRetenus;
        final total = (sousTotal - rem).clamp(0, 1 << 40);
        final paid = aFc + aUsdInFc;
        final remaining = (total - paid).clamp(0, 1 << 40);

        void setPercent(int hundredths) {
          remisePercent.text =
              Discount.formatPercent(hundredths).replaceAll(' %', '');
          setSt(() => kind = DiscountKind.percent);
        }

        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('DÉTAILS DE FACTURATION',
                        style: BsType.eyebrow(color: BsColors.sunrise)),
                    const SizedBox(height: 6),
                    Text('Reçu à générer',
                        style: BsType.display(18, w: FontWeight.w700)),
                    const SizedBox(height: 16),
                    // Détail du sous-total : indispensable pour choisir
                    // l'assiette de la remise en connaissance de cause.
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BsColors.inkSoft.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(BsRadius.sm),
                      ),
                      child: Column(children: [
                        _breakdownRow('Hébergement', accommodationCents),
                        if (extrasCents > 0)
                          _breakdownRow('Consommations', extrasCents),
                        if (negotiatedSavingCents > 0)
                          _breakdownRow('Tarifs négociés déjà déduits',
                              -negotiatedSavingCents,
                              color: BsColors.success),
                        const Divider(height: 12),
                        _breakdownRow('Sous-total', subtotalCents, bold: true),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Text('COORDONNÉES CLIENT (pour la facture)',
                        style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nationality,
                      decoration: const InputDecoration(
                          hintText: 'Nationalité (ex. Congolaise)'),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(hintText: 'Téléphone'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(hintText: 'Email'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text('MODE DE PAIEMENT', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      for (final p in InvoicePayment.values)
                        ChoiceChip(
                          label: Text(p.label),
                          selected: mode == p,
                          onSelected: (_) => setSt(() => mode = p),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    Text('ACOMPTE REÇU', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: acompteFc,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSt(() {}),
                          decoration: const InputDecoration(
                              hintText: '0', suffixText: 'FC'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: acompteUsd,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSt(() {}),
                          decoration: const InputDecoration(
                              hintText: '0', suffixText: 'cts \$'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        'ACOMPTE USD en cents (100 = 1,00 \$). Converti au taux courant : $aUsdInFc FC.',
                        style: BsType.body(10, color: BsColors.slateSoft)),
                    // Inclure ou non les consommations mises sur la note.
                    // Décoché, le séjour est facturé sans le bar et les
                    // notes restent dues — utile quand une société paie
                    // la chambre mais pas les extras de son employé.
                    if (extrasCents > 0) ...[
                      const SizedBox(height: BsSpace.smd),
                      CheckboxListTile(
                        value: inclureConsommations,
                        onChanged: (v) =>
                            setSt(() => inclureConsommations = v ?? true),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Ajouter les consommations',
                            style: BsType.body(14, w: FontWeight.w600)),
                        subtitle: Text(
                            inclureConsommations
                                ? '${moneyCents(extrasCents)} de bar et '
                                    'restaurant sur cette facture'
                                : 'Les ${moneyCents(extrasCents)} de '
                                    'consommations restent dus',
                            style: BsType.body(12,
                                color: inclureConsommations
                                    ? BsColors.slate
                                    : BsColors.warning)),
                      ),
                    ],
                    // ── Remise ────────────────────────────────────────
                    // Invisible pour les serveuses : une remise, c'est de
                    // l'argent qui sort, et le bar n'en décide pas.
                    if (canDiscount) const SizedBox(height: 16),
                    if (canDiscount)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BsColors.sunrise.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(BsRadius.sm),
                          border: Border.all(
                              color: BsColors.sunrise.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('REMISE ACCORDÉE',
                                style: BsType.eyebrow(color: BsColors.sunrise)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, children: [
                              ChoiceChip(
                                label: const Text('Pourcentage'),
                                selected: kind == DiscountKind.percent,
                                onSelected: (_) =>
                                    setSt(() => kind = DiscountKind.percent),
                              ),
                              ChoiceChip(
                                label: const Text('Montant fixe'),
                                selected: kind == DiscountKind.amount,
                                onSelected: (_) =>
                                    setSt(() => kind = DiscountKind.amount),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            if (kind == DiscountKind.percent) ...[
                              Wrap(spacing: 6, runSpacing: 4, children: [
                                for (final p in Discount.quickPercents)
                                  ChoiceChip(
                                    label: Text(Discount.formatPercent(p)),
                                    selected: discount.value == p,
                                    onSelected: (_) => setPercent(p),
                                  ),
                                ActionChip(
                                  avatar: const Icon(Icons.close, size: 14),
                                  label: const Text('Aucune'),
                                  onPressed: () =>
                                      setSt(() => remisePercent.clear()),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              TextField(
                                controller: remisePercent,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => setSt(() {}),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  suffixText: '%',
                                  isDense: true,
                                  helperText:
                                      'Valeur libre acceptée (ex. 12,5). Plafonnée à 100 %.',
                                ),
                              ),
                              if (extrasCents > 0) ...[
                                const SizedBox(height: 10),
                                Text('APPLIQUER SUR', style: BsType.eyebrow()),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, children: [
                                  for (final b in DiscountBase.values)
                                    ChoiceChip(
                                      label: Text(b.shortLabel),
                                      selected: base == b,
                                      onSelected: (_) => setSt(() => base = b),
                                    ),
                                ]),
                              ],
                            ] else ...[
                              TextField(
                                controller: remiseAmount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => setSt(() {}),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  prefixText: '${String.fromCharCode(36)} ',
                                  isDense: true,
                                  helperText: _usdEnCents(remiseAmount.text) > 0
                                      // L'équivalent en francs, tout de
                                      // suite : c'est ce qui sera déduit
                                      // du total, et la réception doit le
                                      // voir avant de valider.
                                      ? 'Soit ${moneyCents(usdVersFc(_usdEnCents(remiseAmount.text)))}'
                                          ' · plafonnée à ${moneyCents(subtotalCents)}'
                                      : 'Plafonnée au sous-total (${moneyCents(subtotalCents)}).',
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text('MOTIF (imprimé sur la facture)',
                                style: BsType.eyebrow()),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              for (final r in Discount.quickReasons)
                                ChoiceChip(
                                  label: Text(r, style: BsType.body(11)),
                                  selected: remiseReason.text.trim() == r,
                                  onSelected: (_) => setSt(() {
                                    remiseReason.text =
                                        remiseReason.text.trim() == r ? '' : r;
                                  }),
                                ),
                            ]),
                            const SizedBox(height: 6),
                            TextField(
                              controller: remiseReason,
                              onChanged: (_) => setSt(() {}),
                              decoration: const InputDecoration(
                                hintText:
                                    'ex. Accord Afrinvest — convention 2026',
                                isDense: true,
                              ),
                            ),
                            if (rem > 0) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                const Icon(Icons.local_offer,
                                    size: 14, color: BsColors.sunrise),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                      'Remise : −${moneyUsdCourt(fcVersUsd(rem))} '
                                      '(−${moneyCents(rem)})'
                                      '${discount.formulaLabel == null ? "" : " (${discount.formulaLabel})"}',
                                      style: BsType.body(12,
                                          w: FontWeight.w700,
                                          color: BsColors.sunrise)),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Preview des totaux
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: BsColors.ink,
                        borderRadius: BorderRadius.circular(BsRadius.sm),
                      ),
                      child: Column(children: [
                        _totalPreviewRow('Sous-total', subtotalCents),
                        if (rem > 0) _totalPreviewRow('Remise', rem),
                        _totalPreviewRow('Total après remise', total),
                        _totalPreviewRow('Total payé', paid),
                        Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            height: 1,
                            color: Colors.white24),
                        _totalPreviewRow('Reste à payer', remaining,
                            highlight: true),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annuler')),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 16),
                        style: FilledButton.styleFrom(
                            backgroundColor: BsColors.sunrise),
                        onPressed: () {
                          Navigator.of(context).pop(_BillingDraft(
                            nationality: nationality.text.trim().isEmpty
                                ? null
                                : nationality.text.trim(),
                            phone: phone.text.trim().isEmpty
                                ? null
                                : phone.text.trim(),
                            email: email.text.trim().isEmpty
                                ? null
                                : email.text.trim(),
                            paymentMode: mode,
                            acompteFcCents: aFc,
                            acompteUsdCents: aUsd,
                            discount: discount,
                            inclureConsommations: inclureConsommations,
                            remiseCents: rem,
                          ));
                        },
                        label: const Text('Générer le reçu'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Ligne du récapitulatif de sous-total (montant négatif = déduction).
  static Widget _breakdownRow(String label, int cents,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: BsType.body(bold ? 12 : 11,
                  color: color ?? BsColors.slate,
                  w: bold ? FontWeight.w700 : FontWeight.w500)),
          Text('${cents < 0 ? "−" : ""}${moneyCents(cents.abs())}',
              style: BsType.body(bold ? 14 : 12,
                  w: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  static Widget _totalPreviewRow(String label, int cents,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: BsType.body(12,
                  color: highlight ? BsColors.sunrise : Colors.white70,
                  w: highlight ? FontWeight.w700 : FontWeight.w500)),
          Text(moneyCents(cents),
              style: BsType.body(highlight ? 14 : 12,
                  w: FontWeight.w700,
                  color: highlight ? BsColors.sunrise : Colors.white)),
        ],
      ),
    );
  }

  void _showCheckIn(BuildContext ctx, WidgetRef ref, Room room) {
    final guest = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    DateTime checkout = DateTime.now().add(const Duration(days: 1));
    Payer? payer;
    int? negotiated;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('CHECK-IN CHAMBRE ${room.number}',
                        style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    Text(
                        '${room.type} · ${montantHotelCourt(room.priceUsdCents)}/nuit',
                        style: BsType.body(13, color: BsColors.slate)),
                    const SizedBox(height: 16),
                    ClientLookupField(
                      nameCtrl: guest,
                      phoneCtrl: phone,
                      autofocusName: true,
                    ),
                    const SizedBox(height: 12),
                    PayerPickerSection(
                      initial: payer,
                      onChanged: (p) => setSt(() => payer = p),
                    ),
                    const SizedBox(height: 12),
                    NegotiatedRateField(
                      listPriceCents: room.pricePerNightCents,
                      onChanged: (v) => negotiated = v,
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
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setSt(() => checkout = picked);
                      },
                      label: Text(
                          '${checkout.day}/${checkout.month}/${checkout.year}',
                          style: BsType.body(13)),
                    ),
                    const SizedBox(height: 12),
                    Text('NOTE (optionnel)', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Ex : petit-déj inclus, chambre calme demandée, VIP, allergie…',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Cette note apparaîtra sur la fiche chambre et dans le rapport.',
                        style: BsType.body(11, color: BsColors.slateSoft)),
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
                                // 1. Fidélité : trouve ou crée le client,
                                //    puis compte cette visite.
                                final clients = ref.read(clientsRepoProvider);
                                final c = await clients.findOrCreate(
                                  fullName: guest.text.trim(),
                                  phone: phone.text.trim(),
                                );
                                await clients.recordVisit(c.id);
                                // 2. Check-in de la chambre avec payerId
                                //    optionnel.
                                await ref.read(roomsRepoProvider).checkIn(
                                      room.number,
                                      guest.text.trim(),
                                      checkout,
                                      note: note.text.trim().isEmpty
                                          ? null
                                          : note.text.trim(),
                                      payerId: payer?.id,
                                      negotiatedPriceCents: negotiated,
                                    );
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: const Text('Enregistrer'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Dialog "Demande de ravitaillement pour l'HÔTEL" — accessible à
  /// la réception + admin + super admin depuis l'écran Chambres.
  ///
  /// Ici l'hôtel n'a pas de "stock" à proprement parler : les produits du
  /// restaurant/terrasse (Coca, bière, portions…) sont gérés séparément.
  /// La demande hôtel est donc une **note libre** que Pamela lit et
  /// exécute manuellement (draps neufs, savon en gros, kit accueil…).
  void _showHotelSupplyRequest(BuildContext ctx, WidgetRef ref) {
    final noteCtrl = TextEditingController();
    String? err;
    bool busy = false;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('DEMANDE DE RAVITAILLEMENT — HÔTEL',
                      style: BsType.eyebrow(color: BsColors.sunrise)),
                  const SizedBox(height: 6),
                  Text('Faire remonter un besoin à Pamela',
                      style: BsType.display(18, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      'Écris librement ce qui manque : Pamela reçoit ta demande sur son tableau et sur son téléphone.',
                      style: BsType.body(11, color: BsColors.slateSoft)),
                  const SizedBox(height: 16),
                  Text('DÉTAIL DE LA DEMANDE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText:
                          'ex. 20 draps blancs, 5 kg savon, kits accueil chambre 12 & 15, ampoules LED pour couloir…',
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    TextButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 16),
                      style: FilledButton.styleFrom(
                          backgroundColor: BsColors.sunrise),
                      onPressed: busy
                          ? null
                          : () async {
                              final text = noteCtrl.text.trim();
                              if (text.isEmpty) {
                                setSt(() => err =
                                    'Écris au moins un mot avant d\'envoyer.');
                                return;
                              }
                              final me = ref.read(authProvider).user;
                              setSt(() {
                                busy = true;
                                err = null;
                              });
                              // On stocke le texte de la demande dans
                              // article_name (visible partout : dashboard,
                              // hub notif, historique) — tronqué à 200
                              // car. pour rester lisible en aperçu.
                              // Le texte complet part aussi dans `note`.
                              final label = text.length <= 200
                                  ? text
                                  : '${text.substring(0, 197)}…';
                              final id = await SupplyRequestsService.submit(
                                articleId: null,
                                articleName: label,
                                location: DbLocation.hotel,
                                qtyRequested: 1,
                                qtyAtRequest: 0,
                                thresholdAtRequest: 0,
                                requestedByLogin: me?.login ?? 'inconnu',
                                note: text,
                              );
                              if (!context.mounted) return;
                              if (id == null) {
                                setSt(() {
                                  busy = false;
                                  err =
                                      'Échec — pas de réseau ou Supabase indisponible ?';
                                });
                                return;
                              }
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      backgroundColor: BsColors.success,
                                      content: Text('Demande envoyée à Pamela.',
                                          style: BsType.body(13,
                                              w: FontWeight.w600,
                                              color: Colors.white))));
                            },
                      label: const Text('Envoyer'),
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
    // Le tarif se saisit en DOLLARS : c'est le prix annoncé au client.
    // Sans décimales quand il tombe rond — « 45 » plutôt que « 45.0 »,
    // parce qu'un tarif d'hôtel tombe presque toujours rond.
    final price = TextEditingController(
        text: existing == null || existing.priceUsdCents <= 0
            ? ''
            : (existing.priceUsdCents % 100 == 0
                ? (existing.priceUsdCents ~/ 100).toString()
                : (existing.priceUsdCents / 100).toStringAsFixed(2)));
    String? imagePath = existing?.imagePath;
    String? err;
    bool busy = false;
    final isEdit = existing != null;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(isEdit ? 'ÉDITER CHAMBRE' : 'NOUVELLE CHAMBRE',
                        style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    Text(
                        isEdit
                            ? 'Chambre ${existing.number}'
                            : 'Ajouter au plan',
                        style: BsType.display(22, w: FontWeight.w700)),
                    const SizedBox(height: 20),
                    // ── Bloc photo (haut, comme les articles POS) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: BsColors.inkSoft.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(BsRadius.sm),
                            border: Border.all(color: BsColors.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _RoomImagePreview(
                              path: imagePath, decodeWidth: 1200),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PHOTO', style: BsType.eyebrow()),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.image_outlined, size: 16),
                                onPressed: () async {
                                  final file = await openFile(
                                    acceptedTypeGroups: const [
                                      XTypeGroup(label: 'Images', extensions: [
                                        'jpg',
                                        'jpeg',
                                        'png',
                                        'webp'
                                      ]),
                                    ],
                                  );
                                  if (file != null) {
                                    setSt(() => imagePath = file.path);
                                  }
                                },
                                label: Text(
                                    imagePath == null ? 'Ajouter' : 'Changer',
                                    style: BsType.body(12)),
                              ),
                              if (imagePath != null)
                                TextButton(
                                  onPressed: () =>
                                      setSt(() => imagePath = null),
                                  child: Text('Retirer',
                                      style: BsType.body(11,
                                          color: BsColors.slate)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('NUMÉRO', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: number,
                      enabled: !isEdit, // PK non modifiable
                      autofocus: !isEdit,
                      decoration: InputDecoration(
                        hintText: 'ex. 12 ou B3',
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
                          hintText: 'Standard / Double / Suite / Bungalow'),
                    ),
                    const SizedBox(height: 12),
                    Text('PRIX / NUIT (USD)', style: BsType.eyebrow()),
                    const SizedBox(height: 6),
                    TextField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setSt(() {}),
                      decoration: InputDecoration(
                          hintText: '45', prefixText: String.fromCharCode(36)),
                    ),
                    const SizedBox(height: 6),
                    // L'équivalent en francs, sous le champ : la réception
                    // encaisse dans cette monnaie-là, elle doit le voir
                    // sans avoir à le calculer.
                    Builder(builder: (_) {
                      final usd = _usdEnCents(price.text);
                      return Text(
                          usd <= 0
                              ? 'Soit — FC au taux actuel'
                              : 'Soit ${moneyCents(usdVersFc(usd))} au taux actuel',
                          style: BsType.body(12, color: BsColors.slate));
                    }),
                    if (err != null) ...[
                      const SizedBox(height: 12),
                      Text(err!,
                          style: BsType.body(12, color: BsColors.danger)),
                    ],
                    const SizedBox(height: 24),
                    Row(children: [
                      TextButton(
                        onPressed:
                            busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final p = _usdEnCents(price.text);
                                if (number.text.trim().isEmpty ||
                                    type.text.trim().isEmpty ||
                                    p <= 0) {
                                  setSt(() =>
                                      err = 'Tous les champs sont requis');
                                  return;
                                }
                                setSt(() {
                                  busy = true;
                                  err = null;
                                });
                                // Upload cloud si nouveau chemin local.
                                var savedImage = imagePath;
                                if (imagePath != null &&
                                    !imagePath!.startsWith('http') &&
                                    File(imagePath!).existsSync() &&
                                    CloudService.enabled) {
                                  final url =
                                      await CloudService.uploadRoomImage(
                                          File(imagePath!));
                                  if (url != null) savedImage = url;
                                }
                                try {
                                  if (isEdit) {
                                    await ref
                                        .read(roomsRepoProvider)
                                        .updateInfo(
                                          number: existing.number,
                                          type: type.text.trim(),
                                          priceUsdCents: p,
                                          imagePath: savedImage,
                                        );
                                  } else {
                                    await ref.read(roomsRepoProvider).create(
                                          number: number.text.trim(),
                                          type: type.text.trim(),
                                          priceUsdCents: p,
                                          imagePath: savedImage,
                                        );
                                  }
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } catch (_) {
                                  setSt(() {
                                    busy = false;
                                    err = 'Ce numéro de chambre existe déjà';
                                  });
                                }
                              },
                        child: Text(isEdit ? 'Enregistrer' : 'Créer'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, WidgetRef ref, Room room) async {
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
      builder: (dialogCtx) => AlertDialog(
        title: Text('Supprimer la chambre ${room.number} ?'),
        content: const Text(
            'Cette action est définitive. La chambre disparaîtra du plan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
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

/// Le bandeau « aujourd'hui » en tête du plan des chambres.
///
/// Remplace l'ancienne bannière de retards, qui ne montrait qu'un quart
/// du problème. Quatre compteurs cliquables qui filtrent la grille en
/// dessous : la réception voit ce qu'il y a à faire avant de voir l'état
/// des 19 chambres.
class _TodayBand extends StatelessWidget {
  final TodayBoard board;
  final RoomTask? selected;
  final ValueChanged<RoomTask?> onSelect;

  const _TodayBand({
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
                  .map((r) => 'Ch. ${r.number} · ${_daysLate(r)} j')
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
          if (room.imagePath != null && room.imagePath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BsRadius.sm),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _RoomImagePreview(path: room.imagePath),
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

/// Détails saisis dans le dialog "Détails de facturation" au check-out.
class _BillingDraft {
  final String? nationality;
  final String? phone;
  final String? email;
  final InvoicePayment paymentMode;
  final int acompteFcCents;
  final int acompteUsdCents;

  /// Remise telle que saisie (type, valeur, assiette, motif).
  final Discount discount;

  /// Faux quand la réception a décoché « Ajouter les consommations » :
  /// le séjour est facturé sans le bar, et les notes restent dues.
  final bool inclureConsommations;

  /// Montant déjà calculé par [Discount.amountCents] — recopié ici pour
  /// que l'appelant n'ait pas à refaire le calcul (et ne risque pas de
  /// le faire différemment).
  final int remiseCents;

  const _BillingDraft({
    required this.paymentMode,
    required this.acompteFcCents,
    required this.acompteUsdCents,
    required this.discount,
    this.inclureConsommations = true,
    required this.remiseCents,
    this.nationality,
    this.phone,
    this.email,
  });
}

/// Aperçu de la photo d'une chambre (fichier local OU URL http). Fallback
/// icône générique si vide/erreur.
/// Applique une remise en centièmes de pourcent à un montant.
///
/// Le calcul se fait sur les DOLLARS, pas sur les francs reconvertis :
/// une remise de 10 % sur $45 doit donner $40,50, pas $40,49 hérité d'un
/// aller-retour par les francs.
int _remise(int usdCents, int centiemesDePourcent) =>
    (usdCents * (10000 - centiemesDePourcent) / 10000).round();

/// Une saisie en dollars vers des cents. « 45 » → 4500, « 12,5 » → 1250.
///
/// Accepte la virgule ET le point : le pavé numérique produit l'un ou
/// l'autre selon la configuration du clavier, et la réception ne doit
/// pas avoir à deviner lequel.
int _usdEnCents(String saisie) {
  final t = saisie.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return 0;
  final v = double.tryParse(t);
  if (v == null || v <= 0) return 0;
  return (v * 100).round();
}

class _RoomImagePreview extends StatelessWidget {
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

  const _RoomImagePreview({required this.path, this.decodeWidth = 400});

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
