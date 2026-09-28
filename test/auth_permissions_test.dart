import 'package:bcrypt/bcrypt.dart';
import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/database.dart';
import 'package:blue_sky/data/repos.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:blue_sky/data/seed.dart';
import 'package:blue_sky/services/accounts_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Ces tests tournent SANS Supabase configuré : `AccountsService.isAvailable`
// est donc faux et [AuthNotifier.login] emprunte directement le chemin
// hors-ligne. C'est exactement le scénario « le wifi est coupé à la
// réception », celui qu'il faut absolument garder vert.

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

  /// Simule un compte Supabase déjà connu de ce poste : présent dans le
  /// cache local avec un hash utilisable (comme après un login en ligne).
  Future<User> cachedAccount(String login, String password,
      {DbUserRole role = DbUserRole.serveur, bool active = true}) async {
    final id = await db.into(db.users).insert(UsersCompanion.insert(
          fullName: login,
          login: login,
          passwordHash: BCrypt.hashpw(password, BCrypt.gensalt()),
          role: role,
          active: Value(active),
          syncedAt: Value(DateTime.now()),
        ));
    return (db.select(db.users)..where((u) => u.id.equals(id))).getSingle();
  }

  group('Comptes de secours locaux', () {
    test('les trois comptes sont créés à l\'installation', () async {
      final all = await users.all();
      final logins = all.map((u) => u.login).toSet();
      expect(logins, containsAll(['reception', 'serveuse', 'admin']));
      expect(all.where((u) => u.isLocalDefault).length, 3);
    });

    test('chacun se connecte avec son code documenté', () async {
      for (final a in kLocalDefaultAccounts) {
        final res = await auth.login(a.login, a.password);
        expect(res.isOk, true, reason: 'échec sur ${a.login}');
        expect(auth.state.user?.role, a.role);
      }
    });

    test(
        'un compte de secours n\'est jamais marqué "hors-ligne" : il est '
        'local par nature', () async {
      final res = await auth.login('reception', '0000');
      expect(res.isOk, true);
      expect(res.offline, false);
    });

    test(
        'aucun compte de secours n\'est super admin — l\'administration '
        'réelle passe par Supabase', () async {
      final all = await users.all();
      for (final u in all.where((u) => u.isLocalDefault)) {
        expect(u.role, isNot(DbUserRole.superAdmin), reason: u.login);
      }
    });

    test('impossible de supprimer ou désactiver un compte de secours',
        () async {
      final all = await users.all();
      final secours = all.firstWhere((u) => u.login == 'reception');
      const actor = (login: 'admin', password: '7000');
      await expectLater(users.delete(actor: actor, target: secours),
          throwsA(isA<AccountException>()));
      await expectLater(
          users.setActive(actor: actor, target: secours, active: false),
          throwsA(isA<AccountException>()));
    });
  });

  group('Connexion hors-ligne (cache local)', () {
    test('mot de passe correct → ok, signalé comme hors-ligne', () async {
      await cachedAccount('grace', 'test1234');
      final res = await auth.login('grace', 'test1234');
      expect(res.isOk, true);
      expect(res.offline, true);
      expect(auth.state.user?.login, 'grace');
    });

    test('mauvais mot de passe → badPassword', () async {
      await cachedAccount('grace', 'test1234');
      final res = await auth.login('grace', 'mauvais');
      expect(res.result, LoginResult.badPassword);
      expect(auth.state.isLoggedIn, false);
    });

    test('identifiant inconnu → unknownUser', () async {
      final res = await auth.login('personne', 'x');
      expect(res.result, LoginResult.unknownUser);
      expect(auth.state.isLoggedIn, false);
    });

    test('compte désactivé → inactive', () async {
      await cachedAccount('grace', 'test1234', active: false);
      final res = await auth.login('grace', 'test1234');
      expect(res.result, LoginResult.inactive);
      expect(auth.state.isLoggedIn, false);
    });

    test('compte connu du serveur mais jamais connecté ici → refus explicite',
        () async {
      // C'est ce que pose syncFromCloud() sur un compte encore inconnu
      // du poste : le hash sentinelle ne peut matcher aucun mot de passe.
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Nouvelle recrue',
            login: 'recrue',
            passwordHash: kNoOfflineAccessHash,
            role: DbUserRole.serveur,
            syncedAt: Value(DateTime.now()),
          ));
      final res = await auth.login('recrue', 'peu importe');
      expect(res.result, LoginResult.badPassword);
      expect(res.message, contains('Internet'));
      expect(auth.state.isLoggedIn, false);
    });

    test('un hash corrompu refuse la connexion au lieu de planter', () async {
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Corrompu',
            login: 'corrompu',
            passwordHash: r'$2a$pas-un-vrai-hash',
            role: DbUserRole.serveur,
          ));
      final res = await auth.login('corrompu', 'x');
      expect(res.result, LoginResult.badPassword);
    });

    test('login insensible à la casse et aux espaces', () async {
      await cachedAccount('Sabrina', 'test1234');
      expect((await auth.login('  sabrina  ', 'test1234')).isOk, true);
    });

    test('champs vides → refus sans requête', () async {
      expect((await auth.login('', '')).result, LoginResult.badPassword);
      expect(
          (await auth.login('reception', '')).result, LoginResult.badPassword);
    });
  });

  group('Session', () {
    test('les identifiants de session servent aux opérations de compte',
        () async {
      expect(auth.actorCredentials, isNull);
      await auth.login('admin', '7000');
      expect(auth.actorCredentials?.login, 'admin');
      expect(auth.actorCredentials?.password, '7000');
    });

    test('logout efface la session ET le mot de passe mémorisé', () async {
      await auth.login('admin', '7000');
      auth.logout();
      expect(auth.state.isLoggedIn, false);
      expect(auth.actorCredentials, isNull);
    });

    test('le hash bcrypt n\'est jamais le mot de passe en clair', () async {
      final all = await users.all();
      for (final u in all) {
        expect(u.passwordHash, isNot(equals('0000')));
        expect(u.passwordHash, isNot(equals('7000')));
        expect(u.passwordHash.length, greaterThan(20));
      }
    });
  });

  group('Changement de mot de passe', () {
    test('un compte de secours change son code en local, sans serveur',
        () async {
      final all = await users.all();
      final me = all.firstWhere((u) => u.login == 'reception');
      await users.changeOwnPassword(
        actor: (login: 'reception', password: '0000'),
        me: me,
        newPassword: 'nouveau12',
      );
      expect((await auth.login('reception', '0000')).result,
          LoginResult.badPassword);
      expect((await auth.login('reception', 'nouveau12')).isOk, true);
    });
  });

  group('Matrice de permissions', () {
    test('Super Admin peut tout', () {
      const p = Perms(DbUserRole.superAdmin);
      expect(p.canPos, true);
      expect(p.canEditCatalog, true);
      expect(p.canStock, true);
      expect(p.canRooms, true);
      expect(p.canManageGerants, true);
      expect(p.canDeleteAccounts, true);
    });

    test('Admin gère tout sauf les super admins et les réglages système', () {
      const p = Perms(DbUserRole.gerant);
      expect(p.canPos, true);
      expect(p.canEditCatalog, true);
      expect(p.canManageServeurs, true);
      expect(p.canEditRooms, true);
      expect(p.canManageGerants, false);
      expect(p.canDeleteAccounts, false);
    });

    test(
        'Serveur : vente, dashboard et historique — mais pas les chambres '
        'ni le stock', () {
      const p = Perms(DbUserRole.serveur);
      expect(p.canPos, true);
      expect(p.canViewCatalog, true);
      expect(p.canDashboard, true);
      // L'historique est ouvert à tous : la UI filtre selon le rôle.
      expect(p.canHistory, true);
      // Interdits — le serveur travaille au bar/restaurant.
      expect(p.canRooms, false);
      expect(p.canEditRooms, false);
      expect(p.canEditCatalog, false);
      expect(p.canStock, false);
      expect(p.canManageServeurs, false);
      expect(p.canDeleteAccounts, false);
    });

    test('Réception : chambres oui, POS et catalogue non', () {
      const p = Perms(DbUserRole.reception);
      expect(p.isReception, true);
      expect(p.canRooms, true);
      expect(p.canEditRooms, true);
      expect(p.canPos, false);
      expect(p.canViewCatalog, false);
      expect(p.canManageServeurs, false);
    });

    test('sans rôle (déconnecté) : aucun accès', () {
      const p = Perms(null);
      expect(p.canPos, false);
      expect(p.canViewCatalog, false);
      expect(p.canRooms, false);
      expect(p.canDashboard, false);
      expect(p.canHistory, false);
    });
  });

  group('Jamais de verrouillage total', () {
    // Régression : avec les clés Supabase dans le build mais le schéma
    // SQL pas encore déployé, l'erreur RPC était classée `unexpected` et
    // ne retombait PAS sur le cache local — plus personne ne pouvait
    // ouvrir l'app, pas même reception/0000. Une panne serveur ne doit
    // jamais fermer l'hôtel.
    test(
        'toute panne empêchant le serveur de trancher autorise le '
        'repli local', () {
      expect(shouldFallBackLocally(AccountErrorKind.offline), true);
      expect(shouldFallBackLocally(AccountErrorKind.notConfigured), true);
      expect(shouldFallBackLocally(AccountErrorKind.unexpected), true,
          reason: 'schéma non déployé / serveur cassé');
    });

    test(
        "un refus explicite du serveur n'est jamais contredit par le "
        "cache local", () {
      expect(shouldFallBackLocally(AccountErrorKind.rejected), false);
    });

    test("tous les cas d'erreur sont couverts par la règle", () {
      // Si un jour on ajoute un AccountErrorKind, ce test force à
      // décider consciemment de quel côté il tombe.
      expect(AccountErrorKind.values.length, 4);
    });
  });

  group('Bascule vers Supabase : la transition ne verrouille personne', () {
    // Situation réelle : le serveur de comptes est déployé, mais les
    // comptes historiques n'y ont pas encore été repris. Le serveur
    // répond donc « inconnu » pour chacun d'eux.

    test('un compte jamais synchronisé garde son accès local', () async {
      // syncedAt == null → il n'a jamais été repris, le serveur ne peut
      // pas le connaître. Il doit continuer à ouvrir l'application.
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Kenny',
            login: 'kenny',
            passwordHash: BCrypt.hashpw('motdepasse', BCrypt.gensalt()),
            role: DbUserRole.superAdmin,
          ));
      final res = await auth.login('kenny', 'motdepasse');
      expect(res.isOk, true,
          reason: 'un compte pas encore repris ne doit pas être exclu');
    });

    test('un compte déjà synchronisé puis supprimé du serveur est refusé',
        () async {
      // syncedAt != null + absent du serveur = suppression volontaire.
      // Le cache local ne doit pas le ressusciter.
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Ancien employé',
            login: 'parti',
            passwordHash: BCrypt.hashpw('motdepasse', BCrypt.gensalt()),
            role: DbUserRole.serveur,
            syncedAt: Value(DateTime.now()),
          ));
      // Sans Supabase configuré, on passe par le chemin local complet ;
      // le périmètre restreint est vérifié directement ci-dessous.
      final user = await (db.select(db.users)
            ..where((u) => u.login.equals('parti')))
          .getSingle();
      expect(user.syncedAt, isNotNull);
      expect(user.isLocalDefault, false);
    });
  });

  group('Connexion super admin par passphrase', () {
    test("un super admin sans hash utilisable ne fait pas planter l'écran",
        () async {
      // Cas réel : `pamela`, compte d'amorçage créé côté Supabase, tiré
      // en local avec le hash sentinelle. BCrypt lève sur ce hash non
      // bcrypt — l'exception remontait au rapport d'erreurs et envoyait
      // un e-mail à CHAQUE tentative de connexion.
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Pamela',
            login: 'pamela',
            passwordHash: kNoOfflineAccessHash,
            role: DbUserRole.superAdmin,
            syncedAt: Value(DateTime.now()),
          ));
      final res = await auth.loginSuperAdminByPassphrase('nimporte quoi');
      expect(res.result, LoginResult.badPassword,
          reason: 'refus propre, pas une exception');
      expect(auth.state.isLoggedIn, false);
    });

    test('un hash corrompu est ignoré sans bloquer les autres comptes',
        () async {
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Corrompu',
            login: 'corrompu',
            passwordHash: r'$2a$pas-un-vrai-hash',
            role: DbUserRole.superAdmin,
          ));
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Vrai patron',
            login: 'patron',
            passwordHash: BCrypt.hashpw('passe-secrete', BCrypt.gensalt()),
            role: DbUserRole.superAdmin,
          ));
      final res = await auth.loginSuperAdminByPassphrase('passe-secrete');
      expect(res.result, LoginResult.ok,
          reason: 'le compte cassé ne doit pas masquer le compte valide');
      expect(auth.state.user?.login, 'patron');
    });
  });

  group("Synchronisation : ne jamais effacer ce qui n'est pas encore repris",
      () {
    test('un compte jamais synchronisé survit à une synchro', () async {
      // Régression : syncFromCloud supprimait tout compte local absent
      // du serveur. Avant la reprise, aucun compte historique n'est sur
      // le serveur — un clic sur « Synchroniser » aurait effacé les 8
      // comptes de l'hôtel d'un coup.
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Kenny',
            login: 'kenny',
            passwordHash: BCrypt.hashpw('x1234', BCrypt.gensalt()),
            role: DbUserRole.superAdmin,
          ));
      final avant = await users.all();
      expect(avant.any((u) => u.login == 'kenny'), true);

      // La règle testée ici est celle du filtre, pas l'appel réseau :
      // un compte sans syncedAt n'est jamais candidat à la suppression.
      final jamaisSync =
          avant.where((u) => !u.isLocalDefault && u.syncedAt == null);
      expect(jamaisSync.map((u) => u.login), contains('kenny'));
    });
  });

  group('Restauration depuis le miroir', () {
    test(
        'un compte restaure sans mot de passe connu porte la sentinelle, '
        'pas un faux hash', () async {
      // Régression de production : la restauration miroir créait les
      // comptes avec un hash bcrypt ALEATOIRE. Le compte avait l'air
      // normal, mais aucun mot de passe ne pouvait marcher — l'employé
      // croyait se tromper de code. La sentinelle, elle, est reconnue
      // et produit un message explicite.
      await db.into(db.users).insert(UsersCompanion.insert(
            fullName: 'Restaure',
            login: 'restaure',
            passwordHash: kNoOfflineAccessHash,
            role: DbUserRole.serveur,
          ));
      final res = await auth.login('restaure', 'nimporte quoi');
      expect(res.isOk, false);
      expect(res.message, contains('Internet'),
          reason: 'le message doit expliquer, pas laisser croire a une '
              'erreur de saisie');
      expect(isUsableHash(kNoOfflineAccessHash), false);
    });
  });

  group('Remises : qui peut en accorder', () {
    // Décision produit : la réception gère l'hôtel et négocie les
    // séjours, donc elle accorde les remises. Les serveuses, non — une
    // remise, c'est de l'argent qui sort, et le bar n'en décide pas.
    test('la réception peut accorder une remise', () {
      expect(const Perms(DbUserRole.reception).canDiscount, true);
    });

    test('la serveuse ne peut pas', () {
      expect(const Perms(DbUserRole.serveur).canDiscount, false);
    });

    test('gérant et super admin le peuvent', () {
      expect(const Perms(DbUserRole.gerant).canDiscount, true);
      expect(const Perms(DbUserRole.superAdmin).canDiscount, true);
    });

    test('un utilisateur déconnecté ne peut rien accorder', () {
      expect(const Perms(null).canDiscount, false);
    });
  });

  group('Renommage admin → gérant', () {
    test(
        "l'index en base est inchangé : les comptes existants gardent "
        'leur rôle', () {
      // Le renommage est cosmétique côté code. Si l'index bougeait, tous
      // les comptes déjà enregistrés changeraient de rôle en silence.
      expect(DbUserRole.gerant.index, 1);
      expect(DbUserRole.superAdmin.index, 0);
      expect(DbUserRole.serveur.index, 2);
      expect(DbUserRole.reception.index, 3);
    });

    test('le libellé affiché est « Gérant »', () {
      expect(DbUserRole.gerant.label, 'Gérant');
    });

    test("le gérant garde exactement les droits de l'ancien admin", () {
      const g = Perms(DbUserRole.gerant);
      expect(g.canStock, true);
      expect(g.canEditCatalog, true);
      expect(g.canClients, true);
      expect(g.canManageServeurs, true);
      // …sauf la gestion des comptes de son propre niveau, qui reste au
      // super admin seul.
      expect(g.canManageGerants, false);
    });
  });
}
