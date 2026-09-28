import 'package:blue_sky/core/discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Depuis que l'hotel tarifie en dollars, `value` est en CENTS DE
  // DOLLAR pour une remise en montant : elle se negocie dans la monnaie
  // ou le prix a ete annonce. Les montants attendus ci-dessous passent
  // donc par le taux -- 2300 FC pour 1 USD, le taux par defaut.
  group('Discount — montant fixe, en dollars', () {
    test('un montant en dollars est deduit en francs, au taux', () {
      const d = Discount(kind: DiscountKind.amount, value: 5000); // 50,00
      expect(d.amountCents(accommodationCents: 600000, extrasCents: 120000),
          115000,
          reason: '50 USD a 2300 = 115 000 FC');
    });

    test('est plafonne au sous-total (jamais de total negatif)', () {
      const d = Discount(kind: DiscountKind.amount, value: 999999);
      expect(d.amountCents(accommodationCents: 60000, extrasCents: 0), 60000);
    });

    test("ignore la base : un montant fixe s'impute sur le total", () {
      const acc = Discount(
          kind: DiscountKind.amount,
          value: 5000,
          base: DiscountBase.accommodation);
      const tot = Discount(
          kind: DiscountKind.amount, value: 5000, base: DiscountBase.total);
      expect(acc.amountCents(accommodationCents: 600000, extrasCents: 120000),
          tot.amountCents(accommodationCents: 600000, extrasCents: 120000));
    });
  });

  group('Discount — pourcentage', () {
    test('10 % sur l\'hébergement exclut les consommations', () {
      const d = Discount(
          kind: DiscountKind.percent,
          value: 1000,
          base: DiscountBase.accommodation);
      expect(
          d.amountCents(accommodationCents: 60000, extrasCents: 12000), 6000);
    });

    test('10 % sur le total inclut les consommations', () {
      const d = Discount(
          kind: DiscountKind.percent, value: 1000, base: DiscountBase.total);
      expect(
          d.amountCents(accommodationCents: 60000, extrasCents: 12000), 7200);
    });

    test('accepte les décimales (12,5 %) et arrondit au FC', () {
      const d = Discount(
          kind: DiscountKind.percent,
          value: 1250,
          base: DiscountBase.accommodation);
      expect(d.amountCents(accommodationCents: 12345, extrasCents: 0), 1543);
    });

    test('100 % ramène le total à zéro sans le dépasser', () {
      const d = Discount(
          kind: DiscountKind.percent, value: 10000, base: DiscountBase.total);
      expect(
          d.amountCents(accommodationCents: 60000, extrasCents: 12000), 72000);
    });
  });

  group('Discount — garde-fous', () {
    test('valeur nulle ou négative → aucune remise', () {
      expect(
          Discount.none.amountCents(accommodationCents: 60000, extrasCents: 0),
          0);
      expect(
          const Discount(kind: DiscountKind.percent, value: -500)
              .amountCents(accommodationCents: 60000, extrasCents: 0),
          0);
    });

    test('sous-total nul → aucune remise (pas de division sur du vide)', () {
      const d = Discount(kind: DiscountKind.percent, value: 1000);
      expect(d.amountCents(accommodationCents: 0, extrasCents: 0), 0);
    });
  });

  group('Discount — saisie et affichage', () {
    test('parsePercent accepte la virgule française et plafonne à 100 %', () {
      expect(Discount.parsePercent('12,5'), 1250);
      expect(Discount.parsePercent('10'), 1000);
      expect(Discount.parsePercent(' 7.25 '), 725);
      expect(Discount.parsePercent('250'), 10000);
      expect(Discount.parsePercent(''), 0);
      expect(Discount.parsePercent('abc'), 0);
      expect(Discount.parsePercent('-5'), 0);
    });

    test('formatPercent supprime les décimales inutiles', () {
      expect(Discount.formatPercent(1000), '10 %');
      expect(Discount.formatPercent(1250), '12,5 %');
      expect(Discount.formatPercent(500), '5 %');
    });

    test('invoiceLabel combine formule et motif', () {
      const d = Discount(
          kind: DiscountKind.percent,
          value: 1000,
          base: DiscountBase.accommodation,
          reason: 'Client fidèle');
      expect(d.invoiceLabel, "10 % sur hébergement · Client fidèle");
      // La remise en montant s'annonce dans SA devise : « 50,00 $ de
      // remise », au lieu d'un vague « montant fixe » qui obligeait a
      // lire le total pour savoir de combien il s'agissait.
      expect(
          const Discount(kind: DiscountKind.amount, value: 5000).invoiceLabel,
          contains('50,00'));
      expect(Discount.none.invoiceLabel, isNull);
    });
  });

  group('Discount — relecture depuis la BDD', () {
    test('reconstruit une remise persistée', () {
      final d = Discount.fromDb(
          kindIndex: 1, value: 1500, baseIndex: 0, reason: 'Séjour long');
      expect(d.kind, DiscountKind.percent);
      expect(d.base, DiscountBase.accommodation);
      expect(
          d.amountCents(accommodationCents: 100000, extrasCents: 20000), 15000);
    });

    test('tolère un index inconnu (base écrite par une version plus récente)',
        () {
      final d = Discount.fromDb(kindIndex: 9, value: 100, baseIndex: 9);
      expect(d.kind, DiscountKind.values.last);
      expect(d.base, DiscountBase.values.last);
    });
  });
}
