import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/repos.dart';
import '../../data/schema.dart';
import '../../core/format.dart';
import '../../services/pdf_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/temps.dart';

/// Section "Séjours facturés" dans l'historique — liste les check-out
/// des 90 derniers jours avec réimpression PDF au clic.
class StaysHistorySection extends ConsumerWidget {
  const StaysHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentStaysProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(BsSpace.xl),
        child: Text('Erreur séjours : $e',
            style: BsType.body(11, color: BsColors.danger)),
      ),
      data: (stays) {
        if (stays.isEmpty) return const SizedBox.shrink();
        final total = stays.fold<int>(0, (s, e) => s + e.totalCents);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              BsSpace.xl, BsSpace.md, BsSpace.xl, BsSpace.lg),
          child: Container(
            decoration: BoxDecoration(
              color: BsColors.paper,
              border: Border.all(color: BsColors.line),
              borderRadius: BorderRadius.circular(BsRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BsSpace.lg, vertical: BsSpace.md),
                  child: Row(children: [
                    const Icon(Icons.hotel_outlined,
                        size: 16, color: BsColors.sunrise),
                    const SizedBox(width: 8),
                    Text('SÉJOURS FACTURÉS',
                        style: BsType.eyebrow(color: BsColors.sunrise)),
                    const Spacer(),
                    Text('${stays.length} séjour(s) · ${moneyCents(total)}',
                        style: BsType.body(11,
                            w: FontWeight.w600, color: BsColors.slate)),
                  ]),
                ),
                const Divider(height: 1, color: BsColors.line),
                for (int i = 0; i < stays.length; i++)
                  _StayRow(
                    stay: stays[i],
                    last: i == stays.length - 1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StayRow extends ConsumerWidget {
  final StayWithRooms stay;
  final bool last;
  const _StayRow({required this.stay, required this.last});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stay.stay;
    final rooms = stay.rooms;
    final labelRooms = rooms.map((r) => 'Ch.${r.roomNumber}').join(', ');
    final nights = rooms.fold<int>(0, (n, r) => n + r.nights);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: BsColors.line)),
      ),
      child: Row(children: [
        // Bloc gauche : date + numéro
        SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat("d MMM y", 'fr_FR').format(aLubumbashi(s.generatedAt)),
                  style: BsType.body(12, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(s.receiptNumber,
                  style: BsType.mono(10, color: BsColors.slate)),
            ],
          ),
        ),
        // Bloc central : client + chambres
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Flexible + ellipsis : sans ça, un nom long déborde la
                // Row et Flutter affiche ses rayures jaune et noir.
                Flexible(
                  child: Text(s.guestFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BsType.body(13, w: FontWeight.w700)),
                ),
                if (s.payerName != null && s.payerName!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: BsColors.sky.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(s.payerName!,
                        style: BsType.body(10,
                            w: FontWeight.w700, color: BsColors.sky)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                  '$labelRooms · $nights nuit(s)${s.stayGroup != null ? " · groupé" : ""}',
                  style: BsType.body(11, color: BsColors.slate)),
            ],
          ),
        ),
        // Bloc droit : total + bouton reprint
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(moneyCents(stay.totalCents),
                style: BsType.body(13, w: FontWeight.w800)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              style: OutlinedButton.styleFrom(
                foregroundColor: BsColors.sunrise,
                side: const BorderSide(color: BsColors.sunrise),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () => _reprint(),
              label: const Text('Régénérer'),
            ),
          ],
        ),
      ]),
    );
  }

  Future<void> _reprint() async {
    // Reconstruit un StayInvoiceData à partir de la ligne persistée
    // + les extras JSON.
    List<dynamic> extrasRaw = const [];
    try {
      extrasRaw = jsonDecode(stay.stay.extrasJson) as List<dynamic>;
    } catch (_) {}
    final data = StayInvoiceData(
      receiptNumber: stay.stay.receiptNumber,
      reservationNumber: stay.stay.reservationNumber,
      generatedAt: stay.stay.generatedAt,
      guestFullName: stay.stay.guestFullName,
      guestNationality: stay.stay.guestNationality,
      guestPhone: stay.stay.guestPhone,
      guestEmail: stay.stay.guestEmail,
      payerName: stay.stay.payerName,
      payerTaxId: stay.stay.payerTaxId,
      payerAddress: stay.stay.payerAddress,
      payerContact: stay.stay.payerContact,
      stayGroup: stay.stay.stayGroup,
      note: stay.stay.note,
      clientVisitsCount: stay.stay.clientVisitsAtCheckout,
      serverLogin: stay.stay.serverLogin,
      paymentMode: InvoicePayment.values[
          stay.stay.paymentMode.clamp(0, InvoicePayment.values.length - 1)],
      acompteFcCents: stay.stay.acompteFcCents,
      acompteUsdCents: stay.stay.acompteUsdCents,
      // Le taux FIGÉ du séjour, pas celui d'aujourd'hui. C'est toute la
      // raison d'avoir stocké cette colonne : rejouer la facture telle
      // qu'elle a été émise.
      fcPerUsdCents: stay.stay.fcPerUsdCents,
      remiseCents: stay.stay.remiseCents,
      remiseLabel: stay.discount.invoiceLabel,
      rooms: [
        for (final r in stay.rooms)
          StayInvoiceRoom(
            number: r.roomNumber,
            type: r.roomType,
            checkinAt: r.checkinAt,
            checkoutAt: r.checkoutAt,
            pricePerNightCents: r.pricePerNightCents,
            priceUsdCents: r.priceUsdCents,
            listPriceCents: r.listPriceCents,
            nights: r.nights,
          ),
      ],
      // Note : les extras sont rejoués depuis le JSON snapshot,
      // pas depuis les Sales originales (qui pourraient avoir été
      // supprimées / modifiées).
      extras: [
        for (final e in extrasRaw) _rehydrateExtra(e as Map<String, dynamic>),
      ],
    );
    await PdfService.previewStayInvoice(data);
  }

  /// Rehydrate un extra depuis le JSON snapshot : on reconstruit un
  /// SaleWithLines minimal qui suffit au rendu PDF.
  SaleWithLines _rehydrateExtra(Map<String, dynamic> j) {
    final soldAt =
        DateTime.tryParse(j['sold_at'] as String? ?? '') ?? DateTime.now();
    final sale = Sale(
      id: (j['sale_id'] as num?)?.toInt() ?? 0,
      soldAt: soldAt,
      serverUserId: null,
      payment: DbPayment.cash,
      location: DbLocation.hotel,
      // Vente reconstruite pour le rendu PDF uniquement : elle n'entre
      // jamais en base, donc rien à synchroniser.
      syncAttempts: 0,
      customerName: null,
      roomNumber: j['room_number'] as String?,
      onCredit: false,
      settledAt: null,
      note: null,
    );
    final lines = <SaleLine>[
      for (final l in (j['lines'] as List? ?? []))
        SaleLine(
          id: 0,
          saleId: 0,
          articleId: null,
          articleName: l['name'] as String? ?? '',
          qty: (l['qty'] as num?)?.toInt() ?? 1,
          unitPriceCents: (l['unit_price_cents'] as num?)?.toInt() ?? 0,
        )
    ];
    return SaleWithLines(sale, lines, null);
  }
}
