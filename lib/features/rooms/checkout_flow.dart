import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../core/temps.dart';
import '../../data/schema.dart';
import '../../services/pdf_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/devise.dart';
import 'billing_dialog.dart';

// Le départ d'un client : facture (ou non), clôture du séjour, libération
// des chambres.

/// Check-out : propose de générer une facture avant de libérer. Si la
/// chambre fait partie d'un séjour groupé, propose au choix "cette
/// chambre seulement" ou "tout le groupe encore présent".
Future<void> confirmCheckOutWithInvoice(
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
          Text('Client : ${room.currentGuest ?? "—"}', style: BsType.body(12)),
          if (isGroup)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'Séjour groupé : ${groupMembers.length} chambre(s) encore présente(s).',
                  style:
                      BsType.body(11, color: BsColors.sky, w: FontWeight.w600)),
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
    final billing = await showBillingDetailsDialog(
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
    // Taux de TVA du jour : le même que celui figé sur le séjour.
    final tvaBp = await ref.read(settingsRepoProvider).getTvaBp();

    final data = StayInvoiceData(
      tvaBp: tvaBp,
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
            style: BsType.body(13, w: FontWeight.w600, color: Colors.white))));
  }
}

/// Traduit le mode de paiement de la facture de séjour vers celui des
/// ventes, pour solder les consommations avec le bon moyen.
DbPayment _paiementVersDbPayment(InvoicePayment p) => switch (p) {
      InvoicePayment.card => DbPayment.card,
      InvoicePayment.mobileMoney => DbPayment.mobileMoney,
      _ => DbPayment.cash,
    };

/// Nombre de nuits arrondi au supérieur, minimum 1.
int _nightsBetween(DateTime checkin, DateTime checkout) {
  if (!checkout.isAfter(checkin)) return 1;
  final hours = checkout.difference(checkin).inHours;
  final n = (hours / 24).ceil();
  return n < 1 ? 1 : n;
}
