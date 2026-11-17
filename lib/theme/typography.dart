import 'package:flutter/material.dart';

import 'tokens.dart';

/// Polices embarquées, déclarées dans pubspec.yaml (section `fonts`).
///
/// Elles passaient par le paquet google_fonts : chaque style attendait le
/// chargement asynchrone de son fichier, les premiers écrans se
/// dessinaient dans une police de secours puis se remettaient en page, et
/// le paquet embarquait de quoi télécharger des polices qu'on ne
/// télécharge plus. Déclarées ici, le moteur les charge lui-même.
///
/// UNE FAMILLE PAR FICHIER (« Inter_600 »), et non une famille à plusieurs
/// graisses : réunies sous un même nom, le moteur choisit le GRAS (700)
/// quand on lui demande le demi-gras (600) — vérifié au pixel. Une famille
/// par fichier, c'est ce que faisait google_fonts : le rendu reste
/// exactement le même.
const String kPoliceTexte = 'Inter';
const String kPoliceChiffres = 'JetBrainsMono';

const _grasInter = [400, 500, 600, 700, 800];
const _grasMono = [500, 600, 700, 800];

/// La famille du fichier le plus proche de [w], parmi [disponibles].
String _famille(String base, List<int> disponibles, FontWeight? w) {
  final voulu = (w ?? FontWeight.w400).value;
  var choisi = disponibles.first;
  for (final g in disponibles) {
    if ((g - voulu).abs() < (choisi - voulu).abs()) choisi = g;
  }
  return '${base}_$choisi';
}

/// Famille Inter du fichier qui correspond à la graisse [w].
String familleTexte(FontWeight? w) => _famille(kPoliceTexte, _grasInter, w);

/// Famille JetBrains Mono du fichier qui correspond à la graisse [w].
String familleChiffres(FontWeight? w) =>
    _famille(kPoliceChiffres, _grasMono, w);

/// [t] avec la famille Inter de sa propre graisse.
TextStyle? enInter(TextStyle? t) =>
    t?.copyWith(fontFamily: familleTexte(t.fontWeight));

/// Tout un thème de texte en Inter, chaque style dans le fichier de sa
/// graisse.
TextTheme texteEnInter(TextTheme t) => t.copyWith(
      displayLarge: enInter(t.displayLarge),
      displayMedium: enInter(t.displayMedium),
      displaySmall: enInter(t.displaySmall),
      headlineLarge: enInter(t.headlineLarge),
      headlineMedium: enInter(t.headlineMedium),
      headlineSmall: enInter(t.headlineSmall),
      titleLarge: enInter(t.titleLarge),
      titleMedium: enInter(t.titleMedium),
      titleSmall: enInter(t.titleSmall),
      bodyLarge: enInter(t.bodyLarge),
      bodyMedium: enInter(t.bodyMedium),
      bodySmall: enInter(t.bodySmall),
      labelLarge: enInter(t.labelLarge),
      labelMedium: enInter(t.labelMedium),
      labelSmall: enInter(t.labelSmall),
    );

class BsType {
  BsType._();

  /// Chiffres à chasse fixe, appliqués à TOUS les styles.
  ///
  /// Sans ça, un « 1 » est plus étroit qu'un « 8 » : dans une colonne de
  /// montants, les nombres se décalent d'une ligne à l'autre. C'est le
  /// détail qui distingue le plus un logiciel soigné d'un logiciel
  /// bricolé — et dans une caisse, presque tout est chiffre.
  ///
  /// Sans aucun effet sur les lettres.
  static const _chiffresAlignes = [FontFeature.tabularFigures()];

  /// Styles déjà construits, par combinaison de paramètres.
  ///
  /// Ces fonctions sont appelées ~500 fois dans l'interface, à CHAQUE
  /// reconstruction d'écran : chaque appel refaisait un style complet et
  /// repassait par la vérification de chargement de la police. Le même
  /// style est maintenant rendu à l'identique, une fois construit. Le
  /// nombre de combinaisons réellement utilisées est petit et fini.
  static final Map<String, TextStyle> _deja = {};

  static TextStyle _une(String cle, TextStyle Function() construire) =>
      _deja[cle] ??= construire();

  /// Titre / display : Inter tight — donne du poids sans rompre le
  /// registre "propre classique" de tout le reste de l'UI.
  static TextStyle display(double size,
          {FontWeight w = FontWeight.w700, Color? color}) =>
      _une(
          'd|$size|${w.value}|${(color ?? BsColors.ink).toARGB32()}',
          () => TextStyle(
                fontFamily: familleTexte(w),
                fontSize: size,
                fontWeight: w,
                letterSpacing: -0.4,
                color: color ?? BsColors.ink,
                fontFeatures: _chiffresAlignes,
                height: 1.1,
              ));

  static TextStyle heading(double size,
          {FontWeight w = FontWeight.w600, Color? color}) =>
      _une(
          'h|$size|${w.value}|${(color ?? BsColors.ink).toARGB32()}',
          () => TextStyle(
                fontFamily: familleTexte(w),
                fontSize: size,
                fontWeight: w,
                letterSpacing: -0.2,
                color: color ?? BsColors.ink,
                fontFeatures: _chiffresAlignes,
                height: 1.2,
              ));

  /// [d] : décoration optionnelle — sert notamment à barrer un tarif
  /// catalogue remplacé par un tarif négocié.
  static TextStyle body(double size,
          {FontWeight w = FontWeight.w400, Color? color, TextDecoration? d}) =>
      _une(
          'b|$size|${w.value}|${(color ?? BsColors.ink).toARGB32()}|$d',
          () => TextStyle(
                fontFamily: familleTexte(w),
                fontSize: size,
                fontWeight: w,
                color: color ?? BsColors.ink,
                fontFeatures: _chiffresAlignes,
                height: 1.4,
                decoration: d,
              ));

  static TextStyle eyebrow({Color? color}) => _une(
      'e|${(color ?? BsColors.slate).toARGB32()}',
      () => TextStyle(
            fontFamily: familleTexte(FontWeight.w600),
            fontFeatures: _chiffresAlignes,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: color ?? BsColors.slate,
          ));

  static TextStyle mono(double size,
          {FontWeight w = FontWeight.w500, Color? color}) =>
      _une(
          'm|$size|${w.value}|${(color ?? BsColors.ink).toARGB32()}',
          () => TextStyle(
                fontFamily: familleChiffres(w),
                fontSize: size,
                fontWeight: w,
                color: color ?? BsColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ));
}
