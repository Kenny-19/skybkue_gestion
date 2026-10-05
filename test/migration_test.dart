import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
      'migration v5 → v9 : utilisateurs préservés, produits de test purgés, '
      'nouvelles colonnes disponibles', () async {
    // 1. Fabrique une base au format v5 sur disque (raw sqlite3).
    final dir = Directory.systemTemp.createTempSync('bs_migr');
    final path = '${dir.path}/old.db';
    final raw = sqlite3.open(path);

    raw.execute('''
      CREATE TABLE articles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price_cents INTEGER NOT NULL,
        category INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        stock_item_id INTEGER,
        image_path TEXT
      );
      CREATE TABLE stock_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        qty INTEGER NOT NULL DEFAULT 0,
        threshold INTEGER NOT NULL DEFAULT 0,
        category INTEGER NOT NULL
      );
      CREATE TABLE users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL, login TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL, role INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT 0, last_login INTEGER
      );
      CREATE TABLE rooms (
        number TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,
        price_per_night_cents INTEGER NOT NULL, status INTEGER NOT NULL,
        current_guest TEXT, checkout_date INTEGER
      );
      CREATE TABLE sales (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sold_at INTEGER NOT NULL,
        server_user_id INTEGER, payment INTEGER NOT NULL,
        location INTEGER NOT NULL DEFAULT 0, customer_name TEXT, note TEXT
      );
      CREATE TABLE sale_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
        article_id INTEGER, article_name TEXT NOT NULL,
        qty INTEGER NOT NULL, unit_price_cents INTEGER NOT NULL
      );
    ''');

    // Un utilisateur existant (doit survivre au reset FC v8) + un vieux produit
    // en cents USD (sera purgé et remplacé par le seed FC).
    raw.execute(
        "INSERT INTO users (id, full_name, login, password_hash, role, active, created_at) "
        "VALUES (1, 'Ancien Admin', 'ancien', 'hash', 0, 1, 0)");
    raw.execute(
        "INSERT INTO stock_items (id, name, unit, qty, threshold, category) VALUES (1, 'Coca', 'canette', 30, 12, 0)");
    raw.execute(
        "INSERT INTO articles (id, name, price_cents, category, active, stock_item_id) VALUES (1, 'Vieux Coca', 200, 0, 1, 1)");

    // Marque la base en version 5.
    raw.execute('PRAGMA user_version = 5');
    raw.dispose();

    // 2. Ouvre avec la nouvelle app → déclenche toutes les migrations (→ v9).
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db.customSelect('SELECT 1').get(); // force l'ouverture + migration

    // 3a. L'utilisateur existant est PRÉSERVÉ (le reset v8 garde les comptes).
    final user = await (db.select(db.users)
          ..where((u) => u.login.equals('ancien')))
        .getSingleOrNull();
    expect(user, isNotNull);
    expect(user!.fullName, 'Ancien Admin');

    // 3b. Les vieux produits (cents USD) sont purgés. Plus de catalogue
    //     d'exemple re-semé : le vrai catalogue arrive du serveur.
    expect(await db.select(db.articles).get(), isEmpty,
        reason: 'ni les vieux produits, ni des exemples');
    expect(await db.select(db.rooms).get(), isEmpty);

    // 3c. Les colonnes v9 (dette) existent et sont interrogeables.
    final debts = await (db.select(db.sales)
          ..where((s) => s.onCredit.equals(true)))
        .get();
    expect(debts, isEmpty); // aucune vente après reset, mais la requête passe

    await db.close();
    dir.deleteSync(recursive: true);
  });

  test(
      'migration v17 → v18 : un compte `admin` existant garde son mot de '
      'passe et n\'est PAS requalifié en compte de secours', () async {
    // Le piège : `admin` est aussi le login d'un compte de secours. Sur
    // une installation qui tourne déjà, c'est un vrai super admin de
    // production — la v18 ne doit ni toucher à son mot de passe ni le
    // marquer local, sinon il serait exclu de la reprise vers Supabase.
    final dir = Directory.systemTemp.createTempSync('bs_v17');
    final path = '${dir.path}/v17.db';
    final raw = sqlite3.open(path);
    raw.execute(
      'CREATE TABLE users ('
      '  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,'
      '  full_name TEXT NOT NULL, login TEXT NOT NULL UNIQUE,'
      '  password_hash TEXT NOT NULL, role INTEGER NOT NULL,'
      '  active INTEGER NOT NULL DEFAULT 1,'
      '  created_at INTEGER NOT NULL DEFAULT 0, last_login INTEGER'
      ')',
    );
    final hash = BCrypt.hashpw('bluesky', BCrypt.gensalt());
    raw.execute(
      'INSERT INTO users (full_name, login, password_hash, role, active, '
      "created_at) VALUES ('Administrateur', 'admin', ?, 0, 1, 0)",
      [hash],
    );
    raw.execute('PRAGMA user_version = 17');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);
    final all = await db.select(db.users).get();

    final admin = all.firstWhere((u) => u.login == 'admin');
    expect(admin.role, DbUserRole.superAdmin, reason: 'rôle préservé');
    expect(admin.passwordHash, hash, reason: 'mot de passe intact');
    expect(admin.isLocalDefault, false,
        reason: 'un compte de production ne devient pas un compte de secours');

    // Les deux autres comptes de secours, eux, sont bien créés.
    final secours =
        all.where((u) => u.isLocalDefault).map((u) => u.login).toList();
    expect(secours, containsAll(['reception', 'serveuse']));
    expect(secours, isNot(contains('admin')));
  });

  test(
      'migration interrompue : une colonne déjà ajoutée alors que '
      'user_version n\'a pas bougé ne bloque pas le démarrage', () async {
    // Cas réel rencontré en production : un build précédent a ajouté
    // `negotiated_price_cents` puis a échoué plus loin, laissant
    // user_version à 16. Au redémarrage, drift rejoue le bloc v17 —
    // l'app ne doit PAS refuser de s'ouvrir sur un « duplicate column ».
    final dir = Directory.systemTemp.createTempSync('bs_partial');
    final path = '${dir.path}/partial.db';
    final raw = sqlite3.open(path);
    raw.execute(
      'CREATE TABLE users ('
      '  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,'
      '  full_name TEXT NOT NULL, login TEXT NOT NULL UNIQUE,'
      '  password_hash TEXT NOT NULL, role INTEGER NOT NULL,'
      '  active INTEGER NOT NULL DEFAULT 1,'
      '  created_at INTEGER NOT NULL DEFAULT 0, last_login INTEGER'
      ')',
    );
    raw.execute(
      'CREATE TABLE rooms ('
      '  number TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,'
      '  price_per_night_cents INTEGER NOT NULL, status INTEGER NOT NULL,'
      '  current_guest TEXT, checkout_date INTEGER, checkin_note TEXT,'
      '  checkin_at INTEGER, stay_group TEXT, payer_id INTEGER,'
      '  image_path TEXT,'
      // La colonne v17 est DÉJÀ là — c'est tout le sujet du test.
      '  negotiated_price_cents INTEGER'
      ')',
    );
    raw.execute(
      "INSERT INTO rooms (number, type, price_per_night_cents, status) "
      "VALUES ('12', 'Deluxe', 60000, 0)",
    );
    raw.execute('PRAGMA user_version = 16');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // L'ouverture rejoue v17 puis v18 sans exploser…
    final rooms = await db.select(db.rooms).get();
    expect(rooms.single.number, '12');
    expect(rooms.single.negotiatedPriceCents, isNull);

    // …et la v18 a bien fait son travail derrière.
    final users = await db.select(db.users).get();
    expect(users.where((u) => u.isLocalDefault).length, 3);
  });

  test('v19 : les index existent, sur une base neuve comme sur une migree',
      () async {
    // Une base creee de zero et une base migree doivent finir
    // identiques. C'est la regle qu'on oublie le plus facilement quand
    // on ajoute des index ailleurs que dans les tables Drift.
    Future<Set<String>> indexesOf(AppDatabase db) async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_%'",
          )
          .get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    // 1. Base neuve.
    final neuve = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(neuve.close);
    final attendus = await indexesOf(neuve);
    expect(attendus, contains('idx_sales_sold_at'));
    expect(attendus.length, greaterThanOrEqualTo(9));

    // 2. Base migree depuis la v18.
    final dir = Directory.systemTemp.createTempSync('bs_v18');
    final path = '${dir.path}/v18.db';
    final migree = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(migree.close);
    await migree.customSelect('SELECT 1').get();

    expect(await indexesOf(migree), attendus,
        reason: 'base neuve et base migree doivent avoir les memes index');
  });

  test('les index portent sur des colonnes qui existent vraiment', () async {
    // Un index sur une colonne mal orthographiee echoue au CREATE :
    // si la base s'ouvre, c'est que les 9 sont valides. On verifie en
    // plus qu'ils sont bien attaches aux tables attendues.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%' ORDER BY name",
        )
        .get();
    final parTable = {
      for (final r in rows) r.read<String>('name'): r.read<String>('tbl_name')
    };
    expect(parTable['idx_sales_sold_at'], 'sales');
    expect(parTable['idx_sale_lines_sale'], 'sale_lines');
    expect(parTable['idx_stays_checkout_at'], 'stays');
    expect(parTable['idx_reservations_arrivee'], 'reservations');
    expect(parTable['idx_rooms_status'], 'rooms');
  });

  test('v20 : les types de chambres de la vraie base sont unifies', () async {
    // Valeurs relevees le 16 septembre 2026 dans la base de production :
    // `standard` x14, `Standard`, `STANDARD`, `SIMPLE`, `APPARTEMENT`,
    // et la chambre 19 qui portait `230000` — un prix saisi dans le
    // champ type.
    final dir = Directory.systemTemp.createTempSync('bs_v19');
    final path = '${dir.path}/v19.db';
    final raw = sqlite3.open(path);
    raw.execute(
      'CREATE TABLE rooms ('
      '  number TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,'
      '  price_per_night_cents INTEGER NOT NULL, status INTEGER NOT NULL,'
      '  current_guest TEXT, checkout_date INTEGER, checkin_note TEXT,'
      '  checkin_at INTEGER, stay_group TEXT, payer_id INTEGER,'
      '  image_path TEXT, negotiated_price_cents INTEGER'
      ')',
    );
    for (final r in [
      ['01', 'standard', 299000],
      ['13', 'Standard', 299000],
      ['16', 'STANDARD', 299000],
      ['17', 'SIMPLE', 230000],
      ['18', 'APPARTEMENT', 414000],
      ['19', '230000', 230000], // le prix dans le champ type
    ]) {
      raw.execute(
        'INSERT INTO rooms (number, type, price_per_night_cents, status) '
        'VALUES (?, ?, ?, 0)',
        [r[0], r[1], r[2]],
      );
    }
    raw.execute('PRAGMA user_version = 19');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);
    final rooms = await db.select(db.rooms).get();
    final parNumero = {for (final r in rooms) r.number: r.type};

    // Les trois ecritures de standard n'en font plus qu'une.
    expect(parNumero['01'], 'Standard');
    expect(parNumero['13'], 'Standard');
    expect(parNumero['16'], 'Standard');
    expect(parNumero['17'], 'Simple');
    expect(parNumero['18'], 'Appartement');

    // La chambre 19 recupere le type de l'autre chambre au meme prix.
    expect(parNumero['19'], 'Simple',
        reason: '230 000 FC est aussi le prix de la 17, une Simple');

    // Plus aucun doublon de casse.
    final types = rooms.map((r) => r.type).toSet();
    expect(types, {'Standard', 'Simple', 'Appartement'});
  });

  test('v20 : sans correspondance de prix, on retombe sur Standard', () async {
    final dir = Directory.systemTemp.createTempSync('bs_v19b');
    final path = '${dir.path}/v19b.db';
    final raw = sqlite3.open(path);
    raw.execute(
      'CREATE TABLE rooms ('
      '  number TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,'
      '  price_per_night_cents INTEGER NOT NULL, status INTEGER NOT NULL,'
      '  current_guest TEXT, checkout_date INTEGER, checkin_note TEXT,'
      '  checkin_at INTEGER, stay_group TEXT, payer_id INTEGER,'
      '  image_path TEXT, negotiated_price_cents INTEGER'
      ')',
    );
    raw.execute(
      "INSERT INTO rooms (number, type, price_per_night_cents, status) "
      "VALUES ('42', '999000', 999000, 0)",
    );
    raw.execute('PRAGMA user_version = 19');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);
    final r = (await db.select(db.rooms).get()).single;
    expect(r.type, 'Standard',
        reason: 'aucune autre chambre a ce prix : repli, jamais « 999000 »');
  });
}
