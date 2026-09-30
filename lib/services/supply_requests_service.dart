import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud_config.dart';
import '../data/schema.dart';
import 'supabase_pages.dart';

/// Représentation d'une demande de ravitaillement (cloud).
class SupplyRequest {
  final int? id;
  final int? articleId;
  final String articleName;
  final DbLocation location;
  final int qtyRequested;
  final int qtyAtRequest;
  final int thresholdAtRequest;
  final String requestedByLogin;
  final DateTime? requestedAt;
  final String status; // pending / approved / rejected / fulfilled
  final String? reviewedByLogin;
  final DateTime? reviewedAt;
  final String? reviewNote;

  const SupplyRequest({
    this.id,
    this.articleId,
    required this.articleName,
    required this.location,
    required this.qtyRequested,
    required this.qtyAtRequest,
    required this.thresholdAtRequest,
    required this.requestedByLogin,
    this.requestedAt,
    this.status = 'pending',
    this.reviewedByLogin,
    this.reviewedAt,
    this.reviewNote,
  });

  factory SupplyRequest.fromJson(Map<String, dynamic> j) => SupplyRequest(
        id: (j['id'] as num?)?.toInt(),
        articleId: (j['article_id'] as num?)?.toInt(),
        articleName: j['article_name'] as String,
        location: DbLocation.values[(j['location'] as num).toInt()],
        qtyRequested: (j['qty_requested'] as num).toInt(),
        qtyAtRequest: (j['qty_at_request'] as num).toInt(),
        thresholdAtRequest: (j['threshold_at_request'] as num).toInt(),
        requestedByLogin: j['requested_by_login'] as String,
        requestedAt: j['requested_at'] == null
            ? null
            : DateTime.tryParse(j['requested_at'] as String),
        status: j['status'] as String? ?? 'pending',
        reviewedByLogin: j['reviewed_by_login'] as String?,
        reviewedAt: j['reviewed_at'] == null
            ? null
            : DateTime.tryParse(j['reviewed_at'] as String),
        reviewNote: j['review_note'] as String?,
      );
}

/// Service cloud-first pour les demandes de ravitaillement.
///
/// - Écriture DIRECTE dans Supabase (`supply_requests`) — nécessite réseau.
/// - Lecture des demandes en attente pour affichage in-app (optionnel).
///
/// Aucune persistance locale : les demandes sont visibles côté site web,
/// c'est là que Pamela les gère.
class SupplyRequestsService {
  SupplyRequestsService._();

  static SupabaseClient? get _client {
    if (!CloudConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Soumet une demande de ravitaillement au cloud.
  /// Retourne l'id créé si succès, sinon `null` (avec log console).
  static Future<int?> submit({
    required int? articleId,
    required String articleName,
    required DbLocation location,
    required int qtyRequested,
    required int qtyAtRequest,
    required int thresholdAtRequest,
    required String requestedByLogin,
    String? note,
  }) async {
    final c = _client;
    if (c == null) return null;
    try {
      final row = await c
          .from('supply_requests')
          .insert({
            'article_id': articleId,
            'article_name': articleName,
            'location': location.index,
            'qty_requested': qtyRequested,
            'qty_at_request': qtyAtRequest,
            'threshold_at_request': thresholdAtRequest,
            'requested_by_login': requestedByLogin,
            if (note != null && note.isNotEmpty) 'review_note': note,
          })
          .select('id')
          .single();
      return (row['id'] as num).toInt();
    } catch (e) {
      // Best-effort — l'appelant décide quoi faire (SnackBar erreur).
      return null;
    }
  }

  /// Liste des demandes de la période récente (défaut 30 jours),
  /// tous statuts confondus.
  static Future<List<SupplyRequest>> listRecent({int days = 30}) async {
    final c = _client;
    if (c == null) return const [];
    try {
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();
      final data = await toutesLesPages(() => c
          .from('supply_requests')
          .select()
          .gte('requested_at', since)
          .order('requested_at', ascending: false)
          .order('id', ascending: false));
      return data.map(SupplyRequest.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Liste des demandes emises par un utilisateur donne (30 derniers jours).
  /// Utilisee par le hub de notifications pour montrer a l'auteur si sa
  /// demande a ete approuvee ou rejetee.
  static Future<List<SupplyRequest>> listMine(String login,
      {int days = 30}) async {
    final c = _client;
    if (c == null) return const [];
    try {
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();
      final data = await toutesLesPages(() => c
          .from('supply_requests')
          .select()
          .eq('requested_by_login', login)
          .gte('requested_at', since)
          .order('requested_at', ascending: false)
          .order('id', ascending: false));
      return data.map(SupplyRequest.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }
}
