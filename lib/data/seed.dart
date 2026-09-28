import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import 'database.dart';
import 'schema.dart';

/// Comptes de SECOURS créés à l'installation.
///
/// Ils vivent uniquement sur le poste : jamais poussés vers Supabase,
/// jamais supprimés par une synchronisation. Ils servent à ouvrir l'app
/// le jour de l'installation et à dépanner quand Internet est coupé —
/// les vrais comptes nominatifs sont créés dans Supabase.
///
/// ⚠️ Ces codes sont publics par nature (ils sont dans le code source et
/// connus de toute l'équipe). Ils ne donnent volontairement PAS le rôle
/// super admin : l'administration réelle passe par un compte Supabase.
class LocalDefaultAccount {
  final String login;
  final String password;
  final String fullName;
  final DbUserRole role;
  const LocalDefaultAccount(
      this.login, this.password, this.fullName, this.role);
}

/// Mot de passe posé sur tout compte créé par un administrateur.
///
/// Il est volontairement trivial : l'employé le reçoit oralement, et
/// l'application lui impose de le changer à sa première connexion. Le
/// couple « défaut connu + changement forcé » vaut mieux qu'un mot de
/// passe choisi par l'admin, qui resterait connu de lui indéfiniment.
const String kMotDePasseProvisoire = '0000';

const kLocalDefaultAccounts = <LocalDefaultAccount>[
  LocalDefaultAccount('reception', '0000', 'Réception (compte de secours)',
      DbUserRole.reception),
  LocalDefaultAccount(
      'serveuse', '2000', 'Serveuse (compte de secours)', DbUserRole.serveur),
  LocalDefaultAccount(
      'admin', '7000', 'Gérant (compte de secours)', DbUserRole.gerant),
];

/// Insertion des données de démarrage.
/// Appelée à la création de la BDD OU au reset FC (schema v8).
///
/// [seedUser] : false lors d'un re-seed (migration v8) — on garde les users
/// existants et on ne recrée pas les comptes de secours.
Future<void> seedInitialData(AppDatabase db, {bool seedUser = true}) async {
  await db.batch((b) {
    if (seedUser) {
      for (final a in kLocalDefaultAccounts) {
        b.insert(
          db.users,
          UsersCompanion.insert(
            fullName: a.fullName,
            login: a.login,
            passwordHash: BCrypt.hashpw(a.password, BCrypt.gensalt()),
            role: a.role,
            isLocalDefault: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }

    // Prix en Franc Congolais (entier). Chiffres ronds à ajuster côté admin.
    // Colonnes : nom, prix(FC), catégorie, suivi stock ?, unité, quantité, seuil.
    const products = <(String, int, DbCategory, bool, String, int, int)>[
      // Boissons — suivies en stock
      ('Eau minérale', 2000, DbCategory.boissons, true, 'bouteille', 42, 24),
      ('Coca Cola 33cl', 3000, DbCategory.boissons, true, 'unité', 18, 24),
      ("Jus d'orange", 4000, DbCategory.boissons, true, 'bouteille', 15, 10),
      ('Bière locale 50cl', 3500, DbCategory.boissons, true, 'unité', 63, 30),
      ('Vin rouge (verre)', 8000, DbCategory.boissons, true, 'verre', 40, 12),
      ('Café', 2500, DbCategory.boissons, true, 'tasse', 60, 20),
      // Nourriture — suivie en stock (portions)
      (
        'Petit-déj continental',
        12000,
        DbCategory.nourriture,
        true,
        'portion',
        30,
        12
      ),
      (
        'Omelette + toast',
        10000,
        DbCategory.nourriture,
        true,
        'portion',
        30,
        12
      ),
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
      // Les chambres ne sont plus des "produits" du POS — la vente d'une
      // nuitée passe désormais uniquement par l'onglet Chambres (check-in
      // / check-out, calcul du prix depuis la table rooms).
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

    // Chambres physiques du Skyblue Guest House : 1 à 19.
    // Type et prix par défaut ; l'admin ajuste chaque chambre depuis
    // l'écran Chambres (bouton "Modifier").
    const rooms = <(String, String, int, DbRoomStatus)>[
      ('1', 'Standard', 60000, DbRoomStatus.libre),
      ('2', 'Standard', 60000, DbRoomStatus.libre),
      ('3', 'Standard', 60000, DbRoomStatus.libre),
      ('4', 'Standard', 60000, DbRoomStatus.libre),
      ('5', 'Standard', 60000, DbRoomStatus.libre),
      ('6', 'Standard', 60000, DbRoomStatus.libre),
      ('7', 'Standard', 60000, DbRoomStatus.libre),
      ('8', 'Standard', 60000, DbRoomStatus.libre),
      ('9', 'Standard', 60000, DbRoomStatus.libre),
      ('10', 'Standard', 60000, DbRoomStatus.libre),
      ('11', 'Standard', 60000, DbRoomStatus.libre),
      ('12', 'Standard', 60000, DbRoomStatus.libre),
      ('13', 'Standard', 60000, DbRoomStatus.libre),
      ('14', 'Standard', 60000, DbRoomStatus.libre),
      ('15', 'Standard', 60000, DbRoomStatus.libre),
      ('16', 'Standard', 60000, DbRoomStatus.libre),
      ('17', 'Standard', 60000, DbRoomStatus.libre),
      ('18', 'Standard', 60000, DbRoomStatus.libre),
      ('19', 'Standard', 60000, DbRoomStatus.libre),
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
