import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/discount.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import 'stay_helpers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/devise.dart';

// L'arrivée d'un client, seul ou en groupe.

void showCheckIn(BuildContext ctx, WidgetRef ref, Room room) {
  final guest = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();
  DateTime checkout = DateTime.now().add(const Duration(days: 1));
  Payer? payer;
  int? negotiated;

  showDialog(
    context: ctx,
    builder: (_) => StatefulBuilder(builder: (context, setSt) {
      return Dialog(
        backgroundColor: BsColors.paper,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BsRadius.md)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CHECK-IN CHAMBRE ${room.number}',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text(
                      '${room.type} · ${montantHotelCourt(room.priceUsdCents)}/nuit',
                      style: BsType.body(13, color: BsColors.slate)),
                  const SizedBox(height: 16),
                  ClientLookupField(
                    nameCtrl: guest,
                    phoneCtrl: phone,
                    autofocusName: true,
                  ),
                  const SizedBox(height: 12),
                  PayerPickerSection(
                    initial: payer,
                    onChanged: (p) => setSt(() => payer = p),
                  ),
                  const SizedBox(height: 12),
                  NegotiatedRateField(
                    listPriceCents: room.pricePerNightCents,
                    onChanged: (v) => negotiated = v,
                  ),
                  const SizedBox(height: 12),
                  Text('DATE DE DÉPART', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: checkout,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSt(() => checkout = picked);
                    },
                    label: Text(
                        '${checkout.day}/${checkout.month}/${checkout.year}',
                        style: BsType.body(13)),
                  ),
                  const SizedBox(height: 12),
                  Text('NOTE (optionnel)', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Ex : petit-déj inclus, chambre calme demandée, VIP, allergie…',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'Cette note apparaîtra sur la fiche chambre et dans le rapport.',
                      style: BsType.body(11, color: BsColors.slateSoft)),
                  const SizedBox(height: 24),
                  Row(children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: guest.text.trim().isEmpty
                          ? null
                          : () async {
                              // 1. Fidélité : trouve ou crée le client,
                              //    puis compte cette visite.
                              final clients = ref.read(clientsRepoProvider);
                              final c = await clients.findOrCreate(
                                fullName: guest.text.trim(),
                                phone: phone.text.trim(),
                              );
                              await clients.recordVisit(c.id);
                              // 2. Check-in de la chambre avec payerId
                              //    optionnel.
                              await ref.read(roomsRepoProvider).checkIn(
                                    room.number,
                                    guest.text.trim(),
                                    checkout,
                                    note: note.text.trim().isEmpty
                                        ? null
                                        : note.text.trim(),
                                    payerId: payer?.id,
                                    negotiatedPriceCents: negotiated,
                                  );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: const Text('Enregistrer'),
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

/// Check-in groupé : sélection multi-chambres libres + un seul
/// formulaire (payeur, date départ, note commune). Toutes les chambres
/// choisies partagent un même `stayGroup`.
void showGroupCheckIn(BuildContext ctx, WidgetRef ref, List<Room> allRooms) {
  final free = allRooms.where((r) => r.status == DbRoomStatus.libre).toList()
    ..sort((a, b) => a.number.compareTo(b.number));
  if (free.length < 2) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text(
            'Il faut au moins 2 chambres libres pour un check-in groupé.')));
    return;
  }

  final picked = <String>{};
  final guest = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();
  DateTime checkout = DateTime.now().add(const Duration(days: 1));
  Payer? payer;
  bool busy = false;
  String? err;
  // Remise groupe en centièmes de % — appliquée au tarif catalogue de
  // chaque chambre sélectionnée pour produire un tarif négocié.
  int groupDiscount = 0;

  showDialog(
    context: ctx,
    builder: (_) => StatefulBuilder(builder: (context, setSt) {
      final selected = free.where((r) => picked.contains(r.number)).toList();
      // Les totaux en dollars, calculés depuis `priceUsdCents` et non
      // reconvertis depuis les francs : un aller-retour ferait
      // apparaître « $44,99 » là où le tarif affiché est $45.
      final listNightlyUsd =
          selected.fold<int>(0, (s, r) => s + r.priceUsdCents);
      // Tarif négocié par chambre = catalogue − remise groupe.
      //
      // La remise s'applique aux DOLLARS, puis on convertit : c'est
      // dans cette monnaie que la remise a été accordée, et un seul
      // arrondi vaut mieux que deux.
      int negotiatedFor(Room r) =>
          usdVersFc(_remise(r.priceUsdCents, groupDiscount));
      return Dialog(
        backgroundColor: BsColors.paper,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BsRadius.md)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CHECK-IN GROUPÉ',
                      style: BsType.eyebrow(color: BsColors.sky)),
                  const SizedBox(height: 6),
                  Text('Loger plusieurs chambres pour un même payeur',
                      style: BsType.display(18, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      'Entreprise, tour opérateur ou groupe familial : toutes les chambres partagent le nom du payeur et une facture consolidée à la fin.',
                      style: BsType.body(11, color: BsColors.slateSoft)),
                  const SizedBox(height: 16),
                  Text(
                      'CHAMBRES LIBRES (${picked.length} sélectionnée${picked.length > 1 ? "s" : ""})',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: BsColors.line),
                      borderRadius: BorderRadius.circular(BsRadius.sm),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: free.length,
                      itemBuilder: (_, i) {
                        final r = free[i];
                        final on = picked.contains(r.number);
                        return CheckboxListTile(
                          dense: true,
                          value: on,
                          onChanged: (v) => setSt(() {
                            if (v == true) {
                              picked.add(r.number);
                            } else {
                              picked.remove(r.number);
                            }
                          }),
                          title: Text('Ch. ${r.number} · ${r.type}',
                              style: BsType.body(13, w: FontWeight.w600)),
                          subtitle: Text(
                              '${montantHotelCourt(r.priceUsdCents)} / nuit',
                              style: BsType.body(11, color: BsColors.slate)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClientLookupField(
                    nameCtrl: guest,
                    phoneCtrl: phone,
                  ),
                  const SizedBox(height: 12),
                  PayerPickerSection(
                    initial: payer,
                    onChanged: (p) => setSt(() => payer = p),
                  ),
                  const SizedBox(height: 12),
                  Text('DATE DE DÉPART INITIALE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: checkout,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (p != null) setSt(() => checkout = p);
                    },
                    label: Text(
                        '${checkout.day}/${checkout.month}/${checkout.year}',
                        style: BsType.body(13)),
                  ),
                  const SizedBox(height: 4),
                  Text('Chaque chambre pourra sortir séparément si besoin.',
                      style: BsType.body(11, color: BsColors.slateSoft)),
                  const SizedBox(height: 12),
                  Text('NOTE COMMUNE (optionnel)', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Bon de commande, événement, VIP…'),
                  ),
                  const SizedBox(height: 12),
                  Text('TARIF NÉGOCIÉ GROUPE (optionnel)',
                      style: BsType.eyebrow()),
                  const SizedBox(height: 2),
                  Text(
                      'Applique la même remise au tarif/nuit de chaque chambre sélectionnée. Le catalogue reste inchangé.',
                      style: BsType.body(10, color: BsColors.slateSoft)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    ChoiceChip(
                      label: const Text('Tarif catalogue'),
                      selected: groupDiscount == 0,
                      onSelected: (_) => setSt(() => groupDiscount = 0),
                    ),
                    for (final p in Discount.quickPercents)
                      ChoiceChip(
                        label: Text('-${Discount.formatPercent(p)}'),
                        selected: groupDiscount == p,
                        onSelected: (_) => setSt(() => groupDiscount = p),
                      ),
                  ]),
                  if (picked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BsColors.sky.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(BsRadius.sm),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: BsColors.sky),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              groupDiscount == 0
                                  ? '${picked.length} chambre(s) · '
                                      '${montantHotelCourt(listNightlyUsd)} / nuit au total'
                                  : '${picked.length} chambre(s) · '
                                      '${moneyUsdCourt(_remise(listNightlyUsd, groupDiscount))} / nuit au lieu de '
                                      '${moneyUsdCourt(listNightlyUsd)} '
                                      '(−${moneyUsdCourt(listNightlyUsd - _remise(listNightlyUsd, groupDiscount))} / nuit)',
                              style: BsType.body(11,
                                  w: FontWeight.w600, color: BsColors.sky)),
                        ),
                      ]),
                    ),
                  ],
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 16),
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
                          : const Icon(Icons.check, size: 16),
                      style:
                          FilledButton.styleFrom(backgroundColor: BsColors.sky),
                      onPressed: (picked.isEmpty ||
                              guest.text.trim().isEmpty ||
                              busy)
                          ? null
                          : () async {
                              setSt(() {
                                busy = true;
                                err = null;
                              });
                              try {
                                // 1. Fidélité : trouve ou crée le client
                                //    du groupe, compte 1 visite par chambre.
                                final clients = ref.read(clientsRepoProvider);
                                final c = await clients.findOrCreate(
                                  fullName: guest.text.trim(),
                                  phone: phone.text.trim(),
                                );
                                for (var i = 0; i < picked.length; i++) {
                                  await clients.recordVisit(c.id);
                                }
                                // 2. Check-in groupé avec payerId optionnel.
                                await ref.read(roomsRepoProvider).groupCheckIn(
                                      numbers: picked.toList(),
                                      guest: guest.text.trim(),
                                      checkout: checkout,
                                      note: note.text.trim().isEmpty
                                          ? null
                                          : note.text.trim(),
                                      payerId: payer?.id,
                                      negotiatedPrices: groupDiscount == 0
                                          ? const {}
                                          : {
                                              for (final r in selected)
                                                r.number: negotiatedFor(r),
                                            },
                                    );
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          backgroundColor: BsColors.success,
                                          content: Text(
                                              '${picked.length} chambres logées pour ${guest.text.trim()}.',
                                              style: BsType.body(13,
                                                  w: FontWeight.w600,
                                                  color: Colors.white))));
                                }
                              } catch (e) {
                                setSt(() {
                                  busy = false;
                                  err = 'Échec : $e';
                                });
                              }
                            },
                      label: Text(picked.isEmpty
                          ? 'Sélectionne des chambres'
                          : 'Loger ${picked.length} chambre(s)'),
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

/// Aperçu de la photo d'une chambre (fichier local OU URL http). Fallback
/// icône générique si vide/erreur.
/// Applique une remise en centièmes de pourcent à un montant.
///
/// Le calcul se fait sur les DOLLARS, pas sur les francs reconvertis :
/// une remise de 10 % sur $45 doit donner $40,50, pas $40,49 hérité d'un
/// aller-retour par les francs.
int _remise(int usdCents, int centiemesDePourcent) =>
    (usdCents * (10000 - centiemesDePourcent) / 10000).round();
