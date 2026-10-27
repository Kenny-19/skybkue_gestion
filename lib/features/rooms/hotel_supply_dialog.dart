import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth.dart';
import '../../data/schema.dart';
import '../../services/supply_requests_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Dialog "Demande de ravitaillement pour l'HÔTEL" — accessible à
/// la réception + admin + super admin depuis l'écran Chambres.
///
/// Ici l'hôtel n'a pas de "stock" à proprement parler : les produits du
/// restaurant/terrasse (Coca, bière, portions…) sont gérés séparément.
/// La demande hôtel est donc une **note libre** que Pamela lit et
/// exécute manuellement (draps neufs, savon en gros, kit accueil…).
void showHotelSupplyRequest(BuildContext ctx, WidgetRef ref) {
  final noteCtrl = TextEditingController();
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
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('DEMANDE DE RAVITAILLEMENT — HÔTEL',
                    style: BsType.eyebrow(color: BsColors.sunrise)),
                const SizedBox(height: 6),
                Text('Faire remonter un besoin à Pamela',
                    style: BsType.display(18, w: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                    'Écris librement ce qui manque : Pamela reçoit ta demande sur son tableau et sur son téléphone.',
                    style: BsType.body(11, color: BsColors.slateSoft)),
                const SizedBox(height: 16),
                Text('DÉTAIL DE LA DEMANDE', style: BsType.eyebrow()),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText:
                        'ex. 20 draps blancs, 5 kg savon, kits accueil chambre 12 & 15, ampoules LED pour couloir…',
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: BsType.body(12, color: BsColors.danger)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
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
                            final text = noteCtrl.text.trim();
                            if (text.isEmpty) {
                              setSt(() => err =
                                  'Écris au moins un mot avant d\'envoyer.');
                              return;
                            }
                            final me = ref.read(authProvider).user;
                            setSt(() {
                              busy = true;
                              err = null;
                            });
                            // On stocke le texte de la demande dans
                            // article_name (visible partout : dashboard,
                            // hub notif, historique) — tronqué à 200
                            // car. pour rester lisible en aperçu.
                            // Le texte complet part aussi dans `note`.
                            final label = text.length <= 200
                                ? text
                                : '${text.substring(0, 197)}…';
                            final id = await SupplyRequestsService.submit(
                              articleId: null,
                              articleName: label,
                              location: DbLocation.hotel,
                              qtyRequested: 1,
                              qtyAtRequest: 0,
                              thresholdAtRequest: 0,
                              requestedByLogin: me?.login ?? 'inconnu',
                              note: text,
                            );
                            if (!context.mounted) return;
                            if (id == null) {
                              setSt(() {
                                busy = false;
                                err =
                                    'Échec — pas de réseau ou Supabase indisponible ?';
                              });
                              return;
                            }
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                backgroundColor: BsColors.success,
                                content: Text('Demande envoyée à Pamela.',
                                    style: BsType.body(13,
                                        w: FontWeight.w600,
                                        color: Colors.white))));
                          },
                    label: const Text('Envoyer'),
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
