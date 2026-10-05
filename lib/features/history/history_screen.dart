import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../data/repos.dart';
import '../../services/backup_service.dart';
import '../../services/mirror_service.dart';
import '../../services/pdf_service.dart';
import '../../services/reports_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'sale_detail_sheet.dart';
import 'stays_history_section.dart';
import '../../core/temps.dart';
import 'encaisser_dette_sheet.dart';
import '../../core/horloge.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

/// Les deux historiques. Ils ne se mélangent plus jamais à l'écran.
///
/// L'hôtel, ce sont les séjours facturés. Le restaurant et la terrasse,
/// ce sont les ventes du point de vente — y compris celles saisies au
/// lieu « Hôtel » (consommations mises sur une chambre) : elles passent
/// par la caisse, elles restent avec la caisse.
enum _Vue { hotel, ventes }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  SaleWithLines? _selected;

  /// La vue choisie, pour qui a accès aux deux (gérant, super admin).
  _Vue _choix = _Vue.ventes;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recentSalesProvider);
    final perms = ref.watch(permsProvider);
    final voitHotel = perms.canHistoriqueHotel;
    final voitVentes = perms.canHistoriqueVentes;
    // Réception : l'hôtel seul. Serveurs : les ventes seules. Gérant et
    // super admin : l'un OU l'autre, au choix, jamais les deux empilés.
    final vue = !voitVentes
        ? _Vue.hotel
        : !voitHotel
            ? _Vue.ventes
            : _choix;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'history_screen')),
      data: (sales) {
        final byDay = <DateTime, List<SaleWithLines>>{};
        for (final s in sales) {
          final d = debutDeJourneeLubumbashi(s.sale.soldAt);
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
                    title: vue == _Vue.hotel
                        ? 'Hôtel — séjours facturés'
                        : 'Restaurant & terrasse',
                    subtitle: vue == _Vue.hotel
                        ? "Départs et factures de l'hôtel"
                        : '${sales.length} transactions · 7 derniers jours',
                    actions: [
                      // Le rapport ne contient que des VENTES : il n'a sa
                      // place que dans la vue restaurant & terrasse.
                      if (vue == _Vue.ventes)
                        FilledButton.icon(
                          icon: const Icon(Icons.summarize_outlined, size: 16),
                          onPressed: () => _showReportDialog(),
                          label: const Text('Générer un rapport'),
                        ),
                    ],
                  ),
                  // Le choix n'existe que pour qui voit les deux. Les
                  // autres n'ont même pas à savoir que l'autre historique
                  // existe.
                  if (voitHotel && voitVentes)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          BsSpace.xl, 0, BsSpace.xl, BsSpace.md),
                      child: SegmentedButton<_Vue>(
                        segments: const [
                          ButtonSegment(
                            value: _Vue.ventes,
                            icon: Icon(Icons.restaurant_outlined, size: 16),
                            label: Text('Restaurant & terrasse'),
                          ),
                          ButtonSegment(
                            value: _Vue.hotel,
                            icon: Icon(Icons.hotel_outlined, size: 16),
                            label: Text('Hôtel'),
                          ),
                        ],
                        selected: {vue},
                        onSelectionChanged: (s) => setState(() {
                          _choix = s.first;
                          // Le détail d'une vente n'a rien à faire ouvert
                          // à côté des séjours.
                          _selected = null;
                        }),
                      ),
                    ),
                  if (vue == _Vue.hotel) ...[
                    const StaysHistorySection(),
                    const SizedBox(height: BsSpace.xxl),
                  ] else if (sales.isEmpty)
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
                          Text(
                              'Va au Point de vente pour enregistrer une vente.',
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
            width: _selected == null || vue != _Vue.ventes ? 0 : 440,
            child: _selected == null || vue != _Vue.ventes
                ? const SizedBox.shrink()
                : SaleDetailSheet(
                    sale: _selected!,
                    onClose: () => setState(() => _selected = null),
                    canDelete: perms.canDeleteSale,
                    onDelete: perms.canDeleteSale
                        ? () => _confirmDelete(_selected!)
                        : null,
                    onSettle: (_selected!.sale.onCredit &&
                            _selected!.sale.settledAt == null)
                        ? () => _settleDebt(_selected!)
                        : null,
                  ),
          ),
        ]);
      },
    );
  }

  Future<void> _confirmDelete(SaleWithLines sale) async {
    final ticket = '#${sale.sale.id.toString().padLeft(4, '0')}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer la facture $ticket ?'),
        content: const Text(
            'Cette action est irréversible. Le ticket sera retiré de '
            'l\'historique et le stock des articles suivis sera restauré.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(salesRepoProvider).deleteSale(sale.sale.id);
      // Miroir Supabase : best-effort, ne bloque pas l'UX.
      MirrorService.deleteSaleByUid(sale.sale.uid);
      if (!mounted) return;
      setState(() => _selected = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Facture $ticket supprimée')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $e')),
      );
    }
  }

  Future<void> _settleDebt(SaleWithLines sale) async {
    final ticket = '#${sale.sale.id.toString().padLeft(4, '0')}';
    final who = sale.sale.customerName ??
        (sale.sale.roomNumber != null
            ? 'Chambre ${sale.sale.roomNumber}'
            : 'client');
    final repo = ref.read(salesRepoProvider);
    // Le déjà-reçu vient de la base, pas de l'écran : une autre caisse a
    // pu encaisser un acompte entre-temps.
    final deja = await repo.dejaPaye(sale.sale.id);
    if (!mounted) return;

    final enc = await demanderEncaissement(
      context,
      ticket: ticket,
      qui: who,
      totalCents: sale.totalCents,
      dejaPayeCents: deja,
    );
    if (enc == null || !mounted) return;

    final moi = ref.read(authProvider).user?.login;
    await repo.encaisserSurDette(
      saleId: sale.sale.id,
      montantCents: enc.montantCents,
      payment: enc.payment,
      parLogin: moi,
    );
    final reste = await repo.resteADevoir(sale.sale.id);
    if (!mounted) return;
    setState(() => _selected = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reste <= 0
            ? 'Dette $ticket soldée (${enc.payment.label})'
            : 'Acompte de ${moneyCents(enc.montantCents)} encaissé · '
                '${moneyCents(reste)} restent dus'),
      ),
    );
  }

  void _showReportDialog() {
    // Période sélectionnée : défaut = 1 mois.
    final now = Horloge.maintenant();
    DateTimeRange range = DateTimeRange(
      start: debutDeJourneeLubumbashi(now).subtract(const Duration(days: 30)),
      end: debutDeJourneeLubumbashi(now)
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1)),
    );
    String label = '1 mois';

    Future<List<SaleWithLines>> fetch() =>
        ref.read(salesRepoProvider).rangeSales(range.start, range.end);

    Future<void> generate(BuildContext ctx, bool detailed) async {
      Navigator.of(ctx).pop();
      final sales = await fetch();
      if (detailed) {
        await PdfService.previewDetailedReport(sales, period: label);
      } else {
        await PdfService.previewSummaryReport(sales, period: label);
      }
    }

    Future<void> generateExcel(BuildContext ctx) async {
      Navigator.of(ctx).pop();
      final sales = await fetch();
      await BackupService.exportSalesExcel(sales);
    }

    Future<void> sendToPamela(BuildContext ctx, bool detailed) async {
      Navigator.of(ctx).pop();
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Envoi du rapport à Pamela ($label)…',
              style: BsType.body(12, w: FontWeight.w600))));
      try {
        final sales = await fetch();
        final bytes = detailed
            ? await PdfService.buildDetailedReportBytes(sales, period: label)
            : await PdfService.buildSummaryReportBytes(sales, period: label);
        final me = ref.read(authProvider).user;
        final res = await ReportsService.send(
          name: detailed
              ? 'Rapport détaillé — $label'
              : 'Rapport synthétique — $label',
          period: label,
          kind: detailed
              ? ReportsService.kindDetailed
              : ReportsService.kindSummary,
          bytes: bytes,
          generatedByLogin: me?.login,
        );
        scaffold.clearSnackBars();
        scaffold.showSnackBar(SnackBar(
          backgroundColor: res.ok ? BsColors.success : BsColors.danger,
          content: Text(
              res.ok
                  ? 'Rapport envoyé à Pamela. Elle recevra une notification.'
                  : 'Échec : ${res.error}',
              style: BsType.body(13, w: FontWeight.w600, color: Colors.white)),
        ));
      } catch (e) {
        scaffold.clearSnackBars();
        scaffold.showSnackBar(SnackBar(
          backgroundColor: BsColors.danger,
          content: Text('Échec envoi : $e',
              style: BsType.body(13, w: FontWeight.w600, color: Colors.white)),
        ));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        void preset(String l, int days) {
          setSt(() {
            label = l;
            range = DateTimeRange(
              start:
                  debutDeJourneeLubumbashi(now).subtract(Duration(days: days)),
              end: debutDeJourneeLubumbashi(now)
                  .add(const Duration(days: 1))
                  .subtract(const Duration(milliseconds: 1)),
            );
          });
        }

        final fmt = DateFormat('d MMM y', 'fr_FR');
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('RAPPORT PDF', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text('Période & format',
                      style: BsType.display(24, w: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text('PÉRIODE', style: BsType.eyebrow()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _periodChip('Aujourd\'hui', label == "Aujourd'hui",
                        () => preset("Aujourd'hui", 0)),
                    _periodChip('7 jours', label == '7 jours',
                        () => preset('7 jours', 7)),
                    _periodChip('1 mois', label == '1 mois',
                        () => preset('1 mois', 30)),
                    _periodChip('3 mois', label == '3 mois',
                        () => preset('3 mois', 90)),
                    _periodChip(
                      'Personnalisé…',
                      label == 'Personnalisé',
                      () async {
                        final picked = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(now.year + 1),
                          initialDateRange: range,
                        );
                        if (picked != null) {
                          setSt(() {
                            label = 'Personnalisé';
                            range = DateTimeRange(
                              start: picked.start,
                              end: DateTime(picked.end.year, picked.end.month,
                                  picked.end.day, 23, 59, 59),
                            );
                          });
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      'Du ${fmt.format(aLubumbashi(range.start))} au ${fmt.format(aLubumbashi(range.end))}',
                      style: BsType.body(12, color: BsColors.slate)),
                  const SizedBox(height: 20),
                  Text('FORMAT', style: BsType.eyebrow()),
                  const SizedBox(height: 8),
                  _opt(
                      'Rapport synthétique',
                      'Résumé + totaux par jour, catégorie et dettes réglées',
                      Icons.summarize_outlined,
                      () => generate(ctx, false)),
                  const SizedBox(height: 10),
                  _opt(
                      'Rapport détaillé',
                      'Chaque vente ligne par ligne — audit complet',
                      Icons.receipt_long_outlined,
                      () => generate(ctx, true)),
                  const SizedBox(height: 10),
                  _opt(
                      'Rapport Excel (du soir)',
                      'Par jour : Restaurant, Terrasse, Crédit + détail des dettes',
                      Icons.table_chart_outlined,
                      () => generateExcel(ctx)),
                  const SizedBox(height: 16),
                  Text('ENVOI À PAMELA', style: BsType.eyebrow()),
                  const SizedBox(height: 8),
                  _opt(
                      'Envoyer synthétique à Pamela',
                      'Upload PDF sur le tableau de bord + notif push',
                      Icons.cloud_upload_outlined,
                      () => sendToPamela(ctx, false)),
                  const SizedBox(height: 10),
                  _opt(
                      'Envoyer détaillé à Pamela',
                      'Upload PDF détaillé + notif push',
                      Icons.cloud_upload_outlined,
                      () => sendToPamela(ctx, true)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _periodChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? BsColors.ink : Colors.transparent,
            border: Border.all(color: BsColors.ink),
            borderRadius: BorderRadius.circular(BsRadius.sm),
          ),
          child: Text(label,
              style: BsType.body(12,
                  w: FontWeight.w700,
                  color: selected ? Colors.white : BsColors.ink)),
        ),
      );

  Widget _opt(
          String title, String subtitle, IconData icon, VoidCallback onTap) =>
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
              Text(
                  DateFormat("EEEE d MMMM", 'fr_FR')
                      .format(aLubumbashi(day))
                      .toUpperCase(),
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
          padding:
              const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
          decoration: BoxDecoration(
            color: widget.selected
                ? BsColors.papyrus
                : (_hover
                    ? BsColors.papyrus.withValues(alpha: 0.5)
                    : Colors.transparent),
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
              child: Text(
                  DateFormat('HH:mm:ss', 'fr_FR')
                      .format(aLubumbashi(s.sale.soldAt)),
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
            if (s.sale.onCredit) ...[
              const SizedBox(width: 6),
              Builder(builder: (_) {
                final settled = s.sale.settledAt != null;
                final c = settled ? BsColors.success : BsColors.sunrise;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(settled ? 'Dette payée' : 'Dette',
                      style: BsType.body(10, w: FontWeight.w700, color: c)),
                );
              }),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (s.sale.customerName != null || s.sale.roomNumber != null)
                    Text(
                      [
                        if (s.sale.roomNumber != null)
                          'Ch. ${s.sale.roomNumber}',
                        if (s.sale.customerName != null) s.sale.customerName!,
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: BsType.body(11,
                          w: FontWeight.w700, color: BsColors.ink),
                    ),
                  Text(
                    s.lines
                        .map((l) => '${l.qty}× ${l.articleName}')
                        .join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: BsType.body(12, color: BsColors.slate),
                  ),
                ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, BsControl.compact),
              ),
              child: Text('Détail', style: BsType.body(12, w: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
