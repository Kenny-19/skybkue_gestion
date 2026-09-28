import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/ventes_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// La file des ventes en attente.
//
// Avant elle, une vente Ã©tait poussÃ©e puis oubliÃ©e : les erreurs Ã©taient
// avalÃ©es, et aucune colonne ne disait si le serveur avait confirmÃ©. Le
// rattrapage consistait Ã  repousser TOUT toutes les dix minutes â€” 21 Mo
// par jour pour 207 ventes. Ã‡a marchait, et c'Ã©tait le piÃ¨ge : le jour
// oÃ¹ ce renvoi aurait dÃ©passÃ© le dÃ©lai d'attente, il aurait Ã©chouÃ© en
// silence et les pertes auraient commencÃ© lÃ .

void main() {
  late AppDatabase db;
  late VentesOutbox file;

  setUp(() {
    db = newTestDb();
    file = VentesOutbox(db);
  });
  tearDown(() => db.close());

  Future<int> vente({DateTime? quand}) => db.into(db.sales).insert(
        SalesCompanion.insert(
          soldAt: quand ?? DateTime.now(),
          payment: DbPayment.cash,
        ),
      );

  group('Une vente neuve est en attente', () {
    test("elle ne se croit jamais en ligne par dÃ©faut", () async {
      await vente();
      expect(await file.enAttente(), 1,
          reason: 'on prÃ©fÃ¨re un renvoi de trop Ã  une vente perdue');
    });

    test('la confirmation la sort de la file', () async {
      final id = await vente();
      await file.marquerEnvoyee(id);
      expect(await file.enAttente(), 0);

      final v =
          await (db.select(db.sales)..where((s) => s.id.equals(id))).getSingle();
      expect(v.syncedAt, isNotNull);
      expect(v.syncError, isNull);
    });
  });

  group('Un Ã©chec ne perd jamais la vente', () {
    test('elle reste en attente, avec la raison', () async {
      final id = await vente();
      await file.marquerEchec(id, 'SocketException: pas de rÃ©seau', 0);

      expect(await file.enAttente(), 1,
          reason: "c'est de l'argent encaissÃ© : elle ne disparaÃ®t pas");
      final v =
          await (db.select(db.sales)..where((s) => s.id.equals(id))).getSingle();
      expect(v.syncAttempts, 1);
      expect(v.syncError, contains('SocketException'));
      expect(v.syncedAt, isNull);
    });

    test('les tentatives se cumulent', () async {
      final id = await vente();
      for (var i = 0; i < 3; i++) {
        final v = await (db.select(db.sales)..where((s) => s.id.equals(id)))
            .getSingle();
        await file.marquerEchec(id, 'Ã©chec', v.syncAttempts);
      }
      final v =
          await (db.select(db.sales)..where((s) => s.id.equals(id))).getSingle();
      expect(v.syncAttempts, 3);
    });

    test('une confirmation efface les tentatives et la derniÃ¨re erreur',
        () async {
      final id = await vente();
      await file.marquerEchec(id, 'Ã©chec', 4);
      await file.marquerEnvoyee(id);

      final v =
          await (db.select(db.sales)..where((s) => s.id.equals(id))).getSingle();
      expect(v.syncAttempts, 0);
      expect(v.syncError, isNull);
    });
  });

  group('Ce que le gÃ©rant doit voir', () {
    test('le compte des ventes pas encore en lieu sÃ»r', () async {
      for (var i = 0; i < 5; i++) {
        await vente();
      }
      final ids = await db.select(db.sales).get();
      await file.marquerEnvoyee(ids.first.id);
      await file.marquerEnvoyee(ids[1].id);
      expect(await file.enAttente(), 3);
    });

    test("l'Ã¢ge de la plus ancienne, qui dit si c'est grave", () async {
      // Une vente d'il y a trois jours qui ne remonte toujours pas ne
      // raconte pas la mÃªme histoire qu'une vente d'il y a deux minutes.
      final vieille = DateTime.now().subtract(const Duration(days: 3));
      await vente(quand: vieille);
      await vente();

      final plusAncienne = await file.plusAncienneEnAttente();
      expect(plusAncienne!.difference(vieille).inSeconds.abs(), lessThan(2));
    });

    test('rien en attente : pas de date Ã  montrer', () async {
      final id = await vente();
      await file.marquerEnvoyee(id);
      expect(await file.plusAncienneEnAttente(), isNull);
    });
  });
}
