import 'dart:io' show Platform;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_version.dart';
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

  /// La vraie version, injectée au build par release.ps1.
  ///
  /// C'était une constante « 0.1.0 » : tous les postes remontaient la
  /// même version, et le 5 octobre 2026 on a cru un moment que les 87
  /// erreurs venaient d'un poste de développement — elles venaient d'une
  /// caisse en 0.0.26.
  static const String _appVersion = kAppVersion;

  /// Même erreur, même contexte : un seul envoi par fenêtre. Une base
  /// qui ne s'ouvre plus échoue toutes les quinze secondes ; on n'a pas
  /// besoin de 120 lignes par demi-heure pour le savoir, et chacune
  /// déclenchait un e-mail.
  static const Duration _fenetre = Duration(minutes: 10);
  static final Map<String, DateTime> _dernierEnvoi = {};
  static final Map<String, int> _repetitions = {};

  /// La clé d'une erreur : son contexte et la première ligne du message.
  static String _cle(Object error, String? context) =>
      '${context ?? ''}|${error.toString().split('\n').first}';

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
    final cle = _cle(error, context);
    final maintenant = DateTime.now();
    final precedent = _dernierEnvoi[cle];
    if (precedent != null && maintenant.difference(precedent) < _fenetre) {
      _repetitions[cle] = (_repetitions[cle] ?? 0) + 1;
      return;
    }
    _dernierEnvoi[cle] = maintenant;
    final repetees = _repetitions.remove(cle) ?? 0;
    try {
      final client = Supabase.instance.client;
      await client.from('error_logs').insert({
        'message': repetees == 0
            ? error.toString()
            : '${error.toString()}\n\n(+ $repetees fois la même erreur '
                'pendant les ${_fenetre.inMinutes} minutes précédentes)',
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
