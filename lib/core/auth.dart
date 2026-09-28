import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/schema.dart';
import '../services/accounts_service.dart';
import 'horloge.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.instance;
  ref.onDispose(db.close);
  return db;
});

class AuthState {
  final User? user;
  const AuthState(this.user);
  bool get isLoggedIn => user != null;

  /// Le compte porte encore le mot de passe provisoire : l'application
  /// reste fermée tant qu'il n'en a pas choisi un autre.
  bool get mustChangePassword => user?.mustChangePassword ?? false;
}

enum LoginResult { ok, unknownUser, badPassword, inactive, lockedOut }

/// Hash sentinelle posé sur un compte connu du serveur mais jamais
/// connecté sur CE poste : il ne peut matcher aucun mot de passe, donc
/// le compte existe dans la liste sans ouvrir d'accès hors-ligne.
const String kNoOfflineAccessHash = '!no-offline-access';

/// True si [hash] est un vrai hash bcrypt utilisable hors-ligne.
bool isUsableHash(String hash) => hash.startsWith(r'$2');

/// Faut-il se rabattre sur le cache local quand le serveur de comptes a
/// échoué ?
///
/// Oui pour tout ce qui empêche le serveur de TRANCHER : pas de réseau,
/// build sans clés, serveur cassé ou schéma pas encore déployé. Dans ces
/// cas, refuser la connexion reviendrait à fermer l'hôtel parce que
/// Supabase tousse.
///
/// Non pour [AccountErrorKind.rejected] : là le serveur fonctionne et a
/// dit non — le cache local n'a pas à le contredire.
bool shouldFallBackLocally(AccountErrorKind kind) =>
    kind != AccountErrorKind.rejected;

/// Quels comptes du cache local ont le droit d'ouvrir une session.
enum LocalLoginScope {
  /// Tous les comptes en cache. Utilisé quand le serveur n'a pas pu
  /// trancher (hors ligne, serveur cassé) : on fait au mieux avec ce
  /// qu'on a.
  any,

  /// Seulement les comptes que le serveur n'est pas censé connaître :
  /// comptes de secours, et comptes jamais synchronisés (pas encore
  /// repris vers Supabase). Utilisé quand le serveur a répondu
  /// « compte inconnu ».
  notOnServer,
}

/// Résultat complet d'une tentative de connexion — au-delà du verdict,
/// l'écran a besoin de savoir si on a tranché en ligne ou de mémoire,
/// et quoi afficher quand le serveur a répondu autre chose qu'un
/// simple oui/non.
class LoginOutcome {
  final LoginResult result;

  /// True quand le verdict vient du cache local faute de serveur.
  final bool offline;

  /// Message prêt à afficher, quand il est plus précis que [result].
  final String? message;

  /// Secondes restantes de blocage (rate-limit serveur).
  final int lockoutSeconds;

  const LoginOutcome(
    this.result, {
    this.offline = false,
    this.message,
    this.lockoutSeconds = 0,
  });

  bool get isOk => result == LoginResult.ok;
}

/// Résultat détaillé d'une tentative super admin par passphrase.
class SuperAdminAttempt {
  final LoginResult result;

  /// Nombre de secondes restantes de blocage. 0 si non bloqué.
  final int lockoutSeconds;
  const SuperAdminAttempt(this.result, {this.lockoutSeconds = 0});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._db) : super(const AuthState(null));
  final AppDatabase _db;

  // Rate-limit pour la passphrase super admin (mémoire process — reset
  // au redémarrage app, ce qui est OK : un attaquant local a déjà accès
  // au binaire).
  int _superAdminFails = 0;
  DateTime? _superAdminBlockedUntil;

  // Mot de passe de la session courante, gardé EN MÉMOIRE uniquement
  // (jamais persisté, effacé au logout). Les fonctions d'administration
  // des comptes le revérifient côté Supabase à chaque appel : sans lui,
  // il faudrait redemander son mot de passe à Pamela à chaque clic.
  String? _sessionPassword;

  /// Identifiants à présenter aux opérations d'administration des
  /// comptes. Null si personne n'est connecté, ou si la session vient
  /// d'un chemin qui n'a pas vu le mot de passe.
  ({String login, String password})? get actorCredentials {
    final u = state.user;
    final p = _sessionPassword;
    if (u == null || p == null) return null;
    return (login: u.login, password: p);
  }

  /// Met la session à jour après que l'utilisateur a changé SON mot de
  /// passe.
  ///
  /// Sans ça, [actorCredentials] continuerait de présenter l'ancien mot
  /// de passe au serveur, et la première action d'administration qui
  /// suit serait refusée. Recharge aussi l'utilisateur depuis la base
  /// pour que le drapeau « provisoire » soit bien retombé.
  Future<void> refreshSession(String nouveauMotDePasse) async {
    _sessionPassword = nouveauMotDePasse;
    final u = state.user;
    if (u == null) return;
    final frais = await (_db.select(_db.users)..where((x) => x.id.equals(u.id)))
        .getSingleOrNull();
    if (frais != null) state = AuthState(frais);
  }

  /// Connexion.
  ///
  /// Supabase est la source de vérité : on lui demande d'abord de
  /// valider le couple login/mot de passe (le hash ne descend jamais
  /// ici). En cas de succès, on met le compte en cache local **avec un
  /// hash bcrypt du mot de passe** — c'est ce qui permettra à cet
  /// employé de se reconnecter sur ce poste si Internet tombe.
  ///
  /// Deux chemins mènent à la vérification locale :
  ///   * serveur injoignable → on se rabat sur le cache ;
  ///   * serveur qui ne connaît pas ce login → c'est peut-être un des
  ///     comptes de secours locaux (réception / serveuse / admin), qui
  ///     n'existent volontairement pas côté Supabase.
  Future<LoginOutcome> login(String login, String password) async {
    final trimmed = login.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      return const LoginOutcome(LoginResult.badPassword,
          message: 'Saisis ton identifiant et ton mot de passe.');
    }

    if (AccountsService.isAvailable) {
      try {
        final res = await AccountsService.verifyLogin(trimmed, password);
        switch (res.status) {
          case RemoteLoginStatus.ok:
            final account = res.account!;
            final user = await _cacheAccount(account, password);
            _sessionPassword = password;
            state = AuthState(user);
            return const LoginOutcome(LoginResult.ok);
          case RemoteLoginStatus.badPassword:
            // Le serveur connaît le compte et refuse : ne jamais laisser
            // le cache local contredire cette réponse.
            return const LoginOutcome(LoginResult.badPassword);
          case RemoteLoginStatus.inactive:
            return const LoginOutcome(LoginResult.inactive,
                message: 'Ce compte a été désactivé.');
          case RemoteLoginStatus.lockedOut:
            return LoginOutcome(LoginResult.lockedOut,
                lockoutSeconds: res.retryAfterSeconds,
                message: 'Trop de tentatives. Réessaie dans '
                    '${(res.retryAfterSeconds / 60).ceil()} minute(s).');
          case RemoteLoginStatus.unknownUser:
            // Le serveur ne connaît pas ce login. Deux cas très
            // différents :
            //   * compte de secours, ou compte pas ENCORE repris vers
            //     Supabase → il doit continuer à ouvrir l'application,
            //     sinon la bascule enferme toute l'équipe dehors ;
            //   * compte déjà synchronisé puis disparu du serveur →
            //     c'est une suppression, et on la respecte.
            final local = await _localLogin(trimmed, password,
                scope: LocalLoginScope.notOnServer);
            return local ??
                const LoginOutcome(LoginResult.unknownUser,
                    message: "Ce compte n'existe plus sur le serveur.");
        }
      } on AccountException catch (e) {
        // Le serveur n'a pas pu trancher → on se rabat sur le cache
        // local. Une panne côté serveur ne doit JAMAIS enfermer la
        // réception dehors : c'est la raison d'être des comptes de
        // secours.
        if (shouldFallBackLocally(e.kind)) {
          final local = await _localLogin(trimmed, password);
          if (local != null) return local;
          return LoginOutcome(LoginResult.unknownUser,
              offline: true,
              message: e.kind == AccountErrorKind.offline
                  ? "Hors ligne, et ce compte ne s'est jamais connecté sur "
                      "ce poste. Utilise un compte de secours (reception, "
                      "serveuse ou admin)."
                  : "${e.message} Utilise un compte de secours en attendant "
                      "(reception, serveuse ou admin).");
        }
        // Refus explicite d'un serveur qui fonctionne : le cache local
        // n'a pas à contredire cette réponse.
        return LoginOutcome(LoginResult.unknownUser, message: e.message);
      }
    }

    // Build sans cloud configuré : 100 % local.
    final local = await _localLogin(trimmed, password);
    return local ??
        const LoginOutcome(LoginResult.unknownUser,
            offline: true, message: 'Compte inconnu sur ce poste.');
  }

  /// Vérifie un mot de passe contre le cache local (bcrypt).
  ///
  /// [scope] borne les comptes acceptés — cf. [LocalLoginScope].
  ///
  /// Retourne null si aucun compte local ne correspond — l'appelant
  /// choisit alors le message.
  Future<LoginOutcome?> _localLogin(String login, String password,
      {LocalLoginScope scope = LocalLoginScope.any}) async {
    final candidates = await (_db.select(_db.users)
          ..where((u) => u.login.lower().equals(login.toLowerCase())))
        .get();
    if (candidates.isEmpty) return null;
    final user = candidates.first;
    // Un compte que le serveur ne connaît pas n'est acceptable en local
    // que s'il n'a jamais été synchronisé : soit un compte de secours,
    // soit un compte pas encore repris vers Supabase. En revanche, un
    // compte DÉJÀ synchronisé qui disparaît du serveur a été supprimé —
    // son cache local ne doit pas le ressusciter.
    if (scope == LocalLoginScope.notOnServer &&
        !user.isLocalDefault &&
        user.syncedAt != null) {
      return null;
    }
    if (!user.active) {
      return const LoginOutcome(LoginResult.inactive,
          offline: true, message: 'Ce compte a été désactivé.');
    }
    if (!isUsableHash(user.passwordHash)) {
      return const LoginOutcome(LoginResult.badPassword,
          offline: true,
          message: 'Ce compte doit se connecter une première fois avec '
              'Internet sur ce poste.');
    }
    bool ok;
    try {
      ok = BCrypt.checkpw(password, user.passwordHash);
    } catch (_) {
      // Hash corrompu : on refuse plutôt que de planter l'écran.
      ok = false;
    }
    if (!ok) {
      return const LoginOutcome(LoginResult.badPassword, offline: true);
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id)))
        .write(UsersCompanion(lastLogin: Value(Horloge.maintenant())));
    final refreshed = await (_db.select(_db.users)
          ..where((u) => u.id.equals(user.id)))
        .getSingleOrNull();
    if (refreshed == null) return null;
    _sessionPassword = password;
    state = AuthState(refreshed);
    return LoginOutcome(LoginResult.ok, offline: !user.isLocalDefault);
  }

  /// Met un compte validé par le serveur en cache local, avec le hash
  /// bcrypt du mot de passe pour permettre la reconnexion hors-ligne.
  /// Le cache est indexé par login (les ids locaux et distants diffèrent).
  Future<User> _cacheAccount(RemoteAccount account, String password) async {
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final role =
        DbUserRole.values[account.role.clamp(0, DbUserRole.values.length - 1)];
    final existing = await (_db.select(_db.users)
          ..where((u) => u.login.lower().equals(account.login.toLowerCase())))
        .getSingleOrNull();

    if (existing == null) {
      final id = await _db.into(_db.users).insert(UsersCompanion.insert(
            fullName: account.fullName,
            login: account.login,
            passwordHash: hash,
            role: role,
            active: Value(account.active),
            createdAt: Value(account.createdAt ?? Horloge.maintenant()),
            lastLogin: Value(Horloge.maintenant()),
            syncedAt: Value(Horloge.maintenant()),
          ));
      return (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingle();
    }

    await (_db.update(_db.users)..where((u) => u.id.equals(existing.id)))
        .write(UsersCompanion(
      fullName: Value(account.fullName),
      passwordHash: Value(hash),
      role: Value(role),
      active: Value(account.active),
      lastLogin: Value(Horloge.maintenant()),
      syncedAt: Value(Horloge.maintenant()),
      isLocalDefault: const Value(false),
    ));
    return (_db.select(_db.users)..where((u) => u.id.equals(existing.id)))
        .getSingle();
  }

  /// Connexion super admin par PASSPHRASE seule (pas de login).
  /// La passphrase est comparée au hash bcrypt de tous les comptes super
  /// admin locaux — le premier match connecte. 3 tentatives ratées →
  /// blocage 60 s, puis 5 min au-delà.
  Future<SuperAdminAttempt> loginSuperAdminByPassphrase(
      String passphrase) async {
    final now = Horloge.maintenant();
    if (_superAdminBlockedUntil != null &&
        now.isBefore(_superAdminBlockedUntil!)) {
      final left = _superAdminBlockedUntil!.difference(now).inSeconds;
      return SuperAdminAttempt(LoginResult.lockedOut, lockoutSeconds: left);
    }

    final supers = await (_db.select(_db.users)
          ..where((u) =>
              u.role.equals(DbUserRole.superAdmin.index) &
              u.active.equals(true)))
        .get();
    if (supers.isEmpty) {
      return const SuperAdminAttempt(LoginResult.unknownUser);
    }

    User? matched;
    for (final s in supers) {
      // Un super admin connu du serveur mais jamais connecté ici porte
      // un hash sentinelle. BCrypt lève sur tout ce qui n'est pas un
      // vrai hash, et l'exception remontait jusqu'au rapport d'erreurs :
      // un e-mail partait à CHAQUE tentative de connexion, et l'écran
      // tombait au lieu d'afficher un refus.
      if (!isUsableHash(s.passwordHash)) continue;
      try {
        if (BCrypt.checkpw(passphrase, s.passwordHash)) {
          matched = s;
          break;
        }
      } catch (_) {
        // Hash corrompu : ce compte ne peut matcher personne. On passe
        // au suivant plutôt que de bloquer tous les autres.
        continue;
      }
    }

    // Personne en local. Avant de refuser : certains super admins
    // n'ont PAS de hash utilisable sur ce poste.
    //
    // C'est la conséquence de la bascule vers des comptes hébergés
    // exclusivement sur Supabase. Un compte connu du serveur mais jamais
    // connecté ici porte un hash sentinelle, qui veut dire « demande au
    // serveur ». Sauf qu'ici il n'y avait personne à qui demander : ce
    // chemin de connexion était resté 100 % local, et il enfermait
    // dehors le propriétaire de l'application — arrivé le 21 septembre
    // 2026, compte `kenny`, actif côté serveur et refusé sur le poste.
    if (matched == null && AccountsService.isAvailable) {
      final sansAccesLocal =
          supers.where((s) => !isUsableHash(s.passwordHash)).toList();
      for (final s in sansAccesLocal) {
        try {
          final res = await AccountsService.verifyLogin(s.login, passphrase);
          if (res.status == RemoteLoginStatus.ok && res.account != null) {
            // Vérifié par le serveur : on met le compte en cache avec un
            // hash local, pour que la prochaine coupure ne le renferme
            // pas dehors.
            final user = await _cacheAccount(res.account!, passphrase);
            _superAdminFails = 0;
            _superAdminBlockedUntil = null;
            _sessionPassword = passphrase;
            state = AuthState(user);
            return const SuperAdminAttempt(LoginResult.ok);
          }
        } catch (_) {
          // Hors ligne ou serveur muet : on passe au suivant, et on
          // finira sur le refus local. Une coupure ne doit pas se
          // raconter comme un mauvais mot de passe.
          continue;
        }
      }
    }

    if (matched == null) {
      _superAdminFails++;
      // Palier de blocage progressif.
      if (_superAdminFails >= 3) {
        final penalty = _superAdminFails >= 5
            ? const Duration(minutes: 5)
            : const Duration(seconds: 60);
        _superAdminBlockedUntil = now.add(penalty);
        return SuperAdminAttempt(LoginResult.lockedOut,
            lockoutSeconds: penalty.inSeconds);
      }
      return const SuperAdminAttempt(LoginResult.badPassword);
    }

    _superAdminFails = 0;
    _superAdminBlockedUntil = null;
    _sessionPassword = passphrase;
    await (_db.update(_db.users)..where((u) => u.id.equals(matched!.id)))
        .write(UsersCompanion(lastLogin: Value(Horloge.maintenant())));
    final refreshed = await (_db.select(_db.users)
          ..where((u) => u.id.equals(matched!.id)))
        .getSingle();
    state = AuthState(refreshed);
    return const SuperAdminAttempt(LoginResult.ok);
  }

  void logout() {
    _sessionPassword = null;
    state = const AuthState(null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(dbProvider)),
);

/// Permissions dérivées du rôle courant.
///
/// Matrice résumée :
/// - Super Admin : tout
/// - Admin       : tout SAUF gestion des super admins + réglages système
/// - Serveur     : POS + catalogue + rooms (check-in/out) + dashboard
/// - Réception   : rooms (check-in/out) + dashboard **restreint aux chambres**
///                 uniquement — pas de POS, pas de catalogue, pas d'historique
class Perms {
  final DbUserRole? role;
  const Perms(this.role);

  /// Vrai si le rôle est purement "réception" — ce flag pilote l'UI :
  /// dashboard filtré (rooms only), pas de POS/Catalogue/Historique.
  bool get isReception => role == DbUserRole.reception;

  bool get canPos => role != null && role != DbUserRole.reception;
  bool get canViewCatalog => role != null && role != DbUserRole.reception;
  bool get canEditCatalog =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;
  bool get canStock =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;
  // Onglet Chambres : réception + admin + super admin. Serveur/serveuse
  // exclu explicitement (il travaille au bar/restaurant, n'a pas
  // besoin de voir l'état des chambres).
  bool get canRooms =>
      role == DbUserRole.reception ||
      role == DbUserRole.gerant ||
      role == DbUserRole.superAdmin;
  // Réception peut désormais gérer entièrement les chambres : créer,
  // éditer, supprimer.
  bool get canEditRooms =>
      role == DbUserRole.reception ||
      role == DbUserRole.gerant ||
      role == DbUserRole.superAdmin;
  // Dashboard accessible à tous les rôles connectés. Pour la réception,
  // le contenu affiché est filtré aux chambres uniquement.
  bool get canDashboard => role != null;
  // Historique accessible à tous les rôles connectés, mais chacun ne
  // voit que le sien. Le détail est dans les deux droits ci-dessous.
  bool get canHistory => role != null;

  /// Voir l'historique de l'HÔTEL : séjours facturés, départs, recettes
  /// d'hébergement.
  ///
  /// La réception, parce que c'est son métier. Pas les serveuses : les
  /// séjours facturés portent des noms de clients, des montants négociés
  /// et des coordonnées de sociétés, qui ne les regardent pas.
  bool get canHistoriqueHotel =>
      role == DbUserRole.reception ||
      role == DbUserRole.gerant ||
      role == DbUserRole.superAdmin;

  /// Voir l'historique des VENTES : bar, restaurant, terrasse.
  ///
  /// Les serveuses, parce qu'elles y retrouvent leurs propres tickets.
  /// Pas la réception : les transactions du bar noyaient ses séjours et
  /// ne la concernent pas.
  bool get canHistoriqueVentes =>
      role == DbUserRole.serveur ||
      role == DbUserRole.gerant ||
      role == DbUserRole.superAdmin;
  // Suppression d'une facture / vente depuis l'historique : admin + super admin.
  bool get canDeleteSale =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;

  /// Accorder une remise ou un tarif négocié.
  ///
  /// La réception l'a parce qu'elle gère l'hôtel et négocie les séjours.
  /// Les serveuses ne l'ont PAS : une remise, c'est de l'argent qui sort,
  /// et le bar n'a pas à en décider.
  ///
  /// Ce getter masque les contrôles à l'écran. Il ne protège rien tant
  /// que la règle n'est pas rejouée côté serveur dans la RPC — cf. le
  /// document d'architecture.
  bool get canDiscount =>
      role == DbUserRole.superAdmin ||
      role == DbUserRole.gerant ||
      role == DbUserRole.reception;

  bool get canManageServeurs =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;
  bool get canManageGerants => role == DbUserRole.superAdmin;

  /// Supprimer définitivement un compte : super admin seul.
  bool get canDeleteAccounts => role == DbUserRole.superAdmin;

  /// Écrans "Clients" (fidélité) + "Sociétés" (payeurs tiers) :
  /// admin + super admin (données commerciales sensibles).
  bool get canClients =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;
  bool get canPayers =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;

  /// Réservations : mêmes droits que la gestion des chambres — réception
  /// + admin + super admin peuvent créer, modifier, annuler, arrivée.
  bool get canReservations =>
      role == DbUserRole.reception ||
      role == DbUserRole.gerant ||
      role == DbUserRole.superAdmin;
  bool get canSettings => role == DbUserRole.superAdmin;

  /// Modifier le taux de change FC→USD : admin ET super admin.
  bool get canCurrency =>
      role == DbUserRole.gerant || role == DbUserRole.superAdmin;
}

final permsProvider = Provider<Perms>((ref) {
  final auth = ref.watch(authProvider);
  return Perms(auth.user?.role);
});

/// Helpers d'affichage pour DbUserRole (label + couleur).
extension DbUserRoleUi on DbUserRole {
  String get label => switch (this) {
        DbUserRole.superAdmin => 'Super Admin',
        DbUserRole.gerant => 'Gérant',
        DbUserRole.serveur => 'Serveur',
        DbUserRole.reception => 'Réception',
      };
}
