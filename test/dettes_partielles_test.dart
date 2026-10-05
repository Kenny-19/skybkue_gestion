import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Les règlements partiels d'une dette.
//
// La règle qui compte : une dette n'est soldée QUE lorsque plus rien
// n'est dû. Un acompte ne doit jamais faire disparaître le reste des
// écrans — c'est de l'argent qu'on n'a pas encore.

void main() {
  late AppDatabase db;
  late SalesRepo repo;

  setUp(() async {
    db = newTestDb();
    repo = SalesRepo(db);
  });
  tearDown(() => db.close());

  /// Une vente à crédit de [totalCents], en une ligne.
  Future<int> venteACredit(int totalCents) async {
    final articleId = await db.into(db.articles).insert(
        ArticlesCompanion.insert(
            name: 'Primus',
            priceCents: totalCents,
            category: DbCategory.boissons));
    final saleId = await db.into(db.sales).insert(SalesCompanion.insert(
          soldAt: DateTime.now(),
          payment: DbPayment.values.first,
          onCredit: const Value(true),
          customerName: const Value('Mme Angeline'),
        ));
    await db.into(db.saleLines).insert(SaleLinesCompanion.insert(
          saleId: saleId,
          articleId: Value(articleId),
          articleName: 'Primus',
          qty: 1,
          unitPriceCents: totalCents,
        ));
    return saleId;
  }

  group('Un acompte ne solde pas la dette', () {
    test('après un versement partiel, le reste est exact', () async {
      final id = await venteACredit(50000);
      await repo.encaisserSurDette(
          saleId: id, montantCents: 20000, payment: DbPayment.values.first);

      expect(await repo.dejaPaye(id), 20000);
      expect(await repo.resteADevoir(id), 30000);
    });

    test('la vente reste NON soldée : cet argent manque encore', () async {
      final id = await venteACredit(50000);
      await repo.encaisserSurDette(
          saleId: id, montantCents: 20000, payment: DbPayment.values.first);

      final v = await (db.select(db.sales)..where((s) => s.id.equals(id)))
          .getSingle();
      expect(v.settledAt, isNull,
          reason: 'un acompte ne fait pas disparaître une dette');
      expect(v.onCredit, isTrue);
    });

    test('elle apparaît toujours dans les dettes en cours', () async {
      final id = await venteACredit(50000);
      await repo.encaisserSurDette(
          saleId: id, montantCents: 20000, payment: DbPayment.values.first);
      final dettes = await repo.watchOutstandingDebts().first;
      expect(dettes.map((d) => d.sale.id), contains(id));
    });
  });

  group('Plusieurs versements se cumulent', () {
    test('trois acomptes qui couvrent le total soldent la dette', () async {
      final id = await venteACredit(50000);
      for (final m in [20000, 20000, 10000]) {
        await repo.encaisserSurDette(
            saleId: id, montantCents: m, payment: DbPayment.values.first);
      }
      expect(await repo.dejaPaye(id), 50000);
      expect(await repo.resteADevoir(id), 0);

      final v = await (db.select(db.sales)..where((s) => s.id.equals(id)))
          .getSingle();
      expect(v.settledAt, isNotNull);
    });

    test('chaque versement laisse sa trace, avec qui a encaissé', () async {
      final id = await venteACredit(50000);
      await repo.encaisserSurDette(
          saleId: id,
          montantCents: 20000,
          payment: DbPayment.values.first,
          parLogin: 'RBK');
      await repo.encaisserSurDette(
          saleId: id,
          montantCents: 30000,
          payment: DbPayment.values.first,
          parLogin: 'est');

      final vs = await repo.versements(id);
      expect(vs.length, 2, reason: 'un cumul écrasé perdrait cette histoire');
      expect(vs.map((v) => v.receivedByLogin), ['RBK', 'est']);
      expect(vs.map((v) => v.amountCents), [20000, 30000]);
    });
  });

  group('Garde-fous', () {
    test('on ne peut pas verser un montant négatif', () async {
      final id = await venteACredit(50000);
      expect(
          () => repo.encaisserSurDette(
              saleId: id, montantCents: -1000, payment: DbPayment.values.first),
          throwsArgumentError);
    });

    test('le reste à devoir ne descend jamais sous zéro', () async {
      final id = await venteACredit(50000);
      await repo.encaisserSurDette(
          saleId: id, montantCents: 50000, payment: DbPayment.values.first);
      await repo.encaisserSurDette(
          saleId: id, montantCents: 10000, payment: DbPayment.values.first);
      expect(await repo.resteADevoir(id), 0,
          reason: 'un trop-perçu est une anomalie, pas une dette inversée');
    });

    test('settleDebt solde tout, quel que soit le déjà-reçu', () async {
      final id = await venteACredit(50000);
      await repo.encaisserSurDette(
          saleId: id, montantCents: 15000, payment: DbPayment.values.first);
      await repo.settleDebt(id, DbPayment.values.first);

      expect(await repo.resteADevoir(id), 0);
      // Le solde a bien été enregistré comme un versement, pas comme un
      // trait de plume sur la vente.
      expect((await repo.versements(id)).map((v) => v.amountCents),
          [15000, 35000]);
    });
  });
}
