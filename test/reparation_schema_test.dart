import 'dart:io';

import 'package:blue_sky/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Le 5 octobre 2026, la base du poste « Robin » se disait en version 25
// sans porter la colonne `rooms.price_usd_cents` que la v25 ajoute. Les
// migrations n'avaient rien à faire, la conversion en dollars plantait à
// chaque ouverture, et le poste a remonté 87 erreurs en trente minutes.
//
// Ce test fabrique exactement cette base et vérifie qu'elle s'ouvre.

void main() {
  test(
      'une base « v25 » à laquelle il manque des colonnes se répare et '
      's\'ouvre', () async {
    final dir = Directory.systemTemp.createTempSync('bs_reparation');
    final path = '${dir.path}/robin.db';
    final raw = sqlite3.open(path);
    raw.execute('''
      CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE rooms (
        number TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,
        price_per_night_cents INTEGER NOT NULL, status INTEGER NOT NULL,
        current_guest TEXT, checkout_date INTEGER, checkin_note TEXT,
        checkin_at INTEGER, stay_group TEXT, payer_id INTEGER,
        image_path TEXT, negotiated_price_cents INTEGER
      );
    ''');
    raw.execute("INSERT INTO settings VALUES ('fc_per_usd_rate', '2500')");
    raw.execute(
        "INSERT INTO rooms (number, type, price_per_night_cents, status) "
        "VALUES ('101', 'standard', 125000, 0)");
    // Le piège : la base prétend être à jour.
    raw.execute('PRAGMA user_version = 25');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    // Avant la réparation, cette ouverture levait « no such column:
    // price_usd_cents ».
    final chambres = await db.select(db.rooms).get();

    expect(chambres, hasLength(1));
    // La colonne a été ajoutée, PUIS la conversion a tourné : 125 000 FC
    // à 2 500 FC le dollar font 50 $.
    expect(chambres.single.priceUsdCents, 5000);
    // Les tables absentes ont été créées : la base est utilisable.
    expect(await db.select(db.sales).get(), isEmpty);

    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('la sauvegarde contient ce qui dort encore dans le journal WAL',
      () async {
    // L'ancienne sauvegarde lisait le seul fichier principal. En mode
    // WAL, les dernières écritures n'y sont pas encore : elles manquaient
    // à la sauvegarde.
    final dir = Directory.systemTemp.createTempSync('bs_instantane');
    final db =
        AppDatabase.forTesting(NativeDatabase(File('${dir.path}/caisse.db')));
    await db.customStatement('PRAGMA journal_mode = WAL');
    // Pas de recopie automatique du journal pendant le test.
    await db.customStatement('PRAGMA wal_autocheckpoint = 0');
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'temoin', value: 'dans le journal'));

    final copie = await db.instantane();
    final lue = sqlite3.open(copie.path, mode: OpenMode.readOnly);
    final r = lue.select("SELECT value FROM settings WHERE key = 'temoin'");
    expect(r.single['value'], 'dans le journal');
    lue.dispose();

    await db.close();
    copie.parent.deleteSync(recursive: true);
    dir.deleteSync(recursive: true);
  });
}
