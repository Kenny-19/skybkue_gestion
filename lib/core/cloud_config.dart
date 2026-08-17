/// Configuration Supabase — stockage cloud (backup BDD + photos produits).
///
/// ⚠️ Remplace les valeurs ci-dessous par celles de TON projet Supabase :
///   Dashboard Supabase → Project Settings → API
///   - Project URL       → supabaseUrl
///   - Project API keys → "anon / public"  → supabaseAnonKey
///
/// N'utilise JAMAIS la clé "service_role" ici (elle est secrète / admin).
///
/// Tant que ces valeurs restent vides, l'app fonctionne 100% en local :
/// le cloud est simplement désactivé (aucun crash, aucun upload).
class CloudConfig {
  CloudConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wdwhfgawuozhkeflgcvs.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkd2hmZ2F3dW96aGtlZmxnY3ZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5NDcwNDgsImV4cCI6MjEwMjUyMzA0OH0.Bz1Wt-3h8AYsR59vPPzKTakxJvTf9BXhQ7Bei4cbAvU',
  );

  /// Noms des buckets Storage à créer dans le dashboard Supabase.
  static const String bucketBackups = 'backups';
  static const String bucketArticles = 'articles';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
