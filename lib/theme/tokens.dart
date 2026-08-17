import 'package:flutter/material.dart';

/// Palette Skyblue — teintes issues du logo (teal profond, blanc chaud).
/// Les surfaces (paper, papyrus, ink, line, slate) ont une variante dark
/// utilisée quand `Theme.of(context).brightness == Brightness.dark`.
class BsColors {
  BsColors._();

  // Accents (identiques en clair et sombre)
  static const sky = Color(0xFF2E7FA1); // teal Skyblue (primaire)
  static const skyDeep = Color(0xFF1D6180);
  static const sunrise = Color(0xFFF4A261); // accent chaud
  static const success = Color(0xFF2E8B57);
  static const danger = Color(0xFFC0392B);
  static const warning = Color(0xFFE0A800);

  // Surfaces — mode clair (défaut)
  static const ink = Color(0xFF0E3A47); // deep teal — sidebar, titres
  static const inkSoft = Color(0xFF164A5A);
  static const papyrus = Color(0xFFF5F1E8); // fond principal chaud
  static const paper = Color(0xFFFBF9F3); // cartes
  static const slate = Color(0xFF5E6A78);
  static const slateSoft = Color(0xFF9AA5B1);
  static const line = Color(0xFFE5DFD1);

  // Surfaces — mode sombre
  static const inkDark = Color(0xFF071B22); // fond principal
  static const inkSoftDark = Color(0xFF0E2E38); // cartes / sidebar
  static const papyrusDark = Color(0xFF0A2029);
  static const paperDark = Color(0xFF102F3A);
  static const slateDark = Color(0xFFA9B8C4);
  static const slateSoftDark = Color(0xFF6B7B87);
  static const lineDark = Color(0xFF1E4655);
}

/// Wrapper contextuel : `context.bs.paper` renvoie la bonne variante
/// (claire ou sombre) selon le thème courant.
class BsSurface {
  final bool dark;
  const BsSurface(this.dark);

  Color get papyrus => dark ? BsColors.papyrusDark : BsColors.papyrus;
  Color get paper => dark ? BsColors.paperDark : BsColors.paper;
  Color get ink => dark ? Colors.white : BsColors.ink;
  Color get inkSoft => dark ? BsColors.inkSoftDark : BsColors.inkSoft;
  Color get slate => dark ? BsColors.slateDark : BsColors.slate;
  Color get slateSoft => dark ? BsColors.slateSoftDark : BsColors.slateSoft;
  Color get line => dark ? BsColors.lineDark : BsColors.line;
}

extension BsContext on BuildContext {
  BsSurface get bs =>
      BsSurface(Theme.of(this).brightness == Brightness.dark);
}

class BsSpace {
  BsSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class BsRadius {
  BsRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
}
