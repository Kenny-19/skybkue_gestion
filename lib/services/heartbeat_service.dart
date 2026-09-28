import 'dart:async';
import 'dart:io' show Platform;

import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/app_version.dart';
import '../core/cloud_config.dart';
import 'horloge_service.dart';
import 'stock_service.dart';
import 'ventes_outbox.dart';

/// Le poste signale son existence et son état.
///
/// Pourquoi ça manquait
/// --------------------
/// Rien dans la base ne disait quels postes existent, lequel tourne,
/// quelle version il porte. Diagnostiquer une panne revenait à arrêter
/// une application et regarder si les erreurs cessaient — méthode qui
/// m'a donné une conclusion FAUSSE le 24 septembre 2026 : deux minutes
/// de silence m'ont fait conclure que les verrous venaient du poste de
/// développement, alors qu'ils ont repris quatre minutes plus tard.
///
/// Un battement de cœur répond tout de suite, et sans se tromper.
///
/// Ce qu'il transporte, et rien de plus
/// ------------------------------------
/// Le nom de la machine, la version, la dérive de l'horloge, et ce qui
/// attend d'être envoyé. Aucune donnée de vente, aucun nom de client :
/// c'est un état technique, pas une copie de la caisse.
class HeartbeatService {
  HeartbeatService._();
  static final instance = HeartbeatService._();

  /// Toutes les cinq minutes. Assez fréquent pour qu'un poste tombé se
  /// voie vite, assez rare pour ne peser ni sur le réseau ni sur la
  /// base — c'est un signal de vie, pas un flux.
  static const _intervalle = Duration(minutes: 5);

  /// Au-delà, le portail considère le poste éteint. Le double de
  /// l'intervalle : un battement manqué ne doit pas déclencher d'alerte.
  static const seuilHorsLigne = Duration(minutes: 10);

  Timer? _minuterie;
  bool _occupe = false;

  /// Les identifiants de la session en cours, fournis par la couche
  /// d'authentification. Le battement exige un compte valide : sans ça,
  /// n'importe qui muni de la clé anon pourrait inventer des postes.
  ({String login, String password})? Function()? _identifiants;

  /// Démarre le battement. Sans effet si le cloud n'est pas configuré.
  void demarrer(({String login, String password})? Function() identifiants) {
    if (!CloudConfig.isConfigured) return;
    _identifiants = identifiants;
    _minuterie?.cancel();
    _minuterie = Timer.periodic(_intervalle, (_) => unawaited(battre()));
    unawaited(battre());
  }

  void arreter() {
    _minuterie?.cancel();
    _minuterie = null;
  }

  /// Le nom de la machine. C'est lui qui identifie le poste.
  static String get nomDuPoste {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'inconnu';
    }
  }

  /// Envoie un battement. Ne lève jamais : un signal de vie manqué ne
  /// doit pas déranger une caisse qui, elle, fonctionne.
  Future<void> battre() async {
    if (_occupe) return;
    final creds = _identifiants?.call();
    if (creds == null) return; // personne n'est connecté
    _occupe = true;
    try {
      final client = Supabase.instance.client;
      final derive = HorlogeService.instance.derive;
      await client.rpc('bs_heartbeat', params: {
        'p_login': creds.login,
        'p_password': creds.password,
        'p_poste': nomDuPoste,
        'p_version': kAppVersion,
        'p_derive_secondes': derive?.inSeconds,
        'p_ventes_en_attente': await VentesOutbox.instance.enAttente(),
        'p_stock_en_attente': await StockService.instance.enAttente(),
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Hors ligne, serveur muet, fonction pas encore déployée : on
      // réessaiera dans cinq minutes. Un battement n'est pas une donnée
      // à conserver — seul le dernier compte.
    } finally {
      _occupe = false;
    }
  }
}
