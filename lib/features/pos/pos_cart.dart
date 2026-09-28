import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/schema.dart';

/// État du panier POS — persistant tant que l'app est ouverte,
/// même quand on quitte l'écran POS.
class PosCartState {
  final Map<int, int> lines; // articleId -> qty
  final DbPayment payment;
  final DbLocation location;
  final String? customerName;
  final String? roomNumber; // chambre rattachée (optionnel)
  const PosCartState({
    this.lines = const {},
    this.payment = DbPayment.cash,
    this.location = DbLocation.restaurant,
    this.customerName,
    this.roomNumber,
  });

  PosCartState copyWith({
    Map<int, int>? lines,
    DbPayment? payment,
    DbLocation? location,
    String? customerName,
    bool clearCustomer = false,
    String? roomNumber,
    bool clearRoom = false,
  }) =>
      PosCartState(
        lines: lines ?? this.lines,
        payment: payment ?? this.payment,
        location: location ?? this.location,
        customerName:
            clearCustomer ? null : (customerName ?? this.customerName),
        roomNumber: clearRoom ? null : (roomNumber ?? this.roomNumber),
      );

  bool get isEmpty => lines.isEmpty;
  int get itemsCount => lines.values.fold(0, (s, e) => s + e);
}

class PosCartNotifier extends StateNotifier<PosCartState> {
  PosCartNotifier() : super(const PosCartState());

  void add(int articleId, {int? available}) {
    final current = state.lines[articleId] ?? 0;
    if (available != null && current + 1 > available) return;
    final next = Map<int, int>.of(state.lines)..[articleId] = current + 1;
    state = state.copyWith(lines: next);
  }

  void remove(int articleId) {
    final current = state.lines[articleId] ?? 0;
    final next = Map<int, int>.of(state.lines);
    if (current <= 1) {
      next.remove(articleId);
    } else {
      next[articleId] = current - 1;
    }
    state = state.copyWith(lines: next);
  }

  void setPayment(DbPayment p) => state = state.copyWith(payment: p);
  void setLocation(DbLocation l) => state = state.copyWith(location: l);
  void setCustomer(String? name) {
    final trimmed = name?.trim();
    state = state.copyWith(
      customerName: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearCustomer: trimmed == null || trimmed.isEmpty,
    );
  }

  /// Rattache une chambre (et pré-remplit le nom du client si fourni).
  void setRoom(String? number, {String? guest}) {
    if (number == null) {
      state = state.copyWith(clearRoom: true);
    } else {
      state = state.copyWith(
        roomNumber: number,
        customerName: guest ?? state.customerName,
      );
    }
  }

  void clear() => state = PosCartState(location: state.location);
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, PosCartState>(
    (_) => PosCartNotifier());
