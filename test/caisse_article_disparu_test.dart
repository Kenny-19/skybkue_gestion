import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/features/pos/pos_cart.dart';
import 'package:blue_sky/features/pos/pos_screen.dart';
import 'package:blue_sky/theme/app_theme.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

// Du 31 octobre au 16 novembre 2026, la caisse de DESKTOP-DPJ4R46 a
// planté 16 fois : un article du panier avait disparu du catalogue, et
// l'écran, qui cherchait son prix, tombait à chaque affichage. Le panier
// survivant aux changements d'écran, la caisse restait bloquée jusqu'au
// redémarrage.

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('un article qui quitte le catalogue sort du panier, '
      'sans planter la caisse', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = newTestDb();
    await tester.runAsync(() => semerCatalogueDeTest(db));
    final articles = (await tester.runAsync(
        () => (db.select(db.articles)..orderBy([(a) => OrderingTerm.asc(a.id)]))
            .get()))!;
    final garde = articles[0];
    final retire = articles[1];

    final conteneur = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      permsProvider.overrideWithValue(const Perms(DbUserRole.superAdmin)),
    ]);
    addTearDown(conteneur.dispose);
    conteneur.read(posCartProvider.notifier)
      ..add(garde.id)
      ..add(retire.id)
      ..add(retire.id);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp(
        theme: buildBlueSkyTheme(),
        home: const Scaffold(body: PosScreen()),
      ),
    ));
    Future<void> laisserVenir() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await laisserVenir();
    expect(conteneur.read(posCartProvider).lines.length, 2);

    // Désactivé ailleurs (ou fusionné par la synchronisation).
    await tester.runAsync(() =>
        (db.update(db.articles)..where((a) => a.id.equals(retire.id)))
            .write(const ArticlesCompanion(active: Value(false))));
    await laisserVenir();

    expect(tester.takeException(), isNull, reason: "la caisse ne plante plus");
    expect(conteneur.read(posCartProvider).lines, {garde.id: 1},
        reason: "l'article disparu est retiré, le reste du panier gardé");
    expect(find.textContaining("n'est plus en vente"), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await laisserVenir();
    await tester.runAsync(db.close);
  });

  test('encaisser un article disparu : refus clair, rien d\'enregistré',
      () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final a = (await db.select(db.articles).get()).first;
    final ventes = SalesRepo(db);

    await expectLater(
      ventes.createSale(
        articleQuantities: {a.id: 1, 999999: 2},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null,
      ),
      throwsA(isA<StateError>()),
    );
    expect(await db.select(db.sales).get(), isEmpty,
        reason: 'tout ou rien : pas de vente à moitié enregistrée');
    await db.close();
  });

  test('le ticket imprimé est celui de la vente encaissée', () async {
    final db = newTestDb();
    await semerCatalogueDeTest(db);
    final arts = await db.select(db.articles).get();
    final ventes = SalesRepo(db);
    final premiere = await ventes.createSale(
        articleQuantities: {arts[0].id: 1},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null);
    final seconde = await ventes.createSale(
        articleQuantities: {arts[1].id: 3},
        payment: DbPayment.cash,
        location: DbLocation.restaurant,
        serverUserId: null);

    final v = await ventes.venteParId(seconde);
    expect(v!.sale.id, seconde);
    expect(v.lines.single.qty, 3);
    expect((await ventes.venteParId(premiere))!.sale.id, premiere);
    expect(await ventes.venteParId(424242), isNull);
    await db.close();
  });
}
