import 'package:flutter/foundation.dart';

import '../data/database.dart';
import 'cloud_service.dart';

/// Filet de sécurité "PC perdu / réinstallation" :
///
/// Au démarrage, si la BDD locale est **absente** (ou vide) et qu'un backup
/// Supabase existe, on télécharge et installe ce backup **avant** que Drift
/// n'ouvre la base — évitant ainsi de partir sur une base neuve seedée.
///
/// La BDD locale reste la source de vérité opérationnelle : ce mécanisme ne
/// se déclenche QUE quand rien n'existe en local. Pour restaurer un backup
/// alors qu'une BDD locale est déjà présente, l'utilisateur doit passer par
/// Paramètres → « Restaurer depuis le cloud » (choix explicite).
class RestoreOnBoot {
  RestoreOnBoot._();

  /// Vrai si une restauration cloud a été effectuée pendant ce boot.
  /// Utilisable pour afficher un SnackBar "Base restaurée depuis le cloud".
  static bool didRestore = false;

  /// Retourne true si un backup cloud a été restauré, false sinon.
  ///
  /// À appeler **une seule fois**, après `Supabase.initialize()` et
  /// **avant** que la première ouverture de `AppDatabase.instance` ne
  /// déclenche `onCreate` / `onUpgrade`.
  static Future<bool> tryRestoreIfMissingLocal() async {
    try {
      final file = await AppDatabase.dbFile();
      if (file.existsSync() && file.lengthSync() > 0) {
        return false; // BDD locale déjà là : on ne touche à rien.
      }
      if (!CloudService.enabled) {
        return false; // cloud non configuré → seed local normal.
      }
      // On tente la restauration. En cas d'échec (hors ligne, pas de backup),
      // on retombe silencieusement sur le seed local par défaut.
      // PC neuf : à défaut de sauvegarde à son nom, la dernière tous
      // postes confondus vaut mieux qu'une base vide.
      final res = await CloudService.restoreLatestBackup(touteSauvegarde: true);
      // La base n'est pas encore ouverte : on installe tout de suite.
      if (res.ok) await AppDatabase.appliquerRestaurationEnAttente();
      if (res.ok) {
        didRestore = true;
        debugPrint('[RestoreOnBoot] Base restaurée depuis Supabase.');
        return true;
      }
      debugPrint('[RestoreOnBoot] Pas de backup cloud disponible : '
          '${res.message}. Démarrage sur base neuve.');
      return false;
    } catch (e) {
      // On avale toute exception : le user doit pouvoir démarrer même si
      // Supabase est cassé / le token expiré.
      debugPrint('[RestoreOnBoot] Erreur ignorée : $e');
      return false;
    }
  }
}
