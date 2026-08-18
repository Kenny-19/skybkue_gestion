import 'package:intl/intl.dart';

/// Devise de l'application : Franc Congolais (FC).
/// Les prix sont STOCKÉS en cents de dollar ($) — l'admin les saisit en $ —
/// puis convertis à l'affichage via un taux USD→FC réglable.
class Currency {
  Currency._();

  /// Taux courant : 1 USD = [rate] FC. Mis à jour au démarrage et à chaque
  /// changement par l'admin (voir CurrencySync dans app.dart).
  static double rate = 2800;

  static final _fc = NumberFormat.decimalPattern('fr_FR');

  /// Convertit des cents USD en montant FC (entier).
  static int centsToFc(int cents) => (cents / 100.0 * rate).round();
}

/// Formate des cents USD en Franc : "23 800 FC".
String moneyCents(int cents, {int decimals = 0}) {
  final fc = Currency.centsToFc(cents);
  return '${Currency._fc.format(fc)} FC';
}

/// Formate un montant en FC déjà calculé.
String moneyFc(int fc) => '${Currency._fc.format(fc)} FC';

final _usd = NumberFormat.currency(locale: 'fr_FR', symbol: r'$', decimalDigits: 2);

/// Montant en dollars : "$8.50".
String moneyUsd(int cents) => _usd.format(cents / 100.0);

/// FC avec le dollar entre parenthèses (pour les rapports) :
/// "23 800 FC ($8.50)".
String moneyBoth(int cents) => '${moneyCents(cents)} (${moneyUsd(cents)})';

/// Formate un double USD (rare) — passe par les cents.
String money(double amountUsd, {int decimals = 0}) =>
    moneyCents((amountUsd * 100).round());

String categoryLabel(int catIndex) {
  const labels = ['Boissons', 'Nourriture', 'Chambres'];
  return labels[catIndex];
}
