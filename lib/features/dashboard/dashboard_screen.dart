import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../../data/repos.dart';
import '../../data/schema.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(metricsWeekProvider);
    final roomsAsync = ref.watch(roomsStreamProvider);
    final stockAsync = ref.watch(articlesStreamProvider);

    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (days) {
        final today = days.last; // metrics repo garantit toujours 7 entrées
        final totalWeek = days.fold<int>(0, (s, d) => s + d.totalCents);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: "Aujourd'hui",
                title: "Bienvenue",
                subtitle:
                    "Le comptoir a réalisé ${today.count} vente(s) aujourd'hui.",
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: _HeroKpi(
                  totalCents: today.totalCents,
                  count: today.count,
                  weekTotalCents: totalWeek,
                ),
              ),
              const SizedBox(height: BsSpace.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Card(
                          title: "Chiffre d'affaires — 7 derniers jours",
                          subtitle: moneyCents(totalWeek, decimals: 0),
                          child:
                              SizedBox(height: 240, child: _WeekChart(days: days)),
                        ),
                      ),
                      const SizedBox(width: BsSpace.md),
                      Expanded(
                        flex: 2,
                        child: _Card(
                          title: 'Répartition par catégorie',
                          subtitle: "Aujourd'hui",
                          child: _CategoryBreakdown(today: today),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BsSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: roomsAsync.when(
                          loading: () => const _Card(
                              title: 'Occupation des chambres',
                              child: Center(child: CircularProgressIndicator())),
                          error: (e, _) => _Card(
                              title: 'Occupation des chambres',
                              child: Text('Erreur : $e')),
                          data: (rooms) {
                            final occupied = rooms
                                .where((r) => r.status == DbRoomStatus.occupee)
                                .length;
                            return _Card(
                              title: 'Occupation des chambres',
                              subtitle:
                                  '$occupied sur ${rooms.length} chambres occupées',
                              child: _RoomsGauge(
                                  occupied: occupied, total: rooms.length),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: BsSpace.md),
                      Expanded(
                        child: stockAsync.when(
                          loading: () => const _Card(
                              title: 'Alertes stock',
                              child: Center(child: CircularProgressIndicator())),
                          error: (e, _) => _Card(
                              title: 'Alertes stock',
                              child: Text('Erreur : $e')),
                          data: (stock) {
                            final low = stock
                                .where((s) =>
                                    s.trackStock && s.stockQty <= s.threshold)
                                .toList();
                            return _Card(
                              title: 'Alertes stock',
                              subtitle: low.isEmpty
                                  ? 'Tout est en stock'
                                  : '${low.length} article(s) sous le seuil',
                              child: low.isEmpty
                                  ? Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 16),
                                      child: Text('—',
                                          style: BsType.body(12,
                                              color: BsColors.slate)),
                                    )
                                  : Column(
                                      children: [
                                        for (final s in low.take(4))
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            child: Row(children: [
                                              Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: const BoxDecoration(
                                                      color: BsColors.danger,
                                                      shape: BoxShape.circle)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: Text(s.name,
                                                      style: BsType.body(12,
                                                          w: FontWeight.w500))),
                                              Text('${s.stockQty} ${s.unit}',
                                                  style: BsType.mono(12,
                                                      w: FontWeight.w600,
                                                      color: BsColors.danger)),
                                              const SizedBox(width: 4),
                                              Text('/ ${s.threshold}',
                                                  style: BsType.mono(11,
                                                      color: BsColors.slate)),
                                            ]),
                                          ),
                                      ],
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _HeroKpi extends StatelessWidget {
  final int totalCents;
  final int count;
  final int weekTotalCents;
  const _HeroKpi({
    required this.totalCents,
    required this.count,
    required this.weekTotalCents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BsSpace.xl),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.lg),
        border: Border.all(color: BsColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Chiffre d'affaires du jour", style: BsType.eyebrow()),
                const SizedBox(height: 12),
                Text(moneyCents(totalCents, decimals: 0),
                    style: BsType.display(76, w: FontWeight.w600)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 3,
                  width: 120,
                  color: BsColors.sunrise,
                ),
              ],
            ),
          ),
          _SubKpi(label: 'Ventes', value: '$count'),
          const SizedBox(width: BsSpace.xl),
          _SubKpi(
              label: 'Panier moyen',
              value: moneyCents(count == 0 ? 0 : totalCents ~/ count)),
          const SizedBox(width: BsSpace.xl),
          _SubKpi(
              label: 'Total 7j', value: moneyCents(weekTotalCents, decimals: 0)),
        ],
      ),
    );
  }
}

class _SubKpi extends StatelessWidget {
  final String label;
  final String value;
  const _SubKpi({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: BsType.eyebrow()),
        const SizedBox(height: 8),
        Text(value, style: BsType.display(24, w: FontWeight.w600)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Card({required this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: BsType.heading(14, w: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: BsType.body(12, color: BsColors.slate)),
          ],
          const SizedBox(height: BsSpace.md),
          child,
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<DailyTotal> days;
  const _WeekChart({required this.days});
  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Center(
          child: Text('Aucune donnée',
              style: BsType.body(12, color: BsColors.slate)));
    }
    final maxY = days
        .map((d) => d.totalCents.toDouble())
        .fold<double>(1, (a, b) => a > b ? a : b) *
        1.2;
    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: BsColors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('E', 'fr_FR').format(days[i].day),
                      style: BsType.body(11, color: BsColors.slate)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: days[i].totalCents.toDouble(),
                width: 24,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                color: i == days.length - 1 ? BsColors.ink : BsColors.sky,
              ),
            ]),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final DailyTotal today;
  const _CategoryBreakdown({required this.today});
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Boissons', today.boissonsCents, BsColors.sky),
      ('Nourriture', today.nourritureCents, BsColors.sunrise),
      ('Chambres', today.chambresCents, BsColors.ink),
    ];
    final t = today.totalCents;
    return Column(
      children: rows.map((r) {
        final pct = t == 0 ? 0.0 : r.$2 / t;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(r.$1,
                        style: BsType.body(13, w: FontWeight.w500))),
                Text(moneyCents(r.$2, decimals: 0),
                    style: BsType.mono(13, w: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: BsColors.papyrus,
                  valueColor: AlwaysStoppedAnimation(r.$3),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RoomsGauge extends StatelessWidget {
  final int occupied;
  final int total;
  const _RoomsGauge({required this.occupied, required this.total});
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : occupied / total;
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 12,
                  backgroundColor: BsColors.papyrus,
                  valueColor: const AlwaysStoppedAnimation(BsColors.sunrise),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(pct * 100).round()}%',
                      style: BsType.display(28, w: FontWeight.w700)),
                  Text('occupé', style: BsType.eyebrow()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('$occupied / $total chambres',
            style: BsType.body(12, color: BsColors.slate)),
      ],
    );
  }
}
