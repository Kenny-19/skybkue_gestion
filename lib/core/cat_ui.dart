import 'package:flutter/material.dart';

import '../data/schema.dart';

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
  Color get color => switch (this) {
        DbLocation.restaurant => const Color(0xFF3D8BFD),
        DbLocation.terrasse => const Color(0xFF2E8B57),
        DbLocation.hotel => const Color(0xFFF4A261),
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
        DbRoomStatus.libre => const Color(0xFF2E8B57),
        DbRoomStatus.occupee => const Color(0xFFF4A261),
        DbRoomStatus.nettoyage => const Color(0xFF3D8BFD),
        DbRoomStatus.maintenance => const Color(0xFFC0392B),
      };
}
