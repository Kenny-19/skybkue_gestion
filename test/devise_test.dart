import 'package:blue_sky/core/devise.dart';
import 'package:blue_sky/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

// Le dollar comme source du tarif, le franc comme monnaie encaissée.
//
// L'enjeu n'est pas la conversion — c'est qu'une facture réimprimée six
// mois plus tard annonce le montant que le client a réellement payé, et
// pas ce qu'il vaudrait au taux du jour.

void main() {
  setUp(() => Currency.rate = Currency.defaultRate); // 2300

  group('Du dollar vers le franc', () {
    test('un tarif de 45 USD donne 103 500 FC à 2300', () {
      expect(usdVersFc(4500), 103500);
    });

    test("l'arrondi se fait au franc, pas au centime", () {
      // 33.33 $ à 2300 = 76 659 FC. La caisse ne rend pas la monnaie en
      // centimes de franc.
      expect(usdVersFc(3333), 76659);
    });

    test('un taux explicite prime sur le taux courant', () {
      Currency.rate = 2300;
      expect(usdVersFc(4500, taux: 2600), 117000,
          reason: 'sinon une facture ancienne serait rejouée au taux du '
              'jour');
    });
  });

  group('Le taux figé', () {
    test('un séjour rejoue SON taux, pas celui du jour', () {
      // Séjour facturé à 2300, réimprimé alors que le taux est à 2600.
      const tauxDuSejour = 230000; // × 100
      Currency.rate = 2600;
      expect(usdVersFc(4500, taux: tauxDepuisCents(tauxDuSejour)), 103500,
          reason: 'le client a payé 103 500 FC, pas 117 000');
    });

    test('un séjour sans taux figé retombe sur le taux courant', () {
      // Séjour antérieur à la bascule : mieux vaut une approximation
      // qu'une division par zéro.
      Currency.rate = 2600;
      expect(tauxDepuisCents(0), 2600);
      expect(tauxDepuisCents(null), 2600);
    });

    test('le taux courant se fige sans perdre les décimales', () {
      Currency.rate = 2350.5;
      expect(tauxCourantEnCents(), 235050);
      expect(tauxDepuisCents(tauxCourantEnCents()), 2350.5);
    });
  });

  group('La reprise de l\'existant', () {
    test('un tarif en francs se retrouve en dollars', () {
      expect(fcVersUsd(103500), 4500);
    });

    test('aller-retour : un tarif rond reste rond', () {
      expect(usdVersFc(fcVersUsd(103500)), 103500);
    });

    test('un taux nul ne fait pas exploser la conversion', () {
      Currency.rate = 0;
      expect(fcVersUsd(103500), 0,
          reason: 'un taux mal saisi ne doit pas planter la réception');
    });
  });

  group("Ce que la réception lit", () {
    /// `fr_FR` sépare les milliers avec une espace INSÉCABLE, pas une
    /// espace ordinaire. Comparer sans normaliser fait échouer un test
    /// sur deux caractères qui se ressemblent à l'œil nu.
    String normalise(String t) =>
        t.replaceAll(' ', ' ').replaceAll(' ', ' ');

    test('le dollar vient en premier, le franc entre parenthèses', () {
      final t = montantHotel(4500);
      expect(t.indexOf(r'$'), lessThan(t.indexOf('FC')),
          reason: "c'est le dollar qui porte l'accord avec le client");
      expect(normalise(t), contains('45,00'));
      expect(normalise(t), contains('103 500'));
    });

    test('les centimes de dollar sont montrés', () {
      // 12,50 USD n'est pas 12 USD : sur une note d'hôtel, la moitié compte.
      expect(moneyUsd(1250), contains('12,50'));
    });
  });
}
