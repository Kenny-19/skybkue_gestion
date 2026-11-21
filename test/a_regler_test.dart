import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/services/operations_service.dart';
import 'package:blue_sky/shell/bandeau_a_regler.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

// Une opération faite hors ligne puis refusée par le serveur ne disparaît
// jamais en silence : un bandeau la signale jusqu'à ce qu'elle soit réglée.

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('refus signalé, listé avec son motif, puis réglé',
      (tester) async {
    final db = newTestDb();
    final ops = OperationsService(db, appel: (a, b, c, d) async => {});
    await tester.runAsync(() => db.into(db.operations).insert(
          OperationsCompanion.insert(
            opId: 'op1',
            type: 'chambres:arrivee',
            payload: '{"chambres":[{"number":"15"}]}',
            libelle: 'Arrivée de Kabila, chambre 15',
            auteur: const Value('benita'),
            creeLe: DateTime(2026, 11, 21, 10),
            refuseeLe: Value(DateTime(2026, 11, 21, 10, 30)),
            motif: const Value('La chambre 15 est déjà occupée par Mwamba.'),
          ),
        ));

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BandeauARegler(operations: ops))));
    Future<void> laisserVenir() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await laisserVenir();
    expect(find.textContaining('refusée par le serveur'), findsOneWidget);

    await tester.tap(find.text('Voir'));
    await laisserVenir();
    expect(find.text('Arrivée de Kabila, chambre 15'), findsOneWidget);
    expect(find.textContaining('déjà occupée par Mwamba'), findsOneWidget);
    expect(find.textContaining('par benita'), findsOneWidget);

    await tester.tap(find.text('Réglé'));
    await laisserVenir();
    expect(find.text('Tout est réglé.'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await laisserVenir();
    expect(find.textContaining('refusée par le serveur'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await laisserVenir();
    await tester.runAsync(db.close);
  });
}
