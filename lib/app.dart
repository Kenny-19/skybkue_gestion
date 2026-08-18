import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth.dart';
import 'core/format.dart';
import 'core/theme_mode.dart';
import 'data/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/history/history_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/rooms/rooms_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/users/users_screen.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class BlueSkyApp extends ConsumerWidget {
  const BlueSkyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final mode = ref.watch(themeModeProvider);
    // Maintient le taux USD→FC à jour ; rebuild l'app (donc tous les prix
    // affichés) dès qu'un admin le modifie.
    final rate = ref.watch(rateProvider).asData?.value;
    if (rate != null) Currency.rate = rate;
    return MaterialApp.router(
      title: 'Skyblue',
      debugShowCheckedModeBanner: false,
      theme: buildBlueSkyTheme(),
      darkTheme: buildBlueSkyThemeDark(),
      themeMode: mode,
      routerConfig: router,
    );
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isLoggedIn;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
          GoRoute(path: '/catalog', builder: (_, __) => const CatalogScreen()),
          GoRoute(path: '/stock', builder: (_, __) => const StockScreen()),
          GoRoute(path: '/rooms', builder: (_, __) => const RoomsScreen()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
