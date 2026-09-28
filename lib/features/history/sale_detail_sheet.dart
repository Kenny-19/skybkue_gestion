import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/repos.dart';
import '../../services/pdf_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/temps.dart';

class SaleDetailSheet extends StatelessWidget {
  final SaleWithLines sale;
  final VoidCallback onClose;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onSettle; // régler une dette
  const SaleDetailSheet({
    super.key,
    required this.sale,
    required this.onClose,
    this.canDelete = false,
    this.onDelete,
    this.onSettle,
  });

  bool get _isOutstandingDebt =>
      sale.sale.onCredit && sale.sale.settledAt == null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BsColors.paper,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: BsColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sale.sale.onCredit) ...[
                      _debtBanner(),
                      const SizedBox(height: BsSpace.md),
                    ],
                    _metaGrid(),
                    const SizedBox(height: BsSpace.lg),
                    Text('ARTICLES', style: BsType.eyebrow()),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: BsColors.line),
                        borderRadius: BorderRadius.circular(BsRadius.sm),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < sale.lines.length; i++)
                            _LineRow(
                              line: sale.lines[i],
                              last: i == sale.lines.length - 1,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: BsSpace.md),
                    _totals(),
                    if (sale.sale.note != null) ...[
                      const SizedBox(height: BsSpace.lg),
                      Text('NOTE', style: BsType.eyebrow()),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BsColors.papyrus,
                          borderRadius: BorderRadius.circular(BsRadius.sm),
                          border: Border.all(color: BsColors.line),
                        ),
                        child: Text(sale.sale.note!,
                            style: BsType.body(13, color: BsColors.slate)
                                .copyWith(fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(BsSpace.lg, 20, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TICKET', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                Text('#${sale.sale.id.toString().padLeft(4, '0')}',
                    style: BsType.display(28, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    DateFormat("EEEE d MMMM y", 'fr_FR')
                        .format(aLubumbashi(sale.sale.soldAt)),
                    style: BsType.body(12, color: BsColors.slate)),
                const SizedBox(height: 2),
                Text(
                    'à ${DateFormat("HH:mm:ss", 'fr_FR').format(aLubumbashi(sale.sale.soldAt))}',
                    style: BsType.mono(13, w: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _metaGrid() {
    return Column(children: [
      if (sale.sale.customerName != null || sale.sale.roomNumber != null) ...[
        Row(children: [
          if (sale.sale.customerName != null)
            Expanded(
                child: _meta('Client', sale.sale.customerName!,
                    icon: Icons.person_outline)),
          if (sale.sale.roomNumber != null)
            Expanded(
                child: _meta('Chambre', 'N° ${sale.sale.roomNumber}',
                    icon: Icons.hotel_outlined)),
        ]),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: _meta('Serveur', sale.server?.fullName ?? '—')),
        Expanded(
            child: _meta('Emplacement', sale.sale.location.label,
                icon: sale.sale.location.icon)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _meta('Paiement', sale.sale.payment.label,
                icon: sale.sale.payment.icon)),
        Expanded(child: _meta('Articles', '${sale.itemsCount}')),
      ]),
    ]);
  }

  Widget _meta(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: BsType.eyebrow()),
        const SizedBox(height: 6),
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: BsColors.slate),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: BsType.body(13, w: FontWeight.w600)),
          ),
        ]),
      ],
    );
  }

  Widget _totals() {
    return Column(children: [
      _row('Sous-total', moneyCents(sale.totalCents)),
      const SizedBox(height: 6),
      _row('TVA (0%)', moneyCents(0)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text('TOTAL', style: BsType.eyebrow())),
        Text(moneyCents(sale.totalCents),
            style: BsType.display(28, w: FontWeight.w700)),
      ]),
    ]);
  }

  Widget _row(String l, String v) => Row(children: [
        Expanded(child: Text(l, style: BsType.body(12, color: BsColors.slate))),
        Text(v, style: BsType.mono(13, w: FontWeight.w500)),
      ]);

  Widget _debtBanner() {
    final settled = sale.sale.settledAt != null;
    final color = settled ? BsColors.success : BsColors.sunrise;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BsRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(
            settled
                ? Icons.check_circle_outline
                : Icons.account_balance_wallet_outlined,
            size: 18,
            color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            settled
                ? 'Dette réglée le ${DateFormat("d MMM y 'à' HH:mm", 'fr_FR').format(aLubumbashi(sale.sale.settledAt!))}'
                : 'DETTE EN COURS — non réglée',
            style: BsType.body(12, w: FontWeight.w700, color: color),
          ),
        ),
      ]),
    );
  }

  Widget _actions() {
    return Container(
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BsColors.line)),
      ),
      child: Column(children: [
        if (_isOutstandingDebt && onSettle != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.payments_outlined, size: 16),
              style: FilledButton.styleFrom(backgroundColor: BsColors.success),
              onPressed: onSettle,
              label: const Text('Régler la dette'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            onPressed: () => PdfService.previewInvoice(sale),
            label: const Text('Voir facture PDF'),
          ),
        ),
        if (canDelete && onDelete != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: BsColors.danger,
                side: const BorderSide(color: BsColors.danger),
              ),
              label: const Text('Supprimer la facture'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _LineRow extends StatelessWidget {
  final dynamic line;
  final bool last;
  const _LineRow({required this.line, required this.last});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: BsColors.line)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.articleName,
                  style: BsType.body(13, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${moneyCents(line.unitPriceCents)} l\'unité',
                  style: BsType.mono(11, color: BsColors.slate)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: BsColors.ink,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('×${line.qty}',
              style: BsType.mono(11, w: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 76,
          child: Text(moneyCents(line.unitPriceCents * line.qty),
              textAlign: TextAlign.right,
              style: BsType.mono(13, w: FontWeight.w700)),
        ),
      ]),
    );
  }
}
