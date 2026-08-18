import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/auth.dart';
import '../core/theme_mode.dart';
import '../core/user_ui.dart';
import '../data/providers.dart';
import '../data/schema.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class NavDest {
  final String label;
  final IconData icon;
  final String route;
  final bool Function(Perms) allowed;
  const NavDest(this.label, this.icon, this.route, this.allowed);
}

final navDests = <NavDest>[
  NavDest('Dashboard', Icons.dashboard_outlined, '/', (p) => p.canDashboard),
  NavDest('Point de vente', Icons.point_of_sale_outlined, '/pos', (p) => p.canPos),
  NavDest('Catalogue', Icons.menu_book_outlined, '/catalog', (p) => p.canViewCatalog),
  NavDest('Stock', Icons.inventory_2_outlined, '/stock', (p) => p.canStock),
  NavDest('Chambres', Icons.hotel_outlined, '/rooms', (p) => p.canRooms),
  NavDest('Historique', Icons.query_stats_outlined, '/history', (p) => p.canHistory),
  NavDest('Comptes', Icons.people_outline, '/users', (p) => p.canManageServeurs),
  NavDest('Paramètres', Icons.settings_outlined, '/settings', (p) => p.canCurrency),
];

class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permsProvider);
    final dests = navDests.where((d) => d.allowed(perms)).toList();
    final index = dests.indexWhere((d) =>
        d.route == '/' ? location == '/' : location.startsWith(d.route));
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(index: index < 0 ? 0 : index, dests: dests),
          const VerticalDivider(width: 1, color: BsColors.line),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final int index;
  final List<NavDest> dests;
  const _Sidebar({required this.index, required this.dests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    final overdueCount = roomsAsync.asData?.value
            .where((r) {
              if (r.status != DbRoomStatus.occupee || r.checkoutDate == null) {
                return false;
              }
              final today = DateTime.now();
              final tDay = DateTime(today.year, today.month, today.day);
              final cDay = DateTime(r.checkoutDate!.year,
                  r.checkoutDate!.month, r.checkoutDate!.day);
              return cDay.isBefore(tDay);
            })
            .length ??
        0;

    return Container(
      width: 240,
      color: BsColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 12),
          for (int i = 0; i < dests.length; i++)
            _NavItem(
              dest: dests[i],
              active: i == index,
              badge: dests[i].route == '/rooms' && overdueCount > 0
                  ? '$overdueCount'
                  : null,
              onTap: () => context.go(dests[i].route),
            ),
          const Spacer(),
          const _ThemeToggle(),
          const _UserChip(),
        ],
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: InkWell(
        onTap: () => ref.read(themeModeProvider.notifier).state =
            isDark ? ThemeMode.light : ThemeMode.dark,
        borderRadius: BorderRadius.circular(BsRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: BsColors.inkSoft,
            borderRadius: BorderRadius.circular(BsRadius.sm),
          ),
          child: Row(
            children: [
              Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                  size: 16, color: BsColors.sunrise),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isDark ? 'Mode sombre' : 'Mode clair',
                    style: BsType.body(12,
                        w: FontWeight.w600, color: Colors.white)),
              ),
              _MiniTrack(dark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTrack extends StatelessWidget {
  final bool dark;
  const _MiniTrack({required this.dark});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 28,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: dark ? BsColors.sky : BsColors.slateSoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(BsRadius.sm),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: 42,
              errorBuilder: (_, __, ___) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: BsColors.sunrise, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text('Skyblue',
                      style: BsType.display(22,
                          w: FontWeight.w700, color: BsColors.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('GUEST HOUSE · BY AFRINVEST',
              style: BsType.eyebrow(color: BsColors.slateSoft)),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final NavDest dest;
  final bool active;
  final String? badge;
  final VoidCallback onTap;
  const _NavItem({
    required this.dest,
    required this.active,
    required this.onTap,
    this.badge,
  });
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active
        ? BsColors.inkSoft
        : (_hover ? BsColors.inkSoft.withValues(alpha: 0.5) : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(BsRadius.sm),
          ),
          child: Row(
            children: [
              if (active)
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                    color: BsColors.sunrise,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                )
              else
                const SizedBox(width: 13),
              Icon(widget.dest.icon,
                  size: 18, color: active ? Colors.white : BsColors.slateSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.dest.label,
                    style: BsType.body(13,
                        w: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? Colors.white : BsColors.slateSoft)),
              ),
              if (widget.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: BsColors.danger,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(widget.badge!,
                      style: BsType.mono(10,
                          w: FontWeight.w700, color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserChip extends ConsumerWidget {
  const _UserChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BsColors.inkSoft,
          borderRadius: BorderRadius.circular(BsRadius.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: user.role.color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(user.initials,
                  style: BsType.body(12,
                      w: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: BsType.body(12,
                          w: FontWeight.w600, color: Colors.white)),
                  Text(user.role.label,
                      style: BsType.eyebrow(color: BsColors.slateSoft)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Se déconnecter',
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout, size: 16, color: BsColors.slateSoft),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final today = DateFormat("EEEE d MMMM y", 'fr_FR').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(BsSpace.xl, BsSpace.xl, BsSpace.xl, BsSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: BsType.eyebrow()),
                const SizedBox(height: 8),
                Text(title, style: BsType.display(38, w: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: BsType.body(14, color: BsColors.slate)),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(today,
                      style: BsType.body(13, color: BsColors.slate)
                          .copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
