import 'dart:async';

import 'package:blue_sky/services/connexion_service.dart';
import 'package:blue_sky/shell/bandeau_hors_ligne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

// En ligne d'abord : le poste doit savoir, et dire, quand le serveur ne
// répond plus ; et mesurer ses coupures, qu'on ne connaissait pas.

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('une coupure est mesurée, gardée, puis envoyée au retour', () async {
    final db = newTestDb();
    final envoyees = <Coupure>[];
    var serveurJoignable = false;
    final cx = ConnexionService(
        db: db,
        envoyer: (l) async {
          if (!serveurJoignable) throw Exception('timeout');
          envoyees.addAll(l);
        });
    final t0 = DateTime(2026, 11, 21, 10);

    await cx.signalerEnLigne(maintenant: t0);
    cx.signalerHorsLigne(maintenant: t0.add(const Duration(minutes: 1)));
    // Plusieurs échecs pendant la même coupure : un seul début.
    cx.signalerHorsLigne(maintenant: t0.add(const Duration(minutes: 3)));
    expect(cx.estHorsLigne, isTrue);
    expect(cx.horsLigneDepuis, t0.add(const Duration(minutes: 1)));

    // Retour, mais l'envoi échoue encore : la coupure reste en attente.
    await cx.signalerEnLigne(maintenant: t0.add(const Duration(minutes: 8)));
    await pumpEventQueue();
    expect(cx.estHorsLigne, isFalse);
    final attente = await cx.enAttente();
    expect(attente, hasLength(1));
    expect(attente.single.duree, const Duration(minutes: 7));

    serveurJoignable = true;
    await cx.envoyerCoupures();
    expect(envoyees.single.duree, const Duration(minutes: 7));
    expect(await cx.enAttente(), isEmpty);
    await db.close();
  });

  test('coupure réseau ou refus du serveur', () {
    expect(ConnexionService.estUneCoupure(TimeoutException('x')), isTrue);
    expect(ConnexionService.estUneCoupure(Exception('SocketException: x')),
        isTrue);
    expect(ConnexionService.estUneCoupure(
            Exception('Connection closed before full header')),
        isTrue);
    expect(ConnexionService.estUneCoupure(Exception('ARTICLE_INCONNU')),
        isFalse, reason: 'le serveur a répondu : ce n\'est pas une coupure');
  });

  testWidgets('le bandeau n\'apparaît que hors ligne', (tester) async {
    final cx = ConnexionService(envoyer: (_) async {});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BandeauHorsLigne(connexion: cx))));
    expect(find.textContaining('Hors ligne'), findsNothing);

    cx.signalerHorsLigne(maintenant: DateTime(2026, 11, 21, 12, 30));
    await tester.pump();
    expect(find.textContaining('Hors ligne depuis'), findsOneWidget);
    expect(find.textContaining('au retour du réseau'), findsOneWidget);

    cx.etat.value = EtatConnexion.enLigne;
    cx.horsLigneDepuis = null;
    await tester.pump();
    expect(find.textContaining('Hors ligne'), findsNothing);
  });
}
