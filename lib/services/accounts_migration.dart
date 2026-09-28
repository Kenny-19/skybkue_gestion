import 'package:drift/drift.dart' show Value;
// `User` existe aussi dans gotrue : ici c'est toujours la ligne Drift.
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/auth.dart';
import '../data/database.dart';
import 'accounts_service.dart';

// Reprise unique des comptes locaux vers Supabase.
//
// Avant la bascule, les comptes vivaient dans la base SQLite de chaque
// poste, mot de passe haché en bcrypt `$2a$` — exactement le format que
// `crypt()` sait vérifier côté Postgres. On recopie donc le hash tel
// quel : personne ne change de mot de passe, et aucun mot de passe en
// clair ne transite.
//
// Contrat serveur : sql/2026_09_reprise_comptes.sql.

/// Pourquoi un compte local n'est pas repris.
enum SkipReason {
  /// Compte de secours (`reception`/`serveuse`/`admin`) : par définition
  /// local, il ne doit jamais monter sur le serveur.
  localDefault,

  /// Pas de hash exploitable (compte créé par une synchro et jamais
  /// connecté ici) : il n'y a rien à reprendre.
  noUsableHash,

  /// Le serveur connaît déjà ce login — on ne l'écrase jamais.
  alreadyOnServer,
}

extension SkipReasonX on SkipReason {
  String get label => switch (this) {
        SkipReason.localDefault => 'compte de secours — reste local',
        SkipReason.noUsableHash => 'aucun mot de passe utilisable sur ce poste',
        SkipReason.alreadyOnServer => 'déjà présent sur le serveur',
      };
}

/// Un compte local et ce qu'on compte en faire.
class MigrationCandidate {
  final User user;

  /// Null → le compte sera importé.
  final SkipReason? skip;

  const MigrationCandidate(this.user, {this.skip});

  bool get willImport => skip == null;
}

/// Ce qui est arrivé à un compte pendant l'exécution.
enum MigrationOutcome { imported, skipped, failed }

class MigrationLine {
  final String login;
  final MigrationOutcome outcome;

  /// Explication affichée à côté de la ligne (raison du saut, ou erreur).
  final String? detail;

  const MigrationLine(this.login, this.outcome, {this.detail});
}

/// Bilan complet d'une reprise.
class MigrationReport {
  final List<MigrationLine> lines;
  const MigrationReport(this.lines);

  int get imported =>
      lines.where((l) => l.outcome == MigrationOutcome.imported).length;
  int get skipped =>
      lines.where((l) => l.outcome == MigrationOutcome.skipped).length;
  int get failed =>
      lines.where((l) => l.outcome == MigrationOutcome.failed).length;

  bool get isCleanRun => failed == 0;

  String get summary {
    final parts = <String>['$imported repris'];
    if (skipped > 0) parts.add('$skipped ignoré(s)');
    if (failed > 0) parts.add('$failed en échec');
    return parts.join(' · ');
  }
}

class AccountsMigration {
  AccountsMigration._();

  /// Décide, sans réseau, ce qui doit être repris.
  ///
  /// Fonction pure : c'est elle qui porte toute la règle métier, et c'est
  /// elle qui est testée. [remoteLogins] vient de `listAccounts()` et est
  /// comparé sans tenir compte de la casse.
  static List<MigrationCandidate> plan(
    List<User> localUsers,
    Set<String> remoteLogins,
  ) {
    final remote = remoteLogins.map((l) => l.toLowerCase()).toSet();
    final out = [
      for (final u in localUsers)
        MigrationCandidate(u, skip: _skipReason(u, remote)),
    ];
    // Les comptes à importer d'abord, puis par rôle puis par login :
    // l'écran de prévisualisation se lit de haut en bas.
    out.sort((a, b) {
      if (a.willImport != b.willImport) return a.willImport ? -1 : 1;
      final r = a.user.role.index.compareTo(b.user.role.index);
      return r != 0 ? r : a.user.login.compareTo(b.user.login);
    });
    return out;
  }

  static SkipReason? _skipReason(User u, Set<String> remoteLower) {
    if (u.isLocalDefault) return SkipReason.localDefault;
    if (!isUsableHash(u.passwordHash)) return SkipReason.noUsableHash;
    if (remoteLower.contains(u.login.toLowerCase())) {
      return SkipReason.alreadyOnServer;
    }
    return null;
  }

  /// Prépare la reprise : lit les comptes locaux, interroge le serveur
  /// pour savoir ce qui existe déjà, et renvoie le plan.
  ///
  /// Lève une [AccountException] si le serveur est injoignable — on ne
  /// propose pas une reprise à l'aveugle.
  static Future<List<MigrationCandidate>> prepare(AppDatabase db) async {
    final local = await db.select(db.users).get();
    final remote = await AccountsService.listAccounts();
    return plan(local, remote.map((a) => a.login).toSet());
  }

  /// Exécute la reprise.
  ///
  /// Autorisation : un [token] généré par `bs_new_import_token()`, OU les
  /// identifiants d'un super admin déjà présent sur le serveur.
  ///
  /// Chaque compte est traité indépendamment : un échec sur l'un
  /// n'interrompt pas les autres, et le rapport dit exactement lequel a
  /// échoué et pourquoi. La reprise est rejouable — relancer ne fait que
  /// re-signaler « déjà présent ».
  ///
  /// Marque au passage les comptes repris comme synchronisés en local :
  /// leur hash y reste, donc l'accès hors-ligne de ce poste est conservé.
  static Future<MigrationReport> run(
    AppDatabase db,
    List<MigrationCandidate> candidates, {
    String? token,
    ({String login, String password})? actor,
  }) async {
    if ((token == null || token.trim().isEmpty) && actor == null) {
      throw const AccountException(
          AccountErrorKind.rejected,
          'Fournis un jeton de reprise, ou connecte-toi avec un super '
          'admin déjà présent sur le serveur.');
    }

    final lines = <MigrationLine>[];
    for (final c in candidates) {
      if (!c.willImport) {
        lines.add(MigrationLine(c.user.login, MigrationOutcome.skipped,
            detail: c.skip!.label));
        continue;
      }
      try {
        final res = await _import(c.user, token: token, actor: actor);
        final status = res['status'] as String?;
        if (status == 'imported') {
          await (db.update(db.users)..where((u) => u.id.equals(c.user.id)))
              .write(UsersCompanion(syncedAt: Value(DateTime.now())));
          lines.add(MigrationLine(c.user.login, MigrationOutcome.imported));
        } else {
          lines.add(MigrationLine(c.user.login, MigrationOutcome.skipped,
              detail: SkipReason.alreadyOnServer.label));
        }
      } on AccountException catch (e) {
        lines.add(MigrationLine(c.user.login, MigrationOutcome.failed,
            detail: e.message));
        // Un jeton invalide ou expiré fera échouer toutes les lignes
        // suivantes de la même façon : inutile de marteler le serveur.
        if (e.code == 'JETON_INVALIDE' || e.code == 'JETON_EXPIRE') {
          for (final rest in candidates.remainingAfter(c)) {
            lines.add(MigrationLine(rest.user.login, MigrationOutcome.failed,
                detail: 'interrompu : ${e.message}'));
          }
          break;
        }
      } catch (e) {
        lines.add(MigrationLine(c.user.login, MigrationOutcome.failed,
            detail: 'Échec inattendu : $e'));
      }
    }
    return MigrationReport(lines);
  }

  static Future<Map<String, dynamic>> _import(
    User u, {
    String? token,
    ({String login, String password})? actor,
  }) async {
    final client = Supabase.instance.client;
    try {
      final res = await client.rpc('bs_import_account', params: {
        'p_token': token?.trim(),
        'p_actor_login': actor?.login,
        'p_actor_password': actor?.password,
        'p_login': u.login,
        'p_full_name': u.fullName,
        'p_password_hash': u.passwordHash,
        'p_role': u.role.index,
        'p_active': u.active,
        'p_created_at': u.createdAt.toUtc().toIso8601String(),
        'p_last_login': u.lastLogin?.toUtc().toIso8601String(),
      }).timeout(AccountsService.timeout);
      if (res is Map) return Map<String, dynamic>.from(res);
      throw const AccountException(AccountErrorKind.unexpected,
          'Réponse inattendue du serveur pendant la reprise.');
    } catch (e) {
      throw AccountsService.translateForMigration(e);
    }
  }
}

extension on List<MigrationCandidate> {
  /// Les candidats qui suivent [from] et qui devaient être importés —
  /// sert à marquer d'un coup le reste comme interrompu.
  Iterable<MigrationCandidate> remainingAfter(MigrationCandidate from) =>
      skip(indexOf(from) + 1).where((c) => c.willImport);
}
