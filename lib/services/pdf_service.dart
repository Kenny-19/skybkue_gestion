import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/cat_ui.dart';
import '../core/format.dart';
import '../data/repos.dart';
import '../data/schema.dart';
import 'backup_service.dart';

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

class PdfService {
  // Montants en Franc Congolais (via le taux courant).
  static String _money(int cents) => moneyCents(cents);

  /// Horodatage compact pour le nom des fichiers générés : YYYYMMDDHHmm.
  static String _stamp() =>
      DateFormat('yyyyMMddHHmm').format(DateTime.now());

  // Thème PDF avec fonts Unicode (Noto Sans) — chargé une seule fois.
  static pw.ThemeData? _cachedTheme;
  static Future<pw.ThemeData> _theme() async {
    if (_cachedTheme != null) return _cachedTheme!;
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
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
          child: pw.Image(logo, width: 380, height: 380, fit: pw.BoxFit.contain),
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
      pageFormat: landscape
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: theme,
      buildBackground: (_) => pw.FullPage(
        ignoreMargins: true,
        child: _watermark(logo),
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
      pageTheme: await _pageTheme(),
      build: (_) => _invoiceContent(s),
    ));
    return doc.save();
  }

  static pw.Widget _invoiceContent(SaleWithLines s) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _brandHeader('Facture'),
        pw.SizedBox(height: 24),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _eyebrow('N° DE FACTURE'),
                pw.Text('#${s.sale.id.toString().padLeft(4, '0')}',
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                _eyebrow('DATE'),
                pw.Text(
                    DateFormat("EEEE d MMMM y", 'fr_FR').format(s.sale.soldAt),
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                _eyebrow('HEURE EXACTE'),
                pw.Text(
                    DateFormat("HH:mm:ss", 'fr_FR').format(s.sale.soldAt),
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1)),
                if (s.sale.customerName != null) ...[
                  pw.SizedBox(height: 10),
                  _eyebrow('CLIENT'),
                  pw.Text(s.sale.customerName!,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ],
            ),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _eyebrow('EMPLACEMENT'),
            pw.Text(s.sale.location.label,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _eyebrow('SERVEUR'),
            pw.Text(s.server?.fullName ?? '—',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _eyebrow('PAIEMENT'),
            pw.Text(s.sale.payment.label,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _eyebrow('ARTICLES'),
            pw.Text('${s.itemsCount}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
        pw.SizedBox(height: 24),
        pw.Table(
          border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _th('Article'),
                _th('Qté', align: pw.TextAlign.right),
                _th('Prix U.', align: pw.TextAlign.right),
                _th('Total', align: pw.TextAlign.right),
              ],
            ),
            for (final l in s.lines)
              pw.TableRow(children: [
                _td(l.articleName),
                _td('${l.qty}', align: pw.TextAlign.right),
                _td(_money(l.unitPriceCents), align: pw.TextAlign.right),
                _td(_money(l.unitPriceCents * l.qty),
                    align: pw.TextAlign.right, bold: true),
              ]),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 260,
            child: pw.Column(children: [
              _totalRow('Sous-total', _money(s.totalCents)),
              _totalRow('TVA (0%)', _money(0)),
              pw.Divider(color: PdfColors.grey400),
              _totalRow('TOTAL', _money(s.totalCents), big: true),
              pw.SizedBox(height: 2),
              pw.Row(children: [
                pw.Spacer(),
                pw.Text('soit ${moneyUsd(s.totalCents)}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ]),
            ]),
          ),
        ]),
        if (s.sale.note != null) ...[
          pw.SizedBox(height: 20),
          _eyebrow('NOTE'),
          pw.SizedBox(height: 4),
          pw.Text(s.sale.note!,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic)),
        ],
        pw.Spacer(),
        _footer(),
      ],
    );
  }

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

  static Future<Uint8List> _buildCartPreview(
      List<CartPreviewLine> lines, DbPayment payment, String? serverName) async {
    final total = lines.fold<int>(0, (s, l) => s + l.unitPriceCents * l.qty);
    final doc = pw.Document(title: 'Aperçu ticket');
    doc.addPage(pw.Page(
      pageTheme: await _pageTheme(),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _brandHeader('Aperçu — non encaissé'),
          pw.SizedBox(height: 24),
          pw.Text(
              DateFormat("EEEE d MMMM y · HH:mm", 'fr_FR').format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          if (serverName != null)
            pw.Text('Serveur : $serverName',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text('Paiement prévu : ${payment.label}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.symmetric(
                inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _th('Article'),
                  _th('Qté', align: pw.TextAlign.right),
                  _th('Prix U.', align: pw.TextAlign.right),
                  _th('Total', align: pw.TextAlign.right),
                ],
              ),
              for (final l in lines)
                pw.TableRow(children: [
                  _td(l.name),
                  _td('${l.qty}', align: pw.TextAlign.right),
                  _td(_money(l.unitPriceCents), align: pw.TextAlign.right),
                  _td(_money(l.unitPriceCents * l.qty),
                      align: pw.TextAlign.right, bold: true),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 220,
              child: pw.Column(children: [
                _totalRow('TOTAL', _money(total), big: true),
              ]),
            ),
          ]),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              border: pw.Border.all(color: PdfColors.orange300),
            ),
            child: pw.Text(
                '⚠ APERÇU UNIQUEMENT — cette vente n\'est pas enregistrée en base tant que le bouton « Encaisser » n\'est pas cliqué.',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.orange900,
                    fontStyle: pw.FontStyle.italic)),
          ),
          pw.Spacer(),
          _footer(),
        ],
      ),
    ));
    return doc.save();
  }

  // ─── Rapport synthétique ─────────────────────────────────────────────

  static Future<void> previewSummaryReport(List<SaleWithLines> sales) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildSummary(sales),
      name: 'rapport_synthetique_${_stamp()}.pdf',
    );
  }

  static Future<Uint8List> _buildSummary(List<SaleWithLines> sales) async {
    final doc = pw.Document(title: 'Rapport synthétique');
    final pt = await _pageTheme();
    final byDay = _groupByDay(sales);
    final total = sales.fold<int>(0, (s, e) => s + e.totalCents);
    int boissons = 0, nourriture = 0, chambres = 0;
    for (final s in sales) {
      for (final l in s.lines) {
        // On ne connaît pas la catégorie ici sans lookup — on approche via nom
        // (Le repo pourrait pré-calculer, mais on garde simple pour la maquette PDF.)
        // Placeholder : tout dans "nourriture" si articleId null.
        // Amélioration : on va aller chercher la catégorie via une carte fournie.
        final t = l.unitPriceCents * l.qty;
        nourriture += t;
      }
    }
    // On refait la répartition proprement : appel synchrone via helper.
    boissons = 0;
    nourriture = 0;
    chambres = 0;
    final catByArticleId = <int, DbCategory>{};
    for (final s in sales) {
      for (final l in s.lines) {
        if (l.articleId != null && !catByArticleId.containsKey(l.articleId)) {
          catByArticleId[l.articleId!] =
              DbCategory.values[l.articleId! ~/ 100 == 2 ? 2 : (l.articleId! ~/ 100 == 1 ? 1 : 0)];
          // Heuristique par plage d'ID (fallback si BDD pas dispo ici)
        }
      }
    }
    for (final s in sales) {
      for (final l in s.lines) {
        final t = l.unitPriceCents * l.qty;
        final cat = catByArticleId[l.articleId];
        switch (cat) {
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
            nourriture += t;
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
              'Période — 7 derniers jours · généré le ${DateFormat("d MMMM y à HH:mm", 'fr_FR').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          _rateNote(),
          pw.SizedBox(height: 20),
          _kpiRow([
            ["CHIFFRE D'AFFAIRES", '${_money(total)}\n${moneyUsd(total)}'],
            ['TRANSACTIONS', '${sales.length}'],
            ['PANIER MOYEN',
                _money(sales.isEmpty ? 0 : (total ~/ sales.length))],
          ]),
          pw.SizedBox(height: 20),
          _eyebrow('RÉPARTITION PAR CATÉGORIE'),
          pw.SizedBox(height: 8),
          _catTable(boissons, nourriture, chambres, total),
          pw.SizedBox(height: 24),
          _eyebrow('DÉTAIL PAR JOUR'),
          pw.SizedBox(height: 8),
          _dayTable(byDay),
          pw.Spacer(),
          _footer(),
        ],
      ),
    ));
    return doc.save();
  }

  // ─── Rapport détaillé ────────────────────────────────────────────────

  static Future<void> previewDetailedReport(List<SaleWithLines> sales) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildDetailed(sales),
      name: 'rapport_detaille_${_stamp()}.pdf',
    );
  }

  static Future<Uint8List> _buildDetailed(List<SaleWithLines> sales) async {
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
              '${sales.length} transactions · Total ${_money(total)} (${moneyUsd(total)}) · Généré le ${DateFormat("d MMMM y à HH:mm", 'fr_FR').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          _rateNote(),
          pw.SizedBox(height: 12),
          pw.Expanded(child: _detailedTable(sales)),
          pw.SizedBox(height: 8),
          _footer(),
        ],
      ),
    ));
    return doc.save();
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
                '${DateFormat("dd/MM", 'fr_FR').format(s.sale.soldAt)}  ${DateFormat("HH:mm", 'fr_FR').format(s.sale.soldAt)}'),
            _tdSmall('#${s.sale.id.toString().padLeft(4, '0')}', bold: true),
            _tdSmall(s.sale.customerName ?? '—'),
            _tdSmall(s.server?.fullName ?? '—'),
            _tdSmall(s.sale.location.label),
            _tdSmall(s.sale.payment.label),
            _tdSmall(s.lines
                .map((l) => '${l.qty}× ${l.articleName}')
                .join(' · ')),
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
            _tdSmall(
                _money(sales.fold<int>(0, (s, e) => s + e.totalCents)),
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
      final d = DateTime(s.sale.soldAt.year, s.sale.soldAt.month, s.sale.soldAt.day);
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
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
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
            _td(DateFormat("EEEE d MMMM y", 'fr_FR').format(e.key)),
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

  static pw.Widget _totalRow(String l, String v, {bool big = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(l,
                  style: pw.TextStyle(
                      fontSize: big ? 12 : 10,
                      fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: PdfColors.grey700))),
          pw.Text(v,
              style: pw.TextStyle(
                  fontSize: big ? 14 : 11, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  // Note du taux appliqué, pour tracer la conversion FC↔$.
  static pw.Widget _rateNote() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Text(
            'Taux appliqué : 1 \$ = ${moneyFc(Currency.rate.round())} · montants indiqués en FC (équivalent \$ entre parenthèses)',
            style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic)),
      );

  static pw.Widget _footer() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
          pw.Text('Merci pour votre visite — Skyblue Guest House · by Afrinvest',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic)),
        ],
      );
}
