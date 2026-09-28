import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

import '../core/app_version.dart';
import '../core/cloud_config.dart';

/// Info d'une nouvelle version disponible cote cloud.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String sha256Hex;
  final int sizeBytes;
  final String? notes;
  final DateTime? releaseDate;
  final bool mandatory;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.sha256Hex,
    required this.sizeBytes,
    this.notes,
    this.releaseDate,
    this.mandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        version: json['version'] as String,
        downloadUrl: json['download_url'] as String,
        sha256Hex: (json['sha256'] as String).toLowerCase(),
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        notes: json['notes'] as String?,
        releaseDate: json['release_date'] == null
            ? null
            : DateTime.tryParse(json['release_date'] as String),
        mandatory: (json['mandatory'] as bool?) ?? false,
      );
}

/// Progression du telechargement (0..1 + bytes recus/total).
class DownloadProgress {
  final int received;
  final int total;
  double get ratio => total > 0 ? received / total : 0;
  const DownloadProgress(this.received, this.total);
}

/// Verifie periodiquement si une nouvelle version est disponible,
/// et gere le telechargement + lancement de l'installeur.
///
///   1. Check au boot + toutes les 6h
///   2. Compare la version distante avec [kAppVersion] (semver)
///   3. Si distant > local -> expose [UpdateInfo], la banniere apparait
///   4. Sur clic "Mettre a jour" : download -> verify SHA-256 -> launch
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // Etat pour l'UI (via provider Riverpod plus bas).
  final ValueNotifier<UpdateInfo?> _available = ValueNotifier(null);
  ValueListenable<UpdateInfo?> get available => _available;

  final ValueNotifier<DownloadProgress?> _progress = ValueNotifier(null);
  ValueListenable<DownloadProgress?> get progress => _progress;

  final ValueNotifier<String?> _error = ValueNotifier(null);
  ValueListenable<String?> get error => _error;

  Timer? _timer;

  /// A appeler UNE fois au demarrage (main.dart). Non-bloquant.
  void start() {
    unawaited(checkNow());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Force une verification manuelle. Retourne l'info si dispo, sinon null.
  Future<UpdateInfo?> checkNow() async {
    if (CloudConfig.updateManifestUrl.isEmpty) return null;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final url = Uri.parse(CloudConfig.updateManifestUrl);
        // Cache-buster : evite les caches CDN agressifs.
        final busted = url.replace(queryParameters: {
          ...url.queryParameters,
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        final req = await client.getUrl(busted);
        req.headers.set('Cache-Control', 'no-cache');
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) return null;
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(sansBom(body)) as Map<String, dynamic>;
        final info = UpdateInfo.fromJson(json);
        final remote = Version.parse(info.version);
        final local = Version.parse(kAppVersion);
        if (remote > local) {
          _available.value = info;
          return info;
        } else {
          _available.value = null;
          return null;
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('[UpdateService] check echoue : $e');
      return null;
    }
  }

  /// Efface l'info affichee ("Plus tard" dans la banniere). Ne bloque
  /// pas le prochain check dans 6h.
  void dismiss() => _available.value = null;

  /// Telecharge l'installeur, verifie le hash, lance en `/S` (silent).
  /// Renvoie `true` si le lancement a reussi (l'app va se fermer).
  Future<bool> downloadAndInstall({bool silent = false}) async {
    final info = _available.value;
    if (info == null) return false;

    _error.value = null;
    _progress.value = const DownloadProgress(0, 0);

    File? installerFile;
    try {
      // 1. Dossier temp + nom prevu.
      final tmpDir = await getTemporaryDirectory();
      final fileName = p.basename(info.downloadUrl.split('?').first);
      installerFile = File(p.join(tmpDir.path, fileName));
      if (installerFile.existsSync()) {
        // Nettoie un ancien download partiel/complet.
        try {
          installerFile.deleteSync();
        } catch (_) {}
      }

      // 2. Download avec progression.
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final req = await client.getUrl(Uri.parse(info.downloadUrl));
        final resp = await req.close();
        if (resp.statusCode != 200) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        final total =
            resp.contentLength > 0 ? resp.contentLength : info.sizeBytes;
        final sink = installerFile.openWrite();
        int received = 0;
        try {
          await for (final chunk in resp) {
            sink.add(chunk);
            received += chunk.length;
            _progress.value = DownloadProgress(received, total);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      } finally {
        client.close(force: true);
      }

      // 3. Verification hash SHA-256.
      final bytes = await installerFile.readAsBytes();
      final gotHash = sha256.convert(bytes).toString();
      if (gotHash != info.sha256Hex) {
        throw Exception(
            'Hash incorrect (attendu ${info.sha256Hex}, recu $gotHash).\n'
            'Fichier corrompu ou modifie. Installation annulee.');
      }

      // 4. Lancement de l'installeur en mode detache.
      // NSIS accepte /S pour silent — ferme aussi l'app via taskkill dans
      // le script (defensive) puis se relance grace au MUI_FINISHPAGE_RUN
      // s'il n'est pas en silent.
      final args = silent ? ['/S'] : <String>[];
      await Process.start(
        installerFile.path,
        args,
        mode: ProcessStartMode.detached,
      );

      // 5. Petit delai pour que l'installeur demarre son taskkill AVANT
      // qu'on quitte proprement l'app.
      await Future.delayed(const Duration(seconds: 2));

      // 6. Quitte l'app pour liberer les fichiers .exe/.dll — l'installeur
      // pourra alors les remplacer. NSIS lance la nouvelle version a la fin.
      exit(0);
    } catch (e) {
      _error.value = e.toString();
      _progress.value = null;
      return false;
    }
  }
}

// ─── Providers Riverpod ────────────────────────────────────────────────

/// Info d'une nouvelle version disponible (null = a jour).
final updateAvailableProvider =
    ChangeNotifierProvider<_ValueListenableNotifier<UpdateInfo?>>(
  (ref) => _ValueListenableNotifier(UpdateService.instance.available),
);

/// Progression du download en cours (null = pas de download actif).
final updateProgressProvider =
    ChangeNotifierProvider<_ValueListenableNotifier<DownloadProgress?>>(
  (ref) => _ValueListenableNotifier(UpdateService.instance.progress),
);

/// Erreur eventuelle du dernier download (null = OK).
final updateErrorProvider =
    ChangeNotifierProvider<_ValueListenableNotifier<String?>>(
  (ref) => _ValueListenableNotifier(UpdateService.instance.error),
);

/// Bridge ValueListenable -> ChangeNotifier pour Riverpod.
class _ValueListenableNotifier<T> extends ChangeNotifier {
  final ValueListenable<T> _source;
  _ValueListenableNotifier(this._source) {
    _source.addListener(_fire);
  }
  T get value => _source.value;
  void _fire() => notifyListeners();
  @override
  void dispose() {
    _source.removeListener(_fire);
    super.dispose();
  }
}


/// Retire la marque d'ordre des octets en tête d'un texte JSON.
///
/// `jsonDecode` lève sur un BOM : « Unexpected character (at character
/// 1) ». Ce n'est pas théorique — `Set-Content -Encoding UTF8` en
/// PowerShell 5.1 en ajoute un, le script de release s'en servait, et la
/// vérification de mise à jour échouait donc à CHAQUE passage. En
/// silence, puisque l'échec se contentait de ne rien afficher : les
/// postes sont restés bloqués plusieurs jours sur une ancienne version
/// alors qu'une nouvelle était publiée et téléchargeable.
///
/// Le script est corrigé. Cette fonction reste : un manifeste peut être
/// réécrit à la main, par un autre outil, sur une autre machine. La
/// bannière de mise à jour est le seul chemin vers les postes distants —
/// elle ne doit pas dépendre de trois octets invisibles.
String sansBom(String texte) =>
    texte.startsWith('﻿') ? texte.substring(1) : texte;
