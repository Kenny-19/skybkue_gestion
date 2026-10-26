import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// La carte « papier » des listes — fond, bord, coins arrondis — dont
/// seules les lignes VISIBLES sont construites.
///
/// Avant, chaque liste (ventes, séjours, clients, produits) était une
/// `Column` dans un `SingleChildScrollView` : toutes les lignes étaient
/// construites et mesurées à chaque ouverture de l'écran et à chaque
/// changement de données, y compris les centaines hors de l'écran. Ici,
/// la même carte est dessinée autour d'une liste paresseuse : à
/// l'affichage, rien ne change.
///
/// C'est un SLIVER : il se place dans un `CustomScrollView`.
class SliverCarteListe extends StatelessWidget {
  /// Ligne d'en-tête dans la carte (titres de colonnes…), facultative.
  final Widget? entete;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Affiché dans la carte quand il n'y a aucune ligne.
  final Widget? vide;

  /// Marge autour de la carte ; par défaut, la gouttière des écrans.
  final EdgeInsetsGeometry marge;

  const SliverCarteListe({
    super.key,
    this.entete,
    required this.itemCount,
    required this.itemBuilder,
    this.vide,
    this.marge = const EdgeInsets.symmetric(horizontal: BsSpace.xl),
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: marge,
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: BsColors.paper,
          border: Border.all(color: BsColors.line),
          borderRadius: BorderRadius.circular(BsRadius.md),
        ),
        // Le retrait d'un pixel que `Container` appliquait pour son bord :
        // les lignes ne doivent pas passer dessus.
        sliver: SliverPadding(
          padding: const EdgeInsets.all(1),
          sliver: SliverMainAxisGroup(slivers: [
            if (entete != null) SliverToBoxAdapter(child: entete),
            if (itemCount == 0 && vide != null)
              SliverToBoxAdapter(child: vide)
            else
              SliverList.builder(
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
          ]),
        ),
      ),
    );
  }
}

/// Un élément simple dans un défilement en slivers, à sa largeur
/// NATURELLE, calé à gauche.
///
/// Dans l'ancienne `Column(crossAxisAlignment: start)`, un bouton ou un
/// encadré gardait sa propre largeur ; un `SliverToBoxAdapter` seul
/// l'étirerait sur toute la page.
class SliverAGauche extends StatelessWidget {
  final Widget child;
  const SliverAGauche({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      );
}
