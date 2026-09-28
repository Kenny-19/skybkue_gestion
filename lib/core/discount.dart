import 'devise.dart';

// Système de remise pour les factures de séjour.
//
// Deux niveaux complémentaires :
//
//  1. **Tarif négocié** (au check-in) — un prix/nuit propre au séjour,
//     stocké dans `Rooms.negotiatedPriceCents`. L'écart avec le tarif
//     catalogue est une remise « invisible » : elle est déjà intégrée
//     au sous-total, mais reste tracée ligne par ligne sur la facture.
//
//  2. **Remise de facturation** (au check-out) — un pourcentage ou un
//     montant fixe appliqué au moment d'éditer le reçu, avec une base
//     de calcul et un motif. C'est ce que décrit [Discount].

/// Nature de la remise saisie au check-out.
enum DiscountKind {
  /// Montant fixe, en CENTS DE DOLLAR.
  ///
  /// En dollars depuis que l'hôtel tarifie dans cette devise : une
  /// remise se négocie dans la monnaie où le prix a été annoncé. « Je
  /// lui fais 10 de moins » veut dire dix dollars, et doit valoir dix
  /// dollars encore l'an prochain — stockée en francs, elle aurait
  /// fondu ou gonflé au gré du taux.
  amount,

  /// Pourcentage — [Discount.value] est exprimé en centièmes de pourcent
  /// (1000 = 10 %) pour rester en entier tout en autorisant 12,5 %.
  percent,
}

/// Assiette sur laquelle porte une remise en pourcentage.
enum DiscountBase {
  /// Seulement les nuitées (les consommations bar/resto sont exclues).
  accommodation,

  /// Hébergement + consommations.
  total,
}

extension DiscountBaseX on DiscountBase {
  String get label => switch (this) {
        DiscountBase.accommodation => 'hébergement',
        DiscountBase.total => 'total',
      };
  String get shortLabel => switch (this) {
        DiscountBase.accommodation => 'Hébergement',
        DiscountBase.total => 'Total (avec extras)',
      };
}

/// Remise consentie sur une facture de séjour.
///
/// Immuable et sans dépendance UI/BDD : toute la règle de calcul vit ici
/// pour que la facture PDF, l'aperçu du dialog et l'historique donnent
/// exactement le même chiffre.
class Discount {
  final DiscountKind kind;

  /// Cents de DOLLAR si [kind] == amount, centièmes de % si percent.
  ///
  /// Un pourcentage, lui, est neutre en devise : 10 % restent 10 %
  /// quelle que soit la monnaie, et rien n'est jamais converti. C'est
  /// pour ça qu'il ressort propre sur la facture.
  final int value;

  /// Ignorée quand [kind] == amount (un montant fixe s'impute sur le total).
  final DiscountBase base;

  /// Motif libre — « Client fidèle », « Accord société »… Apparaît sur
  /// la facture pour justifier le geste commercial.
  final String? reason;

  const Discount({
    required this.kind,
    required this.value,
    this.base = DiscountBase.total,
    this.reason,
  });

  static const none =
      Discount(kind: DiscountKind.amount, value: 0, base: DiscountBase.total);

  /// Pourcentages proposés en un clic dans le dialog de facturation.
  static const quickPercents = <int>[500, 1000, 1500, 2000, 2500];

  /// Motifs proposés en un clic (le champ reste libre).
  static const quickReasons = <String>[
    'Client fidèle',
    'Séjour long',
    'Accord société',
    'Geste commercial',
  ];

  bool get isEmpty => value <= 0;
  bool get isPercent => kind == DiscountKind.percent;

  /// Pourcentage lisible (1250 → 12.5).
  double get percent => value / 100;

  /// Montant de la remise en cents FC, plafonné au sous-total : on ne
  /// facture jamais un total négatif, et on n'offre jamais plus que ce
  /// que le client doit.
  /// [taux] : francs pour un dollar. Seules les remises en MONTANT en
  /// ont besoin — un pourcentage s'applique à une assiette déjà en
  /// francs. Passer le taux FIGÉ du séjour pour rejouer une facture
  /// ancienne ; omis, c'est le taux courant qui s'applique.
  int amountCents({
    required int accommodationCents,
    required int extrasCents,
    double? taux,
  }) {
    final subtotal = accommodationCents + extrasCents;
    if (subtotal <= 0 || value <= 0) return 0;
    final raw = switch (kind) {
      DiscountKind.amount => usdVersFc(value, taux: taux),
      DiscountKind.percent =>
        (_baseCents(accommodationCents, extrasCents) * value / 10000).round(),
    };
    return raw.clamp(0, subtotal);
  }

  /// La remise en cents de dollar, pour l'afficher dans la devise où
  /// elle a été consentie.
  int montantUsdCents({
    required int accommodationCents,
    required int extrasCents,
    double? taux,
  }) {
    if (isEmpty) return 0;
    // Une remise en montant EST déjà en dollars : la reconvertir depuis
    // les francs y introduirait un arrondi, et « 10 $ » s'afficherait
    // « 9,99 $ » sur la facture.
    if (!isPercent) {
      final fc = amountCents(
          accommodationCents: accommodationCents,
          extrasCents: extrasCents,
          taux: taux);
      // Plafonnée par le sous-total : on rend la valeur réellement
      // déduite, pas celle qui était demandée.
      return fc >= usdVersFc(value, taux: taux)
          ? value
          : fcVersUsd(fc, taux: taux);
    }
    return fcVersUsd(
        amountCents(
            accommodationCents: accommodationCents,
            extrasCents: extrasCents,
            taux: taux),
        taux: taux);
  }

  int _baseCents(int accommodationCents, int extrasCents) => switch (base) {
        DiscountBase.accommodation => accommodationCents,
        DiscountBase.total => accommodationCents + extrasCents,
      };

  /// Libellé court affiché à côté du montant — « 10 % sur l'hébergement »,
  /// « montant fixe ». Retourne null quand il n'y a rien à expliquer.
  String? get formulaLabel {
    if (isEmpty) return null;
    if (!isPercent) return '${moneyUsd(value)} de remise';
    return '${formatPercent(value)} sur ${base.label}';
  }

  /// Ligne complète pour la facture : « 10 % sur l'hébergement · Client fidèle ».
  String? get invoiceLabel {
    final f = formulaLabel;
    final r =
        (reason == null || reason!.trim().isEmpty) ? null : reason!.trim();
    if (f == null) return r;
    return r == null ? f : '$f · $r';
  }

  Discount copyWith({
    DiscountKind? kind,
    int? value,
    DiscountBase? base,
    String? reason,
  }) =>
      Discount(
        kind: kind ?? this.kind,
        value: value ?? this.value,
        base: base ?? this.base,
        reason: reason ?? this.reason,
      );

  /// Relit une remise persistée (colonnes `Stays.remise*`). Tolérant aux
  /// index inconnus — une base de données plus récente ne doit pas faire
  /// planter une facture rejouée.
  factory Discount.fromDb({
    required int kindIndex,
    required int value,
    required int baseIndex,
    String? reason,
  }) =>
      Discount(
        kind: DiscountKind
            .values[kindIndex.clamp(0, DiscountKind.values.length - 1)],
        value: value < 0 ? 0 : value,
        base: DiscountBase
            .values[baseIndex.clamp(0, DiscountBase.values.length - 1)],
        reason: reason,
      );

  /// 1000 → « 10 % » ; 1250 → « 12,5 % » (virgule décimale FR).
  static String formatPercent(int hundredthsOfPercent) {
    final p = hundredthsOfPercent / 100;
    final s = p == p.roundToDouble()
        ? p.round().toString()
        : p
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
    return '${s.replaceAll('.', ',')} %';
  }

  /// Parse une saisie utilisateur en pourcentage (« 12,5 » → 1250).
  /// Plafonné à 100 % — au-delà, la remise serait supérieure à la facture.
  static int parsePercent(String input) {
    final cleaned = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null || v <= 0) return 0;
    return (v * 100).round().clamp(0, 10000);
  }
}
