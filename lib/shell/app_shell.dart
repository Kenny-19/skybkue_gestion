import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/auth.dart';
import '../core/cat_ui.dart';
import '../core/theme_mode.dart';
import '../core/user_ui.dart';
import '../data/providers.dart';
import '../data/schema.dart';
import '../services/supply_notifications.dart';
import '../services/supply_requests_service.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'notifications_bell.dart';
import 'update_banner.dart';
import '../core/temps.dart';
import '../core/horloge.dart';

class NavDest {
  final String label;
  final IconData icon;
  final String route;
  final bool Function(Perms) allowed;
  const NavDest(this.label, this.icon, this.route, this.allowed);
}

final navDests = <NavDest>[
  NavDest('Dashboard', Icons.dashboard_outlined, '/', (p) => p.canDashboard),
  NavDest(
      'Point de vente', Icons.point_of_sale_outlined, '/pos', (p) => p.canPos),
  NavDest('Catalogue', Icons.menu_book_outlined, '/catalog',
      (p) => p.canViewCatalog),
  NavDest('Stock', Icons.inventory_2_outlined, '/stock', (p) => p.canStock),
  NavDest('Chambres', Icons.hotel_outlined, '/rooms', (p) => p.canRooms),
  NavDest('Réservations', Icons.calendar_month_outlined, '/reservations',
      (p) => p.canReservations),
  NavDest('Historique', Icons.query_stats_outlined, '/history',
      (p) => p.canHistory),
  NavDest(
      'Comptes', Icons.people_outline, '/users', (p) => p.canManageServeurs),
  NavDest('Clients', Icons.badge_outlined, '/clients', (p) => p.canClients),
  NavDest('Sociétés', Icons.business_outlined, '/payers', (p) => p.canPayers),
  NavDest('Paramètres', Icons.settings_outlined, '/settings',
      (p) => p.role != null),
];

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  void Function(SupplyRequest)? _statusChangeCb;

  @override
  void initState() {
    super.initState();
    // Demarre / arrete le watcher notifications selon l'utilisateur
    // connecte. `listen` sur authProvider = re-declenche sur logout/login.
    Future.microtask(() {
      _wireForCurrentUser();
      ref.listenManual<AuthState>(authProvider, (prev, next) {
        _wireForCurrentUser();
      });
    });
  }

  void _wireForCurrentUser() {
    final service = ref.read(supplyNotifsProvider);
    final user = ref.read(authProvider).user;

    // Detache l'ancien callback si present.
    if (_statusChangeCb != null) {
      service.offStatusChange(_statusChangeCb!);
      _statusChangeCb = null;
    }

    if (user == null) {
      service.stop();
      return;
    }

    // Demarre le polling pour ce user.
    service.startFor(user.login);

    // Enregistre un callback qui affiche un SnackBar quand une decision
    // arrive pendant que l'utilisateur est dans l'app.
    _statusChangeCb = (req) {
      if (!mounted) return;
      final approved = req.status == 'approved';
      final label = approved ? 'Demande APPROUVÉE' : 'Demande rejetée';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: approved ? BsColors.success : BsColors.danger,
        duration: const Duration(seconds: 6),
        content: Row(children: [
          Icon(approved ? Icons.check_circle : Icons.cancel,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                // Demande hôtel note-only (article_id == null) : on montre
                // le texte directement au lieu d'un "1× {longue phrase}".
                req.articleId == null && req.location == DbLocation.hotel
                    ? '$label — hôtel : ${req.articleName}'
                    : '$label : ${req.qtyRequested}× ${req.articleName} pour ${req.location.label}',
                style:
                    BsType.body(13, w: FontWeight.w600, color: Colors.white)),
          ),
        ]),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () {
            // Le panel se trouve via la cloche sidebar.
          },
        ),
      ));
    };
    service.onStatusChange(_statusChangeCb!);
  }

  @override
  void dispose() {
    if (_statusChangeCb != null) {
      ref.read(supplyNotifsProvider).offStatusChange(_statusChangeCb!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permsProvider);
    final dests = navDests.where((d) => d.allowed(perms)).toList();
    final index = dests.indexWhere((d) => d.route == '/'
        ? widget.location == '/'
        : widget.location.startsWith(d.route));
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(index: index < 0 ? 0 : index, dests: dests),
          const VerticalDivider(width: 1, color: BsColors.line),
          Expanded(
            child: Column(
              children: [
                // Banniere de mise a jour (auto-hide si aucune dispo).
                const UpdateBanner(),
                Expanded(child: widget.child),
              ],
            ),
          ),
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
    final overdueCount = roomsAsync.asData?.value.where((r) {
          if (r.status != DbRoomStatus.occupee || r.checkoutDate == null) {
            return false;
          }
          final today = DateTime.now();
          final tDay = debutDeJourneeLubumbashi(today);
          final cDay = debutDeJourneeLubumbashi(r.checkoutDate!);
          return cDay.isBefore(tDay);
        }).length ??
        0;

    return Container(
      width: 200,
      color: BsColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 12),
          // Zone nav scrollable — évite l'overflow sur petits écrans
          // (10+ entrées possibles avec Clients/Sociétés/Historique).
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < dests.length; i++)
                    _NavItem(
                      dest: dests[i],
                      active: i == index,
                      badge: dests[i].route == '/rooms' && overdueCount > 0
                          ? '$overdueCount'
                          : null,
                      onTap: () => context.go(dests[i].route),
                    ),
                ],
              ),
            ),
          ),
          const NotificationsBell(),
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
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
        : (_hover
            ? BsColors.inkSoft.withValues(alpha: 0.5)
            : Colors.transparent);
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  style:
                      BsType.body(12, w: FontWeight.w700, color: Colors.white)),
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
              icon:
                  const Icon(Icons.logout, size: 16, color: BsColors.slateSoft),
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
    final today = DateFormat("EEEE d MMMM y", 'fr_FR')
        .format(aLubumbashi(Horloge.maintenant()));
    // Titre à 24 px et marges resserrées : l'en-tête passe d'environ
    // 170 px à ~100 px sur CHACUN des onze écrans. Sur un logiciel de
    // bureau, la barre latérale dit déjà où l'on est — le titre confirme,
    // il n'a pas à occuper un sixième de la hauteur utile.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BsSpace.xl, BsSpace.lg, BsSpace.xl, BsSpace.smd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: BsType.eyebrow()),
                const SizedBox(height: BsSpace.xs),
                Text(title, style: BsType.display(24, w: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!,
                      style: BsType.body(14, color: BsColors.slate)),
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
