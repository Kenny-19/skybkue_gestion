import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../services/mirror_pull_service.dart';
import '../../services/pdf_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'pos_cart.dart';
import '../../core/temps.dart';
import '../../core/horloge.dart';
import '../../services/ventes_outbox.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  DbCategory _cat = DbCategory.boissons;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pull immédiat des chambres depuis Supabase quand un serveur ouvre
    // le POS — évite d'attendre 30 s pour voir un check-in fait à la
    // réception juste avant l'entrée dans l'écran.
    unawaited(MirrorPullService.instance.pullNow());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _totalCents(List<Article> articles, Map<int, int> lines) {
    int t = 0;
    for (final e in lines.entries) {
      final a = articles.firstWhere((x) => x.id == e.key);
      t += a.priceCents * e.value;
    }
    return t;
  }

  /// [onCredit] = true → la vente est enregistrée comme dette (impayée).
  Future<void> _checkout(List<Article> articles,
      {bool onCredit = false}) async {
    final cart = ref.read(posCartProvider);
    if (cart.isEmpty) return;
    // Une dette exige un nom ou une chambre (pour savoir qui doit).
    if (onCredit && cart.customerName == null && cart.roomNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Renseigne un client ou une chambre avant d\'enregistrer une dette.')));
      return;
    }
    final me = ref.read(authProvider).user;
    final saleId = await ref.read(salesRepoProvider).createSale(
          articleQuantities: Map.of(cart.lines),
          payment: cart.payment,
          location: cart.location,
          serverUserId: me?.id,
          customerName: cart.customerName,
          roomNumber: cart.roomNumber,
          onCredit: onCredit,
        );
    unawaited(VentesOutbox.instance.pousser(saleId));
    if (!mounted) return;
    final loc = cart.location.label;
    ref.read(posCartProvider.notifier).clear();
    final now = DateFormat("HH:mm:ss", 'fr_FR').format(aLubumbashi(Horloge.maintenant()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(onCredit
              ? 'Dette enregistrée #${saleId.toString().padLeft(4, "0")} · $loc · $now'
              : 'Facture #${saleId.toString().padLeft(4, "0")} · $loc · $now')),
    );
    // On imprime la facture uniquement pour un encaissement payé.
    if (!onCredit) {
      final recent =
          await ref.read(salesRepoProvider).watchRecent(days: 1).first;
      final sale = recent.firstWhere(
        (s) => s.sale.id == saleId,
        orElse: () => recent.first,
      );
      await PdfService.previewInvoice(sale);
    }
  }

  Future<void> _printCurrentPreview(List<Article> articles) async {
    final cart = ref.read(posCartProvider);
    if (cart.isEmpty) return;
    // Aperçu AVANT encaissement : on construit un ticket "brouillon".
    await PdfService.previewCartPreview(
      lines: [
        for (final e in cart.lines.entries)
          () {
            final a = articles.firstWhere((x) => x.id == e.key);
            return CartPreviewLine(
              name: a.name,
              qty: e.value,
              unitPriceCents: a.priceCents,
            );
          }(),
      ],
      payment: cart.payment,
      serverName: ref.read(authProvider).user?.fullName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(articlesStreamProvider);
    final cart = ref.watch(posCartProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'pos_screen')),
      data: (articles) {
        // Dispo : null = pas de suivi stock, sinon quantité restante.
        final availableByArticle = <int, int?>{
          for (final a in articles) a.id: a.trackStock ? a.stockQty : null,
        };
        // Filtre : par catégorie ET par recherche. Quand une recherche
        // est active, on ignore la catégorie pour chercher partout — le
        // user attend "je tape 'coca', je le vois d'où qu'il vienne".
        final q = _search.trim().toLowerCase();
        final items = q.isEmpty
            ? articles.where((a) => a.category == _cat).toList()
            : articles.where((a) => a.name.toLowerCase().contains(q)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              eyebrow: 'Point de vente',
              title: 'Encaisser un client',
              subtitle: cart.isEmpty
                  ? 'Sélectionne une catégorie puis tape sur les articles.'
                  : 'Ticket en cours : ${cart.itemsCount} article(s). Ton panier est conservé si tu changes d\'écran.',
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LocationSelector(
                            current: cart.location,
                            onChanged: (l) => ref
                                .read(posCartProvider.notifier)
                                .setLocation(l),
                          ),
                          const SizedBox(height: BsSpace.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _CategoryTabs(
                                    current: _cat,
                                    onChanged: (c) => setState(() => _cat = c)),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 240,
                                child: _SearchField(
                                  controller: _searchCtrl,
                                  onChanged: (v) => setState(() => _search = v),
                                  onClear: () {
                                    _searchCtrl.clear();
                                    setState(() => _search = '');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: BsSpace.md),
                          Expanded(
                              child: _ArticleGrid(
                                  items: items,
                                  availableByArticle: availableByArticle,
                                  onTap: (a) {
                                    ref.read(posCartProvider.notifier).add(
                                          a.id,
                                          available: availableByArticle[a.id],
                                        );
                                    final avail = availableByArticle[a.id];
                                    final cur = (ref
                                            .read(posCartProvider)
                                            .lines[a.id] ??
                                        0);
                                    if (avail != null && cur > avail) {
                                      // add() a rejeté silencieusement — feedback UI.
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Stock insuffisant pour « ${a.name} »')),
                                      );
                                    }
                                  })),
                        ],
                      ),
                    ),
                    const SizedBox(width: BsSpace.md),
                    SizedBox(
                      width: 320,
                      child: _Ticket(
                        cart: cart,
                        articles: articles,
                        totalCents: _totalCents(articles, cart.lines),
                        onPayment: (p) =>
                            ref.read(posCartProvider.notifier).setPayment(p),
                        onDec: (id) =>
                            ref.read(posCartProvider.notifier).remove(id),
                        onInc: (id) {
                          final a = articles.firstWhere((x) => x.id == id);
                          ref.read(posCartProvider.notifier).add(
                                a.id,
                                available: availableByArticle[a.id],
                              );
                        },
                        onClear: () =>
                            ref.read(posCartProvider.notifier).clear(),
                        onCheckout: () => _checkout(articles),
                        onCredit: () => _checkout(articles, onCredit: true),
                        onPrintPreview: () => _printCurrentPreview(articles),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: BsSpace.md),
          ],
        );
      },
    );
  }
}

class _LocationSelector extends StatelessWidget {
  final DbLocation current;
  final ValueChanged<DbLocation> onChanged;
  const _LocationSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 14),
            child: Text('VENDRE POUR', style: BsType.eyebrow()),
          ),
          for (final l in DbLocation.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(l),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: l == current ? l.color : Colors.transparent,
                    borderRadius: BorderRadius.circular(BsRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(l.icon,
                          size: 15,
                          color: l == current ? Colors.white : l.color),
                      const SizedBox(width: 8),
                      Text(l.label,
                          style: BsType.body(13,
                              w: FontWeight.w700,
                              color:
                                  l == current ? Colors.white : BsColors.ink)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Champ de recherche produit — filtre la grille en direct sur le nom.
/// Quand du texte est saisi, le filtre par catégorie est désactivé pour
/// chercher dans TOUT le catalogue.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: BsType.body(13, w: FontWeight.w500),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher un produit…',
        hintStyle: BsType.body(13, color: BsColors.slateSoft),
        prefixIcon: const Icon(Icons.search, size: 18, color: BsColors.slate),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClear,
                tooltip: 'Effacer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              )
            : null,
        filled: true,
        fillColor: BsColors.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BsRadius.sm),
          borderSide: const BorderSide(color: BsColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BsRadius.sm),
          borderSide: const BorderSide(color: BsColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BsRadius.sm),
          borderSide: const BorderSide(color: BsColors.ink, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final DbCategory current;
  final ValueChanged<DbCategory> onChanged;
  const _CategoryTabs({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      // La catégorie "chambres" n'apparaît plus au POS : la vente d'une
      // nuitée passe uniquement par l'onglet Chambres (check-in / check-out).
      children:
          DbCategory.values.where((c) => c != DbCategory.chambres).map((c) {
        final active = c == current;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: active ? BsColors.ink : BsColors.paper,
                borderRadius: BorderRadius.circular(BsRadius.sm),
                border:
                    Border.all(color: active ? BsColors.ink : BsColors.line),
              ),
              child: Row(children: [
                Icon(c.icon,
                    size: 14, color: active ? Colors.white : BsColors.ink),
                const SizedBox(width: 8),
                Text(c.label,
                    style: BsType.body(13,
                        w: FontWeight.w600,
                        color: active ? Colors.white : BsColors.ink)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ArticleGrid extends StatelessWidget {
  final List<Article> items;
  final Map<int, int?> availableByArticle;
  final ValueChanged<Article> onTap;
  const _ArticleGrid({
    required this.items,
    required this.availableByArticle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cross = (c.maxWidth / 200).floor().clamp(2, 6);
      return GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _Tile(
          article: items[i],
          available: availableByArticle[items[i].id],
          onTap: () => onTap(items[i]),
        ),
      );
    });
  }
}

class _Tile extends StatefulWidget {
  final Article article;
  final int? available;
  final VoidCallback onTap;
  const _Tile({
    required this.article,
    required this.available,
    required this.onTap,
  });
  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final avail = widget.available;
    final outOfStock = avail != null && avail <= 0;
    // RepaintBoundary : chaque tuile ne repeint QUE elle-même sur hover,
    // le reste de la grille n'est pas touché — indispensable dès qu'on
    // dépasse ~15 produits, sinon toute la grille repeint à chaque
    // mouvement de souris.
    return RepaintBoundary(
      child: MouseRegion(
        cursor: outOfStock
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: outOfStock ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BsRadius.md),
              border: Border.all(
                  color: outOfStock
                      ? BsColors.line
                      : (_hover ? BsColors.ink : BsColors.line),
                  width: _hover ? 1.5 : 1),
              boxShadow: (_hover && !outOfStock)
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BsRadius.md - 1),
              child: Opacity(
                opacity: outOfStock ? 0.55 : 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fond : photo pleine carte OU placeholder catégorie.
                    _TileBackground(
                      imagePath: widget.article.imagePath,
                      category: widget.article.category,
                    ),
                    // Voile dégradé pour lisibilité du texte en bas.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.35, 1.0],
                          colors: [
                            Colors.transparent,
                            BsColors.scrim,
                          ],
                        ),
                      ),
                    ),
                    // Badge stock coin haut-droit.
                    Positioned(
                      top: 8,
                      right: 8,
                      child: outOfStock
                          ? const _StockBadge(
                              label: 'ÉPUISÉ', color: BsColors.danger)
                          : avail != null && avail <= 5
                              ? _StockBadge(
                                  label: '$avail rest.',
                                  color: BsColors.warning)
                              : avail != null
                                  ? _StockBadge(
                                      label: '$avail', color: Colors.white)
                                  : const SizedBox.shrink(),
                    ),
                    // Nom + prix en bas.
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.article.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BsType.body(13,
                                  w: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(prixArticle(widget.article.priceCents),
                              style: BsType.mono(15,
                                  w: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomPicker extends ConsumerWidget {
  final PosCartState cart;
  const _RoomPicker({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRooms = ref.watch(roomsStreamProvider);
    final rooms = asyncRooms.asData?.value ?? const [];
    // Chambres actuellement occupées, triées par numéro.
    final occupied = rooms
        .where((r) => r.status == DbRoomStatus.occupee)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final payers = ref.watch(payersStreamProvider).asData?.value ?? const [];
    final payerById = {for (final p in payers) p.id: p};
    final pull = MirrorPullService.instance;
    final lastPull = pull.lastPull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('CHAMBRE', style: BsType.eyebrow()),
          const SizedBox(width: 6),
          Text('(${occupied.length} occupée${occupied.length > 1 ? "s" : ""})',
              style: BsType.body(10, color: BsColors.slateSoft)),
          const Spacer(),
          IconButton(
            tooltip: lastPull == null
                ? 'Rafraîchir depuis Supabase'
                : 'MAJ ${_relTime(lastPull)}',
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () async {
              await pull.pullNow();
            },
            icon: const Icon(Icons.refresh, color: BsColors.slate),
          ),
        ]),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: cart.roomNumber,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          hint: Text('Vente au comptoir / terrasse',
              style: BsType.body(13, color: BsColors.slate)),
          // Version compacte affichée dans le champ (1 ligne).
          selectedItemBuilder: (_) => [
            const Text('Vente au comptoir / terrasse'),
            for (final r in occupied)
              Text('Ch. ${r.number} · ${r.currentGuest ?? "occupée"}',
                  overflow: TextOverflow.ellipsis,
                  style: BsType.body(13, w: FontWeight.w600)),
          ],
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— Aucune chambre —'),
            ),
            for (final r in occupied)
              DropdownMenuItem<String?>(
                value: r.number,
                child: _OccupiedRoomLine(
                  room: r,
                  payer: r.payerId == null ? null : payerById[r.payerId],
                ),
              ),
          ],
          onChanged: (number) {
            if (number == null) {
              ref.read(posCartProvider.notifier).setRoom(null);
            } else {
              final r = occupied.firstWhere((x) => x.number == number);
              ref
                  .read(posCartProvider.notifier)
                  .setRoom(r.number, guest: r.currentGuest);
            }
          },
        ),
        // Info payeur si prise en charge société.
        if (cart.roomNumber != null) ...[
          Builder(builder: (_) {
            final r = occupied.firstWhere((x) => x.number == cart.roomNumber,
                orElse: () => occupied.isEmpty
                    ? _fakeRoom(cart.roomNumber!)
                    : occupied.first);
            final p = r.payerId == null ? null : payerById[r.payerId];
            if (p == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: BsColors.sky.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BsRadius.sm),
                  border:
                      Border.all(color: BsColors.sky.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.business, size: 12, color: BsColors.sky),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Facturation à : ${p.name}',
                        style: BsType.body(11,
                            w: FontWeight.w700, color: BsColors.sky)),
                  ),
                ]),
              ),
            );
          }),
        ],
      ],
    );
  }

  static String _relTime(DateTime dt) {
    final s = DateTime.now().difference(dt).inSeconds;
    if (s < 60) return 'sync il y a ${s}s';
    return 'sync il y a ${(s / 60).round()} min';
  }

  static Room _fakeRoom(String number) => Room(
        number: number,
        type: '',
        // Chambre factice : sert uniquement à rattacher une vente à un
        // numéro. Aucun tarif, dans aucune devise.
        priceUsdCents: 0,
        pricePerNightCents: 0,
        status: DbRoomStatus.occupee,
        currentGuest: null,
        checkoutDate: null,
        checkinNote: null,
        checkinAt: null,
        stayGroup: null,
        payerId: null,
      );
}

/// Ligne enrichie d'une chambre occupée dans le picker POS :
///   Ch. 12 · M. Kabongo
///   depuis 08h32 · [Société : Afrinvest]
class _OccupiedRoomLine extends StatelessWidget {
  final Room room;
  final Payer? payer;
  const _OccupiedRoomLine({required this.room, required this.payer});

  @override
  Widget build(BuildContext context) {
    final since = room.checkinAt == null
        ? null
        : DateFormat('d MMM · HH:mm', 'fr_FR').format(aLubumbashi(room.checkinAt!));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: BsColors.sunrise.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('Ch. ${room.number}',
                  style: BsType.mono(10,
                      w: FontWeight.w800, color: BsColors.sunrise)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(room.currentGuest ?? 'occupée',
                  style: BsType.body(12, w: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (since != null || payer != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              if (since != null)
                Text('depuis $since',
                    style: BsType.body(10, color: BsColors.slate)),
              if (payer != null) ...[
                if (since != null)
                  Text(' · ',
                      style: BsType.body(10, color: BsColors.slateSoft)),
                Icon(Icons.business,
                    size: 10, color: BsColors.sky.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(payer!.name,
                      overflow: TextOverflow.ellipsis,
                      style: BsType.body(10,
                          w: FontWeight.w700, color: BsColors.sky)),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

class _CustomerNameField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CustomerNameField> createState() => _CustomerNameFieldState();
}

class _CustomerNameFieldState extends ConsumerState<_CustomerNameField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: ref.read(posCartProvider).customerName ?? '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si le panier est réinitialisé ailleurs, resynchroniser.
    ref.listen<PosCartState>(posCartProvider, (prev, next) {
      final n = next.customerName ?? '';
      if (_c.text != n) _c.text = n;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('NOM DU CLIENT', style: BsType.eyebrow()),
          const SizedBox(width: 6),
          Text('(optionnel)',
              style: BsType.body(10, color: BsColors.slateSoft)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _c,
          onChanged: (v) => ref.read(posCartProvider.notifier).setCustomer(v),
          decoration: InputDecoration(
            hintText: 'ex. M. Kabongo · Table 5',
            isDense: true,
            suffixIcon: _c.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () {
                      _c.clear();
                      ref.read(posCartProvider.notifier).setCustomer(null);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Fond de tuile : photo pleine si dispo, sinon dégradé + gros icône
/// catégorie (verre, plat, hôtel) centré comme placeholder visuel.
///
/// StatefulWidget pour :
///   - Ne PAS refaire `File.existsSync()` à chaque rebuild (I/O disque
///     synchrone sur le main thread — gros frein sur une grille de 20+
///     tuiles qui rebuild à chaque hover / setState du panier).
///   - Passer `cacheWidth` à `Image.network/file` → décodage limité
///     à la taille utile (200 px) au lieu de la résolution native
///     (photos 3000×2000 = décodage énorme).
class _TileBackground extends StatefulWidget {
  final String? imagePath;
  final DbCategory category;
  const _TileBackground({required this.imagePath, required this.category});

  @override
  State<_TileBackground> createState() => _TileBackgroundState();
}

class _TileBackgroundState extends State<_TileBackground> {
  bool _localFileExists = false;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
  }

  @override
  void didUpdateWidget(covariant _TileBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _checkLocalFile();
  }

  void _checkLocalFile() {
    final p = widget.imagePath;
    _localFileExists = p != null &&
        p.isNotEmpty &&
        !p.startsWith('http') &&
        File(p).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.imagePath;
    if (p != null && p.isNotEmpty) {
      if (p.startsWith('http')) {
        return Image.network(p,
            fit: BoxFit.cover,
            cacheWidth: 400,
            errorBuilder: (_, __, ___) => _fallback());
      }
      if (_localFileExists) {
        return Image.file(File(p), fit: BoxFit.cover, cacheWidth: 400);
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    final color = switch (widget.category) {
      DbCategory.boissons => BsColors.sky,
      DbCategory.nourriture => BsColors.sunrise,
      DbCategory.chambres => BsColors.skyDeep,
    };
    final icon = switch (widget.category) {
      DbCategory.boissons => Icons.local_bar,
      DbCategory.nourriture => Icons.restaurant_menu,
      DbCategory.chambres => Icons.hotel,
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.75),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 64, color: Colors.white.withValues(alpha: 0.75)),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StockBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child:
          Text(label, style: BsType.body(9, w: FontWeight.w700, color: color)),
    );
  }
}

class _Ticket extends StatelessWidget {
  final PosCartState cart;
  final List<Article> articles;
  final int totalCents;
  final ValueChanged<DbPayment> onPayment;
  final ValueChanged<int> onDec;
  final ValueChanged<int> onInc;
  final VoidCallback onClear;
  final VoidCallback onCheckout;
  final VoidCallback onCredit;
  final VoidCallback onPrintPreview;
  const _Ticket({
    required this.cart,
    required this.articles,
    required this.totalCents,
    required this.onPayment,
    required this.onDec,
    required this.onInc,
    required this.onClear,
    required this.onCheckout,
    required this.onCredit,
    required this.onPrintPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BsSpace.lg),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TICKET EN COURS', style: BsType.eyebrow()),
                    const SizedBox(height: 4),
                    Text('${cart.itemsCount} article(s)',
                        style: BsType.mono(12, color: BsColors.slate)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Vider',
                onPressed: cart.isEmpty ? null : onClear,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(BsSpace.md),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 40, color: BsColors.slateSoft),
                          const SizedBox(height: 12),
                          Text('Aucun article',
                              style: BsType.body(13, color: BsColors.slate)),
                        ]),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: cart.lines.entries.map((e) {
                      final a = articles.firstWhere((x) => x.id == e.key);
                      return _CartRow(
                        article: a,
                        qty: e.value,
                        onDec: () => onDec(e.key),
                        onInc: () => onInc(e.key),
                      );
                    }).toList(),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(BsSpace.md),
            child: Column(children: [
              // Chambre pertinente uniquement pour l'onglet Hôtel — sinon
              // la vente est au comptoir / à table.
              if (cart.location == DbLocation.hotel) ...[
                _RoomPicker(cart: cart),
                const SizedBox(height: 8),
              ],
              _CustomerNameField(),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text('MODE PAIEMENT', style: BsType.eyebrow())),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final p in DbPayment.values)
                  GestureDetector(
                    onTap: () => onPayment(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: p == cart.payment
                            ? BsColors.ink
                            : Colors.transparent,
                        border: Border.all(color: BsColors.ink),
                        borderRadius: BorderRadius.circular(BsRadius.sm),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(p.icon,
                            size: 11,
                            color: p == cart.payment
                                ? Colors.white
                                : BsColors.ink),
                        const SizedBox(width: 4),
                        Text(p.label,
                            style: BsType.body(10,
                                w: FontWeight.w700,
                                color: p == cart.payment
                                    ? Colors.white
                                    : BsColors.ink)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('TOTAL', style: BsType.eyebrow())),
                Text(moneyCents(totalCents),
                    style: BsType.display(26, w: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: cart.isEmpty ? null : onCheckout,
                  label: const Text('Encaisser & imprimer facture'),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        size: 16),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BsColors.sunrise,
                      side: const BorderSide(color: BsColors.sunrise),
                    ),
                    onPressed: cart.isEmpty ? null : onCredit,
                    label: const Text('Enregistrer en dette'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Aperçu facture (sans encaisser)',
                  onPressed: cart.isEmpty ? null : onPrintPreview,
                  icon: const Icon(Icons.print_outlined, size: 18),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final Article article;
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _CartRow({
    required this.article,
    required this.qty,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.name,
                  style: BsType.body(13, w: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              Text(moneyCents(article.priceCents),
                  style: BsType.mono(11, color: BsColors.slate)),
            ],
          ),
        ),
        _stepBtn(Icons.remove, onDec),
        SizedBox(
          width: 30,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: BsType.mono(14, w: FontWeight.w700)),
        ),
        _stepBtn(Icons.add, onInc),
        const SizedBox(width: 10),
        SizedBox(
          width: 68,
          child: Text(moneyCents(article.priceCents * qty),
              textAlign: TextAlign.right,
              style: BsType.mono(13, w: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: BsColors.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14),
        ),
      );
}
