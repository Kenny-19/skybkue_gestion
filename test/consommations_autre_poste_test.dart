import 'package:blue_sky/core/temps.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// La caisse du bar met une boisson sur la chambre 15 ; la réception, sur
// un autre poste, fait le départ. La facture ne cherchait ses
// consommations que dans la base de la réception : la boisson n'y était
// jamais. Le 17 novembre 2026 : 16 consommations, 925 000 FC, jamais
// facturées.

/// La vente telle que le miroir la rend (colonnes de `mirror_sales`).
Map<String, dynamic> _commeLeServeur(Sale v, int idServeur) => {
      'id': idServeur,
      'uid': v.uid,
      'sold_at': isoServeur(v.soldAt),
      'payment': v.payment.index,
      'location': v.location.index,
      'server_user_id': null,
      'customer_name': v.customerName,
      'room_number': v.roomNumber,
      'on_credit': v.onCredit,
      'settled_at': null,
      'note': v.note,
    };

Map<String, dynamic> _ligneCommeLeServeur(SaleLine l, int idServeur) => {
      'id': l.id + 500,
      'sale_id': idServeur,
      'uid': l.uid,
      'article_name': l.articleName,
      'qty': l.qty,
      'unit_price_cents': l.unitPriceCents,
    };

void main() {
  test('la consommation saisie au bar arrive sur la facture de la réception, '
      'puis disparaît des dettes du bar', () async {
    final bar = newTestDb();
    final reception = newTestDb();
    await semerCatalogueDeTest(bar);
    await semerCatalogueDeTest(reception);

    final arrivee = DateTime.now().subtract(const Duration(days: 2));

    // ── Au bar : 2 bières sur la chambre 15, à crédit ──────────────────
    final biere = (await bar.select(bar.articles).get())
        .firstWhere((a) => a.name.startsWith('Bière'));
    final venteBar = await SalesRepo(bar).createSale(
      articleQuantities: {biere.id: 2},
      payment: DbPayment.cash,
      location: DbLocation.hotel,
      serverUserId: null,
      roomNumber: '15',
      onCredit: true,
    );
    final v = (await SalesRepo(bar).venteParId(venteBar))!;
    final serveur = [_commeLeServeur(v.sale, 1000)];
    final lignesServeur = [
      for (final l in v.lines) _ligneCommeLeServeur(l, 1000)
    ];

    // ── À la réception : rien tant qu'on n'a pas rapatrié ──────────────
    final ventesRecep = SalesRepo(reception);
    Future<List<SaleWithLines>> aFacturer() => ventesRecep.unpaidForStay(
        sejourId: null, roomNumbers: ['15'], since: arrivee);
    expect(await aFacturer(), isEmpty, reason: "c'était le bug");

    final ajoutees = await MirrorService.appliquerVentesDuServeur(
        reception, serveur, lignesServeur);
    expect(ajoutees, 1);
    // Rejouée (deuxième départ, réseau qui répète) : pas de doublon.
    expect(
        await MirrorService.appliquerVentesDuServeur(
            reception, serveur, lignesServeur),
        0);

    final factures = await aFacturer();
    expect(factures, hasLength(1));
    expect(factures.single.totalCents, biere.priceCents * 2);
    expect(factures.single.sale.uid, v.sale.uid,
        reason: 'la même vente, pas une copie sous une autre identité');

    // ── Facturée au départ, donc réglée à la réception ─────────────────
    await ventesRecep.settleDebt(factures.single.sale.id, DbPayment.cash);
    expect(await aFacturer(), isEmpty);

    // ── Le bar apprend le règlement : plus de dette chez lui ───────────
    final regle = await MirrorService.appliquerReglementsDuServeur(bar, [
      {'uid': v.sale.uid, 'settled_at': isoServeur(DateTime.now())}
    ]);
    expect(regle, 1);
    expect(await SalesRepo(bar).watchOutstandingDebts().first, isEmpty,
        reason: "plus d'encaissement possible une seconde fois au bar");
    expect(await bar.select(bar.debtPayments).get(), isEmpty,
        reason: "l'argent est entré à la réception, pas dans la caisse du bar");

    await bar.close();
    await reception.close();
  });

  test('une consommation déjà réglée au bar ne revient pas sur la facture',
      () async {
    final bar = newTestDb();
    final reception = newTestDb();
    await semerCatalogueDeTest(bar);
    await semerCatalogueDeTest(reception);
    final a = (await bar.select(bar.articles).get()).first;
    final id = await SalesRepo(bar).createSale(
      articleQuantities: {a.id: 1},
      payment: DbPayment.cash,
      location: DbLocation.hotel,
      serverUserId: null,
      roomNumber: '15',
      onCredit: true,
    );
    final v = (await SalesRepo(bar).venteParId(id))!;
    final rangee = {
      ..._commeLeServeur(v.sale, 2000),
      'settled_at': isoServeur(DateTime.now()),
    };

    await MirrorService.appliquerVentesDuServeur(reception, [rangee],
        [for (final l in v.lines) _ligneCommeLeServeur(l, 2000)]);
    expect(
        await SalesRepo(reception).unpaidForStay(
            sejourId: null,
            roomNumbers: ['15'],
            since: DateTime.now().subtract(const Duration(days: 1))),
        isEmpty,
        reason: 'le client la paierait deux fois');
    await bar.close();
    await reception.close();
  });
}
