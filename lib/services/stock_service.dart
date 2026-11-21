import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/cloud_config.dart';
import '../core/identite.dart';
import '../data/database.dart';
import 'error_reporter.dart';
import 'heartbeat_service.dart';
import 'mirror_service.dart';
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

/// Modification du stock refusée : le serveur n'est pas joignable.
class StockHorsLigne implements Exception {
  const StockHorsLigne();
  @override
  String toString() =>
      "Pas de connexion au serveur : le stock se modifie en ligne "
      "uniquement. Rien n'a été changé.";
}

/// Envoi d'un mouvement au serveur (remplaçable dans les tests).
typedef EnvoiMouvement = Future<void> Function(StockMove m, String articleUid);

/// Envoi d'une fiche article au serveur, en levant si ça échoue.
typedef PousserArticle = Future<void> Function(int articleId);

class StockService {
  /// La base est INJECTÉE plutôt que prise sur le singleton : sans ça,
  /// un test qui travaille sur une base en mémoire verrait ses
  /// mouvements partir dans la vraie base du poste.
  StockService(this._db,
      {EnvoiMouvement? envoyer, PousserArticle? pousserArticle})
      : _envoyerTest = envoyer,
        _pousserArticleTest = pousserArticle;

  /// Pour les tests : remplacent l'appel au serveur.
  final EnvoiMouvement? _envoyerTest;
  final PousserArticle? _pousserArticleTest;

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

  /// Modifie le stock EN LIGNE : le serveur l'applique tout de suite, ou
  /// rien ne change.
  ///
  /// Pour la gestion du stock (ravitaillement, correction, stock initial)
  /// faite par un gérant. Contrairement à une vente, elle n'est jamais
  /// mise en file : une correction d'inventaire faite hors ligne sur un
  /// poste, et envoyée des heures plus tard, est exactement ce qui donnait
  /// « chaque poste avec son stock ». Sans connexion, elle est refusée et
  /// la personne le sait.
  ///
  /// LÈVE [StockHorsLigne] si le serveur n'est pas joignable.
  Future<void> ajusterEnLigne({
    required int articleId,
    required int delta,
    required String reason,
  }) async {
    if (delta == 0) return;
    final envoyer = _envoyerTest ?? _envoiServeur();
    if (envoyer == null) throw const StockHorsLigne();
    final article = await (_db.select(_db.articles)
          ..where((a) => a.id.equals(articleId)))
        .getSingleOrNull();
    if (article == null) {
      throw StateError('Article $articleId introuvable sur ce poste');
    }
    final uid = article.uid ?? uidArticle(article.name);
    final opId = _nouvelOpId();
    final mouvement = StockMove(
      opId: opId,
      articleId: articleId,
      delta: delta,
      reason: reason,
      occurredAt: Horloge.maintenant(),
      sentAt: null,
      attempts: 0,
      lastError: null,
    );
    try {
      try {
        await envoyer(mouvement, uid);
      } catch (e) {
        if (!e.toString().contains('ARTICLE_INCONNU')) rethrow;
        // Produit encore inconnu du serveur (tout juste créé) : sa fiche
        // d'abord, puis le mouvement.
        await (_pousserArticleTest ??
            MirrorService.pushArticleOrThrow)(articleId);
        await envoyer(mouvement, uid);
      }
    } catch (e) {
      if (_ressembleAUneCoupure(e) || e is StateError) {
        throw const StockHorsLigne();
      }
      rethrow;
    }
    // Confirmé par le serveur : on l'applique ici, et on le garde au
    // journal comme déjà envoyé.
    await _db.transaction(() async {
      await (_db.update(_db.articles)..where((a) => a.id.equals(articleId)))
          .write(ArticlesCompanion(stockQty: Value(article.stockQty + delta)));
      await _db.into(_db.stockMoves).insert(StockMovesCompanion.insert(
            opId: opId,
            articleId: articleId,
            delta: delta,
            reason: Value(reason),
            occurredAt: Value(mouvement.occurredAt),
            sentAt: Value(Horloge.maintenant()),
          ));
    });
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

  /// Prochain essai permis, par mouvement qui a déjà échoué plusieurs
  /// fois. En mémoire : un redémarrage retente tout, et c'est voulu.
  final Map<String, DateTime> _prochainEssai = {};

  /// Après [kEchecsAvantEspacement] échecs, un mouvement n'est plus
  /// retenté qu'une fois par [kEspacement].
  static const kEchecsAvantEspacement = 5;
  static const kEspacement = Duration(minutes: 10);

  /// Envoie les mouvements en attente.
  ///
  /// Avant, un mouvement qui avait échoué six fois n'était PLUS JAMAIS
  /// retenté, et la raison restait sur le poste. Or tant qu'un article a
  /// un mouvement en attente, le poste garde sa propre quantité au lieu
  /// de celle du serveur : le 21 novembre 2026, la caisse avait 41
  /// mouvements bloqués, et donc son propre stock. Désormais :
  ///   * aucun mouvement n'est abandonné : espacé, jamais oublié ;
  ///   * les plus récents passent d'abord : un mouvement bloqué ne retarde
  ///     plus les autres ;
  ///   * « article inconnu » : la fiche est envoyée au serveur, puis le
  ///     mouvement est retenté aussitôt ;
  ///   * un blocage durable est SIGNALÉ, avec sa raison.
  ///
  /// Un seul vidangeur à la fois : deux envois concurrents pourraient
  /// rejouer le même mouvement (sans effet grâce à l'op_id, mais inutile).
  Future<void> viderLaFile({DateTime? maintenant}) async {
    if (_occupe) return;
    final envoyer = _envoyerTest ?? _envoiServeur();
    if (envoyer == null) return;
    _occupe = true;
    final now = maintenant ?? Horloge.maintenant();
    try {
      final enAttente = await (_db.select(_db.stockMoves)
            ..where((m) => m.sentAt.isNull())
            ..orderBy([
              (m) => OrderingTerm.asc(m.attempts),
              (m) => OrderingTerm.asc(m.occurredAt),
            ])
            ..limit(200))
          .get();
      for (final m in enAttente) {
        if (m.attempts >= kEchecsAvantEspacement) {
          final prochain = _prochainEssai[m.opId];
          if (prochain != null && now.isBefore(prochain)) continue;
        }
        try {
          final article = await (_db.select(_db.articles)
                ..where((a) => a.id.equals(m.articleId)))
              .getSingleOrNull();
          if (article == null) {
            throw StateError('Article ${m.articleId} introuvable sur ce poste');
          }
          final uid = article.uid ?? uidArticle(article.name);
          try {
            await envoyer(m, uid);
          } catch (e) {
            if (!e.toString().contains('ARTICLE_INCONNU')) rethrow;
            // Le serveur ne connaît pas encore ce produit (créé ici hors
            // ligne, ou renommé) : on lui envoie la fiche, puis on retente.
            await (_pousserArticleTest ??
                MirrorService.pushArticleOrThrow)(article.id);
            await envoyer(m, uid);
          }
          _prochainEssai.remove(m.opId);
          await (_db.update(_db.stockMoves)
                ..where((x) => x.opId.equals(m.opId)))
              .write(StockMovesCompanion(
                  sentAt: Value(Horloge.maintenant()),
                  lastError: const Value(null)));
        } catch (e, st) {
          // Échec : on garde le mouvement et on note pourquoi. Il ne
          // disparaît jamais en silence — c'est du stock réel.
          final tentatives = m.attempts + 1;
          await (_db.update(_db.stockMoves)
                ..where((x) => x.opId.equals(m.opId)))
              .write(StockMovesCompanion(
                  attempts: Value(tentatives), lastError: Value(e.toString())));
          if (tentatives >= kEchecsAvantEspacement) {
            _prochainEssai[m.opId] = now.add(kEspacement);
          }
          // Réseau coupé : rien d'anormal, et inutile d'essayer les
          // suivants maintenant.
          if (_ressembleAUneCoupure(e)) break;
          // Blocage durable : le signaler, avec sa raison. Avant, elle
          // restait sur le poste et personne ne la voyait.
          if (tentatives == kEchecsAvantEspacement || tentatives % 50 == 0) {
            unawaited(ErrorReporter.report(e, st,
                context: 'stock/mouvement bloqué ($tentatives essais)'));
          }
        }
      }
    } catch (e, st) {
      unawaited(ErrorReporter.report(e, st, context: 'stockQueue'));
    } finally {
      _occupe = false;
    }
  }

  /// L'envoi réel d'un mouvement au serveur. Null hors cloud.
  EnvoiMouvement? _envoiServeur() {
    final c = _client;
    if (c == null) return null;
    return (m, uid) => c.rpc('bs_adjust_stock_uid', params: {
          'p_op_id': m.opId,
          'p_article_uid': uid,
          'p_delta': m.delta,
          'p_reason': m.reason,
          // Le poste d'origine : le journal serveur ne le portait pas,
          // impossible de savoir qui avait sorti quoi.
          'p_poste': HeartbeatService.nomDuPoste,
        }).timeout(const Duration(seconds: 8));
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
