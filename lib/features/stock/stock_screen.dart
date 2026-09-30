import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/article_thumb.dart';
import '../../core/auth.dart';
import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../services/cloud_service.dart';
import '../../services/mirror_service.dart';
import '../../services/supply_requests_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Largeur de la colonne des actions, partagée par l'en-tête et les
/// lignes pour que tout reste aligné.
const double _actionsWidth = 310;

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(articlesStreamProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'stock_screen')),
      data: (items) {
        final low = items
            .where((a) => a.trackStock && a.stockQty <= a.threshold)
            .length;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Stock & Produits',
                title: 'Gestion des produits',
                subtitle: items.isEmpty
                    ? 'Aucun produit — commence par en ajouter un'
                    : '${items.length} produits · $low sous le seuil d\'alerte',
                actions: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => _showProductDialog(context, ref, null),
                    label: const Text('Nouveau produit'),
                  ),
                ],
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(BsSpace.xl),
                  child: _EmptyState(),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                  child: Container(
                    decoration: BoxDecoration(
                      color: BsColors.paper,
                      border: Border.all(color: BsColors.line),
                      borderRadius: BorderRadius.circular(BsRadius.md),
                    ),
                    child: Column(
                      children: [
                        _headerRow(),
                        for (int i = 0; i < items.length; i++)
                          _Row(
                            article: items[i],
                            last: i == items.length - 1,
                            onAdjust: (d) => ref
                                .read(articlesRepoProvider)
                                .adjustQty(items[i].id, d),
                            onEdit: () =>
                                _showProductDialog(context, ref, items[i]),
                            onRestock: () =>
                                _showRestockDialog(context, ref, items[i]),
                            onRequestSupply: () => _showSupplyRequestDialog(
                                context, ref, items[i]),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }

  Widget _headerRow() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BsColors.line)),
        ),
        child: Row(children: [
          const SizedBox(width: 48),
          Expanded(flex: 4, child: Text('PRODUIT', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('CATÉGORIE', style: BsType.eyebrow())),
          Expanded(
              flex: 2,
              child: Text('PRIX',
                  textAlign: TextAlign.right, style: BsType.eyebrow())),
          Expanded(flex: 3, child: Text('STOCK', style: BsType.eyebrow())),
          const SizedBox(width: _actionsWidth),
        ]),
      );

  // ─── Dialog CRUD produit ───────────────────────────────────────────────

  void _showProductDialog(BuildContext ctx, WidgetRef ref, Article? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(
        text: existing == null ? '' : existing.priceCents.toString());
    final unit = TextEditingController(text: existing?.unit ?? 'unité');
    final qty = TextEditingController(text: '${existing?.stockQty ?? 0}');
    final threshold =
        TextEditingController(text: '${existing?.threshold ?? 0}');
    DbCategory cat = existing?.category ?? DbCategory.boissons;
    bool trackStock = existing?.trackStock ?? true;
    String? imagePath = existing?.imagePath;
    String? err;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'NOUVEAU PRODUIT' : 'ÉDITER',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text(existing?.name ?? 'Ajouter un produit',
                      style: BsType.display(22, w: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Photo
                          Row(children: [
                            ArticleThumb(
                              imagePath: imagePath,
                              category: cat,
                              size: 64,
                              radius: BsRadius.sm,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.image_outlined,
                                        size: 16),
                                    onPressed: () async {
                                      final file = await openFile(
                                        acceptedTypeGroups: const [
                                          XTypeGroup(
                                              label: 'Images',
                                              extensions: [
                                                'jpg',
                                                'jpeg',
                                                'png',
                                                'webp'
                                              ]),
                                        ],
                                      );
                                      if (file != null) {
                                        setSt(() => imagePath = file.path);
                                      }
                                    },
                                    label: Text(
                                        imagePath == null ? 'Photo' : 'Changer',
                                        style: BsType.body(12)),
                                  ),
                                  if (imagePath != null)
                                    TextButton(
                                      onPressed: () =>
                                          setSt(() => imagePath = null),
                                      child: Text('Retirer',
                                          style: BsType.body(11,
                                              color: BsColors.slate)),
                                    ),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _label('NOM'),
                          TextField(
                              controller: name,
                              decoration: const InputDecoration(
                                  hintText: 'ex. Café expresso')),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('PRIX (FC)'),
                                  TextField(
                                    controller: price,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        hintText: '5000', suffixText: 'FC'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('UNITÉ'),
                                  TextField(
                                    controller: unit,
                                    decoration: const InputDecoration(
                                        hintText: 'unité / kg / verre'),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _label('CATÉGORIE'),
                          Wrap(spacing: 8, children: [
                            // Chambres = géré exclusivement dans l'onglet
                            // Chambres, plus proposé comme catégorie produit.
                            for (final c in DbCategory.values
                                .where((c) => c != DbCategory.chambres))
                              GestureDetector(
                                onTap: () => setSt(() => cat = c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: c == cat
                                        ? BsColors.ink
                                        : Colors.transparent,
                                    border: Border.all(color: BsColors.ink),
                                    borderRadius:
                                        BorderRadius.circular(BsRadius.sm),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(c.icon,
                                            size: 14,
                                            color: c == cat
                                                ? Colors.white
                                                : BsColors.ink),
                                        const SizedBox(width: 6),
                                        Text(c.label,
                                            style: BsType.body(12,
                                                w: FontWeight.w700,
                                                color: c == cat
                                                    ? Colors.white
                                                    : BsColors.ink)),
                                      ]),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 16),
                          // Suivi stock
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BsColors.papyrus,
                              borderRadius: BorderRadius.circular(BsRadius.sm),
                              border: Border.all(color: BsColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('SUIVI DU STOCK',
                                            style: BsType.eyebrow()),
                                        const SizedBox(height: 2),
                                        Text(
                                            'Décompte auto à chaque vente + alerte seuil',
                                            style: BsType.body(11,
                                                color: BsColors.slate)),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: trackStock,
                                    activeThumbColor: BsColors.sky,
                                    onChanged: (v) =>
                                        setSt(() => trackStock = v),
                                  ),
                                ]),
                                if (trackStock) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _label('QUANTITÉ'),
                                          TextField(
                                            controller: qty,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                                hintText: '0', isDense: true),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _label('SEUIL D\'ALERTE'),
                                          TextField(
                                            controller: threshold,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                                hintText: '0', isDense: true),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                          if (err != null) ...[
                            const SizedBox(height: 12),
                            Text(err!,
                                style: BsType.body(12, color: BsColors.danger)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    if (existing != null)
                      TextButton.icon(
                        onPressed: () async {
                          await ref
                              .read(articlesRepoProvider)
                              .deactivate(existing.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: BsColors.danger),
                        label: Text('Supprimer',
                            style: BsType.body(12,
                                w: FontWeight.w600, color: BsColors.danger)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () async {
                        // Prix en FC entier (ex : 5000, 12000).
                        final p =
                            int.tryParse(price.text.trim().replaceAll(' ', ''));
                        if (name.text.trim().isEmpty || p == null || p < 0) {
                          setSt(() => err = 'Nom et prix valides requis');
                          return;
                        }
                        final cents = p;
                        var savedImage = imagePath;
                        if (imagePath != null &&
                            !imagePath!.startsWith('http') &&
                            File(imagePath!).existsSync() &&
                            CloudService.enabled) {
                          final url = await CloudService.uploadArticleImage(
                              File(imagePath!));
                          if (url != null) savedImage = url;
                        }
                        final q = int.tryParse(qty.text) ?? 0;
                        final t = int.tryParse(threshold.text) ?? 0;
                        int articleId;
                        if (existing == null) {
                          articleId =
                              await ref.read(articlesRepoProvider).create(
                                    name: name.text.trim(),
                                    priceCents: cents,
                                    category: cat,
                                    imagePath: savedImage,
                                    trackStock: trackStock,
                                    unit: unit.text.trim().isEmpty
                                        ? 'unité'
                                        : unit.text.trim(),
                                    stockQty: trackStock ? q : 0,
                                    threshold: trackStock ? t : 0,
                                  );
                        } else {
                          articleId = existing.id;
                          await ref.read(articlesRepoProvider).update(
                                id: existing.id,
                                name: name.text.trim(),
                                priceCents: cents,
                                category: cat,
                                imagePath: savedImage,
                                trackStock: trackStock,
                                unit: unit.text.trim().isEmpty
                                    ? 'unité'
                                    : unit.text.trim(),
                                stockQty: trackStock ? q : 0,
                                threshold: trackStock ? t : 0,
                              );
                        }
                        // Miroir cloud immédiat (offline-safe, non bloquant) :
                        // le produit + l'URL de l'image partent vers Supabase.
                        unawaited(MirrorService.pushArticleById(articleId));
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text(existing == null ? 'Créer' : 'Enregistrer'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: BsType.eyebrow()),
      );

  void _showRestockDialog(BuildContext ctx, WidgetRef ref, Article item) {
    final qty = TextEditingController();
    String? err;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('RAVITAILLEMENT', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text(item.name,
                      style: BsType.display(22, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Stock actuel : ${item.stockQty} ${item.unit}',
                      style: BsType.body(12, color: BsColors.slate)),
                  const SizedBox(height: 20),
                  Text('QUANTITÉ REÇUE (${item.unit})',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qty,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'ex. 24'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler')),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () async {
                        final n = int.tryParse(qty.text.trim());
                        if (n == null || n <= 0) {
                          setSt(() => err = 'Entrer un nombre positif');
                          return;
                        }
                        await ref
                            .read(articlesRepoProvider)
                            .adjustQty(item.id, n);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '+$n ${item.unit} → ${item.stockQty + n}')));
                        }
                      },
                      label: const Text('Ajouter au stock'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Dialog "Demande de ravitaillement" — envoie à Supabase, visible côté
  /// site pour validation par la propriétaire.
  void _showSupplyRequestDialog(BuildContext ctx, WidgetRef ref, Article item) {
    // Quantité suggérée : compléter jusqu'à 2× le seuil (règle usuelle
    // resto/hôtel pour avoir une marge de sécurité).
    final suggestedQty = (item.threshold * 2 - item.stockQty).clamp(1, 9999);
    final qtyCtrl = TextEditingController(text: '$suggestedQty');
    final noteCtrl = TextEditingController();
    DbLocation location = DbLocation.hotel; // défaut : chambre/hôtel
    String? err;
    bool busy = false;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('DEMANDE DE RAVITAILLEMENT',
                      style: BsType.eyebrow(color: BsColors.sunrise)),
                  const SizedBox(height: 6),
                  Text(item.name,
                      style: BsType.display(20, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      'Stock actuel : ${item.stockQty} ${item.unit} · seuil ${item.threshold}',
                      style: BsType.body(12, color: BsColors.slate)),
                  const SizedBox(height: BsSpace.lg),
                  Text('POUR QUEL EMPLACEMENT', style: BsType.eyebrow()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final loc in DbLocation.values)
                      GestureDetector(
                        onTap: () => setSt(() => location = loc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: loc == location
                                ? loc.color
                                : Colors.transparent,
                            border: Border.all(color: loc.color),
                            borderRadius: BorderRadius.circular(BsRadius.sm),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(loc.icon,
                                size: 14,
                                color:
                                    loc == location ? Colors.white : loc.color),
                            const SizedBox(width: 6),
                            Text(loc.label,
                                style: BsType.body(12,
                                    w: FontWeight.w700,
                                    color: loc == location
                                        ? Colors.white
                                        : loc.color)),
                          ]),
                        ),
                      ),
                  ]),
                  const SizedBox(height: BsSpace.md),
                  Text('QUANTITÉ SOUHAITÉE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                        hintText: '$suggestedQty', suffixText: item.unit),
                  ),
                  const SizedBox(height: BsSpace.md),
                  Text('NOTE (optionnel)', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Urgent, préciser marque, etc.'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: BsSpace.lg),
                  Row(children: [
                    TextButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 16),
                      style: FilledButton.styleFrom(
                          backgroundColor: BsColors.sunrise),
                      onPressed: busy
                          ? null
                          : () async {
                              final q = int.tryParse(qtyCtrl.text.trim());
                              if (q == null || q <= 0) {
                                setSt(() => err = 'Quantité invalide');
                                return;
                              }
                              final me = ref.read(authProvider).user;
                              setSt(() {
                                busy = true;
                                err = null;
                              });
                              final id = await SupplyRequestsService.submit(
                                articleId: item.id,
                                articleName: item.name,
                                location: location,
                                qtyRequested: q,
                                qtyAtRequest: item.stockQty,
                                thresholdAtRequest: item.threshold,
                                requestedByLogin: me?.login ?? 'inconnu',
                                note: noteCtrl.text.trim().isEmpty
                                    ? null
                                    : noteCtrl.text.trim(),
                              );
                              if (!context.mounted) return;
                              if (id == null) {
                                setSt(() {
                                  busy = false;
                                  err = 'Échec — pas de réseau ou Supabase ?';
                                });
                                return;
                              }
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Demande envoyée à Pamela pour ${location.label}')));
                            },
                      label: const Text('Envoyer la demande'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Row extends StatelessWidget {
  final Article article;
  final bool last;
  final ValueChanged<int> onAdjust;
  final VoidCallback onEdit;
  final VoidCallback onRestock;
  final VoidCallback onRequestSupply;
  const _Row({
    required this.article,
    required this.last,
    required this.onAdjust,
    required this.onEdit,
    required this.onRestock,
    required this.onRequestSupply,
  });

  @override
  Widget build(BuildContext context) {
    final tracked = article.trackStock;
    final low = tracked && article.stockQty <= article.threshold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: BsColors.line)),
      ),
      child: Row(children: [
        ArticleThumb(
          imagePath: article.imagePath,
          category: article.category,
          size: 40,
          radius: BsRadius.sm,
        ),
        const SizedBox(width: 12),
        Expanded(
            flex: 4,
            child: Text(article.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BsType.body(13, w: FontWeight.w600))),
        Expanded(
            flex: 2,
            child: Text(article.category.label,
                style: BsType.body(12, color: BsColors.slate))),
        Expanded(
          flex: 2,
          child: Text(prixArticle(article.priceCents),
              textAlign: TextAlign.right,
              style: BsType.mono(13, w: FontWeight.w700)),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: tracked
                ? Row(children: [
                    Text('${article.stockQty} ${article.unit}',
                        style: BsType.mono(13,
                            w: FontWeight.w700,
                            color: low ? BsColors.danger : BsColors.ink)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (low ? BsColors.danger : BsColors.success)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(low ? 'Bas' : 'OK',
                          style: BsType.body(10,
                              w: FontWeight.w700,
                              color: low ? BsColors.danger : BsColors.success)),
                    ),
                  ])
                : Text('Non suivi',
                    style: BsType.body(12, color: BsColors.slateSoft)),
          ),
        ),
        SizedBox(
          // Largeur calée sur le pire cas : stock bas, donc « Demander » en
          // plus de « Ravitailler ». À 260, cette ligne-là débordait de
          // 26 px. Garder en phase avec l'en-tête (_actionsWidth).
          width: _actionsWidth,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (tracked) ...[
              IconButton(
                  tooltip: 'Retirer 1',
                  visualDensity: VisualDensity.compact,
                  onPressed: article.stockQty <= 0 ? null : () => onAdjust(-1),
                  icon: const Icon(Icons.remove, size: 16)),
              IconButton(
                  tooltip: 'Ajouter 1',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAdjust(1),
                  icon: const Icon(Icons.add, size: 16)),
              OutlinedButton(
                onPressed: onRestock,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(0, BsControl.compact),
                ),
                child: Text('Ravitailler',
                    style: BsType.body(11, w: FontWeight.w600)),
              ),
              // Bouton "Demander" visible UNIQUEMENT sous seuil — envoie
              // une demande de ravitaillement à Pamela via Supabase.
              if (low) ...[
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: onRequestSupply,
                  icon: const Icon(Icons.forward_to_inbox, size: 14),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BsColors.sunrise,
                    side: const BorderSide(color: BsColors.sunrise),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, BsControl.compact),
                  ),
                  label: Text('Demander',
                      style: BsType.body(11, w: FontWeight.w600)),
                ),
              ],
            ],
            IconButton(
                tooltip: 'Éditer',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16)),
          ]),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
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
        const Icon(Icons.inventory_2_outlined,
            size: 40, color: BsColors.slateSoft),
        const SizedBox(height: 12),
        Text('Aucun produit', style: BsType.body(14, w: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Clique sur « Nouveau produit » pour commencer.',
            style: BsType.body(12, color: BsColors.slate)),
      ]),
    );
  }
}
