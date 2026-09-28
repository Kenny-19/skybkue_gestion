/// Le temps, et les deux fuseaux qui comptent.
///
/// Deux repères cohabitent dans cette application, et les confondre
/// coûte de l'argent :
///
///   • L'INSTANT, qui doit voyager. Un horodatage envoyé au serveur
///     s'écrit toujours en UTC, avec son « Z ». Sans ce suffixe,
///     Postgres lit le texte dans SON fuseau — UTC — et une vente de
///     14h30 à Lubumbashi devient 14h30 UTC, soit deux heures dans le
///     futur. C'était le cas jusqu'au 21 septembre 2026 : toutes les
///     ventes du miroir étaient décalées de +2h, ce qui faisait basculer
///     celles d'après 22h sur le lendemain et faussait les montants du
///     jour sur le tableau de bord.
///
///   • LA JOURNÉE COMMERCIALE, qui ne voyage pas. Elle commence à minuit
///     à Lubumbashi, point. Pas à minuit sur l'horloge du poste : un
///     poste mal réglé — celui de développement est sur UTC−5 — n'a pas
///     le droit de déplacer la frontière entre deux jours de caisse.
library;

/// Décalage de Lubumbashi. Constant : la RDC n'applique pas d'heure
/// d'été, donc aucune table de fuseaux n'est nécessaire.
const Duration decalageLubumbashi = Duration(hours: 2);

/// Horodatage destiné au serveur : instant absolu, suffixe « Z ».
///
/// À utiliser pour TOUT champ `timestamptz`. Jamais `toIso8601String()`
/// seul sur une date locale.
String isoServeur(DateTime d) => d.toUtc().toIso8601String();

/// Idem, pour un champ facultatif.
String? isoServeurOuNull(DateTime? d) => d == null ? null : isoServeur(d);

/// Minuit à Lubumbashi pour la journée qui contient [instant], rendu
/// dans le fuseau du poste — comparable avec les dates lues en base.
DateTime debutDeJourneeLubumbashi([DateTime? instant]) {
  final ref = (instant ?? DateTime.now()).toUtc().add(decalageLubumbashi);
  final minuit = DateTime.utc(ref.year, ref.month, ref.day);
  return minuit.subtract(decalageLubumbashi).toLocal();
}

/// La journée commerciale de Lubumbashi contenant [instant], sous forme
/// `[début, fin[`. La fin est exclusive : une vente à 23:59:59.999 du
/// 20 appartient au 20, jamais au 21.
({DateTime debut, DateTime fin}) journeeLubumbashi([DateTime? instant]) {
  final d = debutDeJourneeLubumbashi(instant);
  return (debut: d, fin: d.add(const Duration(days: 1)));
}

/// Un instant, exprimé en heure murale de Lubumbashi.
///
/// À utiliser pour TOUT affichage de date ou d'heure. Pas pour stocker.
///
/// Le `DateTime` rendu porte les champs — année, heure, minute — qu'une
/// horloge de Lubumbashi afficherait à cet instant. `DateFormat` lit ces
/// champs, donc le formatage tombe juste sur n'importe quelle machine :
/// le poste de développement sur UTC−5, celui de la réception sur UTC+2,
/// ou un poste mal réglé.
///
/// Sans ça, corriger l'instant enregistré reviendrait à afficher une
/// heure fausse au personnel — on aurait réparé la comptabilité en
/// cassant l'écran, ce qui se serait vu tout de suite et aurait fait
/// annuler la correction.
///
/// Le résultat est marqué UTC pour une raison : il ne désigne PLUS
/// l'instant d'origine, seulement ses chiffres. Le rendre « local »
/// laisserait croire qu'on peut le soustraire à un autre, et le premier
/// calcul fait dessus serait faux de deux heures.
DateTime aLubumbashi(DateTime instant) =>
    instant.toUtc().add(decalageLubumbashi);

/// Version tolérante au null, pour les champs facultatifs.
DateTime? aLubumbashiOuNull(DateTime? instant) =>
    instant == null ? null : aLubumbashi(instant);
