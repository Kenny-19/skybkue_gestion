import 'dart:async';
import 'dart:io';

import 'package:blue_sky/core/user_error.dart';
import 'package:blue_sky/services/accounts_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Ce qui s'affiche quand ça casse.
//
// Règle de base, vérifiée par le premier groupe : aucun message montré à
// l'utilisateur ne doit contenir de jargon, d'adresse de serveur ou de
// nom de classe d'exception.

void main() {
  group("Le cas de la capture d'écran", () {
    // Ce que la réception avait sous les yeux :
    //   SocketException: HTTP connection timed out after 0:00:15.000000,
    //   host: wdwhfgawuozhkeflgcvs.supabase.co, port: 443
    const brut = 'SocketException: HTTP connection timed out after '
        '0:00:15.000000, host: wdwhfgawuozhkeflgcvs.supabase.co, port: 443';

    test('devient « Pas de connexion »', () {
      final e = describeError(brut);
      expect(e.title, 'Pas de connexion');
      expect(e.kind, ErrorKind.offline);
    });

    test("n'expose ni l'adresse du serveur ni le nom de l'exception", () {
      final e = describeError(brut);
      final visible = '${e.title} ${e.message} ${e.advice}';
      expect(visible, isNot(contains('supabase')));
      expect(visible, isNot(contains('SocketException')));
      expect(visible, isNot(contains('443')));
      expect(visible, isNot(contains('0:00:15')));
    });

    test('dit à la réception que le poste reste utilisable', () {
      expect(describeError(brut).advice, contains('continue de fonctionner'));
    });

    test("n'alerte pas le gérant : une coupure n'est pas un incident", () {
      // Sinon la boîte mail se remplit de « pas de connexion » et plus
      // personne ne lit les vraies alertes.
      expect(describeError(brut).worthReporting, false);
    });
  });

  group('Classement des pannes', () {
    test('les vraies exceptions réseau sont reconnues', () {
      for (final e in <Object>[
        const SocketException('Failed host lookup'),
        TimeoutException('trop long'),
        const HttpException('connection closed'),
      ]) {
        expect(describeError(e).kind, ErrorKind.offline,
            reason: e.runtimeType.toString());
      }
    });

    test('une panne de base locale oriente vers ce poste', () {
      final e = describeError('SqliteException(5): database is locked');
      expect(e.kind, ErrorKind.local);
      expect(e.message, contains('locale'));
      expect(e.worthReporting, true);
    });

    test('un schéma serveur absent est un incident à remonter', () {
      final e =
          describeError('PostgrestException: function bs_truc does not exist');
      expect(e.kind, ErrorKind.serveur);
      expect(e.worthReporting, true);
      expect(e.message, isNot(contains('bs_truc')));
    });

    test('une erreur inconnue reste lisible et est remontée', () {
      final e = describeError(StateError('Bad state: no element'));
      expect(e.kind, ErrorKind.inattendu);
      expect(e.title, 'Une erreur est survenue');
      expect(e.worthReporting, true);
    });
  });

  group('Erreurs de comptes', () {
    test('leur message déjà rédigé est conservé tel quel', () {
      const src = AccountException(
          AccountErrorKind.rejected, 'Cet identifiant est déjà utilisé.');
      final e = describeError(src);
      expect(e.message, 'Cet identifiant est déjà utilisé.');
      expect(e.kind, ErrorKind.refused);
    });

    test("un refus métier n'alerte personne : c'est un usage normal", () {
      const src =
          AccountException(AccountErrorKind.rejected, 'Droits insuffisants.');
      expect(describeError(src).worthReporting, false);
    });

    test('un compte hors ligne propose de réessayer', () {
      const src =
          AccountException(AccountErrorKind.offline, 'Serveur injoignable.');
      final e = describeError(src);
      expect(e.isRetryable, true);
      expect(e.advice, isNotNull);
    });
  });

  group('Code de référence', () {
    test('la même panne donne toujours le même code', () {
      // C'est ce qui permet de voir qu'une erreur se répète au lieu de
      // la croire nouvelle à chaque fois.
      final a = describeError('SqliteException: disk I/O error');
      final b = describeError('SqliteException: disk I/O error');
      expect(a.reference, b.reference);
    });

    test('les parties variables ne changent pas le code', () {
      // Deux timeouts identiques à la durée près sont la même panne.
      final a = describeError('timed out after 0:00:15.000000, port: 443');
      final b = describeError('timed out after 0:00:30.000000, port: 443');
      expect(a.reference, b.reference);
    });

    test('deux pannes différentes ont des codes différents', () {
      final a = describeError('SqliteException: disk I/O error');
      final b = describeError(StateError('autre chose entièrement'));
      expect(a.reference, isNot(b.reference));
    });

    test('le code est court et citable au téléphone', () {
      final r = describeError('boom').reference;
      expect(r, startsWith('BS-'));
      expect(r.length, 7);
    });
  });

  group('Aucun message ne fuit de technique', () {
    test('sur un échantillon large de pannes réalistes', () {
      const pannes = <String>[
        'SocketException: Failed host lookup: wdwhfgawuozhkeflgcvs.supabase.co',
        'PostgrestException(message: permission denied for function bs_x)',
        'SqliteException(1): no such column: remise_kind',
        'TimeoutException after 0:00:08.000000',
        'Null check operator used on a null value',
      ];
      const interdits = [
        'supabase',
        'Exception',
        'postgrest',
        'sqlite',
        'null check',
        'http',
      ];
      for (final p in pannes) {
        final e = describeError(p);
        final visible =
            '${e.title} ${e.message} ${e.advice ?? ""}'.toLowerCase();
        for (final mot in interdits) {
          expect(visible, isNot(contains(mot.toLowerCase())),
              reason: '« $mot » ne doit pas apparaître pour : $p');
        }
      }
    });
  });
}
