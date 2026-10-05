import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/cloud_config.dart';
import 'data/database.dart';
import 'services/auto_backup.dart';
import 'services/error_reporter.dart';
import 'services/horloge_service.dart';
import 'services/mirror_pull_service.dart';
import 'services/mirror_service.dart';
import 'services/restore_on_boot.dart';
import 'services/update_service.dart';

Future<void> main() async {
  // runZonedGuarded capture les erreurs asynchrones non gérées et les envoie
  // vers Supabase (→ email côté serveur).
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');

    // Fenêtre desktop : c'est le runner Win32 (windows/runner/main.cpp +
    // win32_window.cpp) qui gère taille, position centrée, taille min
    // (WM_GETMINMAXINFO) et force WS_OVERLAPPEDWINDOW à chaque Show().
    // On n'utilise plus window_manager côté Dart : il persistait parfois
    // un état borderless qui masquait la barre de titre au redémarrage.

    // Erreurs du framework Flutter (build/layout/paint).
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      ErrorReporter.report(details.exception, details.stack,
          context: 'FlutterError');
    };

    // Une restauration demandée à la session précédente s'installe ICI,
    // avant que quoi que ce soit n'ouvre la base. Jamais pendant que
    // l'application tourne dessus.
    await AppDatabase.appliquerRestaurationEnAttente();

    // Initialise Supabase uniquement si les clés sont renseignées
    // (injectées au build par --dart-define, cf. CloudConfig). Sinon
    // l'app démarre en 100 % local : seuls les comptes de secours
    // permettent alors de se connecter.
    if (!CloudConfig.isConfigured) {
      debugPrint('⚠️  Build sans clés Supabase : mode 100 % local. '
          'Voir installer/supabase.env.example.');
    }
    if (CloudConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: CloudConfig.supabaseUrl,
          anonKey: CloudConfig.supabaseAnonKey,
        );
        // Filet de sécurité "PC perdu / réinstallation" : si la BDD locale
        // n'existe pas, on tente de récupérer le dernier backup Supabase
        // AVANT que Drift n'en crée une neuve. Bloquant volontairement :
        // il faut que la restauration soit terminée avant d'ouvrir la base.
        await RestoreOnBoot.tryRestoreIfMissingLocal();
        // Sauvegarde cloud auto quotidienne (00:00 + rattrapage au démarrage).
        unawaited(AutoBackup.start());
        // Miroir des données vers Supabase (push initial, offline-safe).
        unawaited(MirrorService.syncAll());
        // Pull périodique (chambres + comptes) : synchronise les
        // ajouts/modifs faits sur les autres postes vers celui-ci.
        MirrorPullService.instance.start();
        // Contrôle de l'horloge. Une horloge fausse classe les
        // ventes au mauvais jour sans rien casser de visible :
        // c'est exactement ce qui est arrivé en septembre 2026.
        // Le décalage retenu la dernière fois sert de filet tant que
        // la mesure fraîche n'est pas revenue — un poste qui démarre
        // sans réseau repartirait sinon sur son horloge fausse.
        unawaited(HorlogeService.instance
            .relireDecalageMemorise()
            .then((_) => HorlogeService.instance.mesurer()));
      } catch (e, st) {
        // Échec d'init (pas de réseau au démarrage, clés invalides,
        // projet Supabase en pause…) → l'app continue en local avec les
        // comptes de secours. On trace au lieu d'avaler : c'est le
        // premier symptôme qu'on regarde quand la production coince.
        debugPrint('Supabase indisponible au démarrage : $e');
        unawaited(ErrorReporter.report(e, st, context: 'boot/supabase'));
      }
    }

    // Verificateur de mise a jour a distance (check au boot + toutes
    // les 6h). Non-bloquant, silencieux si aucun manifest configure.
    UpdateService.instance.start();

    runApp(const ProviderScope(child: BlueSkyApp()));
  }, (error, stack) {
    // Erreurs asynchrones non capturées.
    ErrorReporter.report(error, stack, context: 'uncaught');
  });
}
