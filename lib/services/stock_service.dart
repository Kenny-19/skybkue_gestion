import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/cloud_config.dart';
import '../data/database.dart';
import 'error_reporter.dart';
import '../core/horloge.dart';

// Mouvements de stock en deltas.
//
// Le poste ne déclare plus un résultat (« stock = 7 ») mais une
// intention (« −3 »). Pourquoi c'est la seule façon correcte :
//
//   Il reste 10 Primus. Le bar en vend 3, la terrasse 4, pendant la même
//   coupure. En absolu, le dernier poste à se reconnecter écrase l'autre
//   et la base annonce 6 alors qu'il en reste 3. En deltas, Postgres
//   applique les deux et arrive à 3 — quel que soit l'ordre d'arrivée.
//
// Contrat serveur : sql/2026_09_stock_deltas.sql.

class StockService {
  /// La base est INJECTÉE plutôt que prise sur le singleton : sans ça,
  /// un test qui travaille sur une base en mémoire verrait ses
  /// mouvements partir dans la vraie base du poste.
  StockService(this._db);

  /// Instance de l'application. Les tests construisent la leur.
  static StockService get instance =>
      _instance ??= StockService(AppDatabase.instance);
  static StockService? _instance;

  final AppDatabase _db;

  SupabaseClient? get _client {
    if (!CloudConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final _alea = Random.secure();

  /// Identifiant de mouvement, généré AVANT tout envoi.
  ///
  /// C'est lui qui rend l'opération rejouable sans effet : une coupure
  /// juste après l'enregistrement serveur, mais avant l'accusé de
  /// réception, fait renvoyer le poste. Sans cette clé, le stock
  /// bougerait deux fois.
  static String _nouvelOpId() {
    final t = Horloge.maintenant().microsecondsSinceEpoch.toRadixString(36);
    final r = _alea.nextInt(1 << 32).toRadixString(36);
    return '$t-$r';
  }

  /// Enregistre un mouvement et tente de l'envoyer.
  ///
  /// L'écriture locale est TOUJOURS faite, envoi réussi ou non : les
  /// bouteilles sortent du frigo même sans réseau. La caisse n'attend
  /// jamais le serveur — l'envoi part en arrière-plan.
  Future<void> declarer({
    required int articleId,
    required int delta,
    String? reason,
  }) async {
    if (delta == 0) return;
    final opId = _nouvelOpId();

    await _db.transaction(() async {
      // 1. Le fait local : la quantité bouge ici, tout de suite.
      final art = await (_db.select(_db.articles)
            ..where((a) => a.id.equals(articleId)))
          .getSingleOrNull();
      if (art == null) return;
      await (_db.update(_db.articles)..where((a) => a.id.equals(articleId)))
          .write(ArticlesCompanion(stockQty: Value(art.stockQty + delta)));

      // 2. L'intention, mise en file pour le serveur.
      await _db.into(_db.stockMoves).insert(StockMovesCompanion.insert(
            opId: opId,
            articleId: articleId,
            delta: delta,
            reason: Value(reason),
            // Explicite, et surtout PAS le défaut SQL : CURRENT_TIMESTAMP
            // vient de l'horloge du système, celle-là même qui avançait
            // de deux heures. L'heure de référence est la seule à faire
            // foi pour un mouvement qui remonte au serveur.
            occurredAt: Value(Horloge.maintenant()),
          ));
    });

    unawaited(viderLaFile());
  }

  /// Nombre de mouvements qui n'ont pas encore atteint le serveur.
  Future<int> enAttente() async {
    final q = _db.selectOnly(_db.stockMoves)
      ..addColumns([_db.stockMoves.opId.count()])
      ..where(_db.stockMoves.sentAt.isNull());
    final r = await q.getSingle();
    return r.read(_db.stockMoves.opId.count()) ?? 0;
  }

  bool _occupe = false;

  /// Envoie les mouvements en attente, du plus ancien au plus récent.
  ///
  /// Un seul vidangeur à la fois, en série : deux envois concurrents
  /// pourraient rejouer le même mouvement. L'ordre n'est pas
  /// indispensable — des deltas s'additionnent dans n'importe quel ordre
  /// — mais il rend le journal serveur lisible.
  Future<void> viderLaFile() async {
    if (_occupe) return;
    final c = _client;
    if (c == null) return;
    _occupe = true;
    try {
      final enAttente = await (_db.select(_db.stockMoves)
            ..where((m) => m.sentAt.isNull())
            ..orderBy([(m) => OrderingTerm.asc(m.occurredAt)])
            ..limit(50))
          .get();

      for (final m in enAttente) {
        // Un mouvement qui a déjà échoué plusieurs fois est espacé :
        // inutile de marteler un serveur qui refuse.
        if (m.attempts >= 5 && m.attempts % 5 != 0) continue;
        try {
          await c.rpc('bs_adjust_stock', params: {
            'p_op_id': m.opId,
            'p_article_id': m.articleId,
            'p_delta': m.delta,
            'p_reason': m.reason,
          }).timeout(const Duration(seconds: 8));

          await (_db.update(_db.stockMoves)
                ..where((x) => x.opId.equals(m.opId)))
              .write(StockMovesCompanion(
                  sentAt: Value(Horloge.maintenant()),
                  lastError: const Value(null)));
        } catch (e) {
          // Échec : on garde le mouvement et on note pourquoi. Il ne
          // disparaît jamais en silence — c'est du stock réel.
          await (_db.update(_db.stockMoves)
                ..where((x) => x.opId.equals(m.opId)))
              .write(StockMovesCompanion(
                  attempts: Value(m.attempts + 1),
                  lastError: Value(e.toString())));
          // Réseau coupé : inutile d'essayer les suivants maintenant.
          if (_ressembleAUneCoupure(e)) break;
        }
      }
    } catch (e, st) {
      unawaited(ErrorReporter.report(e, st, context: 'stockQueue'));
    } finally {
      _occupe = false;
    }
  }

  static bool _ressembleAUneCoupure(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('socket') ||
        t.contains('timeout') ||
        t.contains('timed out') ||
        t.contains('failed host lookup') ||
        t.contains('connection');
  }

  /// Purge les mouvements confirmés depuis plus de trente jours.
  ///
  /// Le journal ne sert qu'à garantir l'envoi ; une fois confirmé, c'est
  /// le serveur qui fait foi. Le garder indéfiniment ferait grossir la
  /// base d'un poste pour rien.
  Future<int> purgerAnciens() async {
    final limite = Horloge.maintenant().subtract(const Duration(days: 30));
    return (_db.delete(_db.stockMoves)
          ..where((m) =>
              m.sentAt.isNotNull() & m.sentAt.isSmallerThanValue(limite)))
        .go();
  }
}
