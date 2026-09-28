/// Version courante de l'application, comparee avec la valeur distante
/// publiee sur Supabase (voir [UpdateService]) pour detecter les mises
/// a jour disponibles.
///
/// Cette valeur est **injectee a la build** par le script `release.ps1` :
///
///   flutter build windows --release --dart-define=APP_VERSION=0.3.0
///
/// La `defaultValue` sert uniquement en developpement (`flutter run`).
/// Elle doit rester coherente avec `version:` dans pubspec.yaml.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0',
);
