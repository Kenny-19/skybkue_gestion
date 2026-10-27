import 'package:flutter/material.dart';

import '../../core/discount.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../services/pdf_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/devise.dart';

// Les détails de facturation saisis au départ : coordonnées, acompte,
// remise, mode de paiement.

/// Détails saisis dans le dialog "Détails de facturation" au check-out.
class BillingDraft {
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

  const BillingDraft({
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
Future<BillingDraft?> showBillingDetailsDialog(
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

  return showDialog<BillingDraft>(
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
                  : usdEnCents(remiseAmount.text),
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
                                helperText: usdEnCents(remiseAmount.text) > 0
                                    // L'équivalent en francs, tout de
                                    // suite : c'est ce qui sera déduit
                                    // du total, et la réception doit le
                                    // voir avant de valider.
                                    ? 'Soit ${moneyCents(usdVersFc(usdEnCents(remiseAmount.text)))}'
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
                        Navigator.of(context).pop(BillingDraft(
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
Widget _breakdownRow(String label, int cents,
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
            style:
                BsType.body(bold ? 14 : 12, w: FontWeight.w700, color: color)),
      ],
    ),
  );
}

Widget _totalPreviewRow(String label, int cents, {bool highlight = false}) {
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
