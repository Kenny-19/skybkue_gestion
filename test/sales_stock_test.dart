import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/stock_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late ArticlesRepo articles;
  late SalesRepo sales;

  setUp(() async {
    db = newTestDb();
    articles = ArticlesRepo(db);
    sales = SalesRepo(db);
    // Force l'exécution du onCreate (seed) avant les tests.
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  Future<Article> byName(String name) async =>
      (db.select(db.articles)..where((a) => a.name.equals(name))).getSingle();

  group('Décrément du stock à la vente', () {
    test('une vente diminue le stock du produit suivi', () async {
      final coca = await byName('Coca Cola 33cl'); // seed: 18
      await sales.createSale(
        articleQuantities: {coca.id: 3},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null,
      );
      final after = await byName('Coca Cola 33cl');
      expect(after.stockQty, 15);
    });

    test('un stock insuffisant descend en négatif, et on le montre', () async {
      // Règle changée avec le passage aux deltas, volontairement.
      //
      // Borner à zéro effaçait l'information la plus utile : si on a
      // vendu 100 poissons alors que la base en annonçait 6, ces ventes
      // ont EU LIEU — le client a payé et il est parti. Le négatif dit
      // que le stock initial était faux, ou qu'il y a eu de la casse ou
      // du vol. Le cacher derrière un zéro rassurant ne fait perdre que
      // l'écart à justifier.
      final poisson = await byName('Poisson du jour'); // seed: 6
      await sales.createSale(
        articleQuantities: {poisson.id: 100},
        payment: DbPayment.cash,
        location: DbLocation.terrasse,
        serverUserId: null,
      );
      final after = await byName('Poisson du jour');
      expect(after.stockQty, 6 - 100);
    });

    test("chaque sortie laisse un mouvement en attente d'envoi", () async {
      // C'est ce qui rend le hors-ligne viable : la vente s'enregistre
      // ici, et le mouvement partira dès que le réseau revient.
      final biere = await byName('Bière locale 50cl');
      final avant = await StockService(db).enAttente();
      await sales.createSale(
        articleQuantities: {biere.id: 2},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null,
      );
      expect(await StockService(db).enAttente(), avant + 1);

      final mvt = await (db.select(db.stockMoves)
            ..where((m) => m.articleId.equals(biere.id))
            ..orderBy([(m) => OrderingTerm.desc(m.occurredAt)]))
          .get();
      expect(mvt.first.delta, -2, reason: 'une sortie est un delta négatif');
      expect(mvt.first.reason, 'vente');
      expect(mvt.first.sentAt, isNull, reason: 'pas encore confirmé');
    });

    test('un produit non suivi ne bouge pas', () async {
      // Le seed ne contient plus de produit non suivi (les chambres ont
      // leur propre table) : on en crée un pour l'occasion.
      await articles.create(
        name: 'Service non suivi',
        priceCents: 5000,
        category: DbCategory.nourriture,
        stockQty: 7,
      );
      final item = await byName('Service non suivi');
      expect(item.trackStock, false);
      await sales.createSale(
        articleQuantities: {item.id: 2},
        payment: DbPayment.card,
        location: DbLocation.hotel,
        serverUserId: null,
      );
      final after = await byName('Service non suivi');
      expect(after.stockQty, item.stockQty); // inchangé
    });
  });

  group('Intégrité de la vente', () {
    test('total et lignes correctement enregistrés', () async {
      final coca = await byName('Coca Cola 33cl');
      final cafe = await byName('Café');
      // Total calculé à partir des vrais prix (robuste au seed).
      final expected = coca.priceCents * 2 + cafe.priceCents;
      final id = await sales.createSale(
        articleQuantities: {coca.id: 2, cafe.id: 1},
        payment: DbPayment.mobileMoney,
        location: DbLocation.restaurant,
        serverUserId: null,
        customerName: 'M. Test',
      );
      final recent = await sales.watchRecent(days: 1).first;
      final sale = recent.firstWhere((s) => s.sale.id == id);
      expect(sale.totalCents, expected);
      expect(sale.itemsCount, 3);
      expect(sale.sale.customerName, 'M. Test');
      expect(sale.lines.length, 2);
    });

    test('le nom de l\'article est figé (snapshot) même si renommé après',
        () async {
      final coca = await byName('Coca Cola 33cl');
      final id = await sales.createSale(
        articleQuantities: {coca.id: 1},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null,
      );
      // On renomme l'article après la vente.
      await articles.update(
        id: coca.id,
        name: 'Coca RENOMMÉ',
        priceCents: coca.priceCents,
        category: coca.category,
        trackStock: coca.trackStock,
        unit: coca.unit,
        stockQty: coca.stockQty,
        threshold: coca.threshold,
      );
      final recent = await sales.watchRecent(days: 1).first;
      final sale = recent.firstWhere((s) => s.sale.id == id);
      // La ligne garde l'ancien nom (snapshot).
      expect(sale.lines.first.articleName, 'Coca Cola 33cl');
    });
  });

  group('Ravitaillement & ajustement', () {
    test('adjustQty ajoute au stock', () async {
      final coca = await byName('Coca Cola 33cl'); // 18
      await articles.adjustQty(coca.id, 24);
      expect((await byName('Coca Cola 33cl')).stockQty, 42);
    });

    test("adjustQty peut descendre en négatif : l'écart est une information",
        () async {
      // Borner à zéro effaçait l'écart. Si la base annonce 18 et qu'on
      // en retire 100, c'est que l'inventaire était faux : le montrer
      // vaut mieux que le masquer derrière un zéro rassurant.
      final coca = await byName('Coca Cola 33cl'); // 18
      await articles.adjustQty(coca.id, -100);
      expect((await byName('Coca Cola 33cl')).stockQty, 18 - 100);
    });
  });

  group('Création / désactivation de produit', () {
    test('un nouveau produit apparaît dans la liste active', () async {
      await articles.create(
        name: 'Thé vert',
        priceCents: 180,
        category: DbCategory.boissons,
        trackStock: true,
        unit: 'tasse',
        stockQty: 50,
        threshold: 10,
      );
      final list = await articles.allActive();
      expect(list.any((a) => a.name == 'Thé vert'), true);
    });

    test('un produit désactivé disparaît de la liste active', () async {
      final coca = await byName('Coca Cola 33cl');
      await articles.deactivate(coca.id);
      final list = await articles.allActive();
      expect(list.any((a) => a.id == coca.id), false);
    });
  });
}
