import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/cloud_config.dart';
import 'services/auto_backup.dart';
import 'services/error_reporter.dart';
import 'services/mirror_service.dart';

Future<void> main() async {
  // runZonedGuarded capture les erreurs asynchrones non gérées et les envoie
  // vers Supabase (→ email côté serveur).
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');

    // Erreurs du framework Flutter (build/layout/paint).
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      ErrorReporter.report(details.exception, details.stack,
          context: 'FlutterError');
    };

    // Initialise Supabase uniquement si les clés sont renseignées.
    // Sinon l'app démarre en 100% local sans aucune dépendance réseau.
    if (CloudConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: CloudConfig.supabaseUrl,
          anonKey: CloudConfig.supabaseAnonKey,
        );
        // Sauvegarde cloud auto quotidienne (00:00 + rattrapage au démarrage).
        unawaited(AutoBackup.start());
        // Miroir des données vers Supabase (push initial, offline-safe).
        unawaited(MirrorService.syncAll());
      } catch (_) {
        // Échec d'init (pas de réseau au démarrage) → on continue en local.
      }
    }

    runApp(const ProviderScope(child: BlueSkyApp()));
  }, (error, stack) {
    // Erreurs asynchrones non capturées.
    ErrorReporter.report(error, stack, context: 'uncaught');
  });
}
