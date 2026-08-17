import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud_config.dart';
import '../data/database.dart';

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

  /// Envoie une copie du fichier .db vers le bucket "backups".
  static Future<CloudResult> uploadBackup() async {
    final c = _client;
    if (c == null) return const CloudResult(false, 'Cloud non configuré');
    if (!await isOnline) return const CloudResult(false, 'Aucune connexion internet');
    try {
      final file = await AppDatabase.dbFile();
      if (!file.existsSync()) {
        return const CloudResult(false, 'Fichier de base introuvable');
      }
      final ts = DateFormat('yyyyMMddHHmm').format(DateTime.now());
      final path = 'auto/blue_sky_$ts.db';
      await c.storage.from(CloudConfig.bucketBackups).uploadBinary(
            path,
            await file.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );
      // Copie "latest" toujours écrasée pour retrouver facilement la dernière.
      await c.storage.from(CloudConfig.bucketBackups).uploadBinary(
            'latest/blue_sky.db',
            await file.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );
      return CloudResult(true, 'Sauvegarde envoyée ($ts)');
    } catch (e) {
      return CloudResult(false, 'Échec : $e');
    }
  }

  /// Télécharge la dernière sauvegarde cloud et écrase la base locale.
  /// ⚠️ L'app doit être redémarrée après.
  static Future<CloudResult> restoreLatestBackup() async {
    final c = _client;
    if (c == null) return const CloudResult(false, 'Cloud non configuré');
    if (!await isOnline) return const CloudResult(false, 'Aucune connexion internet');
    try {
      final bytes = await c.storage
          .from(CloudConfig.bucketBackups)
          .download('latest/blue_sky.db');
      final file = await AppDatabase.dbFile();
      await file.writeAsBytes(bytes);
      return const CloudResult(true, 'Base restaurée — redémarre l\'application');
    } catch (e) {
      return CloudResult(false, 'Échec : $e');
    }
  }

  // ─── Photos produits ─────────────────────────────────────────────────

  /// Upload une photo produit vers le bucket "articles".
  /// Retourne l'URL publique, ou null si échec/hors-ligne.
  static Future<String?> uploadArticleImage(File localFile) async {
    final c = _client;
    if (c == null) return null;
    if (!await isOnline) return null;
    try {
      final ext = p.extension(localFile.path);
      final name =
          '${DateTime.now().millisecondsSinceEpoch}$ext';
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
