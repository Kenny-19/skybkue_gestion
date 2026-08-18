import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/cloud_config.dart';
import '../data/database.dart';

/// Miroir des données locales vers Supabase (sens unique : local = maître).
///
/// Permet de consulter les ventes/produits dans le dashboard Supabase même si
/// l'app locale plante. Chaque écriture importante est repoussée vers des
/// tables `mirror_*`. Hors ligne → ignoré (les données restent en local, une
/// synchro complète les rattrapera).
class MirrorService {
  MirrorService._();

  static bool get _enabled => CloudConfig.isConfigured;

  static SupabaseClient? get _c {
    if (!_enabled) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final AppDatabase _db = AppDatabase.instance;

  // ─── Push incrémental d'une vente ────────────────────────────────────

  static Future<void> pushSaleById(int saleId) async {
    final c = _c;
    if (c == null) return;
    try {
      final sale =
          await (_db.select(_db.sales)..where((s) => s.id.equals(saleId)))
              .getSingleOrNull();
      if (sale == null) return;
      final lines = await (_db.select(_db.saleLines)
            ..where((l) => l.saleId.equals(saleId)))
          .get();

      await c.from('mirror_sales').upsert(_saleJson(sale), onConflict: 'id');
      if (lines.isNotEmpty) {
        await c
            .from('mirror_sale_lines')
            .upsert(lines.map(_lineJson).toList(), onConflict: 'id');
      }
    } catch (_) {
      // best-effort
    }
  }

  // ─── Push incrémental d'un produit (création / édition) ──────────────

  static Future<void> pushArticleById(int articleId) async {
    final c = _c;
    if (c == null) return;
    try {
      final art = await (_db.select(_db.articles)
            ..where((a) => a.id.equals(articleId)))
          .getSingleOrNull();
      if (art == null) return;
      await c.from('mirror_articles').upsert(_articleJson(art), onConflict: 'id');
    } catch (_) {
      // best-effort
    }
  }

  // ─── Synchronisation complète (bouton manuel / démarrage) ────────────

  static Future<String> syncAll() async {
    final c = _c;
    if (c == null) return 'Cloud non configuré';
    try {
      final articles = await _db.select(_db.articles).get();
      final rooms = await _db.select(_db.rooms).get();
      final users = await _db.select(_db.users).get();
      final sales = await _db.select(_db.sales).get();
      final lines = await _db.select(_db.saleLines).get();

      if (articles.isNotEmpty) {
        await c.from('mirror_articles').upsert(
            articles.map(_articleJson).toList(),
            onConflict: 'id');
      }
      if (rooms.isNotEmpty) {
        await c.from('mirror_rooms').upsert(rooms.map(_roomJson).toList(),
            onConflict: 'number');
      }
      if (users.isNotEmpty) {
        await c.from('mirror_users').upsert(users.map(_userJson).toList(),
            onConflict: 'id');
      }
      if (sales.isNotEmpty) {
        await c.from('mirror_sales').upsert(sales.map(_saleJson).toList(),
            onConflict: 'id');
      }
      if (lines.isNotEmpty) {
        await c.from('mirror_sale_lines').upsert(lines.map(_lineJson).toList(),
            onConflict: 'id');
      }
      return 'Synchronisation réussie (${sales.length} ventes, ${articles.length} produits)';
    } catch (e) {
      return 'Échec synchro : $e';
    }
  }

  // ─── Mappage vers JSON (colonnes Supabase) ───────────────────────────

  static Map<String, dynamic> _saleJson(Sale s) => {
        'id': s.id,
        'sold_at': s.soldAt.toIso8601String(),
        'server_user_id': s.serverUserId,
        'payment': s.payment.index,
        'location': s.location.index,
        'customer_name': s.customerName,
        'note': s.note,
      };

  static Map<String, dynamic> _lineJson(SaleLine l) => {
        'id': l.id,
        'sale_id': l.saleId,
        'article_id': l.articleId,
        'article_name': l.articleName,
        'qty': l.qty,
        'unit_price_cents': l.unitPriceCents,
      };

  static Map<String, dynamic> _articleJson(Article a) => {
        'id': a.id,
        'name': a.name,
        'price_cents': a.priceCents,
        'category': a.category.index,
        'active': a.active,
        'track_stock': a.trackStock,
        'unit': a.unit,
        'stock_qty': a.stockQty,
        'threshold': a.threshold,
        'image_path': a.imagePath,
      };

  static Map<String, dynamic> _roomJson(Room r) => {
        'number': r.number,
        'type': r.type,
        'price_per_night_cents': r.pricePerNightCents,
        'status': r.status.index,
        'current_guest': r.currentGuest,
        'checkout_date': r.checkoutDate?.toIso8601String(),
      };

  // Pas de mot de passe dans le miroir (sécurité).
  static Map<String, dynamic> _userJson(User u) => {
        'id': u.id,
        'full_name': u.fullName,
        'login': u.login,
        'role': u.role.index,
        'active': u.active,
        'created_at': u.createdAt.toIso8601String(),
        'last_login': u.lastLogin?.toIso8601String(),
      };
}
