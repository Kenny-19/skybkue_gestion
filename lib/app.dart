import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth.dart';
import 'core/format.dart';
import 'core/theme_mode.dart';
import 'data/providers.dart';
import 'features/auth/force_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/clients/clients_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/history/history_screen.dart';
import 'features/payers/payers_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/reservations/reservations_screen.dart';
import 'features/rooms/rooms_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/users/users_screen.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'services/heartbeat_service.dart';

/// Le battement ne se lance qu'une fois, même si `build` est rappelé.
bool _battementLance = false;

class BlueSkyApp extends ConsumerWidget {
  const BlueSkyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final mode = ref.watch(themeModeProvider);
    // Synchronise Currency.rate avec la table settings dès qu'un admin
    // met à jour le taux (utilisé sur les PDF pour l'équivalent USD).
    final rate = ref.watch(rateProvider).asData?.value;
    if (rate != null) Currency.rate = rate;

    // Battement de cœur : le poste signale son existence et son état au
    // portail technique. Démarré ici parce qu'il faut des identifiants
    // valides, et qu'ils n'existent qu'une fois quelqu'un connecté —
    // `actorCredentials` rend null avant, et le battement s'abstient.
    //
    // Sans ce signal, diagnostiquer une panne revient à arrêter une
    // application pour voir si les erreurs cessent. Le 24 septembre
    // 2026, cette méthode m'a donné une conclusion fausse.
    if (!_battementLance) {
      _battementLance = true;
      HeartbeatService.instance
          .demarrer(() => ref.read(authProvider.notifier).actorCredentials);
    }

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
      final auth = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isLoggedIn) return loggingIn ? null : '/login';

      // Le mot de passe provisoire NE BLOQUE PAS : décision produit —
      // tous les comptes sont remis à 0000 et l'équipe est prévenue de
      // vive voix. L'application rappelle, elle n'enferme pas.
      // L'écran /mot-de-passe reste accessible, par le rappel.
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/mot-de-passe',
          builder: (_, __) => const ForcePasswordScreen()),
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
          GoRoute(
              path: '/reservations',
              builder: (_, __) => const ReservationsScreen()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
          GoRoute(path: '/clients', builder: (_, __) => const ClientsScreen()),
          GoRoute(path: '/payers', builder: (_, __) => const PayersScreen()),
          GoRoute(
              path: '/settings', builder: (_, __) => const SettingsScreen()),
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
