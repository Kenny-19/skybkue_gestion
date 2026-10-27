import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/features/rooms/rooms_screen.dart';
import 'package:blue_sky/theme/app_theme.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

// Le plan des chambres reçoit TOUTE la liste à chaque changement d'une
// seule chambre. Seule la carte de cette chambre doit être refaite : les
// autres sont rendues telles quelles, sans être reconstruites.

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('modifier une chambre ne refait que sa carte', (tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = newTestDb();
    await tester.runAsync(() => db.batch((b) {
          for (final n in ['101', '102', '103']) {
            b.insert(
              db.rooms,
              RoomsCompanion.insert(
                number: n,
                type: 'Standard',
                pricePerNightCents: 60000,
                status: DbRoomStatus.libre,
              ),
            );
          }
        }));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        permsProvider.overrideWithValue(const Perms(DbUserRole.superAdmin)),
      ],
      child: MaterialApp(
        theme: buildBlueSkyTheme(),
        home: const Scaffold(body: RoomsScreen()),
      ),
    ));
    Future<void> laisserVenir() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await laisserVenir();
    Widget carte(String n) => tester.widget(find.byKey(ValueKey(n)));
    final avant = {for (final n in ['101', '102', '103']) n: carte(n)};

    // La 102 passe en nettoyage.
    await tester.runAsync(() =>
        (db.update(db.rooms)..where((r) => r.number.equals('102')))
            .write(const RoomsCompanion(status: Value(DbRoomStatus.nettoyage))));
    await laisserVenir();

    expect(find.text('Nettoyage'), findsWidgets, reason: 'la carte a suivi');
    expect(identical(carte('102'), avant['102']), isFalse);
    expect(identical(carte('101'), avant['101']), isTrue,
        reason: 'une chambre inchangée garde sa carte');
    expect(identical(carte('103'), avant['103']), isTrue);

    // Les fenêtres vivent désormais dans leurs propres fichiers : les
    // boutons des cartes doivent toujours les ouvrir.
    await tester.tap(find.widgetWithText(FilledButton, 'Check-in').first);
    await laisserVenir();
    expect(find.text('CHECK-IN CHAMBRE 101'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await laisserVenir();

    await tester.tap(find.text('Nouvelle chambre'));
    await laisserVenir();
    expect(find.text('NUMÉRO'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await laisserVenir();
    await tester.runAsync(db.close);
  });
}
