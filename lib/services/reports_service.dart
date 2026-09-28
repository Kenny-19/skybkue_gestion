import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud_config.dart';
import '../core/temps.dart';

/// Résultat d'un envoi de rapport.
class ReportSendResult {
  final bool ok;
  final String? url;
  final String? error;
  const ReportSendResult({required this.ok, this.url, this.error});
}

/// Service d'envoi de rapports PDF à Pamela via Supabase.
///
/// Pipeline :
///   1. Upload du PDF dans le bucket `reports` (privé)
///   2. Insert d'une ligne dans `sent_reports` (métadonnées + URL)
///   3. Trigger Postgres → Edge Function → push notif à Pamela
///
/// Le web dashboard lit `sent_reports` et affiche la liste avec un
/// bouton de téléchargement.
class ReportsService {
  ReportsService._();

  static bool get _enabled {
    if (!CloudConfig.isConfigured) return false;
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Type de rapport (pour catégoriser côté site).
  static const String kindSummary = 'summary';
  static const String kindDetailed = 'detailed';
  static const String kindStayInvoice = 'stay_invoice';

  /// Envoie un rapport PDF au bucket + trace la ligne.
  ///
  /// Tente d'abord le bucket dédié `reports` (à créer côté Supabase pour
  /// une organisation propre) ; si absent, retombe automatiquement sur
  /// `articles` (bucket toujours présent, avec un préfixe `reports/`).
  /// Résultat identique côté site — la ligne `sent_reports` porte l'URL
  /// publique finale.
  static Future<ReportSendResult> send({
    required String name,
    required String period,
    required String kind,
    required Uint8List bytes,
    String? generatedByLogin,
    String? note,
  }) async {
    if (!_enabled) {
      return const ReportSendResult(ok: false, error: 'Cloud non configuré');
    }
    try {
      final client = Supabase.instance.client;
      final ts = DateTime.now();
      final safe =
          name.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_').toLowerCase();
      final path = 'reports/${ts.year}/${ts.month.toString().padLeft(2, '0')}/'
          '${ts.millisecondsSinceEpoch}_$safe.pdf';

      final buckets = [CloudConfig.bucketReports, CloudConfig.bucketArticles];
      String? usedBucket;
      String? finalPath;
      String? lastError;
      for (final bucket in buckets) {
        try {
          await client.storage.from(bucket).uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'application/pdf',
                ),
              );
          usedBucket = bucket;
          finalPath = path;
          break;
        } catch (e) {
          final msg = e.toString();
          lastError = msg;
          // Bucket introuvable → on tente le suivant. Autre erreur
          // (permissions, quota…) → on abandonne tout de suite.
          if (msg.contains('Bucket not found') ||
              msg.contains('bucket') && msg.contains('not found')) {
            continue;
          }
          rethrow;
        }
      }
      if (usedBucket == null || finalPath == null) {
        return ReportSendResult(
            ok: false,
            error:
                'Aucun bucket disponible pour les rapports (${lastError ?? "inconnu"}). '
                'Crée le bucket "reports" (public) dans Supabase → Storage.');
      }
      final url = client.storage.from(usedBucket).getPublicUrl(finalPath);
      await client.from('sent_reports').insert({
        'name': name,
        'period': period,
        'kind': kind,
        'storage_path': '$usedBucket/$finalPath',
        'public_url': url,
        'size_bytes': bytes.length,
        'generated_by_login': generatedByLogin,
        'note': note,
        'generated_at': isoServeur(ts),
      });
      return ReportSendResult(ok: true, url: url);
    } catch (e) {
      return ReportSendResult(ok: false, error: e.toString());
    }
  }
}
