import 'package:blue_sky/core/discount.dart';
import 'package:blue_sky/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

// Les remises, maintenant que l'hôtel tarifie en dollars.
//
// Le point qui compte : un POURCENTAGE est neutre en devise. Dix pour
// cent restent dix pour cent, rien n'est converti, rien ne s'arrondit —
// et c'est exactement pour ça qu'il ressort propre sur la facture. Une
// remise en MONTANT, elle, se négocie dans la monnaie où le prix a été
// annoncé : en dollars.

void main() {
  setUp(() => Currency.rate = Currency.defaultRate); // 2300

  // Une nuit à 100 $ = 230 000 FC, plus 20 000 FC de bar.
  const hebergement = 230000;
  const extras = 20000;

  group('Le pourcentage ne se convertit jamais', () {
    test("il s'affiche exactement tel qu'il a été saisi", () {
      const d = Discount(kind: DiscountKind.percent, value: 1250);
      expect(d.formulaLabel, contains('12,5 %'),
          reason: 'aucun recalcul depuis un montant : pas de 12,49 %');
    });

    test('un changement de taux ne le déplace pas', () {
      const d = Discount(
          kind: DiscountKind.percent,
          value: 1000,
          base: DiscountBase.accommodation);
      final a2300 = d.amountCents(
          accommodationCents: hebergement, extrasCents: extras, taux: 2300);
      final a2600 = d.amountCents(
          accommodationCents: hebergement, extrasCents: extras, taux: 2600);
      expect(a2300, a2600,
          reason: "10 % d'une assiette en francs ne dépend pas du taux");
      expect(a2300, 23000);
    });

    test("l'assiette hébergement exclut bien le bar", () {
      const d = Discount(
          kind: DiscountKind.percent,
          value: 1000,
          base: DiscountBase.accommodation);
      expect(
          d.amountCents(
              accommodationCents: hebergement, extrasCents: extras),
          23000,
          reason: '10 % de 230 000, pas de 250 000');
    });
  });

  group('La remise en montant est en dollars', () {
    test('10 dollars valent 23 000 FC au taux du jour', () {
      const d = Discount(kind: DiscountKind.amount, value: 1000); // 10,00 $
      expect(
          d.amountCents(
              accommodationCents: hebergement, extrasCents: extras),
          23000);
    });

    test('la même remise suit le taux figé, pas le taux courant', () {
      const d = Discount(kind: DiscountKind.amount, value: 1000);
      Currency.rate = 2600;
      expect(
          d.amountCents(
              accommodationCents: hebergement,
              extrasCents: extras,
              taux: 2300),
          23000,
          reason: 'la facture doit rejouer ce que le client a payé');
    });

    test('elle se réaffiche en dollars sans dériver', () {
      const d = Discount(kind: DiscountKind.amount, value: 1000);
      expect(
          d.montantUsdCents(
              accommodationCents: hebergement, extrasCents: extras),
          1000,
          reason: 'un aller-retour FC introduirait « 9,99 \$ »');
      expect(d.formulaLabel, contains('10,00'));
    });
  });

  group('Garde-fous', () {
    test('une remise ne dépasse jamais le sous-total', () {
      // 500 $ de remise sur une facture de 250 000 FC.
      const d = Discount(kind: DiscountKind.amount, value: 50000);
      expect(
          d.amountCents(
              accommodationCents: hebergement, extrasCents: extras),
          250000,
          reason: 'on ne facture jamais un total négatif');
    });

    test('la remise plafonnée se réaffiche à sa valeur réelle', () {
      const d = Discount(kind: DiscountKind.amount, value: 50000);
      final usd = d.montantUsdCents(
          accommodationCents: hebergement, extrasCents: extras);
      expect(usd, lessThan(50000),
          reason: 'on annonce ce qui a été déduit, pas ce qui était '
              'demandé');
      expect(usd, closeTo(250000 / 2300 * 100, 2));
    });

    test('une remise vide ne dit rien', () {
      expect(Discount.none.formulaLabel, isNull);
      expect(
          Discount.none.montantUsdCents(
              accommodationCents: hebergement, extrasCents: extras),
          0);
    });
  });
}
