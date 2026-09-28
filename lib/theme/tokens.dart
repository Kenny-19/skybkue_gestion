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

  /// Voile sombre posé sur une photo pour que le texte blanc reste
  /// lisible quelle que soit l'image (cartes produits de la caisse).
  static const scrim = Color(0xCC000000);
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
  BsSurface get bs => BsSurface(Theme.of(this).brightness == Brightness.dark);
}

/// Échelle d'espacement.
///
/// Elle ne comptait que 4/8/16/24/32/48, alors que le code utilise
/// massivement 6, 10, 12 et 20 — 66 % des espacements tombaient donc
/// « hors échelle ». Le défaut n'était pas dans le code : une échelle
/// qui double à chaque cran est trop grossière pour de l'interface
/// dense. Elle décrit maintenant ce qui est réellement utilisé, ce qui
/// rend enfin l'écart détectable quand il y en a un.
///
/// Les paliers intermédiaires servent AU SEIN d'un composant (entre un
/// libellé et sa valeur) ; les grands paliers séparent les blocs.
class BsSpace {
  BsSpace._();

  /// 2 — filet entre deux lignes d'un même bloc de texte.
  static const double xxs = 2;

  /// 4
  static const double xs = 4;

  /// 6 — le plus courant : écart libellé ↔ valeur.
  static const double xs2 = 6;

  /// 8
  static const double sm = 8;

  /// 10
  static const double sm2 = 10;

  /// 12 — écart entre deux éléments d'une même carte.
  static const double smd = 12;

  /// 16
  static const double md = 16;

  /// 20
  static const double md2 = 20;

  /// 24
  static const double lg = 24;

  /// 32
  static const double xl = 32;

  /// 48
  static const double xxl = 48;
}

/// Hauteurs de contrôles.
///
/// Trois valeurs coexistaient pour le même objet — un bouton compact
/// faisait 30 px dans Stock et 32 px dans Historique. Personne ne nomme
/// ce genre d'écart, mais il se voit quand deux écrans se suivent.
///
/// Le seuil tactile de 44 px ne s'applique PAS ici : ce logiciel tourne
/// au clavier et à la souris sur un PC. Il vaut pour le tableau de bord
/// de Pamela, qui se consulte au téléphone.
class BsControl {
  BsControl._();

  /// Bouton secondaire dans une liste dense (« Détail », « Ravitailler »).
  static const double compact = 32;

  /// Bouton standard d'un formulaire ou d'un en-tête.
  static const double normal = 40;

  /// Action principale d'un écran (« Encaisser »).
  static const double primary = 52;
}

class BsRadius {
  BsRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
}
