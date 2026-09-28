import 'package:flutter/material.dart';
import '../theme/tokens.dart';

import '../data/database.dart';
import '../data/schema.dart';

extension DbUserUi on User {
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

extension DbRoleUi on DbUserRole {
  Color get color => switch (this) {
        // Le gérant portait le bleu Material étranger, et la réception un
        // violet (0xFF8E44AD) qui n'existait dans aucune charte — ni ici,
        // ni sur le tableau de bord, où il traînait aussi.
        DbUserRole.superAdmin => BsColors.danger,
        DbUserRole.gerant => BsColors.sky,
        DbUserRole.serveur => BsColors.success,
        DbUserRole.reception => BsColors.sunrise,
      };
}
