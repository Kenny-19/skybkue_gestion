import 'dart:async';
import 'dart:io';

import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/services/accounts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Classification des pannes du serveur de comptes.
//
// C'est le maillon qui a causé le verrouillage total en production :
// une erreur mal classée empêche le repli sur les comptes de secours et
// ferme l'application à tout le monde. On le teste donc sans réseau, en
// fabriquant les exceptions telles que Supabase les remonte.

void main() {
  group('Traduction des pannes serveur', () {
    test('fonction SQL absente (42883) → panne technique, PAS un refus', () {
      final e = AccountsService.translateForMigration(
        const PostgrestException(
          message: 'function public.bs_verify_login(text, text) does not exist',
          code: '42883',
        ),
      );
      expect(e.kind, AccountErrorKind.unexpected);
      // Le message doit dire quoi faire, pas juste constater.
      expect(e.message, contains('sql/2026_09_comptes_supabase.sql'));
      // Et surtout : ce cas DOIT autoriser le repli local.
      expect(shouldFallBackLocally(e.kind), true,
          reason: 'sinon plus personne ne peut ouvrir l\'application');
    });

    test('timeout → hors ligne, donc repli local', () {
      final e =
          AccountsService.translateForMigration(TimeoutException('trop long'));
      expect(e.kind, AccountErrorKind.offline);
      expect(e.isRetryable, true);
      expect(shouldFallBackLocally(e.kind), true);
    });

    test('coupure réseau → hors ligne, donc repli local', () {
      final e = AccountsService.translateForMigration(
          const SocketException('Failed host lookup: supabase.co'));
      expect(e.kind, AccountErrorKind.offline);
      expect(shouldFallBackLocally(e.kind), true);
    });

    test('refus métier → rejected, et PAS de repli local', () {
      final e = AccountsService.translateForMigration(
        const PostgrestException(message: 'LOGIN_DEJA_PRIS', code: 'P0001'),
      );
      expect(e.kind, AccountErrorKind.rejected);
      expect(e.code, 'LOGIN_DEJA_PRIS');
      expect(e.message, 'Cet identifiant est déjà utilisé.');
      expect(shouldFallBackLocally(e.kind), false,
          reason: 'un serveur qui fonctionne et dit non fait autorité');
    });

    test('chaque code métier a un message en français, jamais un code brut',
        () {
      for (final code in const [
        'IDENTIFIANTS_ADMIN_INVALIDES',
        'DROITS_INSUFFISANTS',
        'LOGIN_DEJA_PRIS',
        'MOT_DE_PASSE_TROP_COURT',
        'COMPTE_INTROUVABLE',
        'DERNIER_SUPER_ADMIN',
        'JETON_INVALIDE',
        'JETON_EXPIRE',
        'HASH_INVALIDE',
      ]) {
        final e = AccountsService.translateForMigration(
            PostgrestException(message: code, code: 'P0001'));
        expect(e.kind, AccountErrorKind.rejected, reason: code);
        expect(e.message, isNot(contains(code)),
            reason: '$code ne doit pas fuiter tel quel dans l\'UI');
        expect(e.message.length, greaterThan(15), reason: code);
      }
    });

    test('un code inconnu ne plante pas : message générique lisible', () {
      final e = AccountsService.translateForMigration(
          const PostgrestException(message: 'boom inattendu', code: '99999'));
      expect(e.kind, AccountErrorKind.unexpected);
      expect(e.message, isNotEmpty);
    });
  });
}
