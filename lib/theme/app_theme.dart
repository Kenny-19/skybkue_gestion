import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData buildBlueSkyTheme() => _build(Brightness.light);
ThemeData buildBlueSkyThemeDark() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: BsColors.sky,
    onPrimary: Colors.white,
    secondary: BsColors.sunrise,
    onSecondary: BsColors.ink,
    error: BsColors.danger,
    onError: Colors.white,
    surface: dark ? BsColors.paperDark : BsColors.paper,
    onSurface: dark ? Colors.white : BsColors.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? BsColors.papyrusDark : BsColors.papyrus,
    textTheme: GoogleFonts.interTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: dark ? Colors.white : BsColors.ink,
      displayColor: dark ? Colors.white : BsColors.ink,
    ),
  );

  return base.copyWith(
    dividerColor: dark ? BsColors.lineDark : BsColors.line,
    dividerTheme: DividerThemeData(
      color: dark ? BsColors.lineDark : BsColors.line,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: dark ? BsColors.paperDark : BsColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BsRadius.md),
        side: BorderSide(color: dark ? BsColors.lineDark : BsColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? BsColors.paperDark : BsColors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(
          color:
              dark ? BsColors.slateSoftDark : BsColors.slateSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BsRadius.sm),
        borderSide:
            BorderSide(color: dark ? BsColors.lineDark : BsColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BsRadius.sm),
        borderSide:
            BorderSide(color: dark ? BsColors.lineDark : BsColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BsRadius.sm),
        borderSide: const BorderSide(color: BsColors.sky, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? BsColors.sky : BsColors.ink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.sm)),
        textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? Colors.white : BsColors.ink,
        side: BorderSide(color: dark ? Colors.white54 : BsColors.ink),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.sm)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
  );
}
