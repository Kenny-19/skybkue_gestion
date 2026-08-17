import 'dart:io';

import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migration v5 → v6 : les infos stock sont récupérées sans perte',
      () async {
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

    // Un article suivi (lié à un stock_item) + un article non lié.
    raw.execute(
        "INSERT INTO stock_items (id, name, unit, qty, threshold, category) VALUES (1, 'Coca', 'canette', 30, 12, 0)");
    raw.execute(
        "INSERT INTO articles (id, name, price_cents, category, active, stock_item_id) VALUES (1, 'Coca', 200, 0, 1, 1)");
    raw.execute(
        "INSERT INTO articles (id, name, price_cents, category, active, stock_item_id) VALUES (2, 'Chambre', 3000, 2, 1, NULL)");

    // Marque la base en version 5.
    raw.execute('PRAGMA user_version = 5');
    raw.dispose();

    // 2. Ouvre avec la nouvelle app → déclenche onUpgrade(5 → 6).
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db.customSelect('SELECT 1').get(); // force l'ouverture + migration

    // 3. Vérifie que les données sont préservées et enrichies.
    final coca = await (db.select(db.articles)..where((a) => a.id.equals(1)))
        .getSingle();
    expect(coca.name, 'Coca'); // pas perdu
    expect(coca.priceCents, 200);
    expect(coca.trackStock, true); // récupéré du lien
    expect(coca.unit, 'canette');
    expect(coca.stockQty, 30);
    expect(coca.threshold, 12);

    final chambre = await (db.select(db.articles)..where((a) => a.id.equals(2)))
        .getSingle();
    expect(chambre.name, 'Chambre');
    expect(chambre.trackStock, false); // non lié → pas de suivi

    await db.close();
    dir.deleteSync(recursive: true);
  });
}
