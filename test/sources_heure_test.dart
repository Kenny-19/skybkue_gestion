import 'package:blue_sky/services/sources_heure.dart';
import 'package:flutter_test/flutter_test.dart';

// Les sources d'heure en ligne.
//
// Le risque n'est pas qu'une source tombe — c'est qu'elle réponde avec
// une heure fausse. Sondage du 21 septembre 2026 : `worldtimeapi.org`
// ne répondait pas, et `timeapi.io` rendait une heure avancée de quatre
// heures en ayant l'air parfaite. Ces tests fixent ce qui protège de ça.

void main() {
  group('Le choix des sources', () {
    test('une seule source fait autorité', () {
      final autorites = sourcesHeure().where((s) => s.autorite);
      expect(autorites.length, lessThanOrEqualTo(1),
          reason: 'deux autorités qui divergent, et plus personne ne '
              'tranche');
    });

    test('il existe au moins une source indépendante', () {
      final temoins = sourcesHeure().where((s) => !s.autorite);
      expect(temoins, isNotEmpty,
          reason: 'sans témoin, une horloge serveur qui dérive ne se voit '
              'jamais');
    });

    test('toutes les sources sont en HTTPS', () {
      for (final s in sourcesHeure()) {
        expect(s.uri.scheme, 'https',
            reason: "l'heure en clair se laisse réécrire en chemin");
      }
    });

    test('les sources écartées au sondage ne sont pas revenues', () {
      final hotes = sourcesHeure().map((s) => s.uri.host).join(' ');
      expect(hotes, isNot(contains('worldtimeapi')),
          reason: 'ne répondait pas depuis le poste');
      expect(hotes, isNot(contains('timeapi.io')),
          reason: "rendait une heure fausse de 4 h — le pire des cas");
    });
  });

  group('La correction du trajet', () {
    test("la moitié de l'aller-retour est ajoutée", () {
      final t = DateTime.utc(2026, 9, 21, 14, 0, 0);
      final m = MesureHeure(
        source: sourcesHeure().last,
        heure: t,
        trajet: const Duration(seconds: 4),
        horlogePoste: t,
      );
      // L'heure a été écrite quelque part au milieu du trajet : sans
      // cette correction, une liaison lente se lirait comme une horloge
      // en retard.
      expect(m.instantCorrige, t.add(const Duration(seconds: 2)));
    });

    test('un trajet instantané ne déplace rien', () {
      final t = DateTime.utc(2026, 9, 21, 14, 0, 0);
      final m = MesureHeure(
          source: sourcesHeure().last,
          heure: t,
          trajet: Duration.zero,
          horlogePoste: t);
      expect(m.instantCorrige, t);
    });

    test("l'instant corrigé est toujours en UTC", () {
      final m = MesureHeure(
        source: sourcesHeure().last,
        heure: DateTime.utc(2026, 9, 21, 14).toLocal(),
        trajet: Duration.zero,
        horlogePoste: DateTime.utc(2026, 9, 21, 14),
      );
      expect(m.instantCorrige.isUtc, isTrue,
          reason: 'un instant qui voyage ne doit jamais porter de fuseau '
              'local');
    });
  });

  group('Comparer deux sources', () {
    /// Une mesure dont on choisit le décalage par rapport au poste.
    MesureHeure mesure(DateTime quand, Duration decalageDuPoste) => MesureHeure(
          source: sourcesHeure().last,
          heure: quand.subtract(decalageDuPoste),
          trajet: Duration.zero,
          horlogePoste: quand,
        );

    test("deux sources interrogées à 5 s d'intervalle restent d'accord", () {
      // Le piège : comparer leurs INSTANTS ferait passer ces cinq
      // secondes d'écart pour un désaccord d'horloge. C'était le cas
      // avant le 21 septembre 2026.
      final t = DateTime.utc(2026, 9, 21, 14);
      final a = mesure(t, const Duration(hours: 2));
      final b = mesure(t.add(const Duration(seconds: 5)),
          const Duration(hours: 2));

      expect(a.instantCorrige, isNot(b.instantCorrige),
          reason: 'les instants diffèrent bien, forcément');
      expect((a.decalagePoste - b.decalagePoste).abs(), Duration.zero,
          reason: 'mais les décalages, eux, sont identiques');
    });

    test('un vrai désaccord se voit malgré le temps écoulé', () {
      final t = DateTime.utc(2026, 9, 21, 14);
      final a = mesure(t, const Duration(hours: 2));
      final b = mesure(t.add(const Duration(seconds: 5)),
          const Duration(hours: 6)); // 4 h de plus : le cas timeapi.io

      expect((a.decalagePoste - b.decalagePoste).abs(),
          const Duration(hours: 4));
    });
  });
}
