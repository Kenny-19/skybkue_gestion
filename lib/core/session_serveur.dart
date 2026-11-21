import '../data/database.dart';
import '../data/repos.dart';

/// La session SERVEUR de la personne connectée.
///
/// Remise par le serveur à chaque connexion en ligne
/// (`bs_app_connexion`), elle accompagne chaque opération sensible : le
/// serveur vérifie lui-même qui agit et avec quel rôle. La clé publique de
/// l'application ne suffit plus pour gérer le stock.
///
/// Gardée en base, par compte : une personne qui s'est connectée en ligne
/// sur ce poste la retrouve même si sa connexion suivante se fait hors
/// ligne (mot de passe vérifié localement). Elle reste valable trente jours
/// après son dernier usage, et un compte désactivé la perd aussitôt.
class SessionServeur {
  SessionServeur._();

  static String? _login;
  static String? _jeton;

  /// Le jeton de la personne connectée, null si elle n'en a pas sur ce
  /// poste (jamais connectée en ligne ici, ou session expirée).
  static String? get jeton => _jeton;
  static String? get login => _login;

  static String _cle(String login) => 'session_serveur_${login.toLowerCase()}';

  /// Connexion en ligne : nouvelle session, gardée pour ce compte.
  static Future<void> ouvrir(
      AppDatabase db, String login, String? jeton) async {
    _login = login;
    _jeton = jeton;
    if (jeton != null) await SettingsRepo(db).ecrireBrut(_cle(login), jeton);
  }

  /// Connexion hors ligne : on reprend la session gardée pour ce compte.
  static Future<void> reprendre(AppDatabase db, String login) async {
    _login = login;
    final j = await SettingsRepo(db).lireBrut(_cle(login));
    _jeton = (j == null || j.isEmpty) ? null : j;
  }

  /// Le serveur a refusé la session (expirée, compte désactivé) : on
  /// l'oublie, il faudra se reconnecter en ligne.
  static Future<void> oublier(AppDatabase db) async {
    final l = _login;
    _jeton = null;
    if (l != null) await SettingsRepo(db).ecrireBrut(_cle(l), '');
  }

  /// Déconnexion de l'application : rien en mémoire. La session gardée en
  /// base reste, pour la prochaine connexion de ce compte sur ce poste.
  static void quitter() {
    _login = null;
    _jeton = null;
  }
}
