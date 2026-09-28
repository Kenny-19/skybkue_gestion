import 'package:flutter/material.dart';

import '../core/user_error.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

// Composants partagés de l'interface Skyblue.
//
// Pourquoi ce fichier existe
// --------------------------
// Avant lui, l'application comptait 11 685 lignes d'interface où le
// motif « carte » était réécrit 91 fois à la main, les états vides
// rédigés 32 fois, et un champ de recherche reconstruit dans 11 écrans.
// Chaque écran réinventait les mêmes objets, avec des écarts d'un ou
// deux pixels et des formulations différentes.
//
// C'est ce qui rendait l'application difficile à apprendre : le même
// concept ne se présentait pas pareil d'un écran à l'autre, donc rien
// ne s'acquérait une fois pour toutes.
//
// Règle : tout ce qui apparaît dans deux écrans vit ici. Un widget privé
// dans un écran ne se justifie que s'il est vraiment propre à cet écran.

/// La carte, brique de base de tous les écrans.
///
/// Remplace le `Container` + `BoxDecoration` recopié partout. Les trois
/// variantes couvrent tous les usages existants — si une quatrième
/// semble nécessaire, c'est probablement qu'on force un cas particulier.
class BsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Teinte l'arrière-plan et la bordure. Null → carte neutre.
  /// Sert à porter un sens (danger, succès), jamais à décorer.
  final Color? accent;

  /// Rend la carte cliquable, avec l'effet d'appui qui va avec.
  final VoidCallback? onTap;

  /// Épaissit la bordure : la carte est sélectionnée.
  final bool selected;

  const BsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? (accent ?? BsColors.sky)
        : (accent?.withValues(alpha: 0.30) ?? BsColors.line);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.06) ?? BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: border, width: selected ? 1.5 : 1),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(BsRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BsRadius.md),
        child: content,
      ),
    );
  }
}

/// Ce qu'on affiche quand il n'y a rien à afficher.
///
/// Un écran vide doit dire pourquoi il est vide et quoi faire ensuite.
/// « Aucun résultat » tout seul laisse l'utilisateur bloqué ; c'est la
/// raison d'être de [action].
class BsEmptyState extends StatelessWidget {
  final IconData icon;

  /// Le constat, en une ligne. « Aucune vente aujourd'hui ».
  final String title;

  /// Ce que ça veut dire, ou quoi faire. Facultatif mais recommandé.
  final String? hint;

  /// Le geste qui sort de l'état vide, quand il y en a un.
  final Widget? action;

  const BsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: BsColors.slateSoft),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  BsType.body(15, w: FontWeight.w600, color: BsColors.slate)),
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(hint!,
                textAlign: TextAlign.center,
                style: BsType.body(12, color: BsColors.slateSoft)),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Champ de recherche, identique partout.
///
/// Onze écrans en avaient chacun leur version : placeholders différents,
/// icône tantôt présente tantôt absente, effacement parfois impossible.
class BsSearchField extends StatelessWidget {
  final TextEditingController controller;

  /// Ce qu'on cherche ici. « Rechercher un article », pas « Rechercher ».
  final String hint;
  final ValueChanged<String>? onChanged;

  const BsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 18),
        // Effacer doit toujours être possible : sans ça, l'utilisateur
        // croit que l'écran est vide alors qu'il est filtré.
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Effacer',
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
      ),
    );
  }
}

/// Un compteur cliquable : un nombre, ce qu'il désigne, et l'action de
/// filtrer sur lui.
///
/// Sert au bandeau du jour côté hôtel et aux indicateurs du tableau de
/// bord. Un zéro reste lisible mais s'efface — ce qui demande une action
/// doit ressortir sans effort de lecture.
class BsStatTile extends StatelessWidget {
  final int value;
  final String label;

  /// Signale que ce compteur appelle une réaction quand il n'est pas nul.
  final bool urgent;
  final bool selected;
  final VoidCallback? onTap;
  final double width;

  const BsStatTile({
    super.key,
    required this.value,
    required this.label,
    this.urgent = false,
    this.selected = false,
    this.onTap,
    this.width = 132,
  });

  @override
  Widget build(BuildContext context) {
    final vide = value == 0;
    final accent = (urgent && !vide)
        ? BsColors.danger
        : (vide ? BsColors.slateSoft : BsColors.sky);

    return SizedBox(
      width: width,
      child: BsCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        accent: selected ? accent : null,
        selected: selected,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: BsType.display(24,
                    w: FontWeight.w700,
                    color: vide ? BsColors.slateSoft : accent)),
            const SizedBox(height: 2),
            Text(label,
                style: BsType.body(11,
                    w: FontWeight.w600,
                    color: vide ? BsColors.slateSoft : BsColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Titre de section à l'intérieur d'un écran.
///
/// Le `trailing` accueille l'action qui porte sur la section entière —
/// « Tout afficher », « Ajouter » — pour qu'elle soit toujours au même
/// endroit d'un écran à l'autre.
class BsSectionHeader extends StatelessWidget {
  final String label;
  final String? hint;
  final Color? color;
  final Widget? trailing;

  const BsSectionHeader({
    super.key,
    required this.label,
    this.hint,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: BsType.eyebrow(color: color)),
          if (hint != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(hint!,
                  style: BsType.body(11, color: BsColors.slateSoft),
                  overflow: TextOverflow.ellipsis),
            ),
          ] else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pastille d'état : un mot, une couleur, une forme reconnaissable.
///
/// Encoder l'état par la couleur SEULE ne suffit pas — le texte reste
/// lisible pour qui distingue mal les teintes, et à l'impression.
class BsBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const BsBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BsRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: BsType.body(10, w: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Affichage des pannes ──────────────────────────────────────────────
//
// Deux surfaces, une seule règle : l'utilisateur lit ce qui le concerne,
// le détail technique part au journal d'erreurs. Voir core/user_error.

/// L'erreur telle qu'elle remplace un contenu qui n'a pas pu charger.
///
/// Prend la place des `Text('Erreur : $e')` qui exposaient l'exception —
/// et l'adresse du serveur — au milieu de l'écran.
class BsErrorView extends StatelessWidget {
  final UserError error;

  /// Proposé seulement quand refaire la même chose peut marcher.
  final VoidCallback? onRetry;

  const BsErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return BsEmptyState(
      icon: error.kind == ErrorKind.offline
          ? Icons.cloud_off_outlined
          : Icons.error_outline,
      title: error.title,
      hint: [
        error.message,
        if (error.advice != null) error.advice!,
      ].join('\n'),
      action: (onRetry != null && error.isRetryable)
          ? OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: onRetry,
              label: const Text('Réessayer'),
            )
          : null,
    );
  }
}

/// La boîte de dialogue d'erreur.
///
/// Le code de référence est affiché discrètement en bas : il ne parle
/// pas à l'utilisateur, mais il permet au gérant de relier ce que la
/// réception a vu à l'écran avec la ligne exacte du journal reçue par
/// mail.
Future<void> showBsError(
  BuildContext context,
  Object error, {
  StackTrace? stack,
  String? source,
}) async {
  final described = handleError(error, stack, context: source);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BsColors.paper,
      icon: Icon(
        described.kind == ErrorKind.offline
            ? Icons.cloud_off_outlined
            : Icons.error_outline,
        color: described.kind == ErrorKind.offline
            ? BsColors.slate
            : BsColors.danger,
      ),
      title: Text(described.title,
          textAlign: TextAlign.center,
          style: BsType.display(20, w: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(described.message,
              textAlign: TextAlign.center, style: BsType.body(13)),
          if (described.advice != null) ...[
            const SizedBox(height: 8),
            Text(described.advice!,
                textAlign: TextAlign.center,
                style: BsType.body(12, color: BsColors.slate)),
          ],
          if (described.worthReporting) ...[
            const SizedBox(height: 12),
            Text(described.reference,
                style: BsType.mono(10, color: BsColors.slateSoft)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}

/// Le corps d'un écran : une colonne de contenu, bornée et alignée.
///
/// Deux défauts de mise en page qu'il corrige, tous deux visibles sur
/// l'écran Paramètres :
///
/// **Le bord droit en dents de scie.** Une `Column` en
/// `CrossAxisAlignment.start` laisse chaque carte prendre la largeur de
/// son contenu : « Réinitialiser » occupait toute la largeur,
/// « Sauvegarde » s'arrêtait à 570 px, « Emplacement de la base » à 450.
/// Ici tout s'aligne sur une seule colonne.
///
/// **La ligne trop longue.** Sur un écran 1920, un texte qui traverse
/// l'écran entier devient pénible à lire : l'œil perd la ligne en
/// revenant à gauche. On borne, et on laisse la colonne à gauche plutôt
/// que centrée — le regard part du menu, pas du milieu de l'écran.
class BsPageBody extends StatelessWidget {
  final List<Widget> children;

  /// Largeur maximale du contenu. 880 convient aux formulaires et aux
  /// réglages ; les tableaux denses (historique, stock) prennent plus.
  final double maxWidth;

  final EdgeInsetsGeometry padding;

  const BsPageBody({
    super.key,
    required this.children,
    this.maxWidth = 880,
    this.padding =
        const EdgeInsets.fromLTRB(BsSpace.xl, 0, BsSpace.xl, BsSpace.xxl),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            // La règle qui met fin aux dents de scie.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
