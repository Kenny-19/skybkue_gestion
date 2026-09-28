import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud_config.dart';
import 'error_reporter.dart';

// Accès aux comptes utilisateurs — Supabase est la SOURCE DE VÉRITÉ.
//
// Rien ici ne fait confiance au client :
//   * le hash du mot de passe ne descend jamais sur le poste — la
//     vérification se fait par la fonction `bs_verify_login` ;
//   * toute écriture exige les identifiants d'un admin, revérifiés côté
//     serveur (posséder la clé anon ne suffit pas) ;
//   * la liste des comptes vient de la vue `app_users_public`, qui
//     n'expose pas le hash.
//
// Voir sql/2026_09_comptes_supabase.sql pour le contrat exact.

/// Pourquoi une opération sur les comptes a échoué. Sert à afficher un
/// message juste — « pas de réseau » et « mot de passe faux » n'appellent
/// pas la même réaction de la réception.
enum AccountErrorKind {
  /// Cloud non configuré dans ce build (clé absente).
  notConfigured,

  /// Réseau injoignable / timeout. L'opération pourra être retentée.
  offline,

  /// Refus métier renvoyé par le serveur (login pris, droits, etc.).
  rejected,

  /// Réponse inattendue — bug côté app ou schéma SQL pas à jour.
  unexpected,
}

/// Échec d'une opération sur les comptes, avec un message déjà en
/// français prêt à afficher.
class AccountException implements Exception {
  final AccountErrorKind kind;
  final String message;

  /// Code brut renvoyé par Postgres (`LOGIN_DEJA_PRIS`…) quand il y en a.
  final String? code;

  const AccountException(this.kind, this.message, {this.code});

  bool get isRetryable => kind == AccountErrorKind.offline;

  @override
  String toString() => message;
}

/// Compte tel que Supabase le décrit (jamais de hash).
class RemoteAccount {
  final int id;
  final String login;
  final String fullName;
  final int role;
  final bool active;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const RemoteAccount({
    required this.id,
    required this.login,
    required this.fullName,
    required this.role,
    required this.active,
    this.createdAt,
    this.lastLogin,
  });

  static RemoteAccount fromJson(Map<String, dynamic> j) => RemoteAccount(
        id: (j['id'] as num).toInt(),
        login: j['login'] as String,
        fullName: (j['full_name'] as String?) ?? (j['login'] as String),
        role: (j['role'] as num?)?.toInt() ?? 2,
        active: (j['active'] as bool?) ?? true,
        createdAt: _date(j['created_at']),
        lastLogin: _date(j['last_login']),
      );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// Issue d'une tentative de connexion en ligne.
enum RemoteLoginStatus { ok, unknownUser, badPassword, inactive, lockedOut }

class RemoteLoginResult {
  final RemoteLoginStatus status;
  final RemoteAccount? account;
  final int retryAfterSeconds;
  const RemoteLoginResult(this.status,
      {this.account, this.retryAfterSeconds = 0});
}

/// Diagnostic du serveur de comptes, affiché en bandeau.
class AccountsHealth {
  final bool ok;
  final String title;
  final String? detail;
  const AccountsHealth({required this.ok, required this.title, this.detail});
}

class AccountsService {
  AccountsService._();

  /// Au-delà, on considère le serveur injoignable et on bascule sur le
  /// chemin hors-ligne. Court volontairement : à la réception, un login
  /// qui met 30 s est un login cassé.
  static const Duration timeout = Duration(seconds: 8);

  static SupabaseClient? get _client {
    if (!CloudConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Supabase.initialize() n'a pas encore tourné (ou a échoué).
      return null;
    }
  }

  static bool get isAvailable => _client != null;

  // ── Connexion ────────────────────────────────────────────────────────

  /// Vérifie un couple login/mot de passe côté serveur.
  ///
  /// Lève une [AccountException] `offline` si le serveur est injoignable —
  /// l'appelant décide alors de tenter le chemin hors-ligne.
  static Future<RemoteLoginResult> verifyLogin(
      String login, String password) async {
    final res = await _rpc(
        'bs_verify_login',
        {
          'p_login': login.trim(),
          'p_password': password,
        },
        context: 'verifyLogin');

    final status = res['status'] as String?;
    switch (status) {
      case 'ok':
        final u = res['user'];
        if (u is! Map) {
          throw const AccountException(AccountErrorKind.unexpected,
              'Réponse inattendue du serveur de comptes.');
        }
        return RemoteLoginResult(RemoteLoginStatus.ok,
            account: RemoteAccount.fromJson(Map<String, dynamic>.from(u)));
      case 'unknown_user':
        return const RemoteLoginResult(RemoteLoginStatus.unknownUser);
      case 'bad_password':
        return const RemoteLoginResult(RemoteLoginStatus.badPassword);
      case 'inactive':
        return const RemoteLoginResult(RemoteLoginStatus.inactive);
      case 'locked_out':
        return RemoteLoginResult(RemoteLoginStatus.lockedOut,
            retryAfterSeconds:
                (res['retry_after_seconds'] as num?)?.toInt() ?? 300);
      default:
        throw AccountException(AccountErrorKind.unexpected,
            'Réponse inconnue du serveur de comptes : $status');
    }
  }

  // ── Lecture ──────────────────────────────────────────────────────────

  /// Liste tous les comptes (sans hash). Utilisée pour l'écran Comptes et
  /// pour rafraîchir le cache local qui alimente l'écran de connexion.
  static Future<List<RemoteAccount>> listAccounts() async {
    final c = _requireClient();
    try {
      final rows = await c
          .from('app_users_public')
          .select()
          .order('full_name')
          .timeout(timeout);
      return [
        for (final r in (rows as List))
          RemoteAccount.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e, st) {
      throw _translate(e, st, 'listAccounts');
    }
  }

  // ── Diagnostic ───────────────────────────────────────────────────────

  /// État du serveur de comptes, pour l'afficher AVANT que quelqu'un ne
  /// clique et se prenne une erreur.
  static Future<AccountsHealth> checkHealth() async {
    if (!isAvailable) {
      return const AccountsHealth(
        ok: false,
        title: 'Application compilée sans les clés Supabase',
        detail: 'Seuls les comptes de secours fonctionnent. Recompile avec '
            'installer/supabase.env renseigné.',
      );
    }
    try {
      final accounts = await listAccounts();
      return AccountsHealth(
        ok: true,
        title: '${accounts.length} compte(s) sur le serveur',
        detail: null,
      );
    } on AccountException catch (e) {
      return AccountsHealth(
        ok: false,
        title: e.kind == AccountErrorKind.offline
            ? 'Serveur de comptes injoignable'
            : 'Serveur de comptes indisponible',
        detail: e.message,
      );
    } catch (e) {
      return AccountsHealth(
          ok: false, title: 'Serveur de comptes indisponible', detail: '$e');
    }
  }

  // ── Écritures (exigent un admin, revérifié côté serveur) ─────────────

  static Future<int> createAccount({
    required String actorLogin,
    required String actorPassword,
    required String login,
    required String fullName,
    required String password,
    required int role,
  }) async {
    final res = await _rpc(
        'bs_create_account',
        {
          'p_actor_login': actorLogin,
          'p_actor_password': actorPassword,
          'p_login': login.trim(),
          'p_full_name': fullName.trim(),
          'p_password': password,
          'p_role': role,
        },
        context: 'createAccount');
    return (res['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> setPassword({
    required String actorLogin,
    required String actorPassword,
    required String login,
    required String newPassword,
  }) =>
      _rpc(
          'bs_set_password',
          {
            'p_actor_login': actorLogin,
            'p_actor_password': actorPassword,
            'p_login': login,
            'p_new_password': newPassword,
          },
          context: 'setPassword');

  static Future<void> setActive({
    required String actorLogin,
    required String actorPassword,
    required String login,
    required bool active,
  }) =>
      _rpc(
          'bs_set_active',
          {
            'p_actor_login': actorLogin,
            'p_actor_password': actorPassword,
            'p_login': login,
            'p_active': active,
          },
          context: 'setActive');

  static Future<void> rename({
    required String actorLogin,
    required String actorPassword,
    required String login,
    required String fullName,
  }) =>
      _rpc(
          'bs_rename_account',
          {
            'p_actor_login': actorLogin,
            'p_actor_password': actorPassword,
            'p_login': login,
            'p_full_name': fullName,
          },
          context: 'rename');

  static Future<void> deleteAccount({
    required String actorLogin,
    required String actorPassword,
    required String login,
  }) =>
      _rpc(
          'bs_delete_account',
          {
            'p_actor_login': actorLogin,
            'p_actor_password': actorPassword,
            'p_login': login,
          },
          context: 'deleteAccount');

  // ── Plomberie ────────────────────────────────────────────────────────

  static SupabaseClient _requireClient() {
    final c = _client;
    if (c == null) {
      throw const AccountException(
          AccountErrorKind.notConfigured,
          'Le cloud n\'est pas configuré dans cette version de '
          'l\'application. Les comptes ne peuvent pas être gérés ici.');
    }
    return c;
  }

  static Future<Map<String, dynamic>> _rpc(
    String fn,
    Map<String, dynamic> params, {
    required String context,
  }) async {
    final c = _requireClient();
    try {
      final res = await c.rpc(fn, params: params).timeout(timeout);
      if (res is Map) return Map<String, dynamic>.from(res);
      throw AccountException(AccountErrorKind.unexpected,
          'Réponse inattendue du serveur pour $fn.');
    } catch (e, st) {
      throw _translate(e, st, context);
    }
  }

  /// Même traduction, exposée pour la reprise des comptes qui appelle
  /// son propre RPC (cf. AccountsMigration).
  static AccountException translateForMigration(Object e) =>
      _translate(e, StackTrace.current, 'importAccount');

  /// Traduit une exception basse-couche en [AccountException] lisible.
  /// Les erreurs métier (codes levés par les fonctions SQL) ne sont pas
  /// remontées au reporting : ce sont des refus normaux, pas des bugs.
  static AccountException _translate(Object e, StackTrace st, String context) {
    if (e is AccountException) return e;

    if (e is PostgrestException) {
      final code = _businessCode(e.message);
      if (code != null) {
        return AccountException(AccountErrorKind.rejected, _explain(code),
            code: code);
      }
      // 42883 = fonction inexistante → SQL pas déployé sur ce projet.
      if (e.code == '42883' || e.message.contains('does not exist')) {
        unawaited(ErrorReporter.report(e, st, context: 'accounts/$context'));
        return const AccountException(
            AccountErrorKind.unexpected,
            'Le serveur de comptes n\'est pas à jour. Exécute '
            'sql/2026_09_comptes_supabase.sql dans Supabase.');
      }
      unawaited(ErrorReporter.report(e, st, context: 'accounts/$context'));
      return AccountException(
          AccountErrorKind.unexpected, 'Erreur serveur : ${e.message}');
    }

    if (e is TimeoutException) {
      return const AccountException(AccountErrorKind.offline,
          'Le serveur des comptes ne répond pas. Vérifie la connexion.');
    }

    // SocketException, ClientException, AuthRetryableFetchException…
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('failed host lookup') ||
        s.contains('network') ||
        s.contains('connection')) {
      return const AccountException(AccountErrorKind.offline,
          'Pas de connexion Internet. Les comptes sont sur le serveur.');
    }

    unawaited(ErrorReporter.report(e, st, context: 'accounts/$context'));
    return AccountException(
        AccountErrorKind.unexpected, 'Erreur inattendue : $e');
  }

  /// Les fonctions SQL lèvent des codes en majuscules (`LOGIN_DEJA_PRIS`).
  static String? _businessCode(String message) {
    for (final code in _messages.keys) {
      if (message.contains(code)) return code;
    }
    return null;
  }

  static String _explain(String code) =>
      _messages[code] ?? 'Opération refusée par le serveur ($code).';

  static const _messages = <String, String>{
    // Ce code arrive presque toujours pour une raison qui n'a rien à
    // voir avec une faute de frappe : le compte connecté n'existe pas
    // (encore) sur le serveur. Dire « identifiants incorrects » envoyait
    // l'utilisateur chercher une erreur de saisie inexistante.
    'IDENTIFIANTS_ADMIN_INVALIDES':
        "Le serveur ne reconnaît pas ton compte. Soit il n'a pas encore "
            'été repris vers le serveur, soit son mot de passe y est '
            'différent de celui utilisé ici.',
    'DROITS_INSUFFISANTS':
        'Ton rôle ne permet pas cette opération sur ce compte.',
    'LOGIN_DEJA_PRIS': 'Cet identifiant est déjà utilisé.',
    'LOGIN_TROP_COURT': 'L\'identifiant doit faire au moins 2 caractères.',
    'MOT_DE_PASSE_TROP_COURT':
        'Le mot de passe doit faire au moins 4 caractères.',
    'COMPTE_INTROUVABLE': 'Ce compte n\'existe pas sur le serveur.',
    'AUTO_DESACTIVATION': 'Tu ne peux pas désactiver ton propre compte.',
    'AUTO_SUPPRESSION': 'Tu ne peux pas supprimer ton propre compte.',
    'JETON_INVALIDE':
        'Jeton de reprise inconnu. Regénère-le dans Supabase avec '
            'select public.bs_new_import_token();',
    'JETON_EXPIRE':
        'Jeton de reprise expiré. Regénère-en un et relance la reprise.',
    'HASH_INVALIDE':
        'Mot de passe stocké dans un format que le serveur ne sait pas '
            'relire — ce compte doit être recréé à la main.',
    'DERNIER_SUPER_ADMIN':
        'C\'est le dernier super admin actif : impossible de le supprimer.',
  };
}
