import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cloud_service.dart';
import '../core/temps.dart';

/// Sauvegarde cloud automatique une fois par jour, à 00:00.
///
/// Stratégie robuste pour une caisse (souvent éteinte la nuit) :
///  - **Timer minuit** : si l'app tourne, sauvegarde pile à 00:00.
///  - **Rattrapage au démarrage** : si aucune sauvegarde n'a eu lieu
///    aujourd'hui (app éteinte à minuit), sauvegarde dès l'ouverture.
///
/// La date de dernière sauvegarde réussie est stockée dans un petit fichier
/// marqueur (pas de dépendance externe).
class AutoBackup {
  AutoBackup._();

  static Timer? _timer;
  static DateTime? _lastSuccess;

  static Future<File> _markerFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final bsDir = Directory(p.join(dir.path, 'BlueSky'));
    if (!bsDir.existsSync()) bsDir.createSync(recursive: true);
    return File(p.join(bsDir.path, 'last_cloud_backup.txt'));
  }

  /// Dernière sauvegarde auto réussie (null si jamais).
  static Future<DateTime?> lastBackup() async {
    if (_lastSuccess != null) return _lastSuccess;
    final f = await _markerFile();
    if (!f.existsSync()) return null;
    _lastSuccess = DateTime.tryParse(await f.readAsString());
    return _lastSuccess;
  }

  static Future<void> _writeMarker(DateTime when) async {
    _lastSuccess = when;
    final f = await _markerFile();
    await f.writeAsString(when.toIso8601String());
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// À appeler une fois au démarrage de l'app.
  static Future<void> start() async {
    if (!CloudService.enabled) return;
    await _maybeCatchUp();
    _scheduleMidnight();
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Sauvegarde si rien n'a été fait aujourd'hui.
  static Future<void> _maybeCatchUp() async {
    final last = await lastBackup();
    final now = DateTime.now();
    if (last != null && _sameDay(last, now)) return; // déjà fait aujourd'hui
    await _run();
  }

  /// Programme le prochain déclenchement à 00:00.
  static void _scheduleMidnight() {
    _timer?.cancel();
    final now = DateTime.now();
    // Minuit à Lubumbashi : la sauvegarde doit tomber à la clôture
    // de la journée commerciale, pas à celle de l'horloge du poste.
    final nextMidnight =
        debutDeJourneeLubumbashi(now).add(const Duration(days: 1));
    final delay = nextMidnight.difference(now);
    _timer = Timer(delay, () async {
      await _run();
      _scheduleMidnight(); // reprogramme pour le lendemain
    });
  }

  /// Exécute la sauvegarde (silencieuse). N'écrit le marqueur qu'en cas de
  /// succès, pour que le rattrapage retente si c'était hors ligne.
  static Future<void> _run() async {
    if (!CloudService.enabled) return;
    final res = await CloudService.uploadBackup();
    if (res.ok) {
      await _writeMarker(DateTime.now());
    }
  }

  /// Déclenchement manuel (bouton "sauvegarder maintenant") — met à jour
  /// le marqueur si succès.
  static Future<CloudResult> runNow() async {
    final res = await CloudService.uploadBackup();
    if (res.ok) await _writeMarker(DateTime.now());
    return res;
  }
}
