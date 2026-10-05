import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/cat_ui.dart';
import '../data/schema.dart';
import '../services/supply_notifications.dart';
import '../services/supply_requests_service.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../core/temps.dart';

/// Cloche de notifications dans la sidebar :
///   - Badge rouge avec le nombre de decisions non lues (approuvees ou
///     rejetees) sur les demandes emises par l'utilisateur
///   - Tap -> panel qui liste toutes ses demandes recentes avec statut
///   - Ouverture du panel = marque tout comme "vu"
class NotificationsBell extends ConsumerWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(supplyNotifsProvider);
    final unseen = service.state.unseenCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: InkWell(
        onTap: () => _showPanel(context, ref),
        borderRadius: BorderRadius.circular(BsRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: BsColors.inkSoft,
            borderRadius: BorderRadius.circular(BsRadius.sm),
          ),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_outlined,
                  size: 16, color: BsColors.sunrise),
              if (unseen > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(
                      color: BsColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text('$unseen',
                        textAlign: TextAlign.center,
                        style: BsType.mono(9,
                            w: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  unseen == 0
                      ? 'Notifications'
                      : '$unseen nouvelle${unseen > 1 ? 's' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style:
                      BsType.body(12, w: FontWeight.w600, color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }

  void _showPanel(BuildContext ctx, WidgetRef ref) {
    // Marque tout comme vu des l'ouverture du panel.
    ref.read(supplyNotifsProvider).markAllSeen();
    showDialog(
      context: ctx,
      builder: (_) => const _NotificationsPanel(),
    );
  }
}

class _NotificationsPanel extends ConsumerWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(supplyNotifsProvider);
    final requests = service.state.requests;

    return Dialog(
      backgroundColor: BsColors.paper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BsRadius.md)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.notifications, color: BsColors.sunrise),
                const SizedBox(width: 8),
                Text('Mes demandes de ravitaillement',
                    style: BsType.display(18, w: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: () => service.refreshNow(),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
              const SizedBox(height: 4),
              if (service.state.lastRefresh != null)
                Text(
                    'Dernière vérification : ${_relTime(service.state.lastRefresh!)}',
                    style: BsType.body(11, color: BsColors.slateSoft)),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(children: [
                      const Icon(Icons.inbox_outlined,
                          size: 42, color: BsColors.slateSoft),
                      const SizedBox(height: 8),
                      Text('Aucune demande émise récemment.',
                          style: BsType.body(12, color: BsColors.slate)),
                    ]),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: BsColors.line),
                    itemBuilder: (_, i) => _RequestRow(req: requests[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return "il y a ${d.inSeconds}s";
    if (d.inMinutes < 60) return "il y a ${d.inMinutes} min";
    return DateFormat("HH:mm").format(aLubumbashi(dt));
  }
}

class _RequestRow extends StatelessWidget {
  final SupplyRequest req;
  const _RequestRow({required this.req});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (req.status) {
      'approved' => (BsColors.success, 'APPROUVÉE', Icons.check_circle),
      'rejected' => (BsColors.danger, 'REJETÉE', Icons.cancel),
      'fulfilled' => (BsColors.sky, 'LIVRÉE', Icons.local_shipping),
      _ => (BsColors.slateSoft, 'EN ATTENTE', Icons.hourglass_bottom),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: BsType.eyebrow(color: color)),
            const Spacer(),
            if (req.requestedAt != null)
              Text(
                  DateFormat("d MMM · HH:mm", 'fr_FR')
                      .format(aLubumbashi(req.requestedAt!)),
                  style: BsType.body(11, color: BsColors.slateSoft)),
          ]),
          const SizedBox(height: 6),
          // Une demande hôtel (article_id == null) est une note libre :
          // articleName = le texte de la demande tronqué. On l'affiche
          // en note plutôt qu'en "N × produit".
          if (req.articleId == null && req.location == DbLocation.hotel) ...[
            Row(children: [
              const Icon(Icons.hotel_outlined,
                  size: 12, color: BsColors.sunrise),
              const SizedBox(width: 6),
              Text('DEMANDE HÔTEL',
                  style: BsType.eyebrow(color: BsColors.sunrise)),
            ]),
            const SizedBox(height: 4),
            Text(req.articleName,
                style:
                    BsType.body(13, w: FontWeight.w600, color: BsColors.ink)),
          ] else ...[
            Text(req.articleName, style: BsType.body(14, w: FontWeight.w700)),
            Text('${req.qtyRequested} demandé(s) pour ${req.location.label}',
                style: BsType.body(12, color: BsColors.slate)),
          ],
          if (req.reviewNote != null && req.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: BsColors.papyrus,
                borderRadius: BorderRadius.circular(BsRadius.sm),
              ),
              child: Text('« ${req.reviewNote!} »',
                  style: BsType.body(11,
                      color: BsColors.slate, w: FontWeight.w500)),
            ),
          ],
          if (req.reviewedByLogin != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'Décidée par ${req.reviewedByLogin}${req.reviewedAt != null ? " · ${DateFormat("d MMM · HH:mm", 'fr_FR').format(aLubumbashi(req.reviewedAt!))}" : ""}',
                  style: BsType.body(10, color: BsColors.slateSoft)),
            ),
        ],
      ),
    );
  }
}
