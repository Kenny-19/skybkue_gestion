import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/business_info.dart';
import '../core/cat_ui.dart';
import '../core/format.dart';
import '../data/database.dart';
import '../data/repos.dart';
import '../data/schema.dart';
import 'backup_service.dart';
import '../core/temps.dart';
import '../core/horloge.dart';
import '../core/devise.dart';

/// Représente une ligne dans un ticket 80 mm (facture ou aperçu).
class _ReceiptLine {
  final String name;
  final int qty;
  final int unitPriceCents;
  const _ReceiptLine(this.name, this.qty, this.unitPriceCents);
}

class CartPreviewLine {
  final String name;
  final int qty;
  final int unitPriceCents;
  const CartPreviewLine({
    required this.name,
    required this.qty,
    required this.unitPriceCents,
  });
}

/// Une chambre facturée dans une facture de séjour.
class StayInvoiceRoom {
  final String number;
  final String type;
  final DateTime checkinAt;
  final DateTime checkoutAt;

  /// Prix réellement facturé en FRANCS (tarif négocié s'il y en a un).
  final int pricePerNightCents;

  /// Le même prix en CENTS DE DOLLAR — la devise dans laquelle la
  /// chambre a été vendue, et donc celle qui s'affiche en premier.
  ///
  /// 0 pour un séjour antérieur à la bascule : on retombe alors sur le
  /// franc seul plutôt que d'afficher « $0.00 ».
  final int priceUsdCents;

  /// Tarif catalogue — sert à afficher l'écart. Null ou identique au
  /// prix facturé → pas de tarif négocié sur cette chambre.
  final int? listPriceCents;
  final int nights;
  const StayInvoiceRoom({
    required this.number,
    required this.type,
    required this.checkinAt,
    required this.checkoutAt,
    required this.pricePerNightCents,
    required this.nights,
    this.priceUsdCents = 0,
    this.listPriceCents,
  });

  /// True quand la chambre a un prix en dollars à montrer.
  bool get aUnPrixEnDollars => priceUsdCents > 0;
  int get accommodationCents => nights * pricePerNightCents;

  /// True si un tarif négocié inférieur au catalogue a été appliqué.
  bool get hasNegotiatedRate =>
      listPriceCents != null && listPriceCents! > pricePerNightCents;

  /// Économie consentie sur cette chambre (0 si tarif catalogue).
  int get negotiatedSavingCents =>
      hasNegotiatedRate ? (listPriceCents! - pricePerNightCents) * nights : 0;
}

/// Donnée d'une chambre réservée pour le PDF de confirmation.
class ReservationInvoiceRoom {
  final String number;
  final String type;

  /// Tarif de la nuit en FRANCS — la monnaie d'encaissement.
  final int pricePerNightCents;

  /// Le même tarif en CENTS DE DOLLAR, la devise dans laquelle la
  /// chambre est cotée au client. 0 pour une réservation antérieure à
  /// la bascule : on retombe alors sur le franc seul, plutôt que
  /// d'afficher un « $0.00 » qui ferait douter du document.
  final int priceUsdCents;

  const ReservationInvoiceRoom({
    required this.number,
    required this.type,
    required this.pricePerNightCents,
    this.priceUsdCents = 0,
  });

  bool get aUnPrixEnDollars => priceUsdCents > 0;
}

/// Données pour le PDF "CONFIRMATION DE RÉSERVATION" — édité au moment
/// de la création d'une réservation et re-téléchargeable depuis la liste.
class ReservationInvoiceData {
  final String reservationNumber;
  final DateTime generatedAt;
  final DateTime checkinDate;
  final DateTime checkoutDate;
  final String guestFullName;
  final String? guestPhone;
  final String? guestEmail;
  final String? guestNationality;
  final String? payerName;
  final String? payerTaxId;
  final String? payerAddress;
  final String? payerContact;
  final List<ReservationInvoiceRoom> rooms;
  final int depositCents;
  final String? note;
  final String? serverLogin;

  const ReservationInvoiceData({
    required this.reservationNumber,
    required this.generatedAt,
    required this.checkinDate,
    required this.checkoutDate,
    required this.guestFullName,
    required this.rooms,
    this.guestPhone,
    this.guestEmail,
    this.guestNationality,
    this.payerName,
    this.payerTaxId,
    this.payerAddress,
    this.payerContact,
    this.depositCents = 0,
    this.note,
    this.serverLogin,
  });

  bool get hasPayer => payerName != null && payerName!.isNotEmpty;
  int get nights {
    final d = checkoutDate.difference(checkinDate).inDays;
    return d < 1 ? 1 : d;
  }

  int get accommodationTotalCents =>
      rooms.fold(0, (s, r) => s + r.pricePerNightCents) * nights;
  int get remainingCents =>
      (accommodationTotalCents - depositCents).clamp(0, 1 << 40);
}

/// Mode de paiement pour la facture.
enum InvoicePayment { cash, card, mobileMoney, credit }

extension InvoicePaymentLabel on InvoicePayment {
  String get label => switch (this) {
        InvoicePayment.cash => 'Espèce',
        InvoicePayment.card => 'Carte',
        InvoicePayment.mobileMoney => 'Mobile Money',
        InvoicePayment.credit => 'À crédit',
      };
}

/// Données d'une facture de séjour au check-out, calquée sur le reçu
/// papier "SKY BLUE GUEST HOUSE".
class StayInvoiceData {
  // Identité de la facture
  final String receiptNumber; // N° Reçu (FCT…)
  final String? reservationNumber; // N° Reservation (RSV…)
  final DateTime generatedAt;
  final String? serverLogin; // User: LIONEL

  // Client — la ligne "Nom Société" est renseignée UNIQUEMENT si un
  // payeur société prend en charge.
  final String guestFullName;
  final String? guestNationality;
  final String? guestPhone;
  final String? guestEmail;

  // Payeur tiers (société / particulier tiers). Null → l'occupant paie.
  final String? payerName;
  final String? payerTaxId;
  final String? payerAddress;
  final String? payerContact;

  // Contenu
  final String? stayGroup;
  final String? note;
  final List<StayInvoiceRoom> rooms;
  final List<SaleWithLines> extras;

  // Fidélité de l'occupant (pour afficher un chip "CLIENT FIDÈLE · N").
  final int clientVisitsCount;

  // Paiement
  final InvoicePayment paymentMode;
  final int acompteFcCents;
  final int
      acompteUsdCents; // stocké en cents FC (équivalent) OU en cents USD ?
  /// Taux FC pour 1 USD au moment du check-out, × 100.
  ///
  /// Figé, et c'est tout l'enjeu : une facture réimprimée six mois plus
  /// tard doit annoncer le montant que le client a réellement payé, pas
  /// ce qu'il vaudrait au taux du jour. 0 → séjour antérieur à la
  /// bascule, on retombe sur le taux courant faute de mieux.
  final int fcPerUsdCents;

  final int remiseCents; // remise appliquée sur le total FC

  /// Explication de la remise — « 10 % sur l'hébergement · Client fidèle ».
  /// Null → la ligne "Remise" reste affichée sans justification.
  final String? remiseLabel;

  const StayInvoiceData({
    required this.receiptNumber,
    required this.generatedAt,
    required this.guestFullName,
    required this.rooms,
    required this.extras,
    this.reservationNumber,
    this.serverLogin,
    this.guestNationality,
    this.guestPhone,
    this.guestEmail,
    this.payerName,
    this.payerTaxId,
    this.payerAddress,
    this.payerContact,
    this.stayGroup,
    this.note,
    this.clientVisitsCount = 0,
    this.paymentMode = InvoicePayment.cash,
    this.acompteFcCents = 0,
    this.acompteUsdCents = 0,
    this.fcPerUsdCents = 0,
    this.remiseCents = 0,
    this.remiseLabel,
  });

  int get accommodationTotal =>
      rooms.fold(0, (s, r) => s + r.accommodationCents);
  int get extrasTotal => extras.fold(0, (s, e) => s + e.totalCents);
  int get subtotalCents => accommodationTotal + extrasTotal;
  int get nightsTotal => rooms.fold(0, (s, r) => s + r.nights);

  /// Total des tarifs négociés au check-in — déjà déduit du sous-total,
  /// mais affiché pour que le client voie l'effort consenti.
  int get negotiatedSavingCents =>
      rooms.fold(0, (s, r) => s + r.negotiatedSavingCents);
  bool get hasNegotiatedRates => negotiatedSavingCents > 0;

  /// Sous-total au tarif catalogue (avant tarifs négociés).
  int get listSubtotalCents => subtotalCents + negotiatedSavingCents;
  bool get hasPayer => payerName != null && payerName!.isNotEmpty;
  bool get isLoyal => clientVisitsCount >= 2;

  /// Total FC après remise.
  int get totalCents => (subtotalCents - remiseCents).clamp(0, 1 << 40);

  /// Le taux à appliquer pour convertir cette facture-là.
  double get taux => tauxDepuisCents(fcPerUsdCents);

  /// Un montant en francs, rendu en dollars au taux FIGÉ du séjour.
  String enDollars(int fc) => moneyUsdCourt(fcVersUsd(fc, taux: taux));

  /// Acompte USD converti en cents FC pour l'agrégation.
  int get acompteUsdInFcCents =>
      (acompteUsdCents * Currency.rate / 100).round();

  /// Total réellement encaissé (Acompte FC + acompte USD converti).
  int get totalPaidCents => acompteFcCents + acompteUsdInFcCents;

  /// Reste à payer par le client / société.
  int get remainingCents => (totalCents - totalPaidCents).clamp(0, 1 << 40);
}

class PdfService {
  // Montants en Franc Congolais (via le taux courant).
  static String _money(int cents) => moneyCents(cents);

  /// Horodatage compact pour le nom des fichiers générés : YYYYMMDDHHmm.
  static String _stamp() => DateFormat('yyyyMMddHHmm').format(aLubumbashi(Horloge.maintenant()));

  // Thème PDF — Inter (même famille que l'UI) pour un rendu cohérent
  // entre l'écran et le papier. Chargé une seule fois.
  static pw.ThemeData? _cachedTheme;
  static Future<pw.ThemeData> _theme() async {
    if (_cachedTheme != null) return _cachedTheme!;
    final base = await PdfGoogleFonts.interRegular();
    final bold = await PdfGoogleFonts.interSemiBold();
    final italic = await PdfGoogleFonts.interRegular(); // Inter n'a pas
    final boldItalic = await PdfGoogleFonts.interBold(); // d'italique
    _cachedTheme = pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
    return _cachedTheme!;
  }

  // Cache du logo Skyblue chargé une seule fois pour les watermarks PDF.
  static pw.MemoryImage? _cachedLogo;
  static bool _logoLoaded = false;
  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_logoLoaded) return _cachedLogo;
    _logoLoaded = true;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      _cachedLogo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      _cachedLogo = null; // fallback texte
    }
    return _cachedLogo;
  }

  /// Filigrane commun à toutes les pages PDF (facture, rapports…).
  /// Centre : logo Skyblue à faible opacité, ou fallback texte doux si
  /// le fichier logo n'est pas présent.
  static pw.Widget _watermark(pw.MemoryImage? logo) {
    if (logo != null) {
      return pw.Center(
        child: pw.Opacity(
          opacity: 0.06,
          child:
              pw.Image(logo, width: 380, height: 380, fit: pw.BoxFit.contain),
        ),
      );
    }
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.05,
        child: pw.Text('SKYBLUE',
            style: pw.TextStyle(
                fontSize: 120,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0E3A47),
                letterSpacing: 8)),
      ),
    );
  }

  /// PageTheme partagé : Noto Sans + filigrane logo.
  static Future<pw.PageTheme> _pageTheme({bool landscape = false}) async {
    final theme = await _theme();
    final logo = await _loadLogo();
    return pw.PageTheme(
      pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: theme,
      buildBackground: (_) => pw.FullPage(
        ignoreMargins: true,
        child: _watermark(logo),
      ),
    );
  }

  /// PageTheme ticket — page 80 mm (largeur physique du rouleau)
  /// avec **contenu centré** dans ~58 mm au milieu.
  ///
  /// Pourquoi 80 mm et pas 58 mm : le driver de l'imprimante thermique
  /// s'aligne à gauche du rouleau ; en générant un PDF de 58 mm, le
  /// ticket ressortait collé à gauche du papier. Avec une page 80 mm et
  /// des marges gauche/droite de 11 mm, le contenu fait 58 mm centré →
  /// ticket visuellement au milieu du rouleau, pas de coupe à droite.
  /// Hauteur laissée grande (300 mm) : le driver rouleau coupe au bon
  /// endroit selon le contenu réel.
  static Future<pw.PageTheme> _receiptPageTheme() async {
    final theme = await _theme();
    final logo = await _loadLogo();
    return pw.PageTheme(
      pageFormat: const PdfPageFormat(
        80 * PdfPageFormat.mm,
        300 * PdfPageFormat.mm,
        marginLeft: 11 * PdfPageFormat.mm,
        marginRight: 11 * PdfPageFormat.mm,
        marginTop: 3 * PdfPageFormat.mm,
        marginBottom: 3 * PdfPageFormat.mm,
      ),
      theme: theme,
      buildBackground: (_) => pw.FullPage(
        ignoreMargins: true,
        child: _receiptWatermark(logo),
      ),
    );
  }

  /// Filigrane ticket : logo centré en haut à faible opacité.
  static pw.Widget _receiptWatermark(pw.MemoryImage? logo) {
    if (logo == null) {
      return pw.Align(
        alignment: pw.Alignment.topCenter,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(top: 30),
          child: pw.Opacity(
            opacity: 0.06,
            child: pw.Text(BusinessInfo.name,
                style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 3,
                    color: const PdfColor.fromInt(0xFF0E3A47))),
          ),
        ),
      );
    }
    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Opacity(
        opacity: 0.08,
        child: pw.Image(logo, width: 130, height: 130, fit: pw.BoxFit.contain),
      ),
    );
  }

  // ─── Facture ─────────────────────────────────────────────────────────

  static Future<void> previewInvoice(SaleWithLines s) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildInvoice(s),
      name: 'facture_${s.sale.id.toString().padLeft(4, '0')}_${_stamp()}.pdf',
    );
  }

  static Future<Uint8List> _buildInvoice(SaleWithLines s) async {
    final doc = pw.Document(title: 'Facture ${s.sale.id}');
    doc.addPage(pw.Page(
      pageTheme: await _receiptPageTheme(),
      build: (_) => _receiptContent(
        title: 'FACTURE',
        idLabel: '#${s.sale.id.toString().padLeft(4, '0')}',
        soldAt: s.sale.soldAt,
        customerName: s.sale.customerName,
        serverName: s.server?.fullName,
        locationLabel: s.sale.location.label,
        paymentLabel: s.sale.payment.label,
        roomNumber: s.sale.roomNumber,
        onCredit: s.sale.onCredit,
        settledAt: s.sale.settledAt,
        lines: [
          for (final l in s.lines)
            _ReceiptLine(l.articleName, l.qty, l.unitPriceCents),
        ],
        totalCents: s.totalCents,
        note: s.sale.note,
        showFooter: true,
      ),
    ));
    return doc.save();
  }

  // ─── Ticket 58 mm — helper commun facture + aperçu panier ────────────

  /// Contenu d'un ticket 58 mm. Mise en page inspirée directement du ticket
  /// papier de référence utilisé par l'établissement.
  ///
  /// Structure (de haut en bas) :
  ///   - Logo établissement (petit, centré)
  ///   - Nom, téléphone, email, site (centrés)
  ///   - Ligne "Servi par X à table Table {loc}{room}" + "Invités : N"
  ///   - Lignes articles : nom sur une ligne, puis "  N unit × prix   total"
  ///   - Bloc SOMME / mode paiement / RENDU
  ///   - Exonéré TVA + total taxes (0)
  ///   - Numéro de commande + date/heure de l'opération
  ///   - Note client (si présente)
  static pw.Widget _receiptContent({
    required String title,
    required String idLabel,
    required DateTime soldAt,
    required List<_ReceiptLine> lines,
    required int totalCents,
    String? customerName,
    String? serverName,
    String? locationLabel,
    String? paymentLabel,
    String? roomNumber,
    String? note,
    String? previewNotice,
    bool onCredit = false,
    DateTime? settledAt,
    bool showFooter = false,
    int guestCount = 1,
  }) {
    // Construit le libellé "Table R4" façon référence : lettre = initiale
    // du lieu (R restaurant, T terrasse, H hôtel), suffixe = numéro salle
    // s'il y en a un.
    String tableLabel = '';
    if (locationLabel != null) {
      final letter =
          locationLabel.isNotEmpty ? locationLabel[0].toUpperCase() : '';
      tableLabel = 'Table $letter${roomNumber ?? ''}'.trim();
    }
    final serveLine = serverName == null
        ? (tableLabel.isEmpty ? null : 'À $tableLabel')
        : (tableLabel.isEmpty
            ? 'Servi par $serverName'
            : 'Servi par $serverName à $tableLabel');
    final commande =
        '${(soldAt.year % 100).toString().padLeft(2, '0')}${soldAt.month.toString().padLeft(2, '0')}${soldAt.day.toString().padLeft(2, '0')}'
        '-${soldAt.hour.toString().padLeft(2, '0')}${soldAt.minute.toString().padLeft(2, '0')}'
        '-$idLabel';

    // Logo net à intégrer en tête (identique à celui du filigrane).
    final headerLogo = _cachedLogo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Logo établissement (identité visuelle unique en tête) ──
        if (headerLogo != null) ...[
          pw.Center(
            child: pw.Image(headerLogo,
                width: 90, height: 90, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 2),
        ] else ...[
          // Fallback texte si le logo n'a pas pu être chargé.
          pw.Center(
            child: pw.Text(BusinessInfo.name,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1)),
          ),
        ],
        pw.Center(
          child: pw.Text(BusinessInfo.tagline,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('Tél. : ${BusinessInfo.phone}',
              style: const pw.TextStyle(fontSize: 7)),
        ),
        if (BusinessInfo.email.isNotEmpty)
          pw.Center(
            child: pw.Text(BusinessInfo.email,
                style: const pw.TextStyle(fontSize: 7)),
          ),
        if (BusinessInfo.website.isNotEmpty)
          pw.Center(
            child: pw.Text(BusinessInfo.website,
                style: const pw.TextStyle(fontSize: 7)),
          ),
        pw.SizedBox(height: 4),
        _receiptRule(),
        // ── "Servi par ..." + invités ──
        pw.SizedBox(height: 4),
        if (serveLine != null)
          pw.Center(
            child: pw.Text(serveLine, style: const pw.TextStyle(fontSize: 7.5)),
          ),
        pw.Center(
          child: pw.Text('Invités : $guestCount',
              style: const pw.TextStyle(fontSize: 7.5)),
        ),
        if (customerName != null)
          pw.Center(
            child: pw.Text('Client : $customerName',
                style: pw.TextStyle(
                    fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ),
        pw.SizedBox(height: 4),
        _receiptRule(),
        // ── Lignes articles ──
        pw.SizedBox(height: 4),
        for (final l in lines) ...[
          pw.Text(l.name,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Row(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6),
              child: pw.Text('${l.qty} × ${_money(l.unitPriceCents)}',
                  style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Spacer(),
            pw.Text(_money(l.unitPriceCents * l.qty),
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 1),
        ],
        pw.SizedBox(height: 2),
        _receiptRule(),
        // ── Totaux façon référence : SOMME / Espèces / RENDU ──
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(
            child: pw.Text('TOTAL',
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ]),
        pw.Row(children: [
          pw.Expanded(
            child: pw.Text(_money(totalCents),
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ),
        ]),
        pw.SizedBox(height: 4),
        // Mode paiement (Espèces / Carte / …) ou À CRÉDIT.
        if (onCredit)
          pw.Row(children: [
            pw.Text('À CRÉDIT',
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Spacer(),
            pw.Text(_money(totalCents), style: const pw.TextStyle(fontSize: 8)),
          ])
        else if (paymentLabel != null)
          pw.Row(children: [
            pw.Text(paymentLabel, style: const pw.TextStyle(fontSize: 8)),
            pw.Spacer(),
            pw.Text(_money(totalCents), style: const pw.TextStyle(fontSize: 8)),
          ]),
        pw.Row(children: [
          pw.Text('RENDU', style: const pw.TextStyle(fontSize: 8)),
          pw.Spacer(),
          pw.Text(_money(0), style: const pw.TextStyle(fontSize: 8)),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Text('Exonéré de TVA (vente)',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Spacer(),
          pw.Text(_money(0),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ]),
        pw.Row(children: [
          pw.Text('Total des taxes',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Spacer(),
          pw.Text(_money(0),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Spacer(),
          pw.Text('soit ${moneyUsdFromFc(totalCents)}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 6),
        // ── Numéro de commande + horodatage ──
        pw.Center(
          child: pw.Text('Commande $commande',
              style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Center(
          child: pw.Text(
              DateFormat("dd/MM/yyyy HH:mm:ss", 'fr_FR').format(aLubumbashi(soldAt)),
              style: const pw.TextStyle(fontSize: 7)),
        ),
        // ── Note client (optionnelle) ──
        if (note != null) ...[
          pw.SizedBox(height: 6),
          _receiptRule(),
          pw.SizedBox(height: 4),
          pw.Text('Note :',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text(note,
              style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic)),
        ],
        // ── Bandeau "aperçu" (pas-encaissé) ──
        if (previewNotice != null) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.orange300),
            ),
            child: pw.Text(previewNotice,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange900)),
          ),
        ],
        // ── Pied ──
        pw.SizedBox(height: 8),
        _receiptRule(),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text('Merci pour votre visite !',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ),
        if (showFooter && BusinessInfo.footerNotes.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          for (final note in BusinessInfo.footerNotes)
            pw.Center(
              child: pw.Text(note,
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey600)),
            ),
        ],
      ],
    );
  }

  /// Filet horizontal pointillé — sépare les sections du ticket.
  static pw.Widget _receiptRule() => pw.Container(
        height: 1,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColors.grey500,
                  width: 0.5,
                  style: pw.BorderStyle.dashed)),
        ),
      );

  // ─── Aperçu ticket brouillon (avant encaissement) ────────────────────

  static Future<void> previewCartPreview({
    required List<CartPreviewLine> lines,
    required DbPayment payment,
    String? serverName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildCartPreview(lines, payment, serverName),
      name: 'apercu_ticket_${_stamp()}.pdf',
    );
  }

  static Future<Uint8List> _buildCartPreview(List<CartPreviewLine> lines,
      DbPayment payment, String? serverName) async {
    final total = lines.fold<int>(0, (s, l) => s + l.unitPriceCents * l.qty);
    final doc = pw.Document(title: 'Aperçu ticket');
    doc.addPage(pw.Page(
      pageTheme: await _receiptPageTheme(),
      build: (_) => _receiptContent(
        title: 'APERÇU',
        idLabel: '—',
        soldAt: DateTime.now(),
        serverName: serverName,
        paymentLabel: payment.label,
        lines: [
          for (final l in lines) _ReceiptLine(l.name, l.qty, l.unitPriceCents),
        ],
        totalCents: total,
        previewNotice: 'APERÇU — vente non enregistrée tant que « Encaisser » '
            "n'est pas cliqué.",
      ),
    ));
    return doc.save();
  }

  // ─── Rapport synthétique ─────────────────────────────────────────────

  static Future<void> previewSummaryReport(List<SaleWithLines> sales,
      {String period = '7 derniers jours'}) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildSummary(sales, period),
      name: 'rapport_synthetique_${_stamp()}.pdf',
    );
  }

  /// Renvoie les bytes bruts du rapport synthétique (pour upload cloud).
  static Future<Uint8List> buildSummaryReportBytes(List<SaleWithLines> sales,
          {String period = '7 derniers jours'}) =>
      _buildSummary(sales, period);

  static Future<Uint8List> _buildSummary(
      List<SaleWithLines> sales, String period) async {
    final doc = pw.Document(title: 'Rapport synthétique');
    final pt = await _pageTheme();
    final byDay = _groupByDay(sales);
    final total = sales.fold<int>(0, (s, e) => s + e.totalCents);
    // Une vente à crédit non réglée est un chiffre d'affaires réalisé,
    // mais pas un franc encaissé. Le rapport doit dire les deux, sinon
    // la caisse ne tombe jamais juste.
    final impayes =
        sales.where((s) => s.sale.onCredit && s.sale.settledAt == null);
    final impaye = impayes.fold<int>(0, (a, b) => a + b.totalCents);
    final impayeCount = impayes.length;
    final encaisse = total - impaye;

    // Vraie catégorie de chaque article (lookup BDD, plus d'heuristique).
    final articles =
        await AppDatabase.instance.select(AppDatabase.instance.articles).get();
    final catByArticleId = {for (final a in articles) a.id: a.category};

    int boissons = 0, nourriture = 0, chambres = 0;
    for (final s in sales) {
      for (final l in s.lines) {
        final t = l.unitPriceCents * l.qty;
        switch (catByArticleId[l.articleId]) {
          case DbCategory.boissons:
            boissons += t;
            break;
          case DbCategory.nourriture:
            nourriture += t;
            break;
          case DbCategory.chambres:
            chambres += t;
            break;
          case null:
            nourriture += t; // article supprimé : rattaché à Nourriture
        }
      }
    }

    doc.addPage(pw.Page(
      pageTheme: pt,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader('Rapport synthétique'),
          pw.SizedBox(height: 8),
          pw.Text(
              'Période — $period · généré le ${DateFormat("d MMMM y à HH:mm", 'fr_FR').format(aLubumbashi(Horloge.maintenant()))}',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          _kpiRow([
            [
              "CHIFFRE D'AFFAIRES",
              '${_money(total)}\n${moneyUsdFromFc(total)}'
            ],
            // Distinction essentielle : le chiffre d'affaires compte ce
            // qui a été VENDU, l'encaissé ce qui est réellement rentré.
            // Les confondre faisait croire que l'argent des dettes était
            // déjà en caisse.
            [
              'ENCAISSÉ',
              '${_money(encaisse)}\n'
                  '${impaye == 0 ? "tout est réglé" : "hors dettes en cours"}'
            ],
            [
              'À RECOUVRER',
              '${_money(impaye)}\n'
                  '${impayeCount == 0 ? "aucune dette" : "$impayeCount ticket(s)"}'
            ],
            [
              'TRANSACTIONS',
              '${sales.length}\npanier ${_money(sales.isEmpty ? 0 : (total ~/ sales.length))}'
            ],
          ]),
          pw.SizedBox(height: 20),
          _eyebrow('RÉPARTITION PAR CATÉGORIE'),
          pw.SizedBox(height: 8),
          _catTable(boissons, nourriture, chambres, total),
          pw.SizedBox(height: 24),
          _eyebrow('DÉTAIL PAR JOUR'),
          pw.SizedBox(height: 8),
          _dayTable(byDay),
          pw.SizedBox(height: 20),
          _debtsSection(sales),
          pw.Spacer(),
          _footer(),
        ],
      ),
    ));
    return doc.save();
  }

  /// Section dettes du rapport du soir : réglées vs en cours sur la période.
  static pw.Widget _debtsSection(List<SaleWithLines> sales) {
    final credit = sales.where((s) => s.sale.onCredit).toList();
    final settled = credit.where((s) => s.sale.settledAt != null).toList();
    final pending = credit.where((s) => s.sale.settledAt == null).toList();
    if (credit.isEmpty) return pw.SizedBox();
    final settledTotal = settled.fold<int>(0, (a, b) => a + b.totalCents);
    final pendingTotal = pending.fold<int>(0, (a, b) => a + b.totalCents);

    String who(SaleWithLines s) => [
          if (s.sale.roomNumber != null) 'Ch.${s.sale.roomNumber}',
          s.sale.customerName ?? 'Client',
        ].join(' · ');

    return pw
        .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _eyebrow('DETTES'),
      pw.SizedBox(height: 6),
      pw.Text(
          '${settled.length} réglée(s) (${_money(settledTotal)}) · '
          '${pending.length} en cours (${_money(pendingTotal)})',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      if (settled.isNotEmpty)
        pw.Text('Réglées : ${settled.map(who).join(', ')}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      if (pending.isNotEmpty)
        pw.Text('En cours : ${pending.map(who).join(', ')}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ]);
  }

  // ─── Rapport détaillé ────────────────────────────────────────────────

  static Future<void> previewDetailedReport(List<SaleWithLines> sales,
      {String period = '7 derniers jours'}) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildDetailed(sales, period),
      name: 'rapport_detaille_${_stamp()}.pdf',
    );
  }

  /// Renvoie les bytes bruts du rapport détaillé (pour upload cloud).
  static Future<Uint8List> buildDetailedReportBytes(List<SaleWithLines> sales,
          {String period = '7 derniers jours'}) =>
      _buildDetailed(sales, period);

  static Future<Uint8List> _buildDetailed(
      List<SaleWithLines> sales, String period) async {
    final doc = pw.Document(title: 'Rapport détaillé');
    final total = sales.fold<int>(0, (s, e) => s + e.totalCents);

    doc.addPage(pw.Page(
      pageTheme: await _pageTheme(landscape: true),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader('Rapport détaillé'),
          pw.SizedBox(height: 6),
          pw.Text(
              '$period · ${sales.length} transactions · Total ${_money(total)} (${moneyUsdFromFc(total)}) · Généré le ${DateFormat("d MMMM y à HH:mm", 'fr_FR').format(aLubumbashi(Horloge.maintenant()))}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Expanded(child: _detailedTable(sales)),
          pw.SizedBox(height: 8),
          _footer(),
        ],
      ),
    ));

    // Page dédiée : occupation actuelle des chambres avec notes de
    // check-in. Ajoutée seulement s'il y a au moins une chambre occupée.
    final rooms =
        await AppDatabase.instance.select(AppDatabase.instance.rooms).get();
    final occupied = rooms
        .where((r) => r.status == DbRoomStatus.occupee)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    if (occupied.isNotEmpty) {
      doc.addPage(pw.Page(
        pageTheme: await _pageTheme(landscape: true),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _brandHeader('Occupation des chambres'),
            pw.SizedBox(height: 6),
            pw.Text(
                '${occupied.length} chambre(s) actuellement occupée(s) sur ${rooms.length} · Généré le ${DateFormat("d MMMM y à HH:mm", 'fr_FR').format(aLubumbashi(Horloge.maintenant()))}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
            pw.Expanded(child: _roomsTable(occupied)),
            pw.SizedBox(height: 8),
            _footer(),
          ],
        ),
      ));
    }

    return doc.save();
  }

  /// Tableau "Occupation des chambres" pour le rapport détaillé.
  /// Inclut la note saisie au check-in (si présente).
  static pw.Widget _roomsTable(List<Room> occupied) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.9), // Chambre
        1: const pw.FlexColumnWidth(1.0), // Type
        2: const pw.FlexColumnWidth(2.0), // Client
        3: const pw.FlexColumnWidth(1.4), // Arrivée
        4: const pw.FlexColumnWidth(1.4), // Départ prévu
        5: const pw.FlexColumnWidth(4.0), // Note check-in
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _th('Chambre'),
            _th('Type'),
            _th('Client'),
            _th('Arrivée'),
            _th('Départ prévu'),
            _th('Note'),
          ],
        ),
        for (final r in occupied)
          pw.TableRow(children: [
            _td(r.number),
            _td(r.type),
            _td(r.currentGuest ?? '—'),
            _td(r.checkinAt == null
                ? '—'
                : DateFormat('d MMM · HH:mm', 'fr_FR').format(aLubumbashi(r.checkinAt!))),
            _td(r.checkoutDate == null
                ? '—'
                : DateFormat('d MMM', 'fr_FR').format(aLubumbashi(r.checkoutDate!))),
            _td(r.checkinNote ?? ''),
          ]),
      ],
    );
  }

  static pw.Widget _detailedTable(List<SaleWithLines> sales) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1), // Date · Heure
        1: const pw.FlexColumnWidth(0.9), // #
        2: const pw.FlexColumnWidth(1.4), // Client
        3: const pw.FlexColumnWidth(1.2), // Serveur
        4: const pw.FlexColumnWidth(1.1), // Emplacement
        5: const pw.FlexColumnWidth(1.1), // Paiement
        6: const pw.FlexColumnWidth(4.5), // Articles
        7: const pw.FlexColumnWidth(0.6), // Qté
        8: const pw.FlexColumnWidth(1.1), // Total
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _th('Date · Heure'),
            _th('N°'),
            _th('Client'),
            _th('Serveur'),
            _th('Emplacement'),
            _th('Paiement'),
            _th('Articles'),
            _th('Qté', align: pw.TextAlign.right),
            _th('Total', align: pw.TextAlign.right),
          ],
        ),
        for (final s in sales)
          pw.TableRow(children: [
            _tdSmall(
                '${DateFormat("dd/MM", 'fr_FR').format(aLubumbashi(s.sale.soldAt))}  ${DateFormat("HH:mm", 'fr_FR').format(aLubumbashi(s.sale.soldAt))}'),
            _tdSmall('#${s.sale.id.toString().padLeft(4, '0')}', bold: true),
            _tdSmall(s.sale.customerName ?? '—'),
            _tdSmall(s.server?.fullName ?? '—'),
            _tdSmall(s.sale.location.label),
            _tdSmall(s.sale.payment.label),
            _tdSmall(
                s.lines.map((l) => '${l.qty}× ${l.articleName}').join(' · ')),
            _tdSmall('${s.itemsCount}', align: pw.TextAlign.right),
            _tdSmall(_money(s.totalCents),
                align: pw.TextAlign.right, bold: true),
          ]),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
          children: [
            _tdSmall('TOTAL', bold: true),
            _tdSmall(''),
            _tdSmall(''),
            _tdSmall(''),
            _tdSmall(''),
            _tdSmall(''),
            _tdSmall(''),
            _tdSmall('${sales.fold<int>(0, (s, e) => s + e.itemsCount)}',
                align: pw.TextAlign.right, bold: true),
            _tdSmall(_money(sales.fold<int>(0, (s, e) => s + e.totalCents)),
                align: pw.TextAlign.right, bold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tdSmall(String v,
          {pw.TextAlign? align, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(v,
            textAlign: align,
            maxLines: 3,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  // ─── Excel (placeholder) ─────────────────────────────────────────────

  static Future<String?> exportExcel(List<SaleWithLines> sales) {
    return BackupService.exportSalesExcel(sales);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  static Map<DateTime, List<SaleWithLines>> _groupByDay(
      List<SaleWithLines> sales) {
    final map = <DateTime, List<SaleWithLines>>{};
    for (final s in sales) {
      final d =
          debutDeJourneeLubumbashi(s.sale.soldAt);
      map.putIfAbsent(d, () => []).add(s);
    }
    final sorted = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (final k in sorted)
        k: map[k]!..sort((a, b) => b.sale.soldAt.compareTo(a.sale.soldAt))
    };
  }

  static pw.Widget _brandHeader(String subtitle) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF4A261), shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 8),
          pw.Text('SKYBLUE',
              style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0E3A47))),
        ]),
        pw.Text('Guest House · by Afrinvest',
            style: pw.TextStyle(
                fontSize: 9,
                letterSpacing: 1.4,
                color: PdfColors.grey600,
                fontWeight: pw.FontWeight.bold)),
      ]),
      pw.Spacer(),
      pw.Text(subtitle.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700)),
    ]);
  }

  static pw.Widget _kpiRow(List<List<String>> kpis) {
    return pw.Row(children: [
      for (int i = 0; i < kpis.length; i++) ...[
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(kpis[i][0],
                    style: pw.TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: PdfColors.grey600,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(kpis[i][1],
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),
        if (i < kpis.length - 1) pw.SizedBox(width: 10),
      ],
    ]);
  }

  static pw.Widget _catTable(int b, int n, int c, int total) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _th('Catégorie'),
            _th('Montant', align: pw.TextAlign.right),
            _th('Part', align: pw.TextAlign.right),
          ],
        ),
        for (final row in [
          ['Boissons', b],
          ['Nourriture', n],
          ['Chambres', c],
        ])
          pw.TableRow(children: [
            _td(row[0] as String),
            _td(_money(row[1] as int), align: pw.TextAlign.right),
            _td(
                total == 0
                    ? '—'
                    : '${((row[1] as int) / total * 100).toStringAsFixed(1)} %',
                align: pw.TextAlign.right),
          ]),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
          children: [
            _td('TOTAL', bold: true),
            _td(_money(total), align: pw.TextAlign.right, bold: true),
            _td('100 %', align: pw.TextAlign.right, bold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _dayTable(Map<DateTime, List<SaleWithLines>> byDay) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _th('Date'),
            _th('Ventes', align: pw.TextAlign.right),
            _th('Total', align: pw.TextAlign.right),
          ],
        ),
        for (final e in byDay.entries)
          pw.TableRow(children: [
            _td(DateFormat("EEEE d MMMM y", 'fr_FR').format(aLubumbashi(e.key))),
            _td('${e.value.length}', align: pw.TextAlign.right),
            _td(_money(e.value.fold<int>(0, (s, x) => s + x.totalCents)),
                align: pw.TextAlign.right, bold: true),
          ]),
      ],
    );
  }

  static pw.Widget _th(String label, {pw.TextAlign? align}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(label.toUpperCase(),
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 8,
                letterSpacing: 1.2,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700)),
      );

  static pw.Widget _td(String v, {pw.TextAlign? align, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(v,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _eyebrow(String s) => pw.Text(s,
      style: pw.TextStyle(
          fontSize: 8,
          letterSpacing: 1.4,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey600));

  static pw.Widget _footer() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
          pw.Text(
              'Merci pour votre visite — Skyblue Guest House · by Afrinvest',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic)),
        ],
      );

  // ─── Facture de séjour (A4, solo ou groupée) ──────────────────────

  // ─── Confirmation de réservation ──────────────────────────────────

  /// Aperçu + impression d'une confirmation de réservation.
  static Future<void> previewReservationConfirmation(
      ReservationInvoiceData data) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildReservationConfirmation(data),
      name: 'reservation_${data.reservationNumber}_${_stamp()}.pdf',
    );
  }

  static Future<Uint8List> _buildReservationConfirmation(
      ReservationInvoiceData d) async {
    final doc = pw.Document(title: 'Réservation ${d.reservationNumber}');
    final pt = await _pageTheme();
    final logo = await _loadLogo();
    final dfmt = DateFormat("dd/MM/yyyy", 'fr_FR');
    final dfmtLong = DateFormat("d MMMM y", 'fr_FR');
    final parts = d.guestFullName.trim().split(RegExp(r'\s+'));
    final prenom = parts.first;
    final nom = parts.length > 1 ? parts.sublist(1).join(' ') : prenom;

    doc.addPage(pw.MultiPage(
      pageTheme: pt,
      build: (_) => [
        _receiptHeader(logo),
        pw.SizedBox(height: 10),
        // Titre spécifique
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF4A261),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('CONFIRMATION DE RÉSERVATION',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                    color: PdfColors.white)),
          ),
        ),
        pw.SizedBox(height: 12),
        // Bloc client / références (reprend le style du reçu)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _labelValue('Nom Client', nom),
                  _labelValue('Prénom Client', prenom),
                  _labelValue('Nom Société', d.hasPayer ? d.payerName! : ''),
                  _labelValue('Nationalité', d.guestNationality ?? ''),
                  _labelValue('N° Téléphone', d.guestPhone ?? ''),
                  _labelValue('Email', d.guestEmail ?? ''),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.SizedBox(
              width: 230,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _refRow('Émise le :', dfmt.format(aLubumbashi(d.generatedAt))),
                  _refRow('N° Réservation :', d.reservationNumber),
                  pw.SizedBox(height: 8),
                  _dashedBox('Arrivée', dfmtLong.format(aLubumbashi(d.checkinDate))),
                  pw.SizedBox(height: 4),
                  _dashedBox('Départ', dfmtLong.format(aLubumbashi(d.checkoutDate))),
                  pw.SizedBox(height: 4),
                  _dashedBox('Nuits', '${d.nights}'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        // Tableau des chambres réservées
        pw.Text('Chambres réservées',
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0E3A47))),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _thCell('Code'),
                _thCell('Description'),
                _thCell('Nuits', align: pw.TextAlign.center),
                _thCell('P.U.', align: pw.TextAlign.right),
                _thCell('Sous-total', align: pw.TextAlign.right),
              ],
            ),
            for (final r in d.rooms)
              pw.TableRow(children: [
                _tdCell('CHB${r.number}'),
                _tdCell('CHAMBRE ${r.type.toUpperCase()}'),
                _tdCell('${d.nights}', align: pw.TextAlign.center),
                // Le dollar d'abord : c'est la devise dans laquelle le
                // tarif a été annoncé et négocié. Le franc dessous, parce
                // que c'est dans cette monnaie que le client règle.
                _tdCell(
                    r.aUnPrixEnDollars
                        ? '${moneyUsdCourt(r.priceUsdCents)}\n${_money(r.pricePerNightCents)}'
                        : _money(r.pricePerNightCents),
                    align: pw.TextAlign.right),
                _tdCell(
                    r.aUnPrixEnDollars
                        ? '${moneyUsdCourt(r.priceUsdCents * d.nights)}\n${_money(r.pricePerNightCents * d.nights)}'
                        : _money(r.pricePerNightCents * d.nights),
                    align: pw.TextAlign.right, bold: true),
              ]),
          ],
        ),
        if (d.note != null && d.note!.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Note / demandes spéciales',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text(d.note!, style: const pw.TextStyle(fontSize: 10)),
                ]),
          ),
        ],
        pw.SizedBox(height: 20),
        // Bloc user + totaux
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 20),
                child: pw.Row(children: [
                  pw.Text('Enregistré par : ',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800)),
                  pw.Text((d.serverLogin ?? '—').toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.SizedBox(
              width: 260,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _totalsLine(
                      'Total hébergement', _money(d.accommodationTotalCents)),
                  _totalsLine('Acompte reçu', _money(d.depositCents),
                      bg: PdfColors.grey200),
                  _totalsLine(
                      'Solde à régler à l\'arrivée', _money(d.remainingCents),
                      bold: true, big: true),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        // Note de rappel
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF8EE),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFF4A261), width: 0.6),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
              'Important : cette confirmation ne fait pas office de reçu '
              'final. '
              'Un reçu définitif sera émis au moment du check-out.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
        ),
        _receiptFooter(),
      ],
    ));
    return doc.save();
  }

  /// Aperçu + impression d'une facture de séjour au check-out.
  /// Utilisée pour les séjours solo comme pour les entreprises qui
  /// louent plusieurs chambres — la mise en page s'adapte au nombre
  /// de chambres et à la présence ou non de consommations.
  static Future<void> previewStayInvoice(StayInvoiceData data) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildStayInvoice(data),
      name:
          'sejour_${data.rooms.map((r) => r.number).join("-")}_${_stamp()}.pdf',
    );
  }

  static Future<Uint8List> _buildStayInvoice(StayInvoiceData d) async {
    return _buildStayInvoiceReceipt(d);
  }

  /// Layout facture calqué sur le reçu papier "SKY BLEU GUEST HOUSE" :
  /// header centré, 2 colonnes client/référence, table hébergement,
  /// bloc totaux à droite, footer légal.
  static Future<Uint8List> _buildStayInvoiceReceipt(StayInvoiceData d) async {
    final doc = pw.Document(title: 'Reçu ${d.receiptNumber}');
    final pt = await _pageTheme();
    final logo = await _loadLogo();
    final dfmt = DateFormat("dd/MM/yyyy", 'fr_FR');
    final dfmtLong = DateFormat("d MMMM y", 'fr_FR');
    // Split "Nom / Prénom" à partir du fullName. Convention : premier
    // mot = prénom, reste = nom. Si un seul mot → repris dans les deux.
    final parts = d.guestFullName.trim().split(RegExp(r'\s+'));
    final prenom = parts.first;
    final nom = parts.length > 1 ? parts.sublist(1).join(' ') : prenom;

    doc.addPage(pw.MultiPage(
      pageTheme: pt,
      build: (_) => [
        _receiptHeader(logo),
        pw.SizedBox(height: 10),
        _receiptTitle(),
        pw.SizedBox(height: 12),
        _clientAndReferenceBlock(d, nom, prenom, dfmt),
        pw.SizedBox(height: 16),
        _accommodationTable(d, dfmtLong),
        pw.SizedBox(height: 20),
        _userAndTotalsBlock(d),
        pw.SizedBox(height: 24),
        _receiptFooter(),
      ],
    ));
    return doc.save();
  }

  // ── Header centré : logo + coordonnées ─────────────────────────────
  static pw.Widget _receiptHeader(pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Image(logo, width: 90, height: 90, fit: pw.BoxFit.contain)
        else
          pw.SizedBox(width: 90),
        pw.Expanded(
          child: pw.Column(children: [
            pw.Text('SKY BLUe GUEST HOUSE',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.3,
                    color: const PdfColor.fromInt(0xFF0E3A47))),
            pw.SizedBox(height: 4),
            pw.Text(BusinessInfo.phone,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            if (BusinessInfo.email.isNotEmpty)
              pw.Text(BusinessInfo.email,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            pw.Text('7710 avenue kilwa, q./lido golf',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text('LUBUMBASHI',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                    color: PdfColors.grey800)),
          ]),
        ),
        pw.SizedBox(width: 90),
      ],
    );
  }

  static pw.Widget _receiptTitle() {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey800, width: 0.8),
          ),
        ),
        child: pw.Text('REÇU',
            style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 3)),
      ),
    );
  }

  // ── Bloc client (gauche) + références (droite) ─────────────────────
  static pw.Widget _clientAndReferenceBlock(
      StayInvoiceData d, String nom, String prenom, DateFormat dfmt) {
    // Le "Nom Société" est renseigné SEULEMENT si prise en charge société.
    final societe = d.hasPayer ? d.payerName! : '';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Colonne gauche : client
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _labelValue('Nom Client', nom),
              _labelValue('Prénom Client', prenom),
              _labelValue('Nom Société', societe),
              _labelValue('Nationalité Client', d.guestNationality ?? ''),
              _labelValue('N° Téléphone', d.guestPhone ?? ''),
              _labelValue('Email', d.guestEmail ?? ''),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Colonne droite : références + statut + paiement
        pw.SizedBox(
          width: 220,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _refRow('Date reçu :', dfmt.format(aLubumbashi(d.generatedAt))),
              _refRow('N° Reçu :', d.receiptNumber),
              _refRow('N° Reservation :', d.reservationNumber ?? '—'),
              pw.SizedBox(height: 8),
              _dashedBox('Solde',
                  d.remainingCents == 0 ? 'Réglé' : _money(d.remainingCents)),
              pw.SizedBox(height: 4),
              _dashedBox('Mode de paiement', d.paymentMode.label),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text('$label :',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800)),
        ),
        pw.Expanded(
          child: pw.Text(value.isEmpty ? '' : value,
              style: const pw.TextStyle(fontSize: 10.5)),
        ),
      ]),
    );
  }

  static pw.Widget _refRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Cadre en pointillés type reçu papier.
  static pw.Widget _dashedBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
            color: PdfColors.grey500, width: 0.6, style: pw.BorderStyle.dashed),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label :',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Table Hébergement ───────────────────────────────────────────────
  static pw.Widget _accommodationTable(StayInvoiceData d, DateFormat dfmtLong) {
    // Ligne "Date d'entrée … / Date de sortie …" au-dessus de la table.
    final earliest =
        d.rooms.map((r) => r.checkinAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final latest =
        d.rooms.map((r) => r.checkoutAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Hébergement',
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0E3A47))),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          color: PdfColors.grey100,
          child: pw.Text(
              "Date d'entrée le ${dfmtLong.format(aLubumbashi(earliest))} et Date de sortie le ${dfmtLong.format(aLubumbashi(latest))}",
              style: pw.TextStyle(
                  fontSize: 9.5,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey800)),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _thCell('Code'),
                _thCell('Description libellé'),
                _thCell('Nbre Nuitée', align: pw.TextAlign.center),
                _thCell('P.U.', align: pw.TextAlign.right),
                _thCell('Sous Total', align: pw.TextAlign.right),
              ],
            ),
            for (final r in d.rooms)
              pw.TableRow(children: [
                _tdCell('CHB${r.number}'),
                // Sur un tarif négocié, on précise le tarif catalogue
                // sous le libellé : le client voit l'effort consenti.
                r.hasNegotiatedRate
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('CHAMBRE ${r.type.toUpperCase()}',
                                style: const pw.TextStyle(fontSize: 9.5)),
                            pw.Text(
                                'Tarif négocié — au lieu de '
                                '${_money(r.listPriceCents!)}/nuit '
                                '(remise ${_money(r.negotiatedSavingCents)})',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontStyle: pw.FontStyle.italic,
                                    color: PdfColors.grey700)),
                          ],
                        ),
                      )
                    : _tdCell('CHAMBRE ${r.type.toUpperCase()}'),
                _tdCell('${r.nights}', align: pw.TextAlign.center),
                // Le dollar d'abord : c'est la devise dans laquelle le
                // tarif a été annoncé et négocié. Le franc dessous, parce
                // que c'est dans cette monnaie que le client règle.
                _tdCell(
                    r.aUnPrixEnDollars
                        ? '${moneyUsdCourt(r.priceUsdCents)}\n${_money(r.pricePerNightCents)}'
                        : _money(r.pricePerNightCents),
                    align: pw.TextAlign.right),
                _tdCell(
                    r.aUnPrixEnDollars
                        ? '${moneyUsdCourt(r.priceUsdCents * r.nights)}\n${_money(r.accommodationCents)}'
                        : _money(r.accommodationCents),
                    align: pw.TextAlign.right, bold: true),
              ]),
          ],
        ),
        if (d.hasNegotiatedRates) ...[
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
                'Tarifs négociés appliqués : ${_money(d.negotiatedSavingCents)} '
                'déduits du tarif catalogue (${_money(d.listSubtotalCents)}).',
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700)),
          ),
        ],
        // Extras (restauration, bar) si présents — même style de table
        // en dessous, plus discret.
        if (d.extras.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Consommations (restaurant / bar)',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800)),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(4),
              3: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _thCell('Date'),
                  _thCell('Ch.', align: pw.TextAlign.center),
                  _thCell('Détail'),
                  _thCell('Total', align: pw.TextAlign.right),
                ],
              ),
              for (final s in d.extras)
                pw.TableRow(children: [
                  _tdCell(DateFormat("dd/MM · HH:mm", 'fr_FR')
                      .format(aLubumbashi(s.sale.soldAt))),
                  _tdCell(s.sale.roomNumber ?? '—', align: pw.TextAlign.center),
                  _tdCell(s.lines
                      .map((l) => '${l.qty}× ${l.articleName}')
                      .join(', ')),
                  _tdCell(_money(s.totalCents),
                      align: pw.TextAlign.right, bold: true),
                ]),
            ],
          ),
        ],
      ],
    );
  }

  // ── User (gauche) + Totaux (droite) ────────────────────────────────
  static pw.Widget _userAndTotalsBlock(StayInvoiceData d) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(children: [
              pw.Text('User : ',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800)),
              pw.Text((d.serverLogin ?? '—').toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 250,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Les deux acomptes gardent leur devise de versement :
              // ce sont des billets reçus, pas des conversions.
              if (d.acompteUsdCents > 0)
                _totalsLine('Acompte reçu (USD)',
                    moneyUsdCourt(d.acompteUsdCents),
                    bg: PdfColors.grey200),
              if (d.acompteFcCents > 0)
                _totalsLine('Acompte reçu (FC)',
                    '${NumberFormat("#,###", "fr_FR").format(d.acompteFcCents)} FC',
                    bg: PdfColors.grey200),
              _totalsLine('Total payé',
                  '${d.enDollars(d.totalPaidCents)}  ·  ${_money(d.totalPaidCents)}'),
              if (d.remiseCents > 0)
                _totalsLine('Remise',
                    '${d.enDollars(d.remiseCents)}  ·  ${_money(d.remiseCents)}'),
              if (d.remiseCents > 0 &&
                  d.remiseLabel != null &&
                  d.remiseLabel!.isNotEmpty)
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.only(left: 8, right: 8, bottom: 2),
                  child: pw.Text(d.remiseLabel!,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700)),
                ),
              _totalsLine('Total',
                  '${d.enDollars(d.totalCents)}  ·  ${_money(d.totalCents)}'),
              _totalsLine(
                  'Reste à payer',
                  '${d.enDollars(d.remainingCents)}  ·  '
                      '${_money(d.remainingCents)}',
                  bold: true,
                  big: true),
              // Le taux appliqué, écrit noir sur blanc. Sans lui, un
              // client qui refait le calcul chez lui tombe sur un autre
              // chiffre et revient contester une facture juste.
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, right: 8),
                child: pw.Text(
                    'Taux appliqué : 1 USD = '
                    '${NumberFormat("#,###", "fr_FR").format(d.taux.round())} FC',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalsLine(String label, String value,
      {PdfColor? bg, bool bold = false, bool big = false}) {
    return pw.Container(
      color: bg,
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: big ? 8 : 5),
      decoration: pw.BoxDecoration(
        color: bg,
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label :',
              style: pw.TextStyle(
                  fontSize: big ? 12 : 10.5,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: big ? 12 : 10.5,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────
  static pw.Widget _receiptFooter() {
    return pw.Column(children: [
      pw.SizedBox(height: 30),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Sceau et Signature Comptabilité',
            style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700)),
      ),
      pw.SizedBox(height: 40),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Powered by Skyblue',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          pw.Text('1/1',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    ]);
  }

  static pw.Widget _thCell(String s, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(s,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800)),
    );
  }

  static pw.Widget _tdCell(String s,
      {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(s,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
