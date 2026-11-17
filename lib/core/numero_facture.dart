/// Numérotation des factures de séjour.
///
/// Avant : `FCT{3 derniers chiffres de l'heure en millisecondes}/{mois}/
/// {année}`. Mille numéros possibles par mois, tirés au hasard de
/// l'horloge : à cinquante factures, deux portaient presque sûrement le
/// même numéro. Une facture se retrouve, se conteste et se déclare par
/// son numéro ; il doit être unique.
///
/// Désormais : `FCT0042-R/11/2026`.
///   * `0042` : compteur propre au poste, qui ne fait que monter et ne
///     repart jamais à zéro ;
///   * `R` : le code du poste (réglable dans les Paramètres), qui rend le
///     numéro unique d'un poste à l'autre sans avoir besoin du réseau.
library;

/// Code de poste valide : 1 à 3 lettres ou chiffres, en majuscules.
final RegExp _codeValide = RegExp(r'^[A-Z0-9]{1,3}$');

/// Normalise une saisie de code de poste. Null si elle n'est pas valide.
String? codePosteDepuisSaisie(String saisie) {
  final c = saisie.trim().toUpperCase();
  return _codeValide.hasMatch(c) ? c : null;
}

/// Code par défaut, déduit du nom de la machine, tant que personne n'en a
/// réglé un : deux caractères, stables pour un même poste.
///
/// Deux postes peuvent tomber sur le même code (1 chance sur 1 296) :
/// c'est pourquoi les Paramètres le montrent et permettent de le changer.
String codePosteParDefaut(String nomMachine) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  // FNV-1a : le même nom donne toujours le même code, sur toute machine.
  var h = 0x811c9dc5;
  for (final u in nomMachine.toUpperCase().codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return '${alphabet[h % 26]}${alphabet[(h ~/ 26) % alphabet.length]}';
}

/// `FCT0042-R/11/2026`.
String numeroFacture(int compteur, String codePoste, DateTime le) =>
    'FCT${compteur.toString().padLeft(4, '0')}-$codePoste/${le.month}/${le.year}';

/// Le numéro de réservation imprimé sur la même facture, même forme.
String numeroReservation(int compteur, String codePoste, DateTime le) =>
    'RSV${compteur.toString().padLeft(4, '0')}-$codePoste/${le.month}/${le.year}';
