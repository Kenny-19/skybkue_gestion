/// TVA sur les factures et les tickets.
///
/// Les prix de Skyblue sont TTC : le client paie exactement ce qu'il
/// payait avant. La facture DÉTAILLE ce total — hors taxe, puis TVA —
/// sans l'augmenter.
///
/// Le taux est exprimé en POINTS DE BASE (centièmes de pour cent) :
/// 1600 = 16 %. Un entier, comme le taux de change figé sur les séjours :
/// un taux est une donnée comptable, il ne s'arrondit pas au hasard des
/// divisions en virgule flottante.
library;

/// Taux normal de TVA en RDC, valeur par défaut tant que le super admin
/// n'en a pas réglé un autre dans les Paramètres.
const int kTvaDefautBp = 1600;

/// Un total TTC détaillé.
class DetailTva {
  final int ttc;
  final int ht;
  final int tva;
  final int tauxBp;
  const DetailTva(
      {required this.ttc,
      required this.ht,
      required this.tva,
      required this.tauxBp});
}

/// Détaille un montant TTC (en francs entiers) au taux [tauxBp].
///
/// TVA = TTC × t / (1 + t), arrondie au franc ; le HT est le reste. On
/// arrondit la TVA et non le HT pour que HT + TVA retombe TOUJOURS sur le
/// TTC payé : une facture dont les lignes ne s'additionnent pas se
/// conteste.
DetailTva detaillerTtc(int ttc, int tauxBp) {
  if (tauxBp <= 0 || ttc <= 0) {
    return DetailTva(ttc: ttc, ht: ttc, tva: 0, tauxBp: tauxBp);
  }
  final tva = (ttc * tauxBp / (10000 + tauxBp)).round();
  return DetailTva(ttc: ttc, ht: ttc - tva, tva: tva, tauxBp: tauxBp);
}

/// « 16 % », « 16,5 % ».
String libelleTaux(int tauxBp) {
  final entier = tauxBp ~/ 100;
  final reste = tauxBp % 100;
  if (reste == 0) return '$entier %';
  final dec =
      reste % 10 == 0 ? '${reste ~/ 10}' : reste.toString().padLeft(2, '0');
  return '$entier,$dec %';
}

/// Lit un taux saisi (« 16 », « 16,5 », « 16.5 ») en points de base.
/// Null si la saisie n'est pas un taux plausible (0 à 50 %).
int? tauxDepuisSaisie(String saisie) {
  final v = double.tryParse(saisie.trim().replaceAll(',', '.'));
  if (v == null || v < 0 || v > 50) return null;
  return (v * 100).round();
}
