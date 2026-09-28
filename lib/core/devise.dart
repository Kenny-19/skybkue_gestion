import 'package:intl/intl.dart';

import 'format.dart';

/// Le dollar et le franc, et lequel dit la vérité.
///
/// L'hôtel tarifie en DOLLARS : c'est le prix annoncé au client, et donc
/// la seule valeur saisie. Le franc reste la monnaie d'encaissement — la
/// caisse, les dettes et les rapports sont en FC — mais il se calcule au
/// taux. Le tarif d'une chambre ne doit pas bouger parce que le franc a
/// bougé.
///
/// Pourquoi le taux se fige
/// ------------------------
/// `Currency.rate` est une valeur unique et COURANTE. Une facture émise
/// à 2300 et réimprimée à 2600 annoncerait un total en dollars différent
/// de celui que le client a payé. Chaque séjour porte donc le taux de
/// son check-out, et c'est lui qu'on rejoue — jamais celui du jour.

final _usdStrict =
    NumberFormat.currency(locale: 'fr_FR', symbol: r'$', decimalDigits: 2);

/// Taux stocké × 100, ramené au taux réel. Zéro ou absurde → taux
/// courant, faute de mieux.
double tauxDepuisCents(int? fcPerUsdCents) {
  if (fcPerUsdCents == null || fcPerUsdCents <= 0) return Currency.rate;
  return fcPerUsdCents / 100;
}

/// Le taux courant, sous la forme figeable sur un séjour.
int tauxCourantEnCents() => (Currency.rate * 100).round();

/// Dollars → francs, au taux donné.
///
/// L'arrondi se fait au franc, pas au centime : la caisse ne rend pas la
/// monnaie en centimes de franc, et un total qui ne tombe pas juste
/// oblige la réception à bricoler.
int usdVersFc(int usdCents, {double? taux}) =>
    ((usdCents / 100) * (taux ?? Currency.rate)).round();

/// Francs → dollars. Utilisé pour reprendre l'existant, pas pour
/// tarifer : le sens normal va du dollar vers le franc.
int fcVersUsd(int fc, {double? taux}) {
  final t = taux ?? Currency.rate;
  if (t <= 0) return 0;
  return ((fc / t) * 100).round();
}

/// `4500` → `"$45.00"`.
String moneyUsd(int usdCents) => _usdStrict.format(usdCents / 100);

/// Le montant tel qu'on l'annonce à l'hôtel : dollar d'abord, franc
/// entre parenthèses.
///
/// L'ordre n'est pas décoratif. Le client négocie en dollars, la
/// réception encaisse en francs : les deux doivent être lisibles d'un
/// coup d'œil, mais c'est le dollar qui porte l'accord.
String montantHotel(int usdCents, {double? taux}) =>
    '${moneyUsd(usdCents)} (${moneyCents(usdVersFc(usdCents, taux: taux))})';

/// `4500` → `"$45"` ; `4550` → `"$45.50"`.
///
/// Les centimes ne s'affichent que s'il y en a. Un tarif d'hôtel tombe
/// presque toujours rond, et « $45.00 » partout ajoute du bruit sans
/// rien apprendre — mais « $45 » quand le vrai prix est 45,50 serait un
/// mensonge, alors on garde les décimales quand elles existent.
String moneyUsdCourt(int usdCents) => usdCents % 100 == 0
    ? '\$${usdCents ~/ 100}'
    : moneyUsd(usdCents);

/// Version compacte pour les listes : `"$45 · 103 500 FC"`.
///
/// Même ordre que [montantHotel] — le dollar d'abord, parce que c'est
/// lui qui porte l'accord avec le client — mais sans parenthèses, qui
/// mangent la place dans un sous-titre.
String montantHotelCourt(int usdCents, {double? taux}) =>
    '${moneyUsdCourt(usdCents)} · ${moneyCents(usdVersFc(usdCents, taux: taux))}';
