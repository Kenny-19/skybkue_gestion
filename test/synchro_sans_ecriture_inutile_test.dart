import 'dart:async';

import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Légèreté : la relecture du serveur, toutes les quinze secondes,
// réécrivait chaque chambre, chaque article, chaque client et chaque
// société même quand rien n'avait changé. Chaque écriture prévient tous
// les écrans qui affichent ces données, et ils se redessinaient en entier
// quatre fois par minute.
//
// Ces tests appliquent deux fois les mêmes données : la seconde fois ne
// doit RIEN écrire, donc ne réveiller aucun écran.

final chambres = [
  {
    'number': '101',
    'type': 'standard',
    'price_per_night_cents': 125000,
    'price_usd_cents': 5000,
    'status': 0,
  },
  // Chambre occupée : des dates, au format réel du serveur.
  {
    'number': '102',
    'type': 'standard',
    'price_per_night_cents': 125000,
    'price_usd_cents': 5000,
    'status': 1,
    'current_guest': 'M. Kabila',
    'checkin_at': '2026-10-05T12:30:00.654321+00:00',
    'checkout_date': '2026-10-08T09:00:00+00:00',
  },
];
final articles = [
  {
    'uid': 'c71cc3ad-cc26-82be-8260-abe07460453b',
    'name': 'Eau minérale',
    'price_cents': 2000,
    'category': 0,
    'active': true,
    'track_stock': true,
    'unit': 'bouteille',
    'stock_qty': 39,
    'threshold': 24,
  },
];
final clients = [
  {
    'full_name': 'M. Kabila',
    'phone': '+243810000000',
    'visits_count': 3,
    'total_spent_cents': 450000,
    // Instant UTC à la microseconde : la forme réelle du serveur.
    'last_seen_at': '2026-10-01T10:00:00.123456+00:00',
  },
];
final societes = [
  {'name': 'ONG Espoir', 'type': 1, 'tax_id': 'A123'},
];

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Nombre de notifications de modification reçues pendant [action].
  Future<int> ecrituresPendant(Future<void> Function() action) async {
    await db.customSelect('SELECT 1').get(); // base ouverte
    var n = 0;
    final abo = db.tableUpdates().listen((_) => n++);
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await abo.cancel();
    return n;
  }

  test('chambres : seconde application identique, aucune écriture', () async {
    expect(await MirrorService.appliquerChambresDuServeur(db, chambres), 2);
    expect(
        await ecrituresPendant(
            () => MirrorService.appliquerChambresDuServeur(db, chambres)),
        0);
  });

  test('articles : une fois à jour, plus aucune écriture', () async {
    // 1er passage : l'article arrive, stock à zéro sur ce poste.
    // 2e passage : il adopte le stock du serveur (comportement voulu).
    expect(await MirrorService.appliquerArticlesDuServeur(db, articles), 1);
    expect(await MirrorService.appliquerArticlesDuServeur(db, articles), 1);
    expect((await db.select(db.articles).getSingle()).stockQty, 39);
    // Ensuite, rien ne bouge : rien n'est écrit.
    expect(
        await ecrituresPendant(
            () => MirrorService.appliquerArticlesDuServeur(db, articles)),
        0);
  });

  test('clients : seconde application identique, aucune écriture', () async {
    expect(await MirrorService.appliquerClientsDuServeur(db, clients), 1);
    expect(
        await ecrituresPendant(
            () => MirrorService.appliquerClientsDuServeur(db, clients)),
        0);
  });

  test('sociétés : seconde application identique, aucune écriture', () async {
    expect(await MirrorService.appliquerSocietesDuServeur(db, societes), 1);
    expect(
        await ecrituresPendant(
            () => MirrorService.appliquerSocietesDuServeur(db, societes)),
        0);
  });

  test('un vrai changement, lui, est bien écrit', () async {
    await MirrorService.appliquerArticlesDuServeur(db, articles);
    final nouveauPrix = [
      {...articles.first, 'price_cents': 2500},
    ];
    expect(await MirrorService.appliquerArticlesDuServeur(db, nouveauPrix), 1);
    final a = await db.select(db.articles).getSingle();
    expect(a.priceCents, 2500);
  });

  test('deux fiches locales de même nom ne bloquent plus la synchro', () async {
    for (var i = 0; i < 2; i++) {
      await db.into(db.clients).insert(ClientsCompanion.insert(
          fullName: 'Client Doublon', phone: Value('+24390000000$i')));
    }
    // Avant : getSingleOrNull levait, et toute la synchro s'arrêtait.
    await MirrorService.appliquerClientsDuServeur(db, [
      {'full_name': 'Client Doublon', 'visits_count': 9},
      ...clients,
    ]);
    expect(
        (await db.select(db.clients).get())
            .any((c) => c.fullName == 'M. Kabila'),
        isTrue);
  });
}
