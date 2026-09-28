import 'dart:io' show Platform;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud_config.dart';
import '../core/temps.dart';

/// Enregistre les erreurs de l'app dans une table Supabase `error_logs`.
/// Un déclencheur côté Supabase (Edge Function / webhook) envoie ensuite un
/// email — aucun identifiant email n'est stocké dans l'application (sécurité).
///
/// Hors ligne ou cloud non configuré → l'erreur est ignorée silencieusement
/// (l'app ne doit jamais planter à cause du reporting lui-même).
class ErrorReporter {
  ErrorReporter._();

  static const String _appVersion = '0.1.0';

  /// Le nom de la machine, joint à chaque erreur.
  ///
  /// Sans lui, on ne sait pas QUEL poste remonte une panne. Le
  /// 24 septembre 2026, il a fallu arrêter une application et regarder
  /// si les erreurs continuaient pour deviner leur origine — deux
  /// minutes de silence ne prouvant d'ailleurs pas grand-chose. Un nom
  /// de machine aurait répondu tout de suite.
  ///
  /// C'est un nom d'ordinateur, pas une donnée personnelle : « CAISSE-1 »,
  /// « RECEPTION ». Rien sur qui l'utilisait.
  static String get _poste {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'inconnu';
    }
  }

  static Future<void> report(Object error, StackTrace? stack,
      {String? context}) async {
    if (!CloudConfig.isConfigured) return;
    try {
      final client = Supabase.instance.client;
      await client.from('error_logs').insert({
        'message': error.toString(),
        'stack': stack?.toString(),
        'context': context,
        'app_version': _appVersion,
        'poste': _poste,
        'platform': _platformLabel(),
        'occurred_at': isoServeur(DateTime.now()),
      });
    } catch (_) {
      // Reporting best-effort : on n'aggrave jamais la situation.
    }
  }

  static String _platformLabel() {
    try {
      if (Platform.isWindows) return 'Windows';
      if (Platform.isLinux) return 'Linux';
      if (Platform.isMacOS) return 'macOS';
      return Platform.operatingSystem;
    } catch (_) {
      return 'inconnu';
    }
  }
}
