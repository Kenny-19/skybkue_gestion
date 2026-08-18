import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth.dart';
import 'repos.dart';

final settingsRepoProvider = Provider((ref) => SettingsRepo(ref.watch(dbProvider)));
final usersRepoProvider = Provider((ref) => UsersRepo(ref.watch(dbProvider)));
final articlesRepoProvider = Provider((ref) => ArticlesRepo(ref.watch(dbProvider)));
final roomsRepoProvider = Provider((ref) => RoomsRepo(ref.watch(dbProvider)));
final salesRepoProvider = Provider((ref) => SalesRepo(ref.watch(dbProvider)));
final metricsRepoProvider = Provider((ref) => MetricsRepo(ref.watch(dbProvider)));

final usersStreamProvider = StreamProvider((ref) => ref.watch(usersRepoProvider).watchAll());
final articlesStreamProvider = StreamProvider((ref) => ref.watch(articlesRepoProvider).watchActive());
final roomsStreamProvider = StreamProvider((ref) => ref.watch(roomsRepoProvider).watchAll());
final recentSalesProvider = StreamProvider((ref) => ref.watch(salesRepoProvider).watchRecent());
final metricsWeekProvider = StreamProvider((ref) => ref.watch(metricsRepoProvider).watchLast7Days());

/// Taux de change USD→FC, réactif (mis à jour dès qu'un admin le change).
final rateProvider = StreamProvider<double>((ref) => ref.watch(settingsRepoProvider).watchRate());
