import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/room_type.dart';
import 'schema.dart';
import 'seed.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Settings,
  Users,
  Articles,
  Rooms,
  Sales,
  SaleLines,
  DebtPayments,
  StockMoves,
  Clients,
  Payers,
  Stays,
  StayRooms,
  Reservations,
  ReservationRooms,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur pour les tests : accepte un exécuteur en mémoire.
  AppDatabase.forTesting(super.executor);

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 25;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureIndexes();
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
          // ⚠️ Les branches ci-dessous DOIVENT rester en ordre croissant :
          // la v8 re-seed les articles avec les colonnes ajoutées en v6.
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
          // v7 : table des réglages.
          if (from < 7) {
            await m.createTable(settings);
          }
          // v8 : passage en Franc Congolais comme devise unique. On purge
          // produits/chambres/ventes (données de test en cents USD) et on
          // ressème avec des prix FC. Les utilisateurs sont conservés.
          // (Doit venir APRÈS v6 : le seed insère les colonnes stock.)
          if (from < 8) {
            await customStatement('DELETE FROM sale_lines');
            await customStatement('DELETE FROM sales');
            await customStatement('DELETE FROM articles');
            await customStatement('DELETE FROM rooms');
            await seedInitialData(this, seedUser: false);
          }
          // v9 : chambre + gestion de dette sur les ventes.
          if (from < 9) {
            await m.addColumn(sales, sales.roomNumber);
            await m.addColumn(sales, sales.onCredit);
            await m.addColumn(sales, sales.settledAt);
          }
          // v10 : les chambres ne sont plus des "produits" du POS. On
          // purge tous les articles de catégorie chambres (index 2). Les
          // lignes de vente qui les référençaient conservent leur
          // articleName (snapshot) mais leur article_id passe à NULL via
          // la FK setNull — l'historique reste intact et lisible.
          if (from < 10) {
            await customStatement('DELETE FROM articles WHERE category = 2');
          }
          // v11 : notes de check-in sur les chambres + horodatage précis.
          // Purement additif — nullable, aucune donnée existante touchée.
          if (from < 11) {
            await m.addColumn(rooms, rooms.checkinNote);
            await m.addColumn(rooms, rooms.checkinAt);
          }
          // v12 : séjour groupé (entreprise loue plusieurs chambres à
          // la fois). stay_group est un id court partagé. Nullable —
          // aucune donnée existante impactée.
          if (from < 12) {
            await m.addColumn(rooms, rooms.stayGroup);
          }
          // v13 : fichier client (fidélité) + payeurs tiers (prise en
          // charge société / privée). rooms.payer_id lie une chambre
          // à son payeur, null = l'occupant paie.
          if (from < 13) {
            await m.createTable(clients);
            await m.createTable(payers);
            await m.addColumn(rooms, rooms.payerId);
          }
          // v14 : historique des séjours (Stays + StayRooms) pour
          // permettre la régénération de facture depuis l'onglet
          // Historique après un check-out.
          if (from < 14) {
            await m.createTable(stays);
            await m.createTable(stayRooms);
          }
          // v15 : image de la chambre (comme les produits POS).
          if (from < 15) {
            await m.addColumn(rooms, rooms.imagePath);
          }
          // v16 : réservations futures (Reservations + ReservationRooms).
          if (from < 16) {
            await m.createTable(reservations);
            await m.createTable(reservationRooms);
          }
          // v17 : système de remise complet — tarif négocié par chambre
          // au check-in + détail de la remise de facturation (type, base,
          // valeur, motif) au check-out.
          //
          // Chaque ajout passe par [_addColumnIfMissing] : une migration
          // interrompue en cours de route laisse des colonnes déjà
          // créées alors que `user_version` n'a pas bougé, et le
          // prochain démarrage rejoue le bloc. Sans ce garde-fou, l'app
          // ne s'ouvre plus du tout ("duplicate column name").
          if (from < 17) {
            await _addColumnIfMissing(m, rooms, rooms.negotiatedPriceCents);
            // stays / stay_rooms n'existent que depuis la v14. On
            // VÉRIFIE leur présence au lieu de la déduire de `from` :
            // sur une base à l'état incertain, l'inférence se trompe et
            // l'app refuse de démarrer.
            if (await _tableExists('stays')) {
              await _addColumnIfMissing(m, stays, stays.remiseKind);
              await _addColumnIfMissing(m, stays, stays.remiseValue);
              await _addColumnIfMissing(m, stays, stays.remiseBase);
              await _addColumnIfMissing(m, stays, stays.remiseReason);
              await _addColumnIfMissing(m, stayRooms, stayRooms.listPriceCents);
              // Les séjours déjà archivés avaient une remise en montant
              // fixe : on recopie le montant dans remise_value pour que
              // l'historique reste cohérent avec le nouveau modèle.
              // Le WHERE rend l'opération rejouable sans double effet.
              await customStatement(
                  'UPDATE stays SET remise_value = remise_cents '
                  'WHERE remise_cents > 0 AND remise_value = 0');
            }
          }
          // v18 : comptes de secours locaux + suivi de synchronisation,
          // la source de vérité des comptes passant à Supabase.
          if (from < 18) {
            await _addColumnIfMissing(m, users, users.isLocalDefault);
            await _addColumnIfMissing(m, users, users.syncedAt);
            // Les comptes de secours (réception / serveuse / admin) sont
            // créés s'ils manquent. Un login déjà pris n'est NI écrasé NI
            // requalifié en compte de secours : sur une installation
            // existante, `admin` est un vrai super admin de production —
            // il garde son mot de passe et reste éligible à la reprise
            // vers Supabase.
            for (final a in kLocalDefaultAccounts) {
              // Requête BRUTE, volontairement. `select(users)` lit toutes
              // les colonnes du schéma COURANT — dont celles ajoutées par
              // des migrations ultérieures, qui n'existent pas encore à ce
              // stade. C'est une erreur qu'on ne voit qu'en migrant une
              // vraie vieille base, jamais sur une base neuve.
              final dejaLa = await customSelect(
                'SELECT 1 FROM users WHERE lower(login) = ? LIMIT 1',
                variables: [Variable<String>(a.login)],
              ).get();
              if (dejaLa.isNotEmpty) continue;
              await into(users).insert(UsersCompanion.insert(
                fullName: a.fullName,
                login: a.login,
                passwordHash: BCrypt.hashpw(a.password, BCrypt.gensalt()),
                role: a.role,
                isLocalDefault: const Value(true),
              ));
            }
          }
          // v19 : index sur les chemins de lecture chauds. Aucun n'avait
          // jamais été déclaré — SQLite faisait un balayage complet pour
          // chaque rapport et chaque facture. Sans effet visible sur 92
          // ventes, insupportable sur deux ans d'exploitation.
          if (from < 19) {
            await _ensureIndexes();
          }
          // v20 : normalisation des types de chambre.
          //
          // En production, la même catégorie s'écrivait `standard`,
          // `Standard` et `STANDARD`, et une chambre portait `230000`
          // comme type — un prix saisi dans le mauvais champ.
          //
          // Le nettoyage vit dans la migration plutôt que dans un script
          // SQL ponctuel : chaque poste a sa propre base, et un script
          // n'aurait corrigé que celui sur lequel on l'aurait lancé.
          if (from < 20 && await _tableExists('rooms')) {
            await _normaliserTypesChambres();
          }
          // v21 : mot de passe provisoire à changer à la première
          // connexion. Les comptes existants ne sont PAS marqués — leurs
          // propriétaires ont déjà choisi leur mot de passe.
          if (from < 21 && await _tableExists('users')) {
            await _addColumnIfMissing(m, users, users.mustChangePassword);
          }
          // v22 : file des mouvements de stock. Le poste déclare des
          // deltas au lieu d'écraser une quantité — deux postes peuvent
          // alors vendre hors ligne sans s'effacer l'un l'autre.
          if (from < 22) {
            await m.createTable(stockMoves);
          }
          // v23 : règlements partiels des dettes. Jusqu'ici une dette se
          // soldait d'un bloc — impossible d'enregistrer un acompte, et
          // les versements reçus n'étaient tracés nulle part.
          if (from < 23 && !await _tableExists('debt_payments')) {
            await m.createTable(debtPayments);
          }
          // v24 : accusé de réception sur les ventes. Les ventes déjà en
          // base partent avec `synced_at` à null — elles seront donc
          // republiées une fois, puis marquées. C'est voulu : on préfère
          // un renvoi de trop à une vente qu'on croit en ligne à tort.
          if (from < 24 && await _tableExists('sales')) {
            await _addColumnIfMissing(m, sales, sales.syncedAt);
            await _addColumnIfMissing(m, sales, sales.syncAttempts);
            await _addColumnIfMissing(m, sales, sales.syncError);
          }
          // v25 : l'hôtel tarifie en dollars. Le franc reste la monnaie
          // d'encaissement, mais il n'est plus la source du prix.
          if (from < 25) {
            if (await _tableExists('rooms')) {
              await _addColumnIfMissing(m, rooms, rooms.priceUsdCents);
            }
            if (await _tableExists('stay_rooms')) {
              await _addColumnIfMissing(m, stayRooms, stayRooms.priceUsdCents);
              await _addColumnIfMissing(m, stayRooms, stayRooms.listUsdCents);
            }
            if (await _tableExists('stays')) {
              await _addColumnIfMissing(m, stays, stays.fcPerUsdCents);
            }
            await _convertirTarifsEnDollars();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // WAL : un lecteur ne bloque plus sur un écrivain.
          //
          // En mode « delete » — le défaut de SQLite, et ce que le poste
          // utilisait — une écriture verrouille le fichier entier et
          // toute lecture concurrente échoue. Avec la file des ventes qui
          // interroge la base toutes les quinze secondes pendant que la
          // synchronisation écrit, la collision était mécanique.
          //
          // WAL ne se pose que sur un dossier NON synchronisé : ses
          // fichiers annexes (-wal, -shm) doivent rester cohérents avec
          // la base. C'est pourquoi ce PRAGMA arrive en même temps que le
          // déménagement hors de OneDrive, et pas avant.
          await customStatement('PRAGMA journal_mode = WAL');
          // Et si un verrou survient quand même, on attend au lieu
          // d'abandonner : dix secondes valent mieux qu'une vente qui
          // ne part pas.
          await customStatement('PRAGMA busy_timeout = 10000');
          // Filet de rattrapage, à CHAQUE ouverture.
          //
          // La conversion en dollars est idempotente — elle ne touche que
          // les lignes restées à zéro. La rejouer ici répare les postes
          // où elle a été perdue : le 22 septembre, la migration avait
          // bien converti 19 chambres, et le pull les a remises à zéro
          // dans les quinze secondes. Sans ce filet, il aurait fallu
          // republier une version pour chaque poste abîmé.
          await _convertirTarifsEnDollars();
        },
      );

  /// Convertit les tarifs existants, du franc vers le dollar.
  ///
  /// Le taux est lu dans la table `settings`, PAS dans `Currency.rate` :
  /// ce cache mémoire est rempli par `app.dart` après l'ouverture de la
  /// base, donc il vaut encore sa valeur par défaut au moment où cette
  /// migration s'exécute. Convertir à 2300 une base réglée à 2600
  /// fausserait tous les tarifs d'un coup, et personne ne le verrait
  /// avant la première facture.
  ///
  /// Requêtes BRUTES, volontairement : `select(rooms)` lit toutes les
  /// colonnes du schéma COURANT, dont celles qu'une migration ultérieure
  /// ajoutera et qui n'existent pas encore à ce stade.
  Future<void> _convertirTarifsEnDollars() async {
    // La table `settings` peut manquer : une base très ancienne, ou une
    // restauration partielle. On ne suppose l'existence d'AUCUNE table
    // dans une migration — c'est la règle qui a sauvé le démarrage plus
    // d'une fois ici, et je l'avais oubliée sur cette ligne.
    final r = await _tableExists('settings')
        ? await customSelect(
            "SELECT value FROM settings WHERE key = 'fc_per_usd_rate' "
            'LIMIT 1',
          ).get()
        : const [];
    final taux = double.tryParse(
            r.isEmpty ? '' : (r.first.data['value'] as String? ?? '')) ??
        2300.0;
    if (taux <= 0) return;
    // Taux × 100, pour figer un entier sur les séjours.
    final tauxCents = (taux * 100).round();

    // Tarifs catalogue : franc → dollar.
    if (await _tableExists('rooms')) {
      await customStatement(
        'UPDATE rooms SET price_usd_cents = '
        'CAST(ROUND(price_per_night_cents * 100.0 / ?) AS INTEGER) '
        'WHERE price_usd_cents = 0',
        [taux],
      );
    }

    // Séjours déjà facturés : on fige le taux du jour de la migration,
    // faute de connaître celui qui s'appliquait à l'époque. C'est une
    // approximation, et elle ne concerne que l'historique — les séjours
    // à venir figeront le vrai taux à leur check-out.
    if (await _tableExists('stays')) {
      await customStatement(
        'UPDATE stays SET fc_per_usd_cents = ? WHERE fc_per_usd_cents = 0',
        [tauxCents],
      );
    }
    // Remises en MONTANT déjà enregistrées : elles étaient en francs,
    // elles deviennent des dollars. Le pourcentage n'est PAS touché — il
    // est neutre en devise, et c'est précisément ce qui le rend fiable.
    if (await _tableExists('stays')) {
      await customStatement(
        'UPDATE stays SET remise_value = '
        'CAST(ROUND(remise_value * 100.0 / ?) AS INTEGER) '
        'WHERE remise_kind = 0 AND remise_value > 0',
        [taux],
      );
    }

    if (await _tableExists('stay_rooms')) {
      await customStatement(
        'UPDATE stay_rooms SET '
        'price_usd_cents = CAST(ROUND(price_per_night_cents * 100.0 / ?) AS INTEGER), '
        'list_usd_cents = CASE WHEN list_price_cents IS NULL THEN NULL '
        '  ELSE CAST(ROUND(list_price_cents * 100.0 / ?) AS INTEGER) END '
        'WHERE price_usd_cents = 0',
        [taux, taux],
      );
    }
  }

  /// Crée les index de lecture s'ils manquent.
  ///
  /// Appelé à la création ET par la migration v19 : une base neuve et
  /// une base migrée doivent finir identiques. `IF NOT EXISTS` rend
  /// l'opération rejouable, comme le reste des migrations.
  ///
  /// Chaque index correspond à une requête réelle de repos.dart, pas à
  /// une supposition — un index inutile coûte à chaque écriture.
  Future<void> _ensureIndexes() async {
    // Chaque entrée : table visée, puis l'instruction. On VÉRIFIE que la
    // table existe au lieu de le supposer — une base à l'état incertain
    // (migration interrompue, restauration partielle) ferait autrement
    // échouer l'ouverture de l'application entière pour un index.
    const statements = <(String, String)>[
      // Rapports et historique : tout est filtré par date de vente.
      (
        'sales',
        'CREATE INDEX IF NOT EXISTS idx_sales_sold_at ON sales (sold_at)'
      ),
      // Dettes en cours (écran Dettes, alerte du tableau de bord).
      (
        'sales',
        'CREATE INDEX IF NOT EXISTS idx_sales_credit ON sales (on_credit, settled_at)'
      ),
      // Lignes d'une vente : jointure de chaque facture.
      (
        'sale_lines',
        'CREATE INDEX IF NOT EXISTS idx_sale_lines_sale ON sale_lines (sale_id)'
      ),
      // Historique hôtelier, trié et filtré par date de départ.
      (
        'stays',
        'CREATE INDEX IF NOT EXISTS idx_stays_checkout_at ON stays (checkout_at)'
      ),
      // Facture consolidée d'un séjour groupé.
      (
        'stays',
        'CREATE INDEX IF NOT EXISTS idx_stays_group ON stays (stay_group)'
      ),
      // Chambres d'un séjour (régénération de facture).
      (
        'stay_rooms',
        'CREATE INDEX IF NOT EXISTS idx_stay_rooms_stay ON stay_rooms (stay_id)'
      ),
      // Arrivées du jour : filtre statut + date.
      (
        'reservations',
        'CREATE INDEX IF NOT EXISTS idx_reservations_arrivee ON reservations (status, checkin_date)'
      ),
      // Chambres d'une réservation.
      (
        'reservation_rooms',
        'CREATE INDEX IF NOT EXISTS idx_reservation_rooms_res ON reservation_rooms (reservation_id)'
      ),
      // Plan des chambres : filtré par statut à chaque ouverture.
      (
        'rooms',
        'CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms (status)'
      ),
    ];
    for (final (table, sql) in statements) {
      if (!await _tableExists(table)) continue;
      await customStatement(sql);
    }
  }

  /// Réécrit chaque type de chambre sous une forme unique.
  ///
  /// Une valeur qui n'est pas un type (vide, ou un prix) est retrouvée
  /// par le PRIX : une chambre à 230 000 FC prend le type de l'autre
  /// chambre à 230 000 FC. C'est une déduction, mais une déduction
  /// vérifiable — et nettement préférable à laisser « 230000 » à
  /// l'écran. Sans correspondance, on retombe sur « Standard ».
  Future<void> _normaliserTypesChambres() async {
    if (!await _tableExists('rooms')) return;

    // Requêtes BRUTES, volontairement — et la leçon a coûté cher deux
    // fois. `select(rooms)` lit toutes les colonnes du schéma COURANT,
    // dont celles qu'une migration ULTÉRIEURE ajoutera : ici `price_usd_
    // cents`, créée en v25, alors qu'on est en train de jouer la v20.
    // La lecture échoue sur un « null check operator » incompréhensible,
    // et l'application ne démarre plus du tout.
    //
    // Une migration ne doit lire que ce qui existe à SON étape, jamais
    // ce que le code connaît aujourd'hui.
    final toutes = await customSelect(
      'SELECT number, type, price_per_night_cents FROM rooms',
    ).get();

    String typeDe(QueryRow r) => r.read<String>('type');
    int prixDe(QueryRow r) => r.read<int>('price_per_night_cents');

    final parPrix = <int, String>{};
    for (final r in toutes) {
      final t = normalizeRoomType(typeDe(r));
      if (t != null) parPrix.putIfAbsent(prixDe(r), () => t);
    }

    for (final r in toutes) {
      final actuel = typeDe(r);
      final cible = normalizeRoomType(actuel) ??
          parPrix[prixDe(r)] ??
          kTypeChambreParDefaut;
      if (cible == actuel) continue;
      await customStatement(
        'UPDATE rooms SET type = ? WHERE number = ?',
        [cible, r.read<String>('number')],
      );
    }
  }

  /// True si la table existe réellement dans le fichier SQLite.
  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Colonnes réellement présentes dans une table SQLite.
  ///
  /// Sert aux migrations : sur un poste où une mise à jour a échoué en
  /// cours de route, des colonnes existent alors que `user_version` n'a
  /// pas bougé. Le prochain démarrage rejoue le bloc — il doit pouvoir
  /// le faire sans planter.
  Future<Set<String>> _existingColumns(String table) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  /// `ALTER TABLE … ADD COLUMN` rejouable : ne fait rien si la colonne
  /// est déjà là.
  Future<void> _addColumnIfMissing(
      Migrator m, TableInfo table, GeneratedColumn column) async {
    final existing = await _existingColumns(table.actualTableName);
    if (existing.contains(column.name)) return;
    await m.addColumn(table, column);
  }

  /// Le fichier de base, HORS de tout dossier synchronisé.
  ///
  /// Pourquoi ce n'est plus « Documents »
  /// ------------------------------------
  /// `getApplicationDocumentsDirectory()` rend le dossier Documents, que
  /// Windows redirige couramment vers OneDrive — c'était le cas sur le
  /// poste de Lubumbashi. OneDrive resynchronise alors le fichier à
  /// chaque écriture, et pose un verrou dessus pendant l'envoi. SQLite
  /// répond « database is locked » et l'opération échoue.
  ///
  /// Mesuré le 24 septembre 2026 : 100 erreurs de ce type remontées
  /// depuis le 27 août, dont 70 sur la seule file des ventes, qui
  /// interroge la base toutes les quinze secondes.
  ///
  /// Le risque dépasse l'erreur affichée : un service de synchronisation
  /// qui copie une base SQLite en cours d'écriture peut en envoyer une
  /// image incohérente, ou créer un fichier de conflit. Une base de
  /// caisse n'a rien à faire dans un dossier grand public synchronisé.
  ///
  /// `getApplicationSupportDirectory()` rend un dossier propre à
  /// l'application sous AppData, que rien ne synchronise.
  static Future<File> dbFile() async {
    final support = await getApplicationSupportDirectory();
    final dossier = Directory(p.join(support.path, 'BlueSky'));
    if (!dossier.existsSync()) dossier.createSync(recursive: true);
    final cible = File(p.join(dossier.path, 'blue_sky.db'));

    // Déjà déménagée, ou poste neuf : rien à faire.
    if (cible.existsSync() && cible.lengthSync() > 0) return cible;

    final ancienne = await _ancienneBase();
    if (ancienne == null) return cible;

    // Le déménagement a échoué → ON RESTE SUR L'ANCIENNE.
    //
    // C'est le point le plus important de cette méthode. Rendre la
    // nouvelle adresse vide ferait croire à `RestoreOnBoot` que le poste
    // n'a pas de base, et il restaurerait une sauvegarde cloud plus
    // ancienne : le poste repartirait sur des données périmées pendant
    // que sa vraie caisse dort dans l'ancien dossier. Mieux vaut
    // continuer à subir les verrous de OneDrive que perdre une journée
    // de ventes.
    final ok = await _copierBase(ancienne, cible);
    return ok ? cible : ancienne;
  }

  /// L'ancienne base, dans Documents — donc souvent dans OneDrive.
  /// Null si elle n'existe pas ou si elle est vide.
  static Future<File?> _ancienneBase() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final f = File(p.join(docs.path, 'BlueSky', 'blue_sky.db'));
      if (!f.existsSync() || f.lengthSync() == 0) return null;
      return f;
    } catch (_) {
      return null;
    }
  }

  /// Copie la base vers sa nouvelle adresse, sans jamais toucher
  /// l'original.
  ///
  /// Passe par un fichier temporaire puis un renommage : le renommage
  /// est atomique sur un même volume, donc la destination n'existe
  /// qu'une fois la copie COMPLÈTE. Une copie interrompue — coupure de
  /// courant, disque plein, OneDrive qui reprend la main — laisserait
  /// sinon un fichier tronqué que l'application ouvrirait comme s'il
  /// était sain.
  static Future<bool> _copierBase(File source, File cible) async {
    final temporaire = File('${cible.path}.entrant');
    try {
      if (temporaire.existsSync()) temporaire.deleteSync();
      await source.copy(temporaire.path);

      // Vérification minimale : une base SQLite commence par cet
      // en-tête. Un fichier verrouillé ou partiellement écrit par la
      // synchronisation ne le porte pas.
      final entete = await temporaire.openRead(0, 16).first;
      final signature = String.fromCharCodes(entete.take(15));
      if (signature != 'SQLite format 3') {
        temporaire.deleteSync();
        return false;
      }
      if (temporaire.lengthSync() != source.lengthSync()) {
        temporaire.deleteSync();
        return false;
      }

      await temporaire.rename(cible.path);

      // Les journaux d'un arrêt brutal, s'il y en a : sans eux, la copie
      // manquerait les dernières transactions validées.
      for (final suffixe in const ['-wal', '-shm']) {
        final j = File('${source.path}$suffixe');
        if (j.existsSync()) await j.copy('${cible.path}$suffixe');
      }

      // L'original est LAISSÉ EN PLACE, volontairement. Il sert de
      // retour arrière si la nouvelle version pose problème, et rien ne
      // presse de l'effacer.
      return true;
    } catch (_) {
      try {
        if (temporaire.existsSync()) temporaire.deleteSync();
      } catch (_) {}
      return false;
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await AppDatabase.dbFile();
    return NativeDatabase.createInBackground(file);
  });
}
