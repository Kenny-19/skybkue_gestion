import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Crée une base Drift 100% en mémoire (jetable), avec le seed initial appliqué
/// (onCreate → createAll + seedInitialData : les comptes de secours
/// seulement). Chaque test part d'une base neuve.
AppDatabase newTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Catalogue de TEST : les articles qui servaient d'exemples dans
/// l'application. Ils vivent ici désormais, et seulement ici — une base
/// de production n'en reçoit plus (cf. lib/data/seed.dart).
///
/// Mêmes noms, prix et stocks qu'avant : les tests qui les citent
/// (« Coca Cola 33cl » à 18, « Poisson du jour » à 6…) gardent leur sens.
Future<void> semerCatalogueDeTest(AppDatabase db) async {
  const produits = <(String, int, DbCategory, bool, String, int, int)>[
    ('Eau minérale', 2000, DbCategory.boissons, true, 'bouteille', 42, 24),
    ('Coca Cola 33cl', 3000, DbCategory.boissons, true, 'unité', 18, 24),
    ("Jus d'orange", 4000, DbCategory.boissons, true, 'bouteille', 15, 10),
    ('Bière locale 50cl', 3500, DbCategory.boissons, true, 'unité', 63, 30),
    ('Vin rouge (verre)', 8000, DbCategory.boissons, true, 'verre', 40, 12),
    ('Café', 2500, DbCategory.boissons, true, 'tasse', 60, 20),
    (
      'Petit-déj continental',
      12000,
      DbCategory.nourriture,
      true,
      'portion',
      30,
      12
    ),
    ('Omelette + toast', 10000, DbCategory.nourriture, true, 'portion', 30, 12),
    (
      'Poulet rôti + frites',
      18000,
      DbCategory.nourriture,
      true,
      'portion',
      12,
      8
    ),
    ('Poisson du jour', 25000, DbCategory.nourriture, true, 'portion', 6, 6),
    ('Salade mixte', 8000, DbCategory.nourriture, true, 'portion', 20, 10),
    ('Dessert maison', 5000, DbCategory.nourriture, true, 'portion', 25, 12),
  ];
  await db.batch((b) {
    for (final p in produits) {
      b.insert(
        db.articles,
        ArticlesCompanion.insert(
          name: p.$1,
          priceCents: p.$2,
          category: p.$3,
          trackStock: Value(p.$4),
          unit: Value(p.$5),
          stockQty: Value(p.$6),
          threshold: Value(p.$7),
        ),
      );
    }
  });
}
