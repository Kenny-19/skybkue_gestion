import 'package:fl_chart/fl_chart.dart';
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
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/temps.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permsProvider);
    // La réception ne voit qu'une vue centrée sur les chambres.
    if (perms.isReception) return const _ReceptionDashboard();

    final metricsAsync = ref.watch(metricsWeekProvider);
    final roomsAsync = ref.watch(roomsStreamProvider);
    final stockAsync = ref.watch(articlesStreamProvider);
    final debtsAsync = ref.watch(outstandingDebtsProvider);

    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'dashboard_screen')),
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
                          child: SizedBox(
                              height: 240, child: _WeekChart(days: days)),
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
                              child:
                                  Center(child: CircularProgressIndicator())),
                          error: (e, _) => _Card(
                              title: 'Occupation des chambres',
                              child: BsErrorView(
                                  error: handleError(e, null,
                                      context: 'dashboard_screen'))),
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
                              child:
                                  Center(child: CircularProgressIndicator())),
                          error: (e, _) => _Card(
                              title: 'Alertes stock',
                              child: BsErrorView(
                                  error: handleError(e, null,
                                      context: 'dashboard_screen'))),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
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
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              BsColors.danger,
                                                          shape:
                                                              BoxShape.circle)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: Text(s.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
              const SizedBox(height: BsSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: debtsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => _Card(
                      title: 'Dettes',
                      child: BsErrorView(
                          error: handleError(e, null,
                              context: 'dashboard_screen'))),
                  data: (debts) => _DebtsCard(debts: debts),
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

class _DebtsCard extends StatelessWidget {
  final List<SaleWithLines> debts; // dettes EN COURS (non réglées)
  const _DebtsCard({required this.debts});

  @override
  Widget build(BuildContext context) {
    final total = debts.fold<int>(0, (s, d) => s + d.totalCents);
    return _Card(
      title: 'Dettes en cours',
      subtitle: debts.isEmpty
          ? 'Aucune dette impayée'
          : '${debts.length} dette(s) · ${moneyCents(total)} à recouvrer',
      child: debts.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: BsColors.success),
                const SizedBox(width: 8),
                Text('Tout est réglé.',
                    style: BsType.body(12, color: BsColors.slate)),
              ]),
            )
          : Column(
              children: [
                for (final d in debts.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 14, color: BsColors.sunrise),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          [
                            if (d.sale.roomNumber != null)
                              'Ch. ${d.sale.roomNumber}',
                            d.sale.customerName ?? 'Client',
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: BsType.body(12, w: FontWeight.w600),
                        ),
                      ),
                      Text(moneyCents(d.totalCents),
                          style: BsType.mono(12,
                              w: FontWeight.w700, color: BsColors.sunrise)),
                    ]),
                  ),
                if (debts.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('+ ${debts.length - 6} autre(s)…',
                        style: BsType.body(11, color: BsColors.slate)),
                  ),
              ],
            ),
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
              label: 'Total 7j',
              value: moneyCents(weekTotalCents, decimals: 0)),
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
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      DateFormat('E', 'fr_FR').format(aLubumbashi(days[i].day)),
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
                    child:
                        Text(r.$1, style: BsType.body(13, w: FontWeight.w500))),
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

// ─── Dashboard "Réception" ──────────────────────────────────────────────
// Vue simplifiée pour le rôle Réception : uniquement chambres et arrivées
// du jour. Aucune donnée de vente / stock / dette.
class _ReceptionDashboard extends ConsumerWidget {
  const _ReceptionDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'dashboard_screen')),
      data: (rooms) {
        final total = rooms.length;
        final occupied =
            rooms.where((r) => r.status == DbRoomStatus.occupee).toList();
        final free = rooms.where((r) => r.status == DbRoomStatus.libre).length;
        final cleaning =
            rooms.where((r) => r.status == DbRoomStatus.nettoyage).length;
        final maintenance =
            rooms.where((r) => r.status == DbRoomStatus.maintenance).length;
        // Chambres dont le checkout est prévu aujourd'hui ou déjà passé.
        final now = DateTime.now();
        final today = debutDeJourneeLubumbashi(now);
        final overdue = <Room>[];
        final todayOut = <Room>[];
        for (final r in occupied) {
          if (r.checkoutDate == null) continue;
          final c = debutDeJourneeLubumbashi(r.checkoutDate!);
          if (c.isBefore(today)) {
            overdue.add(r);
          } else if (c.isAtSameMomentAs(today)) {
            todayOut.add(r);
          }
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Réception',
                title: 'Vue d\'ensemble chambres',
                subtitle:
                    '${occupied.length} occupée(s) · $free libre(s) · $cleaning à nettoyer · $maintenance en maintenance',
              ),
              // KPIs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniKpi(
                        label: 'Occupées',
                        value: '${occupied.length}',
                        sub: '/ $total',
                        color: BsColors.sky,
                        icon: Icons.hotel,
                      ),
                    ),
                    const SizedBox(width: BsSpace.md),
                    Expanded(
                      child: _MiniKpi(
                        label: 'Libres',
                        value: '$free',
                        sub: 'prêtes à accueillir',
                        color: BsColors.success,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: BsSpace.md),
                    Expanded(
                      child: _MiniKpi(
                        label: 'À nettoyer',
                        value: '$cleaning',
                        sub: '',
                        color: BsColors.warning,
                        icon: Icons.cleaning_services_outlined,
                      ),
                    ),
                    const SizedBox(width: BsSpace.md),
                    Expanded(
                      child: _MiniKpi(
                        label: 'Départs en retard',
                        value: '${overdue.length}',
                        sub: overdue.isEmpty ? 'RAS' : 'à relancer',
                        color:
                            overdue.isEmpty ? BsColors.slate : BsColors.danger,
                        icon: Icons.event_busy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BsSpace.lg),
              // Occupation gauge + départs du jour
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _Card(
                          title: 'Taux d\'occupation',
                          subtitle:
                              '${occupied.length} sur $total chambres occupées',
                          child: _RoomsGauge(
                              occupied: occupied.length, total: total),
                        ),
                      ),
                      const SizedBox(width: BsSpace.md),
                      Expanded(
                        flex: 3,
                        child: _Card(
                          title: 'Départs du jour',
                          subtitle: todayOut.isEmpty
                              ? 'Aucun départ prévu aujourd\'hui'
                              : '${todayOut.length} départ(s) prévu(s)',
                          child: _RoomsList(rooms: todayOut, empty: 'RAS.'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BsSpace.md),
              // Départs en retard (attention)
              if (overdue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                  child: _Card(
                    title: 'Départs en retard',
                    subtitle: '${overdue.length} chambre(s) avec un checkout '
                        'dépassé — à relancer',
                    child: _RoomsList(rooms: overdue, empty: '', danger: true),
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

class _MiniKpi extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;
  const _MiniKpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BsSpace.md),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label.toUpperCase(), style: BsType.eyebrow()),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: BsType.display(28, w: FontWeight.w700, color: color)),
          if (sub.isNotEmpty)
            Text(sub, style: BsType.body(11, color: BsColors.slate)),
        ],
      ),
    );
  }
}

class _RoomsList extends StatelessWidget {
  final List<Room> rooms;
  final String empty;
  final bool danger;
  const _RoomsList(
      {required this.rooms, required this.empty, this.danger = false});
  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(empty, style: BsType.body(12, color: BsColors.slate)),
      );
    }
    return Column(
      children: [
        for (final r in rooms.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: danger ? BsColors.danger : BsColors.sky,
                      shape: BoxShape.circle)),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                child: Text('Ch. ${r.number}',
                    style: BsType.mono(12, w: FontWeight.w700)),
              ),
              Expanded(
                child: Text(r.currentGuest ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: BsType.body(12, w: FontWeight.w500)),
              ),
              if (r.checkoutDate != null)
                Text(
                    'Sortie : ${DateFormat("d MMM", 'fr_FR').format(aLubumbashi(r.checkoutDate!))}',
                    style: BsType.body(11,
                        color: danger ? BsColors.danger : BsColors.slate)),
            ]),
          ),
      ],
    );
  }
}
