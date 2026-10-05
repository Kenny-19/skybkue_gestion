import 'package:blue_sky/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Les polices de l'interface et des factures sont EMBARQUÉES dans l'app
// (assets/fonts). Avant, elles étaient téléchargées à l'usage : hors
// ligne, l'app s'affichait dans une police système et une facture pouvait
// échouer.
//
// Ce test interdit tout téléchargement, puis demande chaque graisse que
// l'interface utilise réellement. Si l'une manque dans assets/fonts, il
// échoue — au lieu de le découvrir à l'hôtel, sans réseau.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

  test('chaque graisse Inter utilisée est embarquée', () async {
    for (final w in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      BsType.body(13, w: w);
    }
    BsType.display(24);
    BsType.heading(16);
    BsType.eyebrow();
    await expectLater(GoogleFonts.pendingFonts(), completes);
  });

  test('chaque graisse JetBrains Mono utilisée est embarquée', () async {
    for (final w in [
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      BsType.mono(12, w: w);
    }
    await expectLater(GoogleFonts.pendingFonts(), completes);
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
