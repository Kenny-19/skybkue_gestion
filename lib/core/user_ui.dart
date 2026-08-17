import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/schema.dart';

extension DbUserUi on User {
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

extension DbRoleUi on DbUserRole {
  Color get color => switch (this) {
        DbUserRole.superAdmin => const Color(0xFFC0392B),
        DbUserRole.admin => const Color(0xFF3D8BFD),
        DbUserRole.serveur => const Color(0xFF2E8B57),
      };
}
