import 'package:blue_sky/core/numero_facture.dart';
import 'package:blue_sky/core/temps.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/mirror_service.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Les numéros de facture étaient tirés de l'horloge (mille valeurs par
// mois) et se répétaient. Et un même séjour envoyé par plusieurs postes
// était compté deux ou trois fois chez Pamela.

void main() {
  group('Numéros de facture', () {
    final le = DateTime(2026, 11, 17);

    test('forme : compteur sur 4 chiffres, code du poste, mois, année', () {
      expect(numeroFacture(42, 'R', le), 'FCT0042-R/11/2026');
      expect(numeroReservation(42, 'R', le), 'RSV0042-R/11/2026');
      expect(numeroFacture(12345, 'BAR', le), 'FCT12345-BAR/11/2026');
    });

    test('code du poste : saisie validée, défaut stable', () {
      expect(codePosteDepuisSaisie(' r '), 'R');
      expect(codePosteDepuisSaisie('bar'), 'BAR');
      expect(codePosteDepuisSaisie(''), isNull);
      expect(codePosteDepuisSaisie('ABCD'), isNull);
      expect(codePosteDepuisSaisie('R-1'), isNull,
          reason: 'le tiret sépare déjà le compteur du code');
      expect(codePosteParDefaut('DESKTOP-DPJ4R46'),
          codePosteParDefaut('desktop-dpj4r46'));
      expect(codePosteParDefaut('DESKTOP-DPJ4R46'), hasLength(2));
      expect(codePosteParDefaut('DESKTOP-DPJ4R46'),
          isNot(codePosteParDefaut('LAPTOP-415S9H3U')));
    });

    test('mille départs : mille numéros différents, à la suite', () async {
      final db = newTestDb();
      final reglages = SettingsRepo(db);
      await reglages.setCodePoste('R');
      final vus = <String>{};
      for (var i = 1; i <= 1000; i++) {
        final n =
            await reglages.prochainNumeroFacture(nomMachine: 'POSTE', le: le);
        expect(n.facture, numeroFacture(i, 'R', le));
        vus.add(n.facture);
      }
      expect(vus, hasLength(1000));
      await db.close();
    });

    test('deux postes ne produisent jamais le même numéro', () async {
      final reception = newTestDb();
      final bar = newTestDb();
      await SettingsRepo(reception).setCodePoste('R');
      await SettingsRepo(bar).setCodePoste('B');
      final a = await SettingsRepo(reception)
          .prochainNumeroFacture(nomMachine: 'X', le: le);
      final b = await SettingsRepo(bar)
          .prochainNumeroFacture(nomMachine: 'Y', le: le);
      expect(a.facture, 'FCT0001-R/11/2026');
      expect(b.facture, 'FCT0001-B/11/2026');
      await reception.close();
      await bar.close();
    });

    test('départs simultanés : pas deux fois le même numéro', () async {
      final db = newTestDb();
      final reglages = SettingsRepo(db);
      final numeros = await Future.wait([
        for (var i = 0; i < 20; i++)
          reglages.prochainNumeroFacture(nomMachine: 'POSTE', le: le)
      ]);
      expect(numeros.map((n) => n.facture).toSet(), hasLength(20));
      await db.close();
    });
  });

  test('un séjour local et sa copie du serveur sont reconnus comme le même',
      () async {
    final db = newTestDb();
    final arrivee = DateTime(2026, 9, 2, 9, 46, 12);
    final depart = DateTime(2026, 9, 2, 9, 48, 40);
    final id = await db.into(db.stays).insert(StaysCompanion.insert(
          receiptNumber: 'FCT542/9/2026',
          checkinAt: arrivee,
          checkoutAt: depart,
          guestFullName: 'Client A',
          subtotalCents: 299000,
          statut: const Value(DbStayStatus.facture),
        ));
    final local =
        await (db.select(db.stays)..where((s) => s.id.equals(id))).getSingle();

    // Tel que le serveur le rend, envoyé par un autre poste.
    Map<String, dynamic> serveur({int montant = 299000, String? client}) => {
          'receipt_number': 'FCT542/9/2026',
          'guest_full_name': client ?? 'Client A',
          'checkin_at': isoServeur(arrivee),
          'checkout_at': isoServeur(depart),
          'subtotal_cents': montant,
        };

    expect(MirrorService.cleDeSejourServeur(serveur()),
        MirrorService.cleDeSejour(local));
    // Même ancien numéro, autre facture : pas confondues.
    expect(MirrorService.cleDeSejourServeur(serveur(client: 'Client B')),
        isNot(MirrorService.cleDeSejour(local)));
    expect(MirrorService.cleDeSejourServeur(serveur(montant: 230000)),
        isNot(MirrorService.cleDeSejour(local)));
    await db.close();
  });
}
