import 'package:blue_sky/data/database.dart';
import 'package:drift/native.dart';

/// Crée une base Drift 100% en mémoire (jetable), avec le seed initial appliqué
/// (onCreate → createAll + seedInitialData). Chaque test part d'une base neuve.
AppDatabase newTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
