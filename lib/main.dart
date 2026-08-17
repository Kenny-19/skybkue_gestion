import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/cloud_config.dart';
import 'services/auto_backup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  // Initialise Supabase uniquement si les clés sont renseignées.
  // Sinon l'app démarre en 100% local sans aucune dépendance réseau.
  if (CloudConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        anonKey: CloudConfig.supabaseAnonKey,
      );
      // Sauvegarde cloud auto quotidienne (00:00 + rattrapage au démarrage).
      // Non-bloquant : ne ralentit pas le lancement.
      unawaited(AutoBackup.start());
    } catch (_) {
      // Échec d'init (pas de réseau au démarrage) → on continue en local.
    }
  }

  runApp(const ProviderScope(child: BlueSkyApp()));
}
