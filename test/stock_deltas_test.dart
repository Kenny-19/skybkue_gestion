import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:blue_sky/services/stock_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Le stock en deltas, et le piège qui l'a fait échouer en production.
//
// Le 21 septembre, un diagnostic a retiré 1 au stock via la RPC serveur.
// L'application, qui tournait, a repoussé l'ancienne quantité ABSOLUE
// dans les quinze secondes — et le mouvement a été effacé. Le stock
// avait gagné une unité au lieu d'en perdre une.
//
// La cause : la fiche produit transportait encore `stock_qty`. Le
// premier test ci-dessous rend ce retour impossible.

void main() {
  group('La fiche produit ne transporte jamais la quantité', () {
    test('stock_qty est absent du payload envoyé au miroir', () {
      // Depuis les deltas, la quantité est calculée par le serveur seul.
      // L'envoyer d'ici l'écraserait — c'est exactement ce qui s'est
      // produit en production.
      expect(MirrorService.champsFicheArticle, isNot(contains('stock_qty')),
          reason: 'la quantité appartient au serveur, pas au poste');
      // Le reste de la fiche doit bien voyager.
      expect(MirrorService.champsFicheArticle,
          containsAll(['name', 'price_cents', 'threshold', 'track_stock']));
    });
  });

  group('Un mouvement déclaré est conservé jusqu\'à confirmation', () {
    late AppDatabase db;
    setUp(() => db = newTestDb());
    tearDown(() => db.close());

    test('une sortie inscrit un delta négatif et bouge le stock local',
        () async {
      final art =
          (await db.select(db.articles).get()).firstWhere((a) => a.trackStock);
      final avant = art.stockQty;

      await StockService(db)
          .declarer(articleId: art.id, delta: -3, reason: 'vente');

      final apres = await (db.select(db.articles)
            ..where((a) => a.id.equals(art.id)))
          .getSingle();
      expect(apres.stockQty, avant - 3,
          reason: 'les bouteilles sortent du frigo tout de suite');

      final mvt = await (db.select(db.stockMoves)
            ..where((m) => m.articleId.equals(art.id)))
          .getSingle();
      expect(mvt.delta, -3);
      expect(mvt.sentAt, isNull, reason: 'pas encore confirmé par le serveur');
      expect(mvt.opId, isNotEmpty,
          reason: "l'op_id est généré AVANT l'envoi, c'est lui qui rend "
              'le renvoi sans effet');
    });

    test('deux mouvements ont des identifiants différents', () async {
      // Sinon le serveur prendrait le second pour un doublon du premier
      // et la deuxième vente serait perdue.
      final art =
          (await db.select(db.articles).get()).firstWhere((a) => a.trackStock);
      final svc = StockService(db);
      await svc.declarer(articleId: art.id, delta: -1, reason: 'vente');
      await svc.declarer(articleId: art.id, delta: -1, reason: 'vente');
      final mvts = await (db.select(db.stockMoves)
            ..where((m) => m.articleId.equals(art.id)))
          .get();
      expect(mvts.length, 2);
      expect(mvts[0].opId, isNot(mvts[1].opId));
    });

    test('un delta nul ne crée aucun mouvement', () async {
      final art = (await db.select(db.articles).get()).first;
      await StockService(db).declarer(articleId: art.id, delta: 0);
      expect(await db.select(db.stockMoves).get(), isEmpty);
    });

    test('le compteur en attente reflète la file', () async {
      final art =
          (await db.select(db.articles).get()).firstWhere((a) => a.trackStock);
      final svc = StockService(db);
      expect(await svc.enAttente(), 0);
      await svc.declarer(articleId: art.id, delta: -2, reason: 'vente');
      expect(await svc.enAttente(), 1);
    });

    test('les deltas s\'additionnent, quel que soit l\'ordre', () async {
      // C'est la propriété qui rend le hors-ligne viable : deux postes
      // peuvent déclarer -3 et -4 dans n'importe quel ordre, le total
      // est le même.
      final art =
          (await db.select(db.articles).get()).firstWhere((a) => a.trackStock);
      final avant = art.stockQty;
      final svc = StockService(db);
      await svc.declarer(articleId: art.id, delta: -3, reason: 'bar');
      await svc.declarer(articleId: art.id, delta: -4, reason: 'terrasse');
      final apres = await (db.select(db.articles)
            ..where((a) => a.id.equals(art.id)))
          .getSingle();
      expect(apres.stockQty, avant - 7);
    });
  });
}
