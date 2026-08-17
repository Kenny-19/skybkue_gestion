import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import 'database.dart';
import 'schema.dart';

/// Insertion des données de démarrage.
/// Appelée UNIQUEMENT à la création de la BDD (première ouverture).
///
/// Compte super admin par défaut :
///   login    : kenny
///   password : bluesky
/// À CHANGER dès la première connexion.
Future<void> seedInitialData(AppDatabase db) async {
  final defaultHash = BCrypt.hashpw('bluesky', BCrypt.gensalt());

  await db.batch((b) {
    b.insert(
      db.users,
      UsersCompanion.insert(
        fullName: 'Kenny Tshibangu',
        login: 'kenny',
        passwordHash: defaultHash,
        role: DbUserRole.superAdmin,
      ),
    );

    // Produits — chaque ligne : nom, prix(cents), catégorie,
    // suivi stock ?, unité, quantité, seuil.
    const products = <(String, int, DbCategory, bool, String, int, int)>[
      // Boissons — suivies en stock
      ('Eau minérale', 150, DbCategory.boissons, true, 'bouteille', 42, 24),
      ('Coca Cola 33cl', 200, DbCategory.boissons, true, 'unité', 18, 24),
      ("Jus d'orange", 250, DbCategory.boissons, true, 'bouteille', 15, 10),
      ('Bière locale 50cl', 350, DbCategory.boissons, true, 'unité', 63, 30),
      ('Vin rouge (verre)', 400, DbCategory.boissons, true, 'verre', 40, 12),
      ('Café', 150, DbCategory.boissons, true, 'tasse', 60, 20),
      // Nourriture — suivie en stock (portions)
      ('Petit-déj continental', 600, DbCategory.nourriture, true, 'portion', 30, 12),
      ('Omelette + toast', 550, DbCategory.nourriture, true, 'portion', 30, 12),
      ('Poulet rôti + frites', 850, DbCategory.nourriture, true, 'portion', 12, 8),
      ('Poisson du jour', 1000, DbCategory.nourriture, true, 'portion', 6, 6),
      ('Salade mixte', 450, DbCategory.nourriture, true, 'portion', 20, 10),
      ('Dessert maison', 300, DbCategory.nourriture, true, 'portion', 25, 12),
      // Chambres — pas de suivi stock
      ('Chambre simple', 3000, DbCategory.chambres, false, 'nuit', 0, 0),
      ('Chambre double', 5000, DbCategory.chambres, false, 'nuit', 0, 0),
      ('Suite (2 pièces)', 8000, DbCategory.chambres, false, 'nuit', 0, 0),
      ('Bungalow', 12000, DbCategory.chambres, false, 'nuit', 0, 0),
    ];
    for (final p in products) {
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

    // Chambres physiques (plan d'occupation).
    const rooms = <(String, String, int, DbRoomStatus)>[
      ('101', 'Simple', 3000, DbRoomStatus.libre),
      ('102', 'Simple', 3000, DbRoomStatus.libre),
      ('103', 'Simple', 3000, DbRoomStatus.libre),
      ('201', 'Double', 5000, DbRoomStatus.libre),
      ('202', 'Double', 5000, DbRoomStatus.libre),
      ('203', 'Double', 5000, DbRoomStatus.libre),
      ('301', 'Suite', 8000, DbRoomStatus.libre),
      ('302', 'Suite', 8000, DbRoomStatus.libre),
      ('B1', 'Bungalow', 12000, DbRoomStatus.libre),
      ('B2', 'Bungalow', 12000, DbRoomStatus.libre),
    ];
    for (final r in rooms) {
      b.insert(
        db.rooms,
        RoomsCompanion.insert(
          number: r.$1,
          type: r.$2,
          pricePerNightCents: r.$3,
          status: r.$4,
        ),
      );
    }
  });
}
