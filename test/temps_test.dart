import 'package:blue_sky/core/temps.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ces tests ne supposent RIEN du fuseau de la machine qui les exécute.
/// C'est le point : le poste de développement est sur UTC−5, ceux du
/// terrain sur UTC+2, et la journée commerciale doit être la même.
void main() {
  group('isoServeur', () {
    test('produit toujours un instant UTC explicite', () {
      // 6h45 à Lubumbashi = 4h45 UTC.
      final vente = DateTime.utc(2026, 9, 21, 4, 45).toLocal();
      expect(isoServeur(vente), '2026-09-21T04:45:00.000Z');
    });

    test('le suffixe Z est présent — sans lui Postgres se trompe de 2h', () {
      expect(isoServeur(DateTime.now()), endsWith('Z'));
    });

    test('ne perd pas le null', () {
      expect(isoServeurOuNull(null), isNull);
      expect(isoServeurOuNull(DateTime.utc(2026, 1, 1)),
          '2026-01-01T00:00:00.000Z');
    });
  });

  group('journée commerciale de Lubumbashi', () {
    /// Minuit à Lubumbashi, c'est 22h UTC la veille.
    void attendMinuitLubumbashi(DateTime borne, int an, int mois, int jour) {
      final u = borne.toUtc();
      expect(u.add(decalageLubumbashi), DateTime.utc(an, mois, jour),
          reason: 'borne = $u');
    }

    test('une vente de 6h45 appartient au jour même', () {
      attendMinuitLubumbashi(
          debutDeJourneeLubumbashi(DateTime.utc(2026, 9, 21, 4, 45)),
          2026,
          9,
          21);
    });

    test('une vente de 23h30 appartient ENCORE au jour même', () {
      // 23h30 à Lubumbashi = 21h30 UTC. C'est exactement le cas qui
      // basculait sur le lendemain et faussait les montants.
      attendMinuitLubumbashi(
          debutDeJourneeLubumbashi(DateTime.utc(2026, 9, 21, 21, 30)),
          2026,
          9,
          21);
    });

    test('une vente de 00h30 appartient au jour suivant', () {
      // 00h30 le 22 à Lubumbashi = 22h30 UTC le 21.
      attendMinuitLubumbashi(
          debutDeJourneeLubumbashi(DateTime.utc(2026, 9, 21, 22, 30)),
          2026,
          9,
          22);
    });

    test('la journée dure exactement 24 heures', () {
      final j = journeeLubumbashi(DateTime.utc(2026, 9, 21, 12));
      expect(j.fin.difference(j.debut), const Duration(days: 1));
    });

    test('la fin est exclusive : 23:59:59.999 reste dans la journée', () {
      final j = journeeLubumbashi(DateTime.utc(2026, 9, 21, 12));
      final presqueMinuit = j.fin.subtract(const Duration(milliseconds: 1));
      expect(debutDeJourneeLubumbashi(presqueMinuit), j.debut);
    });

    test('appliquer la règle deux fois ne déplace pas la borne', () {
      // Propriété indispensable : le code compare des bornes déjà
      // tronquées avec des bornes fraîchement calculées.
      final d = debutDeJourneeLubumbashi(DateTime.utc(2026, 9, 21, 15));
      expect(debutDeJourneeLubumbashi(d), d);
    });
  });
}
