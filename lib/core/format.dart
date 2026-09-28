import 'package:intl/intl.dart';

/// Devise unique de l'application : Franc Congolais (FC).
///
/// Historique : la colonne DB s'appelle encore `priceCents` (nom Drift figé)
/// mais elle stocke désormais un **montant FC entier**, pas des cents USD.
/// Les fonctions ci-dessous formatent ce montant tel quel — plus aucune
/// conversion à l'affichage courant.
///
/// L'équivalent USD n'est utilisé QUE dans les rapports/factures PDF, via
/// [moneyUsdFromFc]. Le taux FC→USD est modifiable par admin / super admin
/// depuis Paramètres → « Taux de change ». La valeur courante est stockée
/// dans la table `settings`, cache mémoire dans [Currency.rate].
final _fc = NumberFormat.decimalPattern('fr_FR');

/// Cache mémoire du taux courant, synchronisé avec la table `settings` par
/// [BlueSkyApp] au démarrage et à chaque changement d'admin.
///
/// [defaultRate] est la valeur utilisée quand rien n'a encore été configuré
/// (2300 FC pour 1 USD au moment de l'écriture — modifiable ensuite).
class Currency {
  Currency._();
  static const double defaultRate = 2300;
  static double rate = defaultRate;
}

final _usd =
    NumberFormat.currency(locale: 'fr_FR', symbol: r'$', decimalDigits: 2);

/// Formate un montant FC entier : `5000` → `"5 000 FC"`.
///
/// Le paramètre s'appelle toujours `cents` pour compatibilité avec les
/// nombreux call-sites (`priceCents`, `unitPriceCents`, `totalCents`).
String moneyCents(int cents, {int decimals = 0}) => '${_fc.format(cents)} FC';

/// Prix d'un article au catalogue, ou la mention qu'il n'en a pas.
///
/// Un article sans prix affichait « 0 FC » — ce qui ressemble à un bug
/// et laisse croire qu'il est gratuit. Whisky Red Label, Amarula et
/// Baileys étaient dans ce cas. Le dire explicitement invite à corriger
/// la fiche au lieu de douter du logiciel.
String prixArticle(int cents) =>
    cents <= 0 ? 'Prix à définir' : moneyCents(cents);

/// Alias explicite (nouveau code) — même comportement que [moneyCents].
String moneyFc(int fc) => '${_fc.format(fc)} FC';

/// Convertit un montant FC en équivalent USD affichable : `100000` → `"$43.48"`.
/// **PDF uniquement.** Utilise [Currency.rate].
String moneyUsdFromFc(int fc) => _usd.format(fc / Currency.rate);

String categoryLabel(int catIndex) {
  const labels = ['Boissons', 'Nourriture', 'Chambres'];
  return labels[catIndex];
}
