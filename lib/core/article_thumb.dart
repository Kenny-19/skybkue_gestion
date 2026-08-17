import 'dart:io';

import 'package:flutter/material.dart';

import '../data/schema.dart';
import '../theme/tokens.dart';

/// Vignette d'article : photo réelle si disponible, sinon icône générique
/// tintée selon la catégorie (verre pour boisson, plat pour nourriture, etc.).
class ArticleThumb extends StatelessWidget {
  final String? imagePath;
  final DbCategory category;
  final double size;
  final double radius;
  const ArticleThumb({
    super.key,
    required this.imagePath,
    required this.category,
    this.size = 64,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final p = imagePath;
    if (p != null && p.isNotEmpty) {
      // URL distante (photo hébergée sur le cloud).
      if (p.startsWith('http://') || p.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            p,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        );
      }
      // Fichier local.
      if (File(p).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            File(p),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final color = _fallbackColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.28),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(_fallbackIcon(), size: size * 0.5, color: color),
    );
  }

  IconData _fallbackIcon() => switch (category) {
        DbCategory.boissons => Icons.local_bar,
        DbCategory.nourriture => Icons.restaurant_menu,
        DbCategory.chambres => Icons.hotel,
      };

  Color _fallbackColor() => switch (category) {
        DbCategory.boissons => BsColors.sky,
        DbCategory.nourriture => BsColors.sunrise,
        DbCategory.chambres => BsColors.skyDeep,
      };
}
