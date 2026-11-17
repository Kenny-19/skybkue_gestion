import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Le tableau de bord n'écoute plus la table des ventes entière : il doit
// pourtant toujours suivre chaque encaissement.

void main() {
  test('une vente encaissée apparaît dans les 7 derniers jours', () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final a = (await db.select(db.articles).get()).first;
    final flux = MetricsRepo(db).watchLast7Days();
    final recus = <int>[];
    final abo = flux.listen((jours) => recus.add(jours.last.totalCents));

    await pumpEventQueue();
    await SalesRepo(db).createSale(
        articleQuantities: {a.id: 2},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null);
    await pumpEventQueue(times: 50);

    expect(recus.first, 0, reason: 'premier calcul, base vide');
    expect(recus.last, a.priceCents * 2, reason: 'recalculé après la vente');
    await abo.cancel();
    await db.close();
  });
}
