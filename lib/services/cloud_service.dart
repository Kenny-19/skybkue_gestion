import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud_config.dart';
import '../data/database.dart';
import '../core/temps.dart';
import '../core/horloge.dart';

/// Résultat d'une opération cloud, pour retour UI clair.
class CloudResult {
  final bool ok;
  final String message;
  const CloudResult(this.ok, this.message);
}

/// Service de stockage cloud (Supabase Storage).
/// L'app reste 100% fonctionnelle en local ; ce service ne fait qu'ajouter
/// une couche de sauvegarde/partage quand internet est disponible.
class CloudService {
  CloudService._();

  static bool get enabled => CloudConfig.isConfigured;

  static SupabaseClient? get _client {
    if (!enabled) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Vrai s'il y a une interface réseau active (WiFi/ethernet/mobile).
  static Future<bool> get isOnline async {
    final res = await Connectivity().checkConnectivity();
    return res.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.mobile);
  }

  /// Statut global affichable dans l'UI.
  static Future<String> statusLabel() async {
    if (!enabled) return 'Cloud non configuré';
    if (!await isOnline) return 'Hors ligne';
    return 'En ligne';
  }

  // ─── Backup de la base ───────────────────────────────────────────────

  /// Nom du poste, utilisable dans un chemin de stockage.
  ///
  /// Chaque poste a sa propre base : une sauvegarde unique partagée
  /// (`latest/blue_sky.db`) était écrasée par le dernier poste à
  /// sauvegarder, et « Restaurer depuis le cloud » pouvait installer sur
  /// la caisse la base de la réception.
  static String get _dossierPoste {
    String nom;
    try {
      nom = Platform.localHostname;
    } catch (_) {
      nom = 'inconnu';
    }
    final propre = nom.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return propre.isEmpty ? 'inconnu' : propre;
  }

  /// Envoie une copie COHÉRENTE de la base vers le bucket "backups".
  ///
  /// Trois emplacements :
  ///   * `postes/<poste>/latest.db` — la dernière de CE poste, celle que
  ///     « Restaurer depuis le cloud » reprend ;
  ///   * `auto/<poste>/blue_sky_<date>.db` — l'historique ;
  ///   * `latest/blue_sky.db` — la dernière, tous postes confondus. Elle
  ///     ne sert qu'à un PC neuf, qui n'a pas encore de sauvegarde à son
  ///     nom (cf. RestoreOnBoot).
  static Future<CloudResult> uploadBackup() async {
    final c = _client;
    if (c == null) return const CloudResult(false, 'Cloud non configuré');
    if (!await isOnline) {
      return const CloudResult(false, 'Aucune connexion internet');
    }
    File? copie;
    try {
      // Plus de lecture brute du fichier : en mode WAL, il lui manque ce
      // qui dort encore dans le journal (dernières ventes, et parfois des
      // changements de structure).
      copie = await AppDatabase.instance.instantane();
      final octets = await copie.readAsBytes();
      final ts =
          DateFormat('yyyyMMddHHmm').format(aLubumbashi(Horloge.maintenant()));
      final poste = _dossierPoste;
      final bucket = c.storage.from(CloudConfig.bucketBackups);
      const opts = FileOptions(upsert: true);
      await bucket.uploadBinary('auto/$poste/blue_sky_$ts.db', octets,
          fileOptions: opts);
      await bucket.uploadBinary('postes/$poste/latest.db', octets,
          fileOptions: opts);
      await bucket.uploadBinary('latest/blue_sky.db', octets,
          fileOptions: opts);
      return CloudResult(true, 'Sauvegarde envoyée ($ts)');
    } catch (e) {
      return CloudResult(false, 'Échec : $e');
    } finally {
      try {
        copie?.parent.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Télécharge la dernière sauvegarde de CE poste et la prépare pour le
  /// prochain démarrage.
  ///
  /// La base ouverte n'est plus écrasée en direct : la copie attend à
  /// côté, et c'est le démarrage suivant qui l'installe, avant toute
  /// ouverture, en écartant l'ancien journal WAL (cf.
  /// [AppDatabase.appliquerRestaurationEnAttente]).
  ///
  /// [touteSauvegarde] : à défaut de sauvegarde à son nom, accepter la
  /// dernière tous postes confondus. Réservé au PC neuf — sur un poste
  /// existant, mieux vaut ne rien restaurer que la base d'un autre.
  static Future<CloudResult> restoreLatestBackup(
      {bool touteSauvegarde = false}) async {
    final c = _client;
    if (c == null) return const CloudResult(false, 'Cloud non configuré');
    if (!await isOnline) {
      return const CloudResult(false, 'Aucune connexion internet');
    }
    try {
      final bucket = c.storage.from(CloudConfig.bucketBackups);
      List<int> octets;
      try {
        octets = await bucket.download('postes/$_dossierPoste/latest.db');
      } catch (e) {
        if (!touteSauvegarde) {
          return CloudResult(
              false, 'Aucune sauvegarde cloud pour ce poste ($_dossierPoste).');
        }
        octets = await bucket.download('latest/blue_sky.db');
      }
      if (!await AppDatabase.preparerRestauration(octets)) {
        return const CloudResult(
            false, 'La sauvegarde téléchargée n\'est pas une base valide.');
      }
      return const CloudResult(true,
          'Sauvegarde prête — redémarre l\'application pour l\'installer.');
    } catch (e) {
      return CloudResult(false, 'Échec : $e');
    }
  }

  // ─── Photos produits ─────────────────────────────────────────────────

  /// Upload une photo produit vers le bucket "articles".
  /// Retourne l'URL publique, ou null si échec/hors-ligne.
  static Future<String?> uploadArticleImage(File localFile) async {
    return _uploadImage(localFile, prefix: 'art');
  }

  /// Upload une photo de chambre vers le même bucket que les produits,
  /// avec un préfixe distinctif pour repérage.
  static Future<String?> uploadRoomImage(File localFile) async {
    return _uploadImage(localFile, prefix: 'room');
  }

  static Future<String?> _uploadImage(File localFile,
      {required String prefix}) async {
    final c = _client;
    if (c == null) return null;
    if (!await isOnline) return null;
    try {
      final ext = p.extension(localFile.path);
      final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
      await c.storage.from(CloudConfig.bucketArticles).uploadBinary(
            name,
            await localFile.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );
      return c.storage.from(CloudConfig.bucketArticles).getPublicUrl(name);
    } catch (_) {
      return null;
    }
  }
}
