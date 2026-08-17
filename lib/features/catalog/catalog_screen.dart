import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/article_thumb.dart';
import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Catalogue = le MENU, en lecture seule.
/// La gestion des produits se fait dans l'écran Stock.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(articlesStreamProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Menu',
                title: 'Notre carte',
                subtitle: '${all.length} produits proposés',
              ),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(BsSpace.xl),
                  child: _Empty(),
                )
              else
                for (final cat in DbCategory.values) ...[
                  Builder(builder: (_) {
                    final rows =
                        all.where((x) => x.category == cat).toList();
                    if (rows.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              BsSpace.xl, BsSpace.lg, BsSpace.xl, BsSpace.sm),
                          child: Row(children: [
                            Icon(cat.icon, size: 18, color: BsColors.sky),
                            const SizedBox(width: 8),
                            Text(cat.label.toUpperCase(),
                                style: BsType.eyebrow()),
                            const SizedBox(width: 8),
                            Text('· ${rows.length}',
                                style: BsType.body(11, color: BsColors.slate)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Container(height: 1, color: BsColors.line)),
                          ]),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                          child: LayoutBuilder(builder: (ctx, c) {
                            final cross =
                                (c.maxWidth / 260).floor().clamp(1, 5);
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.6,
                              ),
                              itemCount: rows.length,
                              itemBuilder: (_, i) => _MenuCard(article: rows[i]),
                            );
                          }),
                        ),
                      ],
                    );
                  }),
                ],
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _MenuCard extends StatelessWidget {
  final Article article;
  const _MenuCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final out = article.trackStock && article.stockQty <= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Row(children: [
        ArticleThumb(
          imagePath: article.imagePath,
          category: article.category,
          size: 56,
          radius: BsRadius.sm,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(article.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BsType.body(14, w: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Text(moneyCents(article.priceCents),
                    style: BsType.mono(15,
                        w: FontWeight.w700, color: BsColors.sky)),
                if (out) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BsColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('ÉPUISÉ',
                        style: BsType.body(9,
                            w: FontWeight.w700, color: BsColors.danger)),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BsSpace.xl),
      decoration: BoxDecoration(
        color: BsColors.paper,
        border: Border.all(color: BsColors.line),
        borderRadius: BorderRadius.circular(BsRadius.md),
      ),
      child: Column(children: [
        const Icon(Icons.menu_book_outlined, size: 40, color: BsColors.slateSoft),
        const SizedBox(height: 12),
        Text('Le menu est vide', style: BsType.body(14, w: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Ajoute des produits depuis l\'écran Stock.',
            style: BsType.body(12, color: BsColors.slate)),
      ]),
    );
  }
}
