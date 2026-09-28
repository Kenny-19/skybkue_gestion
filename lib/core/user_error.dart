import 'dart:async';
import 'dart:io';

import '../services/accounts_service.dart';
import '../services/error_reporter.dart';

// Traduction des pannes en langage humain.
//
// Le problème qu'on corrige ici
// -----------------------------
// L'application affichait l'exception brute. À l'écran, la réception
// lisait :
//
//   « SocketException: HTTP connection timed out after 0:00:15.000000,
//     host: wdwhfgawuozhkeflgcvs.supabase.co, port: 443 »
//
// Ce texte ne lui dit ni ce qui s'est passé, ni quoi faire — et il
// affiche au passage l'adresse du serveur. Vingt-huit endroits dans
// l'application faisaient ça.
//
// Le principe : l'utilisateur voit ce qui le concerne, le détail
// technique part vers le journal d'erreurs, qui alerte le super admin
// par mail. Personne ne perd d'information, chacun reçoit la sienne.

/// Nature de la panne, du point de vue de celui qui l'a sous les yeux.
enum ErrorKind {
  /// Réseau absent ou trop lent. Réessayable tel quel.
  offline,

  /// Le serveur a répondu, mais il a refusé. Ce n'est pas une panne :
  /// l'utilisateur n'a pas le droit, ou la donnée n'est pas valable.
  refused,

  /// Le serveur ou le schéma ne sont pas dans l'état attendu.
  serveur,

  /// Problème de la base locale du poste.
  local,

  /// Tout le reste. C'est là que se cachent les vrais bugs, d'où le
  /// rapport systématique.
  inattendu,
}

/// Une panne, telle qu'on la montre à l'utilisateur.
class UserError {
  /// Le constat, en trois mots. C'est le titre de la boîte.
  final String title;

  /// Ce qui s'est passé, sans jargon et sans nom de serveur.
  final String message;

  /// Ce qu'il peut faire maintenant. Null quand il n'y a rien à faire
  /// de son côté.
  final String? advice;

  final ErrorKind kind;

  /// Code court à citer au support. Il se retrouve dans le mail envoyé
  /// au super admin, ce qui permet de relier « l'écran a affiché BS-3F2A »
  /// à la ligne exacte du journal.
  final String reference;

  const UserError({
    required this.title,
    required this.message,
    required this.kind,
    required this.reference,
    this.advice,
  });

  /// Vrai quand refaire la même chose plus tard a des chances de marcher.
  bool get isRetryable => kind == ErrorKind.offline;

  /// Vrai quand la panne mérite d'alerter le super admin. Un problème de
  /// réseau ou un refus métier n'est pas un incident — inonder la boîte
  /// mail de « pas de connexion » la rendrait inutile.
  bool get worthReporting =>
      kind == ErrorKind.inattendu ||
      kind == ErrorKind.serveur ||
      kind == ErrorKind.local;
}

/// Traduit n'importe quelle exception en message affichable.
///
/// Fonction pure — aucun réseau, aucune écriture. C'est elle qui porte
/// toute la règle, et c'est elle qui est testée. Le rapport au journal
/// est fait séparément par [reportIfNeeded], pour que la traduction
/// reste utilisable dans un test.
UserError describeError(Object error) {
  final e = error;
  final texte = e.toString();

  // Les erreurs de comptes savent déjà se raconter : on ne retraduit pas.
  if (e is AccountException) {
    return UserError(
      title: switch (e.kind) {
        AccountErrorKind.offline => 'Pas de connexion',
        AccountErrorKind.notConfigured => 'Cloud non configuré',
        AccountErrorKind.rejected => 'Opération refusée',
        AccountErrorKind.unexpected => 'Serveur indisponible',
      },
      message: e.message,
      advice: e.isRetryable ? 'Réessaie quand la connexion revient.' : null,
      kind: switch (e.kind) {
        AccountErrorKind.offline => ErrorKind.offline,
        AccountErrorKind.notConfigured => ErrorKind.serveur,
        AccountErrorKind.rejected => ErrorKind.refused,
        AccountErrorKind.unexpected => ErrorKind.serveur,
      },
      reference: _reference(texte),
    );
  }

  // ── Réseau ──────────────────────────────────────────────────────────
  // Le cas de la capture d'écran : timeout vers Supabase. L'utilisateur
  // n'a pas à savoir qu'il existe un hôte ni un port 443.
  if (e is SocketException ||
      e is TimeoutException ||
      e is HttpException ||
      _contient(texte, const [
        'timed out',
        'timeout',
        'failed host lookup',
        'connection refused',
        'connection closed',
        'network is unreachable',
        'no address associated',
      ])) {
    return UserError(
      title: 'Pas de connexion',
      message: 'Le serveur est injoignable pour le moment.',
      advice: "L'application continue de fonctionner. "
          'Réessaie quand la connexion revient.',
      kind: ErrorKind.offline,
      reference: _reference(texte),
    );
  }

  // ── Base locale ─────────────────────────────────────────────────────
  if (_contient(texte, const [
    'sqliteexception',
    'database is locked',
    'disk i/o error',
    'no such table',
    'no such column',
  ])) {
    return UserError(
      title: 'Problème sur ce poste',
      message: "La base de données locale n'a pas répondu correctement.",
      advice: "Ferme et rouvre l'application. Si ça recommence, "
          'préviens le gérant.',
      kind: ErrorKind.local,
      reference: _reference(texte),
    );
  }

  // ── Serveur / schéma ────────────────────────────────────────────────
  if (_contient(texte, const [
    'postgrest',
    'does not exist',
    'permission denied',
    'violates',
    'pgrst',
  ])) {
    return UserError(
      title: 'Serveur indisponible',
      message: "Le serveur a refusé l'opération.",
      advice: 'Le gérant a été prévenu automatiquement.',
      kind: ErrorKind.serveur,
      reference: _reference(texte),
    );
  }

  // ── Le reste ────────────────────────────────────────────────────────
  return UserError(
    title: 'Une erreur est survenue',
    message: "L'opération n'a pas pu être terminée.",
    advice: 'Réessaie. Si ça recommence, cite le code ci-dessous.',
    kind: ErrorKind.inattendu,
    reference: _reference(texte),
  );
}

/// Envoie le détail technique au journal d'erreurs — donc au mail du
/// super admin — quand la panne le mérite.
///
/// Best-effort et silencieux : rapporter une erreur ne doit jamais
/// produire une deuxième erreur à l'écran.
Future<void> reportIfNeeded(
  UserError described,
  Object error,
  StackTrace? stack, {
  String? context,
}) async {
  if (!described.worthReporting) return;
  await ErrorReporter.report(
    error,
    stack,
    context: '[${described.reference}] ${context ?? "inconnu"}',
  );
}

/// Traduit ET rapporte, en une fois. C'est ce que les écrans appellent.
UserError handleError(Object error, StackTrace? stack, {String? context}) {
  final described = describeError(error);
  // Volontairement sans await : l'affichage ne doit pas attendre le
  // réseau pour dire à l'utilisateur ce qui se passe.
  unawaited(reportIfNeeded(described, error, stack, context: context));
  return described;
}

bool _contient(String texte, List<String> motifs) {
  final t = texte.toLowerCase();
  return motifs.any(t.contains);
}

/// Code court et STABLE : la même panne donne toujours le même code, ce
/// qui permet de voir qu'elle se répète au lieu de la croire nouvelle.
String _reference(String texte) {
  // On ne garde que la nature de l'erreur, sans les parties variables
  // (horodatage, durée du timeout), pour que le code reste stable.
  final noyau = texte
      .toLowerCase()
      .replaceAll(RegExp(r'[0-9]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final h = noyau.hashCode.abs() % 0xFFFF;
  return 'BS-${h.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}
