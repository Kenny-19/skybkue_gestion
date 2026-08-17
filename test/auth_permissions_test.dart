import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late AuthNotifier auth;
  late UsersRepo users;

  setUp(() async {
    db = newTestDb();
    auth = AuthNotifier(db);
    users = UsersRepo(db);
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  group('Connexion (bcrypt)', () {
    test('bon identifiant + bon mot de passe → ok', () async {
      final res = await auth.login('kenny', 'bluesky');
      expect(res, LoginResult.ok);
      expect(auth.state.user?.login, 'kenny');
      expect(auth.state.user?.role, DbUserRole.superAdmin);
    });

    test('mauvais mot de passe → badPassword', () async {
      final res = await auth.login('kenny', 'mauvais');
      expect(res, LoginResult.badPassword);
      expect(auth.state.isLoggedIn, false);
    });

    test('identifiant inconnu → unknownUser', () async {
      final res = await auth.login('personne', 'x');
      expect(res, LoginResult.unknownUser);
    });

    test('compte désactivé → inactive', () async {
      final id = await users.create(
        fullName: 'Grace M',
        login: 'grace',
        password: 'test1234',
        role: DbUserRole.serveur,
      );
      await users.setActive(id, false);
      final res = await auth.login('grace', 'test1234');
      expect(res, LoginResult.inactive);
    });

    test('le hash bcrypt n\'est jamais le mot de passe en clair', () async {
      await users.create(
        fullName: 'Test Hash',
        login: 'hashuser',
        password: 'secret42',
        role: DbUserRole.serveur,
      );
      final u = await (db.select(db.users)
            ..where((x) => x.login.equals('hashuser')))
          .getSingle();
      expect(u.passwordHash, isNot('secret42'));
      expect(u.passwordHash.startsWith(r'$2'), true); // préfixe bcrypt
    });

    test('la connexion met à jour lastLogin', () async {
      final before = (await (db.select(db.users)
                ..where((x) => x.login.equals('kenny')))
              .getSingle())
          .lastLogin;
      await auth.login('kenny', 'bluesky');
      final after = (await (db.select(db.users)
                ..where((x) => x.login.equals('kenny')))
              .getSingle())
          .lastLogin;
      expect(before, isNull);
      expect(after, isNotNull);
    });

    test('logout vide la session', () async {
      await auth.login('kenny', 'bluesky');
      expect(auth.state.isLoggedIn, true);
      auth.logout();
      expect(auth.state.isLoggedIn, false);
    });
  });

  group('Matrice de permissions', () {
    test('Super Admin peut tout', () {
      const p = Perms(DbUserRole.superAdmin);
      expect(p.canPos, true);
      expect(p.canEditCatalog, true);
      expect(p.canStock, true);
      expect(p.canDashboard, true);
      expect(p.canHistory, true);
      expect(p.canManageServeurs, true);
      expect(p.canManageAdmins, true);
      expect(p.canSettings, true);
      expect(p.canEditRooms, true);
    });

    test('Admin gère tout sauf les super admins et les réglages système', () {
      const p = Perms(DbUserRole.admin);
      expect(p.canStock, true);
      expect(p.canDashboard, true);
      expect(p.canManageServeurs, true);
      expect(p.canEditRooms, true);
      expect(p.canManageAdmins, false);
      expect(p.canSettings, false);
    });

    test('Serveur : vente + dashboard, mais rien de sensible', () {
      const p = Perms(DbUserRole.serveur);
      expect(p.canPos, true);
      expect(p.canViewCatalog, true);
      expect(p.canRooms, true); // check-in/out autorisé
      expect(p.canDashboard, true); // dashboard ouvert aux serveuses
      // Interdits :
      expect(p.canEditCatalog, false);
      expect(p.canStock, false);
      expect(p.canHistory, false);
      expect(p.canManageServeurs, false);
      expect(p.canEditRooms, false);
      expect(p.canSettings, false);
    });

    test('sans rôle (déconnecté) : aucun accès', () {
      const p = Perms(null);
      expect(p.canPos, false);
      expect(p.canViewCatalog, false);
      expect(p.canRooms, false);
    });
  });

  group('Gestion des comptes', () {
    test('identifiant en double → exception', () async {
      await expectLater(
        users.create(
          fullName: 'Doublon',
          login: 'kenny', // déjà pris par le seed
          password: 'x1234',
          role: DbUserRole.serveur,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('resetPassword change le hash et permet la nouvelle connexion',
        () async {
      final id = await users.create(
        fullName: 'Reset Me',
        login: 'resetme',
        password: 'ancien12',
        role: DbUserRole.serveur,
      );
      await users.resetPassword(id, 'nouveau12');
      expect(await auth.login('resetme', 'ancien12'), LoginResult.badPassword);
      expect(await auth.login('resetme', 'nouveau12'), LoginResult.ok);
    });
  });
}
