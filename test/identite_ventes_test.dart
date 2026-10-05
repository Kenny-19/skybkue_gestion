import 'dart:io';

import 'package:blue_sky/core/identite.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Sprint de refonte, priorité 1 : une vente garde son identité partout.
//
// Avant : le serveur rangeait les ventes par numéro LOCAL. La vente n° 345
// de la caisse et la vente n° 345 de la réception étaient la même ligne,
// et la dernière envoyée écrasait l'autre.

void main() {
  group('Formule partagée avec le serveur', () {
    // Valeurs calculées par PostgreSQL avec le script
    // sql/2026_10_identite_ventes.sql (test PGlite du 5 octobre 2026).
    // Si l'une de ces deux lignes casse, le poste et le serveur ne
    // reconnaissent plus les mêmes ventes.
    test('vente héritée : même uid que le serveur', () {
      final u = uidVenteHerite(
          345, DateTime.fromMillisecondsSinceEpoch(1790572508 * 1000));
      expect(u, '1ebb8708-75ac-8640-d5ab-ac09a9abc4c9');
    });

    test('ligne héritée : même uid que le serveur', () {
      expect(uidLigneHerite('1ebb8708-75ac-8640-d5ab-ac09a9abc4c9', 900),
          '14bd3675-b7f0-0901-6b9b-ee099ed05bc8');
    });

    test('même numéro, autre poste, autre seconde : autre identité', () {
      final caisse = uidVenteHerite(
          345, DateTime.fromMillisecondsSinceEpoch(1790572508 * 1000));
      final reception = uidVenteHerite(
          345, DateTime.fromMillisecondsSinceEpoch(1790590000 * 1000));
      expect(caisse, isNot(reception));
    });

    test('uid neuf : format UUID v4, jamais deux fois le même', () {
      final tous = {for (var i = 0; i < 5000; i++) nouvelUid()};
      expect(tous, hasLength(5000));
      expect(
          tous.first,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
  });

  group('Base locale', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('bs_identite'));
    tearDown(() => dir.deleteSync(recursive: true));

    /// Une base v25 (avant l'identité) avec une vente et ses lignes.
    String baseV25(int idVente, int soldAt) {
      final path = '${dir.path}/poste_$idVente$soldAt.db';
      final raw = sqlite3.open(path);
      raw.execute('''
        CREATE TABLE sales (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sold_at INTEGER NOT NULL,
          server_user_id INTEGER, payment INTEGER NOT NULL,
          location INTEGER NOT NULL DEFAULT 0, customer_name TEXT,
          room_number TEXT, on_credit INTEGER NOT NULL DEFAULT 0,
          settled_at INTEGER, note TEXT, synced_at INTEGER,
          sync_attempts INTEGER NOT NULL DEFAULT 0, sync_error TEXT);
        CREATE TABLE sale_lines (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
          article_id INTEGER, article_name TEXT NOT NULL,
          qty INTEGER NOT NULL, unit_price_cents INTEGER NOT NULL);
      ''');
      raw.execute('INSERT INTO sales (id, sold_at, payment) VALUES (?, ?, 0)',
          [idVente, soldAt]);
      raw.execute(
          "INSERT INTO sale_lines (id, sale_id, article_name, qty, unit_price_cents) "
          "VALUES (900, ?, 'Simba', 2, 5000)",
          [idVente]);
      raw.execute('PRAGMA user_version = 25');
      raw.dispose();
      return path;
    }

    test('les ventes existantes reçoivent l\'uid que le serveur calcule',
        () async {
      final db = AppDatabase.forTesting(
          NativeDatabase(File(baseV25(345, 1790572508))));
      final v = await db.select(db.sales).getSingle();
      final l = await db.select(db.saleLines).getSingle();
      expect(v.uid, '1ebb8708-75ac-8640-d5ab-ac09a9abc4c9');
      expect(l.uid, '14bd3675-b7f0-0901-6b9b-ee099ed05bc8');
      await db.close();
    });

    test('deux postes, même n° 345 : deux identités distinctes', () async {
      final caisse = AppDatabase.forTesting(
          NativeDatabase(File(baseV25(345, 1790572508))));
      final reception = AppDatabase.forTesting(
          NativeDatabase(File(baseV25(345, 1790590000))));
      final a = await caisse.select(caisse.sales).getSingle();
      final b = await reception.select(reception.sales).getSingle();
      expect(a.id, b.id, reason: 'même numéro de ticket');
      expect(a.uid, isNot(b.uid), reason: 'mais pas la même vente');
      await caisse.close();
      await reception.close();
    });

    test('une vente neuve reçoit un uid neuf, unique', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final id = await db.into(db.sales).insert(SalesCompanion.insert(
          soldAt: DateTime.now(), payment: DbPayment.cash));
      await db.into(db.saleLines).insert(SaleLinesCompanion.insert(
          saleId: id, articleName: 'Fanta', qty: 1, unitPriceCents: 3000));
      final v = await db.select(db.sales).getSingle();
      final l = await db.select(db.saleLines).getSingle();
      expect(v.uid, isNotNull);
      expect(l.uid, isNotNull);
      expect(v.uid, isNot(l.uid));

      // L'unicité est imposée par la base, pas seulement espérée.
      await expectLater(
        db.into(db.sales).insert(SalesCompanion.insert(
            soldAt: DateTime.now(),
            payment: DbPayment.cash,
            uid: Value(v.uid))),
        throwsA(isA<SqliteException>()),
      );
      await db.close();
    });
  });
}
