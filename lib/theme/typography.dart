import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class BsType {
  BsType._();

  static TextStyle display(double size, {FontWeight w = FontWeight.w600, Color? color}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: w,
        letterSpacing: -0.5,
        color: color ?? BsColors.ink,
        height: 1.05,
      );

  static TextStyle heading(double size, {FontWeight w = FontWeight.w600, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        letterSpacing: -0.2,
        color: color ?? BsColors.ink,
        height: 1.2,
      );

  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: color ?? BsColors.ink,
        height: 1.4,
      );

  static TextStyle eyebrow({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: color ?? BsColors.slate,
      );

  static TextStyle mono(double size, {FontWeight w = FontWeight.w500, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: w,
        color: color ?? BsColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
