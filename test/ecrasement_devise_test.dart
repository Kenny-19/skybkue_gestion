import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Le zéro serveur qui efface un tarif local.
//
// Le 22 septembre 2026, la migration a converti 19 chambres en dollars.
// Quinze secondes plus tard, tout était revenu à zéro : la colonne
// `price_usd_cents` venait d'être créée côté Supabase avec `default 0`,
// le pull l'a rapatriée, et le poste l'a adoptée comme si elle faisait
// foi.
//
// Même mécanisme que l'incident du stock en septembre. Deux fois le même
// piège mérite un test : une valeur qu'un poste CALCULE ne doit jamais
// être écrasée par une valeur serveur simplement absente.

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDb());
  tearDown(() => db.close());

  Future<void> poserChambre({
    required String numero,
    required int usdCents,
    required int fc,
  }) =>
      db.into(db.rooms).insert(
            RoomsCompanion.insert(
              number: numero,
              type: 'Standard',
              priceUsdCents: Value(usdCents),
              pricePerNightCents: fc,
              status: DbRoomStatus.libre,
            ),
          );

  Future<Room> relire(String numero) =>
      (db.select(db.rooms)..where((r) => r.number.equals(numero))).getSingle();

  /// Reproduit la décision du pull : adopter, ou laisser tel quel.
  ///
  /// C'est la règle testée, écrite ici telle qu'elle vit dans
  /// `MirrorService.pullRoomsIntoLocal`.
  Value<int> adoption(int valeurServeur) =>
      valeurServeur > 0 ? Value(valeurServeur) : const Value.absent();

  group("Un zéro serveur n'efface rien", () {
    test('le tarif local en dollars survit à un pull qui dit zéro', () async {
      await poserChambre(numero: '01', usdCents: 10000, fc: 230000);

      // Le serveur ne connaît pas encore les dollars : colonne créée
      // avec `default 0`.
      await (db.update(db.rooms)..where((r) => r.number.equals('01')))
          .write(RoomsCompanion(priceUsdCents: adoption(0)));

      expect((await relire('01')).priceUsdCents, 10000,
          reason: 'le poste a calculé ce tarif, le serveur ne dit rien');
    });

    test('un vrai tarif serveur, lui, est bien adopté', () async {
      await poserChambre(numero: '02', usdCents: 10000, fc: 230000);

      // Un gérant a changé le tarif depuis un autre poste.
      await (db.update(db.rooms)..where((r) => r.number.equals('02')))
          .write(RoomsCompanion(priceUsdCents: adoption(12000)));

      expect((await relire('02')).priceUsdCents, 12000,
          reason: 'sinon un changement de tarif ne se propagerait jamais');
    });

    test('un tarif local à zéro accepte la valeur du serveur', () async {
      // Poste neuf, ou chambre créée avant la bascule.
      await poserChambre(numero: '03', usdCents: 0, fc: 230000);
      await (db.update(db.rooms)..where((r) => r.number.equals('03')))
          .write(RoomsCompanion(priceUsdCents: adoption(10000)));

      expect((await relire('03')).priceUsdCents, 10000);
    });

    test('quinze pulls successifs ne grignotent pas le tarif', () async {
      // Le pull tourne toutes les quinze secondes. Un défaut qui
      // n'abîme qu'une fois sur dix reste un défaut.
      await poserChambre(numero: '04', usdCents: 18000, fc: 414000);
      for (var i = 0; i < 15; i++) {
        await (db.update(db.rooms)..where((r) => r.number.equals('04')))
            .write(RoomsCompanion(priceUsdCents: adoption(0)));
      }
      expect((await relire('04')).priceUsdCents, 18000);
    });
  });
}
