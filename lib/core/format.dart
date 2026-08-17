import 'package:intl/intl.dart';

final _money2 = NumberFormat.currency(locale: 'fr_FR', symbol: r'$', decimalDigits: 2);
final _money0 = NumberFormat.currency(locale: 'fr_FR', symbol: r'$', decimalDigits: 0);

String moneyCents(int cents, {int decimals = 2}) {
  final v = cents / 100.0;
  return decimals == 0 ? _money0.format(v) : _money2.format(v);
}

String money(double amount, {int decimals = 2}) =>
    decimals == 0 ? _money0.format(amount) : _money2.format(amount);

String categoryLabel(int catIndex) {
  const labels = ['Boissons', 'Nourriture', 'Chambres'];
  return labels[catIndex];
}
