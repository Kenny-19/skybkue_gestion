import 'dart:io';

import 'package:blue_sky/theme/typography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Les polices de l'interface et des factures sont EMBARQUÉES dans l'app
// et déclarées au moteur (pubspec.yaml, section `fonts`). Hors ligne,
// l'app s'affiche dans sa vraie police et les factures se génèrent.
//
// Ce test vérifie que chaque graisse que l'interface demande a son
// fichier déclaré ET présent. Une graisse manquante ne casse rien de
// visible : le moteur prend la plus proche — on veut le savoir ici, pas
// à l'hôtel.

/// Fichier déclaré dans pubspec.yaml pour chaque famille (« Inter_600 »).
Map<String, String> _declarees() {
  final res = <String, String>{};
  String? famille;
  for (final l in File('pubspec.yaml').readAsLinesSync()) {
    final t = l.trim();
    if (t.startsWith('- family:')) famille = t.split(':').last.trim();
    if (t.startsWith('- asset:') && famille != null) {
      res[famille] = t.split(':').last.trim();
    }
  }
  return res;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chaque graisse Inter utilisée est déclarée et présente', () {
    final declarees = _declarees();
    for (final w in FontWeight.values) {
      final famille = familleTexte(w);
      expect(declarees[famille], isNotNull, reason: famille);
      expect(File(declarees[famille]!).existsSync(), isTrue, reason: famille);
    }
    expect(BsType.body(13).fontFamily, 'Inter_400');
    expect(BsType.body(13, w: FontWeight.w600).fontFamily, 'Inter_600');
    expect(BsType.display(24).fontFamily, 'Inter_700');
    expect(BsType.eyebrow().fontFamily, 'Inter_600');
  });

  test('chaque graisse JetBrains Mono utilisée est déclarée et présente', () {
    final declarees = _declarees();
    for (final w in FontWeight.values) {
      final famille = familleChiffres(w);
      expect(declarees[famille], isNotNull, reason: famille);
      expect(File(declarees[famille]!).existsSync(), isTrue, reason: famille);
    }
    expect(BsType.mono(12, w: FontWeight.w600).fontFamily, 'JetBrainsMono_600');
  });

  test('les polices des factures se chargent sans réseau', () async {
    for (final f in [
      'Inter-Regular.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
    ]) {
      final data = await rootBundle.load('assets/fonts/$f');
      expect(data.lengthInBytes, greaterThan(100000), reason: f);
    }
  });

  test('un même style est construit une seule fois', () {
    expect(identical(BsType.body(13), BsType.body(13)), isTrue);
    expect(identical(BsType.body(13), BsType.body(14)), isFalse);
  });
}
