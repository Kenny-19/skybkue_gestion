import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../data/repos.dart';
import '../../services/pdf_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'sale_detail_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  SaleWithLines? _selected;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recentSalesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (sales) {
        final byDay = <DateTime, List<SaleWithLines>>{};
        for (final s in sales) {
          final d = DateTime(
              s.sale.soldAt.year, s.sale.soldAt.month, s.sale.soldAt.day);
          byDay.putIfAbsent(d, () => []).add(s);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

        return Row(children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    eyebrow: 'Historique',
                    title: 'Ventes récentes',
                    subtitle: '${sales.length} transactions · 7 derniers jours',
                    actions: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        onPressed: sales.isEmpty
                            ? null
                            : () => PdfService.exportExcel(sales),
                        label: const Text('Excel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        onPressed:
                            sales.isEmpty ? null : () => _showPdfDialog(sales),
                        label: const Text('Rapport PDF'),
                      ),
                    ],
                  ),
                  if (sales.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(BsSpace.xl),
                      child: Container(
                        padding: const EdgeInsets.all(BsSpace.xl),
                        decoration: BoxDecoration(
                          color: BsColors.paper,
                          border: Border.all(color: BsColors.line),
                          borderRadius: BorderRadius.circular(BsRadius.md),
                        ),
                        child: Column(children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 40, color: BsColors.slateSoft),
                          const SizedBox(height: 12),
                          Text('Aucune vente enregistrée',
                              style: BsType.body(14, w: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Va au Point de vente pour enregistrer une vente.',
                              style: BsType.body(12, color: BsColors.slate)),
                        ]),
                      ),
                    )
                  else
                    for (final d in days)
                      _DaySection(
                        day: d,
                        sales: byDay[d]!,
                        selectedId: _selected?.sale.id,
                        onOpen: (s) => setState(() => _selected = s),
                      ),
                  const SizedBox(height: BsSpace.xxl),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _selected == null ? 0 : 440,
            child: _selected == null
                ? const SizedBox.shrink()
                : SaleDetailSheet(
                    sale: _selected!,
                    onClose: () => setState(() => _selected = null),
                  ),
          ),
        ]);
      },
    );
  }

  void _showPdfDialog(List<SaleWithLines> sales) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BsColors.paper,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.md)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('EXPORT PDF', style: BsType.eyebrow()),
                const SizedBox(height: 6),
                Text('Choisir le format',
                    style: BsType.display(24, w: FontWeight.w700)),
                const SizedBox(height: 20),
                _opt('Rapport synthétique',
                    'Résumé + tableau totaux par jour et catégorie',
                    Icons.summarize_outlined, () {
                  Navigator.of(ctx).pop();
                  PdfService.previewSummaryReport(sales);
                }),
                const SizedBox(height: 10),
                _opt('Rapport détaillé',
                    'Chaque vente ligne par ligne — audit complet',
                    Icons.receipt_long_outlined, () {
                  Navigator.of(ctx).pop();
                  PdfService.previewDetailedReport(sales);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _opt(String title, String subtitle, IconData icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BsRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: BsColors.line),
            borderRadius: BorderRadius.circular(BsRadius.sm),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BsColors.papyrus,
                borderRadius: BorderRadius.circular(BsRadius.sm),
              ),
              child: Icon(icon, color: BsColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BsType.body(14, w: FontWeight.w700)),
                  Text(subtitle, style: BsType.body(12, color: BsColors.slate)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16, color: BsColors.slate),
          ]),
        ),
      );
}

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<SaleWithLines> sales;
  final int? selectedId;
  final ValueChanged<SaleWithLines> onOpen;
  const _DaySection({
    required this.day,
    required this.sales,
    required this.selectedId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final total = sales.fold<int>(0, (s, e) => s + e.totalCents);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, BsSpace.md, 0, BsSpace.sm),
            child: Row(children: [
              Text(DateFormat("EEEE d MMMM", 'fr_FR').format(day).toUpperCase(),
                  style: BsType.eyebrow()),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: BsColors.line)),
              const SizedBox(width: 12),
              Text('${sales.length} ventes',
                  style: BsType.body(11, color: BsColors.slate)),
              const SizedBox(width: 8),
              Text(moneyCents(total),
                  style: BsType.mono(12, w: FontWeight.w700)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              color: BsColors.paper,
              borderRadius: BorderRadius.circular(BsRadius.md),
              border: Border.all(color: BsColors.line),
            ),
            child: Column(
              children: [
                for (int i = 0; i < sales.length; i++)
                  _SaleRow(
                    sale: sales[i],
                    selected: sales[i].sale.id == selectedId,
                    last: i == sales.length - 1,
                    onOpen: () => onOpen(sales[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatefulWidget {
  final SaleWithLines sale;
  final bool selected;
  final bool last;
  final VoidCallback onOpen;
  const _SaleRow({
    required this.sale,
    required this.selected,
    required this.last,
    required this.onOpen,
  });
  @override
  State<_SaleRow> createState() => _SaleRowState();
}

class _SaleRowState extends State<_SaleRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
          decoration: BoxDecoration(
            color: widget.selected
                ? BsColors.papyrus
                : (_hover ? BsColors.papyrus.withValues(alpha: 0.5) : Colors.transparent),
            border: widget.last
                ? null
                : const Border(bottom: BorderSide(color: BsColors.line)),
          ),
          child: Row(children: [
            SizedBox(
              width: 64,
              child: Text('#${s.sale.id.toString().padLeft(4, '0')}',
                  style: BsType.mono(12, color: BsColors.slate)),
            ),
            SizedBox(
              width: 76,
              child: Text(DateFormat('HH:mm:ss', 'fr_FR').format(s.sale.soldAt),
                  style: BsType.mono(13, w: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: s.sale.location.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.sale.location.icon,
                    size: 10, color: s.sale.location.color),
                const SizedBox(width: 4),
                Text(s.sale.location.label,
                    style: BsType.body(10,
                        w: FontWeight.w700, color: s.sale.location.color)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.lines.map((l) => '${l.qty}× ${l.articleName}').join(' · '),
                overflow: TextOverflow.ellipsis,
                style: BsType.body(13),
              ),
            ),
            Row(children: [
              Icon(s.sale.payment.icon, size: 14, color: BsColors.slate),
              const SizedBox(width: 6),
              Text(s.server?.fullName.split(' ').first ?? '—',
                  style: BsType.body(12, color: BsColors.slate)),
            ]),
            const SizedBox(width: 20),
            SizedBox(
              width: 80,
              child: Text(moneyCents(s.totalCents),
                  textAlign: TextAlign.right,
                  style: BsType.mono(14, w: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: widget.onOpen,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text('Détail',
                  style: BsType.body(12, w: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
