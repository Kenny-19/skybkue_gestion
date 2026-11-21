import 'package:blue_sky/core/session_serveur.dart';
import 'package:blue_sky/services/stock_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Le serveur vérifie lui-même qui gère le stock : chaque opération
// sensible présente la session de la personne connectée.

void main() {
  tearDown(SessionServeur.quitter);

  test('la session survit à une reconnexion hors ligne du même compte',
      () async {
    final db = newTestDb();
    await SessionServeur.ouvrir(db, 'Benita', 'jeton-benita');
    SessionServeur.quitter();
    expect(SessionServeur.jeton, isNull);

    await SessionServeur.reprendre(db, 'benita');
    expect(SessionServeur.jeton, 'jeton-benita',
        reason: 'même compte, casse différente');

    await SessionServeur.reprendre(db, 'robin');
    expect(SessionServeur.jeton, isNull,
        reason: "jamais la session d'une autre personne");
    await db.close();
  });

  test('session refusée par le serveur : oubliée, et message clair',
      () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final a = (await db.select(db.articles).get()).first;
    await SessionServeur.ouvrir(db, 'gerant1', 'perimee');

    final svc = StockService(db,
        envoyer: (m, uid) async =>
            throw Exception('PostgrestException(message: SESSION_INVALIDE)'));
    await expectLater(
        svc.ajusterEnLigne(articleId: a.id, delta: 5, reason: 'ravitaillement'),
        throwsA(isA<StockRefus>().having(
            (e) => e.message, 'message', contains('reconnecte-toi'))));
    expect(SessionServeur.jeton, isNull);
    SessionServeur.quitter();
    await SessionServeur.reprendre(db, 'gerant1');
    expect(SessionServeur.jeton, isNull, reason: 'oubliée aussi en base');
    expect((await db.select(db.stockMoves).get()), isEmpty);
    await db.close();
  });

  test('droits insuffisants : refus, rien ne change', () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final a = (await db.select(db.articles).get()).first;
    final svc = StockService(db,
        envoyer: (m, uid) async => throw Exception('DROITS_INSUFFISANTS'));
    await expectLater(
        svc.ajusterEnLigne(articleId: a.id, delta: 5, reason: 'x'),
        throwsA(isA<StockRefus>()
            .having((e) => e.message, 'message', contains('gérants'))));
    final apres = (await db.select(db.articles).get()).first;
    expect(apres.stockQty, a.stockQty);
    await db.close();
  });
}
