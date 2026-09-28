import 'dart:async';

import 'package:drift/drift.dart';

import '../core/horloge.dart';
import '../data/database.dart';
import 'error_reporter.dart';
import 'mirror_service.dart';

/// La file des ventes qui n'ont pas encore atteint le serveur.
///
/// Le problème qu'elle résout
/// --------------------------
/// Une vente était poussée puis oubliée : `pushSaleById` avalait ses
/// erreurs, et aucune colonne ne disait si le serveur avait confirmé.
/// Le rattrapage consistait à repousser TOUTES les ventes toutes les dix
/// minutes — 21 Mo par jour pour 207 ventes, et une facture qui grandit
/// avec l'historique.
///
/// Ça marchait, et c'est bien le piège : tant que le volume reste petit,
/// le gâchis passe inaperçu. Le jour où le renvoi complet dépasse le
/// délai d'attente, il échoue — en silence, comme le reste — et les
/// pertes commencent exactement là, sans que rien ne fasse le lien avec
/// la cause.
///
/// Ici, chaque vente porte son accusé de réception. On n'envoie que ce
/// qui manque, et ce qui manque se compte.
class VentesOutbox {
  VentesOutbox(this._db);

  static VentesOutbox get instance => _instance ??= VentesOutbox(AppDatabase.instance);
  static VentesOutbox? _instance;

  final AppDatabase _db;

  bool _occupe = false;

  /// Combien de ventes ne sont pas encore en lieu sûr.
  ///
  /// C'est le chiffre à montrer au gérant. Une file qui ne se vide pas
  /// est le premier symptôme visible d'une caisse qui décroche.
  Future<int> enAttente() async {
    final s = _db.sales;
    final q = _db.selectOnly(s)
      ..addColumns([s.id.count()])
      ..where(s.syncedAt.isNull());
    return (await q.getSingle()).read(s.id.count()) ?? 0;
  }

  /// La plus ancienne vente non confirmée, s'il y en a une.
  ///
  /// Une vente d'il y a trois jours qui n'est toujours pas remontée ne
  /// raconte pas la même histoire qu'une vente d'il y a deux minutes.
  Future<DateTime?> plusAncienneEnAttente() async {
    final v = await (_db.select(_db.sales)
          ..where((s) => s.syncedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.soldAt)])
          ..limit(1))
        .getSingleOrNull();
    return v?.soldAt;
  }

  /// Marque une vente comme confirmée par le serveur.
  Future<void> marquerEnvoyee(int saleId) =>
      (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          syncedAt: Value(Horloge.maintenant()),
          syncAttempts: const Value(0),
          syncError: const Value(null),
        ),
      );

  /// Note un échec, sans jamais perdre la vente.
  Future<void> marquerEchec(int saleId, Object erreur, int tentatives) =>
      (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          syncAttempts: Value(tentatives + 1),
          syncError: Value(erreur.toString()),
        ),
      );

  /// Envoie une vente tout de suite, sans jamais lever.
  ///
  /// Appelée depuis la caisse, juste après l'encaissement. Une panne de
  /// réseau ne doit pas empêcher de rendre la monnaie — mais l'échec
  /// n'est plus perdu pour autant : `synced_at` reste null, la vente
  /// reste dans la file, et [vider] la reprendra. C'est toute la
  /// différence avec l'ancien `catch (_) {}`, qui oubliait vraiment.
  Future<bool> pousser(int saleId) async {
    try {
      await MirrorService.pushSaleOrThrow(saleId);
      await marquerEnvoyee(saleId);
      return true;
    } catch (e) {
      final v = await (_db.select(_db.sales)
            ..where((s) => s.id.equals(saleId)))
          .getSingleOrNull();
      if (v != null) await marquerEchec(saleId, e, v.syncAttempts);
      return false;
    }
  }

  /// Envoie les ventes en attente, de la plus ancienne à la plus récente.
  ///
  /// Un seul vidangeur à la fois. L'ordre chronologique n'est pas exigé
  /// par le serveur — chaque vente est indépendante — mais il rend le
  /// rattrapage lisible et fait remonter d'abord ce qui attend depuis le
  /// plus longtemps.
  ///
  /// [lot] borne le travail d'un passage : après une longue coupure, la
  /// file peut contenir des centaines de ventes, et il ne faut pas que
  /// le rattrapage fasse ramer la caisse pendant le service.
  Future<int> vider({int lot = 40}) async {
    if (_occupe) return 0;
    _occupe = true;
    var envoyees = 0;
    try {
      final enAttente = await (_db.select(_db.sales)
            ..where((s) => s.syncedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.soldAt)])
            ..limit(lot))
          .get();

      for (final v in enAttente) {
        // Une vente qui a déjà échoué cinq fois est espacée : inutile de
        // marteler un serveur qui refuse. Elle reste dans la file.
        if (v.syncAttempts >= 5 && v.syncAttempts % 5 != 0) continue;
        try {
          await MirrorService.pushSaleOrThrow(v.id);
          await marquerEnvoyee(v.id);
          envoyees++;
        } catch (e) {
          await marquerEchec(v.id, e, v.syncAttempts);
          // Réseau coupé : les suivantes échoueront pareil. On s'arrête
          // là plutôt que d'incrémenter inutilement tous les compteurs.
          if (_ressembleAUneCoupure(e)) break;
        }
      }
    } catch (e, st) {
      unawaited(ErrorReporter.report(e, st, context: 'ventesOutbox'));
    } finally {
      _occupe = false;
    }
    return envoyees;
  }

  static bool _ressembleAUneCoupure(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('socket') ||
        t.contains('timeout') ||
        t.contains('timed out') ||
        t.contains('failed host lookup') ||
        t.contains('connection');
  }
}
