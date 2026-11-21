import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/ventes_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Le 21 novembre 2026, la caisse avait 46 ventes bloquées : après six
// échecs, une vente n'était plus jamais retentée, et quarante ventes
// bloquées occupaient tout le lot.

void main() {
  test('une vente qui échoue est retentée toutes les 10 minutes, '
      'et part dès que le serveur l\'accepte', () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final a = (await db.select(db.articles).get()).first;
    final id = await SalesRepo(db).createSale(
        articleQuantities: {a.id: 1},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null);

    var refus = true;
    final file = VentesOutbox(db, envoyer: (saleId) async {
      if (refus) throw Exception('refus du serveur');
    });
    var t = DateTime.now();
    for (var i = 0; i < 10; i++) {
      t = t.add(const Duration(minutes: 11));
      await file.vider(maintenant: t);
    }
    final v = await SalesRepo(db).venteParId(id);
    expect(v!.sale.syncAttempts, 10);
    expect(v.sale.syncedAt, isNull);

    refus = false;
    await file.vider(maintenant: t.add(const Duration(minutes: 11)));
    expect((await SalesRepo(db).venteParId(id))!.sale.syncedAt, isNotNull,
        reason: 'avant : plus jamais retentée après 6 échecs');
    await db.close();
  });

  test('quarante ventes bloquées ne retiennent plus les nouvelles', () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final a = (await db.select(db.articles).get()).first;
    final bloquees = <int>{};
    for (var i = 0; i < 40; i++) {
      bloquees.add(await SalesRepo(db).createSale(
          articleQuantities: {a.id: 1},
          payment: DbPayment.cash,
          location: DbLocation.restaurant,
          serverUserId: null));
    }
    final envoyees = <int>[];
    final file = VentesOutbox(db, envoyer: (saleId) async {
      if (bloquees.contains(saleId)) throw Exception('refus');
      envoyees.add(saleId);
    });
    final t = DateTime.now();
    for (var i = 0; i < 6; i++) {
      await file.vider(maintenant: t);
    }
    final nouvelle = await SalesRepo(db).createSale(
        articleQuantities: {a.id: 1},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null);
    await file.vider(maintenant: t);
    expect(envoyees, [nouvelle]);
    await db.close();
  });
}
