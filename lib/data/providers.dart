import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth.dart';
import 'repos.dart';

final settingsRepoProvider =
    Provider((ref) => SettingsRepo(ref.watch(dbProvider)));
final usersRepoProvider = Provider((ref) => UsersRepo(ref.watch(dbProvider)));
final articlesRepoProvider =
    Provider((ref) => ArticlesRepo(ref.watch(dbProvider)));
final roomsRepoProvider = Provider((ref) => RoomsRepo(ref.watch(dbProvider)));
final salesRepoProvider = Provider((ref) => SalesRepo(ref.watch(dbProvider)));
final metricsRepoProvider =
    Provider((ref) => MetricsRepo(ref.watch(dbProvider)));
final clientsRepoProvider =
    Provider((ref) => ClientsRepo(ref.watch(dbProvider)));
final payersRepoProvider = Provider((ref) => PayersRepo(ref.watch(dbProvider)));
final staysRepoProvider = Provider((ref) => StaysRepo(ref.watch(dbProvider)));
final reservationsRepoProvider =
    Provider((ref) => ReservationsRepo(ref.watch(dbProvider)));

final usersStreamProvider =
    StreamProvider((ref) => ref.watch(usersRepoProvider).watchAll());
final articlesStreamProvider =
    StreamProvider((ref) => ref.watch(articlesRepoProvider).watchActive());
final roomsStreamProvider =
    StreamProvider((ref) => ref.watch(roomsRepoProvider).watchAll());
final recentSalesProvider =
    StreamProvider((ref) => ref.watch(salesRepoProvider).watchRecent());
final outstandingDebtsProvider = StreamProvider(
    (ref) => ref.watch(salesRepoProvider).watchOutstandingDebts());
final metricsWeekProvider =
    StreamProvider((ref) => ref.watch(metricsRepoProvider).watchLast7Days());
final clientsStreamProvider =
    StreamProvider((ref) => ref.watch(clientsRepoProvider).watchAll());
final payersStreamProvider =
    StreamProvider((ref) => ref.watch(payersRepoProvider).watchAll());
final recentStaysProvider =
    StreamProvider((ref) => ref.watch(staysRepoProvider).watchRecent());
final upcomingReservationsProvider = StreamProvider(
    (ref) => ref.watch(reservationsRepoProvider).watchUpcoming());
final allReservationsProvider =
    StreamProvider((ref) => ref.watch(reservationsRepoProvider).watchAll());

/// Taux FC→USD réactif — mis à jour dès qu'un admin le change dans les
/// Paramètres. Écouté par BlueSkyApp pour synchroniser Currency.rate.
final rateProvider = StreamProvider<double>(
    (ref) => ref.watch(settingsRepoProvider).watchRate());
