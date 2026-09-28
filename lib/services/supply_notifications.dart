import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supply_requests_service.dart';

/// Etat expose au hub de notifications :
///   - `requests` : demandes emises par l'utilisateur courant (30 derniers jours)
///   - `unseenCount` : nombre de changements de statut non encore consultes
class SupplyNotifState {
  final List<SupplyRequest> requests;
  final int unseenCount;
  final DateTime? lastRefresh;

  const SupplyNotifState({
    this.requests = const [],
    this.unseenCount = 0,
    this.lastRefresh,
  });

  SupplyNotifState copyWith({
    List<SupplyRequest>? requests,
    int? unseenCount,
    DateTime? lastRefresh,
  }) =>
      SupplyNotifState(
        requests: requests ?? this.requests,
        unseenCount: unseenCount ?? this.unseenCount,
        lastRefresh: lastRefresh ?? this.lastRefresh,
      );
}

/// Poll toutes les 60 s les demandes de l'utilisateur courant et detecte
/// les changements de statut (pending -> approved / rejected).
///
/// Notifie via [state] pour :
///   - Afficher un badge sur l'icone cloche (unseenCount > 0)
///   - Emettre un `onStatusChange(newState)` que l'UI peut ecouter pour
///     afficher un SnackBar au moment ou une decision arrive
class SupplyNotifsService extends ChangeNotifier {
  SupplyNotifsService();

  SupplyNotifState _state = const SupplyNotifState();
  SupplyNotifState get state => _state;

  Timer? _timer;
  String? _login;

  // Map id -> ancien statut, pour detecter les transitions.
  final Map<int, String> _lastKnownStatus = {};

  // Callbacks pour notifier l'UI d'un changement (SnackBar).
  final List<void Function(SupplyRequest changed)> _listeners = [];
  void onStatusChange(void Function(SupplyRequest) cb) => _listeners.add(cb);
  void offStatusChange(void Function(SupplyRequest) cb) =>
      _listeners.remove(cb);

  /// A appeler apres login (login peut changer entre 2 sessions).
  void startFor(String login) {
    _login = login;
    _lastKnownStatus.clear();
    _state = const SupplyNotifState();
    notifyListeners();
    _timer?.cancel();
    // Premier fetch immediat, puis toutes les 60 s.
    _refresh(silent: true);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _login = null;
  }

  /// Marque toutes les demandes comme "vues" (reset du badge).
  void markAllSeen() {
    if (_state.unseenCount == 0) return;
    _state = _state.copyWith(unseenCount: 0);
    notifyListeners();
  }

  /// Force un refresh manuel (bouton "Actualiser" dans le panel).
  Future<void> refreshNow() => _refresh();

  Future<void> _refresh({bool silent = false}) async {
    final login = _login;
    if (login == null) return;
    try {
      final list = await SupplyRequestsService.listMine(login);
      // Detecte les changements de statut : id present dans map avec un
      // statut different du current = evenement a notifier.
      int newlyChanged = 0;
      for (final r in list) {
        final id = r.id;
        if (id == null) continue;
        final prev = _lastKnownStatus[id];
        if (prev != null && prev != r.status && r.status != 'pending') {
          newlyChanged++;
          // Silent = premier fetch au startFor, on ne notifie pas
          // l'UI (sinon SnackBar au boot pour du vieux).
          if (!silent) {
            for (final cb in List.of(_listeners)) {
              cb(r);
            }
          }
        }
        _lastKnownStatus[id] = r.status;
      }
      _state = _state.copyWith(
        requests: list,
        unseenCount: _state.unseenCount + newlyChanged,
        lastRefresh: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[SupplyNotifs] refresh echoue : $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Instance globale + provider. Le service doit etre demarre a la
/// connexion de l'utilisateur (voir shell/app_shell.dart) et arrete au
/// logout.
final supplyNotifsProvider = ChangeNotifierProvider<SupplyNotifsService>(
  (ref) => SupplyNotifsService(),
);
