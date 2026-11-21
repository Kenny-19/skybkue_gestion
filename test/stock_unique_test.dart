import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:blue_sky/services/stock_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Un seul stock, celui du serveur. Le 21 novembre 2026, la caisse avait
// 41 mouvements bloqués et gardait donc son propre stock : un article
// avec UN mouvement en attente n'adoptait plus jamais la quantité du
// serveur, et un mouvement échoué six fois n'était plus jamais retenté.

Map<String, dynamic> _serveur(Article a, int qte) => {
      'uid': a.uid,
      'name': a.name,
      'price_cents': a.priceCents,
      'category': a.category.index,
      'active': true,
      'track_stock': true,
      'unit': a.unit,
      'threshold': a.threshold,
      'stock_qty': qte,
    };

void main() {
  late AppDatabase db;
  late Article coca;
  setUp(() async {
    db = newTestDb();
    await semerCatalogueDeTest(db);
    coca = (await db.select(db.articles).get())
        .firstWhere((a) => a.name.startsWith('Coca'));
  });
  tearDown(() => db.close());

  Future<int> stockLocal() async =>
      (await (db.select(db.articles)..where((a) => a.id.equals(coca.id)))
              .getSingle())
          .stockQty;

  test('le stock affiché est celui du serveur, plus ce que ce poste n\'a pas '
      'encore envoyé', () async {
    // Deux ventes faites ici pendant une coupure : −3, pas encore parties.
    await StockService(db).declarer(articleId: coca.id, delta: -3);
    // Le serveur, lui, a reçu entre-temps les ventes des autres postes.
    await MirrorService.appliquerArticlesDuServeur(db, [_serveur(coca, 40)]);
    expect(await stockLocal(), 37,
        reason: 'avant : 15, le stock local d\'origine, gardé tel quel');
  });

  test('une fois le mouvement parti, c\'est le chiffre du serveur', () async {
    final svc = StockService(db, envoyer: (m, uid) async {});
    await StockService(db).declarer(articleId: coca.id, delta: -3);
    await svc.viderLaFile();
    await MirrorService.appliquerArticlesDuServeur(db, [_serveur(coca, 40)]);
    expect(await stockLocal(), 40);
  });

  test('un mouvement qui échoue n\'est jamais abandonné', () async {
    var panne = true;
    final envoyes = <String>[];
    final svc = StockService(db, envoyer: (m, uid) async {
      if (panne) throw Exception('refus du serveur');
      envoyes.add(m.opId);
    });
    await StockService(db).declarer(articleId: coca.id, delta: -1);
    var t = DateTime.now();
    for (var i = 0; i < 12; i++) {
      t = t.add(const Duration(minutes: 11));
      await svc.viderLaFile(maintenant: t);
    }
    final m = await db.select(db.stockMoves).getSingle();
    expect(m.sentAt, isNull);
    expect(m.attempts, 12, reason: 'retenté toutes les 10 minutes');
    expect(m.lastError, contains('refus du serveur'));

    panne = false;
    await svc.viderLaFile(maintenant: t.add(const Duration(minutes: 11)));
    expect(envoyes, hasLength(1),
        reason: 'avant : plus jamais retenté après 6 échecs');
  });

  test('article inconnu du serveur : sa fiche part, puis le mouvement',
      () async {
    final fiches = <int>[];
    var connu = false;
    final svc = StockService(db,
        envoyer: (m, uid) async {
          if (!connu) throw Exception('ARTICLE_INCONNU');
        },
        pousserArticle: (id) async {
          fiches.add(id);
          connu = true;
        });
    await StockService(db).declarer(articleId: coca.id, delta: 6);
    await svc.viderLaFile();
    expect(fiches, [coca.id]);
    expect((await db.select(db.stockMoves).getSingle()).sentAt, isNotNull);
  });

  test('un mouvement bloqué ne retarde plus les suivants', () async {
    final envoyes = <int>[];
    final svc = StockService(db, envoyer: (m, uid) async {
      if (m.delta == -99) throw Exception('refus');
      envoyes.add(m.delta);
    });
    await StockService(db).declarer(articleId: coca.id, delta: -99);
    final t = DateTime.now();
    for (var i = 0; i < 6; i++) {
      await svc.viderLaFile(maintenant: t);
    }
    await StockService(db).declarer(articleId: coca.id, delta: -2);
    await svc.viderLaFile(maintenant: t);
    expect(envoyes, [-2]);
  });

  test('supprimer une vente remet le stock par un mouvement', () async {
    final ventes = SalesRepo(db);
    final id = await ventes.createSale(
      articleQuantities: {coca.id: 4},
      payment: DbPayment.cash,
      location: DbLocation.restaurant,
      serverUserId: null,
    );
    expect(await stockLocal(), coca.stockQty - 4);
    await ventes.deleteSale(id);
    expect(await stockLocal(), coca.stockQty);
    final retour = await (db.select(db.stockMoves)
          ..where((m) => m.reason.equals('vente supprimée')))
        .getSingle();
    expect(retour.delta, 4,
        reason: 'avant : remis en dur sur ce poste, jamais au serveur');
  });
}
