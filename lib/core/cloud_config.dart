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
/// Tant que ces valeurs restent vides, l'app fonctionne 100 % en local :
/// le cloud est simplement désactivé (aucun crash, aucun upload), et
/// seuls les comptes de secours permettent de se connecter.
class CloudConfig {
  CloudConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

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
