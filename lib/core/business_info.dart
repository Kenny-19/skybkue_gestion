/// Informations de l'établissement imprimées sur les factures / tickets.
///
/// Ces constantes sont volontairement gardées en dur : l'établissement change
/// rarement d'infos. Pour les modifier, éditer ce fichier puis rebuild.
class BusinessInfo {
  BusinessInfo._();

  /// Nom commercial affiché en gros en tête de ticket.
  static const String name = 'SkyBlue GUEST HOUSE';

  /// Sous-titre sous le nom (une ligne, court).
  static const String tagline = 'Lubumbashi';

  /// Adresse — chaque élément = une ligne imprimée. Laisser vide pour
  /// ne rien imprimer (le ticket restera compact).
  static const List<String> addressLines = [];

  /// Téléphone principal (avec indicatif international).
  static const String phone = '+243 832 111 171';

  /// Email de contact (imprimé si non vide).
  static const String email = 'info@skyblue.com';

  /// Site web (imprimé si non vide).
  static const String website = 'http://www.skyblue-rdc.com';

  /// Services / commodités à mentionner en pied de ticket (courts).
  /// Laisser une liste vide pour ne rien afficher.
  static const List<String> footerNotes = [];
}
