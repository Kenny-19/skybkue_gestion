import 'package:blue_sky/core/tva.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// TVA : les prix restent TTC (le client paie le même montant) ; factures
// et tickets détaillent le HT et la TVA contenus dans ce total.

void main() {
  group('Détail d\'un prix TTC', () {
    test('116 000 FC à 16 % : 100 000 HT + 16 000 de TVA', () {
      final d = detaillerTtc(116000, 1600);
      expect(d.ht, 100000);
      expect(d.tva, 16000);
    });

    test('HT + TVA retombe TOUJOURS sur le TTC payé', () {
      // Une facture dont les lignes ne s'additionnent pas se conteste.
      for (var ttc = 1; ttc <= 50000; ttc += 7) {
        for (final bp in [1600, 1650, 1800, 500]) {
          final d = detaillerTtc(ttc, bp);
          expect(d.ht + d.tva, ttc, reason: '$ttc à $bp');
          expect(d.tva, greaterThanOrEqualTo(0));
        }
      }
    });

    test('taux nul ou montant nul : aucune TVA', () {
      expect(detaillerTtc(5000, 0).tva, 0);
      expect(detaillerTtc(0, 1600).tva, 0);
    });
  });

  group('Libellé et saisie du taux', () {
    test('libellés', () {
      expect(libelleTaux(1600), '16 %');
      expect(libelleTaux(1650), '16,5 %');
      expect(libelleTaux(1625), '16,25 %');
    });

    test('saisie', () {
      expect(tauxDepuisSaisie('16'), 1600);
      expect(tauxDepuisSaisie('16,5'), 1650);
      expect(tauxDepuisSaisie(' 16.5 '), 1650);
      expect(tauxDepuisSaisie('abc'), isNull);
      expect(tauxDepuisSaisie('80'), isNull, reason: 'taux implausible');
    });
  });

  group('Taux figé à l\'émission', () {
    test('16 % par défaut, puis le taux réglé', () async {
      final db = newTestDb();
      final reglages = SettingsRepo(db);
      expect(await reglages.getTvaBp(), 1600);
      await reglages.setTvaBp(1800);
      expect(await reglages.getTvaBp(), 1800);
      await db.close();
    });

    test('une vente garde le taux du jour où elle est encaissée', () async {
      final db = newTestDb();
      await semerCatalogueDeTest(db);
      final reglages = SettingsRepo(db);
      final ventes = SalesRepo(db);
      final article = (await db.select(db.articles).get()).first;

      final avant = await ventes.createSale(
          articleQuantities: {article.id: 1},
          payment: DbPayment.cash,
          location: DbLocation.restaurant,
          serverUserId: null);
      await reglages.setTvaBp(1800);
      final apres = await ventes.createSale(
          articleQuantities: {article.id: 1},
          payment: DbPayment.cash,
          location: DbLocation.restaurant,
          serverUserId: null);

      final v = {for (final s in await db.select(db.sales).get()) s.id: s};
      expect(v[avant]!.tvaBp, 1600, reason: 'pas réécrite par le changement');
      expect(v[apres]!.tvaBp, 1800);
      await db.close();
    });
  });
}
