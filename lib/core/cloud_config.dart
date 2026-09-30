import 'dart:io';

import 'package:flutter/foundation.dart';

/// Configuration Supabase — comptes, miroir multi-postes, sauvegardes,
/// photos produits.
///
/// ── Où sont les clés ? ────────────────────────────────────────────────
///
/// Elles ne sont PLUS écrites en dur dans ce fichier. Elles sont
/// injectées au moment du build :
///
///   flutter build windows --release ^
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co ^
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// `installer/release.ps1` le fait pour toi à partir du fichier
/// `installer/supabase.env` (non versionné — cf. installer/README.md).
///
/// ── Ce que la clé anon protège, et ce qu'elle ne protège pas ──────────
///
/// La clé `anon` N'EST PAS UN SECRET : elle est extractible du binaire
/// livré au client. La sortir du code source évite de la publier dans le
/// dépôt et permet d'en changer sans toucher au code — mais la sécurité
/// réelle vient de la RLS et des fonctions SECURITY DEFINER côté
/// Supabase (cf. sql/2026_09_comptes_supabase.sql) :
///
///   * la table des comptes n'est jamais lisible avec cette clé ;
///   * les hashs de mots de passe ne quittent jamais le serveur ;
///   * créer ou modifier un compte exige les identifiants d'un admin,
///     revérifiés côté serveur.
///
/// N'utilise JAMAIS la clé `service_role` ici : elle contourne la RLS.
///
/// ── Plus de build « 100 % local » par accident ─────────────────────────
///
/// Un `flutter run` tapé au terminal n'a pas les `--dart-define` : l'app
/// démarrait sans cloud, avec la bannière rouge et les seuls comptes de
/// secours. En DEBUG, on va donc chercher les clés dans
/// `installer/supabase.env` quand le build ne les porte pas. Jamais en
/// release (le fichier n'est pas livré, et `release.ps1` refuse de
/// compiler sans clés), jamais sous `flutter test` (les tests ne doivent
/// pas parler au vrai Supabase).
class CloudConfig {
  CloudConfig._();

  static const String _urlBuild =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String _anonKeyBuild =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String get supabaseUrl => _urlBuild.isNotEmpty
      ? _urlBuild
      : (_depuisEnvLocal['SUPABASE_URL'] ?? '');

  static String get supabaseAnonKey => _anonKeyBuild.isNotEmpty
      ? _anonKeyBuild
      : (_depuisEnvLocal['SUPABASE_ANON_KEY'] ?? '');

  /// Clés lues une fois dans `installer/supabase.env`, en debug seulement.
  static final Map<String, String> _depuisEnvLocal = _lireEnvLocal();

  static Map<String, String> _lireEnvLocal() {
    if (!kDebugMode || kIsWeb) return const {};
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return const {};
      // Le dossier courant n'est pas forcément le projet : selon la façon
      // dont l'app est lancée, c'est celui de l'exécutable
      // (build\windows\x64\runner\Debug). On remonte depuis les deux.
      File? f;
      for (final depart in [
        Directory.current,
        File(Platform.resolvedExecutable).parent,
      ]) {
        var d = depart;
        for (var i = 0; i < 7 && f == null; i++) {
          final essai = File('${d.path}${Platform.pathSeparator}installer'
              '${Platform.pathSeparator}supabase.env');
          if (essai.existsSync()) f = essai;
          d = d.parent;
        }
        if (f != null) break;
      }
      if (f == null) return const {};
      final cles = <String, String>{};
      for (final ligne in f.readAsLinesSync()) {
        final t = ligne.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final i = t.indexOf('=');
        if (i < 1) continue;
        cles[t.substring(0, i).trim()] = t.substring(i + 1).trim();
      }
      return cles;
    } catch (_) {
      return const {};
    }
  }

  /// Noms des buckets Storage à créer dans le dashboard Supabase.
  static const String bucketBackups = 'backups';
  static const String bucketArticles = 'articles';

  /// Bucket privé pour les rapports PDF envoyés à Pamela via l'app.
  /// URLs signées émises par le dashboard web.
  static const String bucketReports = 'reports';

  /// URL publique du manifest de mise à jour (bucket `releases`).
  /// Voir installer/release.ps1 pour la génération de ce fichier.
  /// Déduite de [supabaseUrl] pour qu'un changement de projet n'oblige
  /// pas à modifier le code.
  static String get updateManifestUrl => supabaseUrl.isEmpty
      ? ''
      : '$supabaseUrl/storage/v1/object/public/releases/manifest.json';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Message à afficher quand une fonctionnalité cloud est demandée sur
  /// un build sans clés.
  static const String notConfiguredMessage =
      'Cette version de l\'application a été compilée sans les clés '
      'Supabase : les comptes, la synchronisation et les sauvegardes '
      'cloud sont désactivés.';
}
