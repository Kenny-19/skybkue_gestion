import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/services/accounts_migration.dart';
import 'package:blue_sky/services/accounts_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Le plan de reprise est une fonction pure : aucun réseau, aucune base.
// C'est volontaire — c'est là que vit la règle « qui monte, qui reste »,
// et c'est la partie qu'on ne veut pas se tromper en production.

User _user(
  String login, {
  String hash = r'$2a$10$abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMN',
  bool localDefault = false,
  DbUserRole role = DbUserRole.serveur,
  bool active = true,
}) =>
    User(
      id: login.hashCode.abs() % 100000,
      fullName: login,
      login: login,
      passwordHash: hash,
      role: role,
      active: active,
      createdAt: DateTime(2026, 1, 1),
      lastLogin: null,
      isLocalDefault: localDefault,
      mustChangePassword: false,
      syncedAt: null,
    );

void main() {
  group('Plan de reprise', () {
    test('un compte local ordinaire est repris', () {
      final plan = AccountsMigration.plan([_user('sabrina')], {});
      expect(plan.single.willImport, true);
      expect(plan.single.skip, isNull);
    });

    test('les comptes de secours ne montent jamais sur le serveur', () {
      final plan = AccountsMigration.plan([
        _user('reception', localDefault: true, role: DbUserRole.reception),
        _user('serveuse', localDefault: true),
        _user('admin', localDefault: true, role: DbUserRole.gerant),
      ], {});
      expect(plan.every((c) => c.skip == SkipReason.localDefault), true);
      expect(plan.every((c) => c.willImport), false);
    });

    test('un compte sans hash utilisable n\'a rien à reprendre', () {
      final plan = AccountsMigration.plan(
          [_user('recrue', hash: kNoOfflineAccessHash)], {});
      expect(plan.single.skip, SkipReason.noUsableHash);
    });

    test('un login déjà sur le serveur n\'est jamais écrasé', () {
      final plan = AccountsMigration.plan([_user('sabrina')], {'sabrina'});
      expect(plan.single.skip, SkipReason.alreadyOnServer);
    });

    test('la comparaison des logins ignore la casse', () {
      final plan = AccountsMigration.plan([_user('Sabrina')], {'sabrina'});
      expect(plan.single.skip, SkipReason.alreadyOnServer);
    });

    test('un compte désactivé est repris quand même — avec son statut', () {
      // Le départ d'un employé doit se propager, pas disparaître.
      final plan = AccountsMigration.plan([_user('parti', active: false)], {});
      expect(plan.single.willImport, true);
      expect(plan.single.user.active, false);
    });

    test('les comptes à reprendre sont listés en premier, puis par rôle', () {
      final plan = AccountsMigration.plan([
        _user('zoe'),
        _user('reception', localDefault: true),
        _user('patron', role: DbUserRole.superAdmin),
        _user('alice'),
      ], {});
      final order = plan.map((c) => c.user.login).toList();
      expect(order.first, 'patron'); // super admin d'abord
      expect(order.sublist(0, 3), ['patron', 'alice', 'zoe']);
      expect(order.last, 'reception'); // ignoré, donc en fin de liste
    });

    test('rejouer la reprise ne propose plus rien', () {
      final locals = [_user('sabrina'), _user('grace')];
      final apres = AccountsMigration.plan(locals, {'sabrina', 'grace'});
      expect(apres.any((c) => c.willImport), false);
    });
  });

  group('Bilan de reprise', () {
    test('compte et résume chaque issue', () {
      const r = MigrationReport([
        MigrationLine('a', MigrationOutcome.imported),
        MigrationLine('b', MigrationOutcome.imported),
        MigrationLine('c', MigrationOutcome.skipped, detail: 'déjà présent'),
        MigrationLine('d', MigrationOutcome.failed, detail: 'jeton expiré'),
      ]);
      expect(r.imported, 2);
      expect(r.skipped, 1);
      expect(r.failed, 1);
      expect(r.isCleanRun, false);
      expect(r.summary, '2 repris · 1 ignoré(s) · 1 en échec');
    });

    test('une reprise sans échec est signalée comme propre', () {
      const r = MigrationReport([
        MigrationLine('a', MigrationOutcome.imported),
      ]);
      expect(r.isCleanRun, true);
      expect(r.summary, '1 repris');
    });
  });

  group("Garde-fou d'autorisation", () {
    test('ni jeton ni super admin → refus avant tout appel réseau', () async {
      final db = newTestDb();
      addTearDown(db.close);
      await expectLater(
        AccountsMigration.run(db, const []),
        throwsA(isA<AccountException>()),
      );
    });

    test('un jeton fait de blancs ne compte pas comme un jeton', () async {
      final db = newTestDb();
      addTearDown(db.close);
      await expectLater(
        AccountsMigration.run(db, const [], token: '   '),
        throwsA(isA<AccountException>()),
      );
    });
  });
}
