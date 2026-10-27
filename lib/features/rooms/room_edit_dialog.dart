import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../services/cloud_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/devise.dart';
import 'room_card.dart';

// Création, modification et suppression d'une chambre.

void showRoomDialog(BuildContext ctx, WidgetRef ref, {Room? existing}) {
  final number = TextEditingController(text: existing?.number ?? '');
  final type = TextEditingController(text: existing?.type ?? '');
  // Le tarif se saisit en DOLLARS : c'est le prix annoncé au client.
  // Sans décimales quand il tombe rond — « 45 » plutôt que « 45.0 »,
  // parce qu'un tarif d'hôtel tombe presque toujours rond.
  final price = TextEditingController(
      text: existing == null || existing.priceUsdCents <= 0
          ? ''
          : (existing.priceUsdCents % 100 == 0
              ? (existing.priceUsdCents ~/ 100).toString()
              : (existing.priceUsdCents / 100).toStringAsFixed(2)));
  String? imagePath = existing?.imagePath;
  String? err;
  bool busy = false;
  final isEdit = existing != null;

  showDialog(
    context: ctx,
    builder: (_) => StatefulBuilder(builder: (context, setSt) {
      return Dialog(
        backgroundColor: BsColors.paper,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BsRadius.md)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEdit ? 'ÉDITER CHAMBRE' : 'NOUVELLE CHAMBRE',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text(
                      isEdit ? 'Chambre ${existing.number}' : 'Ajouter au plan',
                      style: BsType.display(22, w: FontWeight.w700)),
                  const SizedBox(height: 20),
                  // ── Bloc photo (haut, comme les articles POS) ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: BsColors.inkSoft.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(BsRadius.sm),
                          border: Border.all(color: BsColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: RoomImagePreview(
                            path: imagePath, decodeWidth: 1200),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PHOTO', style: BsType.eyebrow()),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.image_outlined, size: 16),
                              onPressed: () async {
                                final file = await openFile(
                                  acceptedTypeGroups: const [
                                    XTypeGroup(label: 'Images', extensions: [
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
                                  imagePath == null ? 'Ajouter' : 'Changer',
                                  style: BsType.body(12)),
                            ),
                            if (imagePath != null)
                              TextButton(
                                onPressed: () => setSt(() => imagePath = null),
                                child: Text('Retirer',
                                    style:
                                        BsType.body(11, color: BsColors.slate)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('NUMÉRO', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: number,
                    enabled: !isEdit, // PK non modifiable
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      hintText: 'ex. 12 ou B3',
                      helperText:
                          isEdit ? 'Le numéro ne peut pas être modifié.' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('TYPE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: type,
                    decoration: const InputDecoration(
                        hintText: 'Standard / Double / Suite / Bungalow'),
                  ),
                  const SizedBox(height: 12),
                  Text('PRIX / NUIT (USD)', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setSt(() {}),
                    decoration: InputDecoration(
                        hintText: '45', prefixText: String.fromCharCode(36)),
                  ),
                  const SizedBox(height: 6),
                  // L'équivalent en francs, sous le champ : la réception
                  // encaisse dans cette monnaie-là, elle doit le voir
                  // sans avoir à le calculer.
                  Builder(builder: (_) {
                    final usd = usdEnCents(price.text);
                    return Text(
                        usd <= 0
                            ? 'Soit — FC au taux actuel'
                            : 'Soit ${moneyCents(usdVersFc(usd))} au taux actuel',
                        style: BsType.body(12, color: BsColors.slate));
                  }),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    TextButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final p = usdEnCents(price.text);
                              if (number.text.trim().isEmpty ||
                                  type.text.trim().isEmpty ||
                                  p <= 0) {
                                setSt(
                                    () => err = 'Tous les champs sont requis');
                                return;
                              }
                              setSt(() {
                                busy = true;
                                err = null;
                              });
                              // Upload cloud si nouveau chemin local.
                              var savedImage = imagePath;
                              if (imagePath != null &&
                                  !imagePath!.startsWith('http') &&
                                  File(imagePath!).existsSync() &&
                                  CloudService.enabled) {
                                final url = await CloudService.uploadRoomImage(
                                    File(imagePath!));
                                if (url != null) savedImage = url;
                              }
                              try {
                                if (isEdit) {
                                  await ref.read(roomsRepoProvider).updateInfo(
                                        number: existing.number,
                                        type: type.text.trim(),
                                        priceUsdCents: p,
                                        imagePath: savedImage,
                                      );
                                } else {
                                  await ref.read(roomsRepoProvider).create(
                                        number: number.text.trim(),
                                        type: type.text.trim(),
                                        priceUsdCents: p,
                                        imagePath: savedImage,
                                      );
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } catch (_) {
                                setSt(() {
                                  busy = false;
                                  err = 'Ce numéro de chambre existe déjà';
                                });
                              }
                            },
                      child: Text(isEdit ? 'Enregistrer' : 'Créer'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
    }),
  );
}

Future<void> confirmDeleteRoom(
    BuildContext ctx, WidgetRef ref, Room room) async {
  if (room.status != DbRoomStatus.libre) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
            'Impossible de supprimer la chambre ${room.number} : elle est ${room.status.label.toLowerCase()}.'),
      ),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      title: Text('Supprimer la chambre ${room.number} ?'),
      content: const Text(
          'Cette action est définitive. La chambre disparaîtra du plan.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(roomsRepoProvider).delete(room.number);
  }
}
