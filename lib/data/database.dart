import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'schema.dart';
import 'seed.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Settings, Users, Articles, Rooms, Sales, SaleLines])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur pour les tests : accepte un exécuteur en mémoire.
  AppDatabase.forTesting(super.executor);

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedInitialData(this);
        },
        onUpgrade: (m, from, to) async {
          // v1→v2 : ancien lien article↔stock (SQL brut car la table
          // stock_items n'existe plus dans le schéma Dart).
          if (from < 2) {
            await customStatement(
                'ALTER TABLE articles ADD COLUMN stock_item_id INTEGER');
            await customStatement('''
              UPDATE articles SET stock_item_id =
                (SELECT id FROM stock_items WHERE stock_items.name = articles.name)
            ''');
          }
          if (from < 3) {
            await m.addColumn(sales, sales.location);
          }
          if (from < 4) {
            await m.addColumn(articles, articles.imagePath);
          }
          if (from < 5) {
            await m.addColumn(sales, sales.customerName);
          }
          // v7 : table des réglages (taux de change, etc.).
          if (from < 7) {
            await m.createTable(settings);
          }
          // v6 : fusion des infos stock dans articles.
          if (from < 6) {
            await customStatement(
                "ALTER TABLE articles ADD COLUMN track_stock INTEGER NOT NULL DEFAULT 0");
            await customStatement(
                "ALTER TABLE articles ADD COLUMN unit TEXT NOT NULL DEFAULT 'unité'");
            await customStatement(
                "ALTER TABLE articles ADD COLUMN stock_qty INTEGER NOT NULL DEFAULT 0");
            await customStatement(
                "ALTER TABLE articles ADD COLUMN threshold INTEGER NOT NULL DEFAULT 0");
            // Récupère les infos depuis l'ancienne table stock_items via le lien.
            await customStatement('''
              UPDATE articles SET
                track_stock = 1,
                unit = COALESCE((SELECT unit FROM stock_items WHERE stock_items.id = articles.stock_item_id), 'unité'),
                stock_qty = COALESCE((SELECT qty FROM stock_items WHERE stock_items.id = articles.stock_item_id), 0),
                threshold = COALESCE((SELECT threshold FROM stock_items WHERE stock_items.id = articles.stock_item_id), 0)
              WHERE stock_item_id IS NOT NULL
                AND stock_item_id IN (SELECT id FROM stock_items)
            ''');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static Future<File> dbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final bsDir = Directory(p.join(dir.path, 'BlueSky'));
    if (!bsDir.existsSync()) bsDir.createSync(recursive: true);
    return File(p.join(bsDir.path, 'blue_sky.db'));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await AppDatabase.dbFile();
    return NativeDatabase.createInBackground(file);
  });
}
