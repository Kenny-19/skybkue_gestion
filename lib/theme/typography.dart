import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

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
          () => GoogleFonts.inter(
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
          () => GoogleFonts.inter(
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
          () => GoogleFonts.inter(
                fontSize: size,
                fontWeight: w,
                color: color ?? BsColors.ink,
                fontFeatures: _chiffresAlignes,
                height: 1.4,
                decoration: d,
              ));

  static TextStyle eyebrow({Color? color}) => _une(
      'e|${(color ?? BsColors.slate).toARGB32()}',
      () => GoogleFonts.inter(
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
          () => GoogleFonts.jetBrainsMono(
                fontSize: size,
                fontWeight: w,
                color: color ?? BsColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ));
}
