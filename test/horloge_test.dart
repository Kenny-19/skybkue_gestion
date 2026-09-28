import 'package:blue_sky/core/horloge.dart';
import 'package:blue_sky/core/temps.dart';
import 'package:flutter_test/flutter_test.dart';

// L'heure de référence, et pourquoi elle ne peut pas venir du poste.
//
// L'horloge de Lubumbashi avançait de deux heures. Personne ne l'a vu
// pendant des semaines : une date fausse reste une date valide, et le
// personnel voyait la bonne heure sur son écran. Ces tests fixent le
// comportement qui rend ce silence impossible.

void main() {
  setUp(Horloge.oublier);
  tearDown(Horloge.oublier);

  group('Sans serveur', () {
    test("on rend l'heure du poste, et on le dit", () {
      expect(Horloge.source, SourceHeure.posteSeul);
      final ecart =
          Horloge.maintenant().difference(DateTime.now()).abs();
      expect(ecart, lessThan(const Duration(seconds: 1)));
    });

    test('un décalage retenu de la session précédente est réutilisé', () {
      // Le poste démarre sans réseau : c'est précisément le matin où on
      // a le plus besoin que la correction tienne.
      Horloge.restaurerDecalage(const Duration(hours: 2));
      expect(Horloge.source, SourceHeure.dernierAccord);
      final corrigee = Horloge.maintenant();
      expect(DateTime.now().difference(corrigee).inMinutes,
          closeTo(120, 1),
          reason: 'le poste avance de 2h, on les retranche');
    });
  });

  group('Ancrée sur le serveur', () {
    test("l'heure rendue est celle du serveur, pas celle du poste", () {
      // Poste réglé deux heures en avance, comme à Lubumbashi.
      final vraieHeure = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      Horloge.ancrer(vraieHeure, const Duration(milliseconds: 40));

      expect(Horloge.source, SourceHeure.serveur);
      final ecart = Horloge.maintenant().toUtc().difference(vraieHeure).abs();
      expect(ecart, lessThan(const Duration(seconds: 2)));
    });

    test("le décalage du poste est mesuré, et c'est lui qui déclenche l'alerte",
        () {
      final vraieHeure = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      Horloge.ancrer(vraieHeure, Duration.zero);
      expect(Horloge.decalage!.inMinutes, closeTo(120, 1));
    });

    test("la moitié de l'aller-retour est compensée", () {
      // L'heure a été écrite quelque part au milieu du trajet. Sans
      // cette correction, une liaison lente se lirait comme une horloge
      // en retard.
      final t = DateTime.now().toUtc();
      Horloge.ancrer(t, const Duration(seconds: 4));
      final avance = Horloge.maintenant().toUtc().difference(t);
      expect(avance.inMilliseconds, greaterThanOrEqualTo(2000),
          reason: 'la moitié de 4 s doit être ajoutée');
    });

    test("l'heure avance toute seule entre deux mesures", () async {
      Horloge.ancrer(DateTime.now().toUtc(), Duration.zero);
      final t1 = Horloge.maintenant();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final t2 = Horloge.maintenant();
      expect(t2.isAfter(t1), isTrue,
          reason: 'sinon toutes les ventes d\'une session auraient la même heure');
    });

    test('une mesure fraîche prime sur un souvenir', () {
      Horloge.ancrer(DateTime.now().toUtc(), Duration.zero);
      Horloge.restaurerDecalage(const Duration(hours: 9));
      expect(Horloge.source, SourceHeure.serveur,
          reason: 'un souvenir ne doit jamais écraser une mesure en cours');
    });
  });

  group('Affichage à Lubumbashi', () {
    test('une vente de 21h30 UTC se lit 23h30 — pas le lendemain', () {
      final affichee = aLubumbashi(DateTime.utc(2026, 9, 21, 21, 30));
      expect(affichee.day, 21);
      expect(affichee.hour, 23);
      expect(affichee.minute, 30);
    });

    test('une vente de 22h30 UTC se lit 00h30 le lendemain', () {
      final affichee = aLubumbashi(DateTime.utc(2026, 9, 21, 22, 30));
      expect(affichee.day, 22);
      expect(affichee.hour, 0);
    });

    test("l'affichage ne dépend pas du fuseau de la machine", () {
      // Même instant, exprimé dans deux fuseaux : même heure affichée.
      final instant = DateTime.utc(2026, 9, 21, 21, 30);
      expect(aLubumbashi(instant.toLocal()), aLubumbashi(instant));
    });

    test('la journée commerciale et l\'affichage sont d\'accord', () {
      // Une vente à 23h30 heure de Lubumbashi appartient au 21, et
      // s'affiche le 21. Les deux règles ne doivent jamais diverger.
      final vente = DateTime.utc(2026, 9, 21, 21, 30);
      expect(aLubumbashi(vente).day, 21);
      expect(aLubumbashi(debutDeJourneeLubumbashi(vente)).day, 21);
    });
  });
}
