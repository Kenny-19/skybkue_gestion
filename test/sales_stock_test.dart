import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart';
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

    test('le stock ne descend jamais sous zéro', () async {
      final poisson = await byName('Poisson du jour'); // seed: 6
      await sales.createSale(
        articleQuantities: {poisson.id: 100}, // bien plus que le stock
        payment: DbPayment.cash,
        location: DbLocation.terrasse,
        serverUserId: null,
      );
      final after = await byName('Poisson du jour');
      expect(after.stockQty, 0);
    });

    test('un produit non suivi (chambre) ne bouge pas', () async {
      final chambre = await byName('Chambre simple'); // trackStock=false
      expect(chambre.trackStock, false);
      await sales.createSale(
        articleQuantities: {chambre.id: 2},
        payment: DbPayment.card,
        location: DbLocation.hotel,
        serverUserId: null,
      );
      final after = await byName('Chambre simple');
      expect(after.stockQty, chambre.stockQty); // inchangé
    });
  });

  group('Intégrité de la vente', () {
    test('total et lignes correctement enregistrés', () async {
      final coca = await byName('Coca Cola 33cl'); // 200 cents
      final cafe = await byName('Café'); // 150 cents
      final id = await sales.createSale(
        articleQuantities: {coca.id: 2, cafe.id: 1},
        payment: DbPayment.mobileMoney,
        location: DbLocation.restaurant,
        serverUserId: null,
        customerName: 'M. Test',
      );
      final recent = await sales.watchRecent(days: 1).first;
      final sale = recent.firstWhere((s) => s.sale.id == id);
      expect(sale.totalCents, 200 * 2 + 150); // 550
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

    test('adjustQty ne descend pas sous zéro', () async {
      final coca = await byName('Coca Cola 33cl'); // 18
      await articles.adjustQty(coca.id, -100);
      expect((await byName('Coca Cola 33cl')).stockQty, 0);
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
