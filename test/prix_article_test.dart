import 'package:blue_sky/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

// Whisky Red Label, Amarula et Baileys affichaient « 0 FC » au
// catalogue : ça ressemble à un bug, et ça laisse croire que l'article
// est gratuit.

void main() {
  group('Prix non renseigné', () {
    test('ne s\'affiche jamais comme « 0 FC »', () {
      expect(prixArticle(0), isNot(contains('0 FC')));
      expect(prixArticle(0), 'Prix à définir');
    });

    test('un prix négatif est traité pareil, pas affiché', () {
      // Une saisie aberrante ne doit pas produire « -5 000 FC » en rayon.
      expect(prixArticle(-500000), 'Prix à définir');
    });

    test('un vrai prix reste un montant normal', () {
      expect(prixArticle(1000000), moneyCents(1000000));
      expect(prixArticle(1), moneyCents(1));
    });
  });
}
