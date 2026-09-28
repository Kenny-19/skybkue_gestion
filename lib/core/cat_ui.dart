import 'package:flutter/material.dart';

import '../data/schema.dart';
import '../theme/tokens.dart';

extension DbCategoryUi on DbCategory {
  String get label => switch (this) {
        DbCategory.boissons => 'Boissons',
        DbCategory.nourriture => 'Nourriture',
        DbCategory.chambres => 'Chambres',
      };
  IconData get icon => switch (this) {
        DbCategory.boissons => Icons.local_bar_outlined,
        DbCategory.nourriture => Icons.restaurant_outlined,
        DbCategory.chambres => Icons.hotel_outlined,
      };
}

extension DbPaymentUi on DbPayment {
  String get label => switch (this) {
        DbPayment.cash => 'Espèces',
        DbPayment.card => 'Carte bancaire',
        DbPayment.mobileMoney => 'Mobile Money',
      };
  IconData get icon => switch (this) {
        DbPayment.cash => Icons.payments_outlined,
        DbPayment.card => Icons.credit_card_outlined,
        DbPayment.mobileMoney => Icons.smartphone_outlined,
      };
}

extension DbLocationUi on DbLocation {
  String get label => switch (this) {
        DbLocation.restaurant => 'Restaurant',
        DbLocation.terrasse => 'Terrasse',
        DbLocation.hotel => 'Hôtel',
      };
  IconData get icon => switch (this) {
        DbLocation.restaurant => Icons.restaurant_menu_outlined,
        DbLocation.terrasse => Icons.deck_outlined,
        DbLocation.hotel => Icons.hotel_outlined,
      };

  /// Couleurs prises dans la charte, pas réécrites en littéral.
  ///
  /// `restaurant` était un bleu Material (0xFF3D8BFD) qui n'existait
  /// nulle part ailleurs dans l'application : il jurait avec le teal de
  /// la marque sur l'écran le plus regardé.
  Color get color => switch (this) {
        DbLocation.restaurant => BsColors.sky,
        DbLocation.terrasse => BsColors.success,
        DbLocation.hotel => BsColors.sunrise,
      };
}

extension DbRoomStatusUi on DbRoomStatus {
  String get label => switch (this) {
        DbRoomStatus.libre => 'Libre',
        DbRoomStatus.occupee => 'Occupée',
        DbRoomStatus.nettoyage => 'Nettoyage',
        DbRoomStatus.maintenance => 'Maintenance',
      };
  Color get color => switch (this) {
        // Couleurs prises dans la charte. `nettoyage` était le même bleu
        // Material étranger (0xFF3D8BFD) que l'emplacement Restaurant —
        // il devient `warning`, qui dit mieux « une tâche attend ».
        DbRoomStatus.libre => BsColors.success,
        DbRoomStatus.occupee => BsColors.sunrise,
        DbRoomStatus.nettoyage => BsColors.warning,
        DbRoomStatus.maintenance => BsColors.danger,
      };
}
