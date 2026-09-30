import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../data/database.dart';
import '../data/repos.dart';
import '../data/schema.dart';
import '../core/temps.dart';
import '../core/horloge.dart';

class BackupService {
  BackupService._();

  /// Copie le fichier .db vers un chemin choisi par l'utilisateur.
  static Future<String?> exportDatabase() async {
    final src = await AppDatabase.dbFile();
    if (!src.existsSync()) return null;
    final ts =
        DateFormat("yyyyMMddHHmm").format(aLubumbashi(Horloge.maintenant()));
    final path = await getSaveLocation(
      suggestedName: 'sauvegarde_bdd_$ts.db',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Base SQLite', extensions: ['db']),
      ],
    );
    if (path == null) return null;
    await src.copy(path.path);
    return path.path;
  }

  /// Restaure la BDD depuis un fichier .db choisi.
  /// ⚠️ Écrase la BDD actuelle — l'app doit être redémarrée après.
  static Future<String?> importDatabase() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Base SQLite', extensions: ['db']),
      ],
    );
    if (picked == null) return null;
    final dst = await AppDatabase.dbFile();
    await File(picked.path).copy(dst.path);
    return dst.path;
  }

  /// Génère un rapport Excel "du soir" : une colonne par jour (2 colonnes),
  /// Restaurant / Terrasse / (Hôtel) / Crédit, Total Cash Vendu, puis le
  /// détail des dettes du jour et le Total Crédit. Montants en FC.
  static Future<String?> exportSalesExcel(List<SaleWithLines> sales) async {
    final xl = Excel.createExcel();
    final sh = xl['Feuil1'];
    xl.delete('Sheet1');

    // Regroupement par jour (ordre chronologique).
    final byDay = <DateTime, List<SaleWithLines>>{};
    for (final s in sales) {
      final d = debutDeJourneeLubumbashi(s.sale.soldAt);
      byDay.putIfAbsent(d, () => []).add(s);
    }
    final days = byDay.keys.toList()..sort();
    if (days.isEmpty) days.add(DateTime.now());

    final hasHotel = sales.any((s) => s.sale.location == DbLocation.hotel);
    // Nombre de lignes de crédit max (pour aligner "Total Crédit").
    int maxCredit = 1;
    for (final d in days) {
      final n = byDay[d]?.where((s) => s.sale.onCredit).length ?? 0;
      if (n > maxCredit) maxCredit = n;
    }

    // Indices de lignes (0-based).
    const rTitle = 0, rDay = 1, rResto = 2, rTerr = 3;
    final rHotel = hasHotel ? 4 : -1;
    final rCredit = hasHotel ? 5 : 4;
    final rTotalCash = rCredit + 2;
    final rDetails = rTotalCash + 2;
    final rDetailStart = rDetails + 1;
    final rTotalCredit = rDetailStart + maxCredit;

    CellStyle bold(
            {int size = 11,
            HorizontalAlign align = HorizontalAlign.Left,
            ExcelColor fill = ExcelColor.none}) =>
        CellStyle(
            bold: true,
            fontSize: size,
            horizontalAlign: align,
            backgroundColorHex: fill);
    CellStyle normal(
            {int size = 11,
            HorizontalAlign align = HorizontalAlign.Left,
            ExcelColor fill = ExcelColor.none}) =>
        CellStyle(
            fontSize: size, horizontalAlign: align, backgroundColorHex: fill);

    final headerFill = ExcelColor.fromHexString('#DCE6F1'); // bleu clair
    final totalFill = ExcelColor.fromHexString('#F2F2F2'); // gris clair

    void put(int col, int row, String text, CellStyle style) {
      final c =
          sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      c.value = TextCellValue(text);
      c.cellStyle = style;
    }

    // Titre (fusionné sur toutes les colonnes).
    final fmtD = DateFormat('d MMM y', 'fr_FR');
    sh.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rTitle),
        CellIndex.indexByColumnRow(
            columnIndex: days.length * 2 - 1, rowIndex: rTitle),
        customValue: TextCellValue(
            'RAPPORT DES VENTES DU ${fmtD.format(aLubumbashi(days.first))} AU ${fmtD.format(aLubumbashi(days.last))}'));
    sh
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rTitle))
        .cellStyle = bold(size: 14, align: HorizontalAlign.Center);

    for (int i = 0; i < days.length; i++) {
      final lc = i * 2, ac = i * 2 + 1; // colonne libellé / montant
      final daySales = byDay[days[i]] ?? const [];
      sh.setColumnWidth(lc, 18);
      sh.setColumnWidth(ac, 13);

      int cashAt(DbLocation loc) => daySales
          .where((s) => !s.sale.onCredit && s.sale.location == loc)
          .fold(0, (a, b) => a + b.totalCents);
      final resto = cashAt(DbLocation.restaurant);
      final terr = cashAt(DbLocation.terrasse);
      final hotel = cashAt(DbLocation.hotel);
      final credits = daySales.where((s) => s.sale.onCredit).toList();
      final creditTotal = credits.fold(0, (a, b) => a + b.totalCents);

      // Nom du jour (fusionné, centré, fond bleu).
      final dayName =
          _cap(DateFormat('EEEE d MMMM', 'fr_FR').format(aLubumbashi(days[i])));
      sh.merge(CellIndex.indexByColumnRow(columnIndex: lc, rowIndex: rDay),
          CellIndex.indexByColumnRow(columnIndex: ac, rowIndex: rDay),
          customValue: TextCellValue(dayName));
      sh
          .cell(CellIndex.indexByColumnRow(columnIndex: lc, rowIndex: rDay))
          .cellStyle = bold(align: HorizontalAlign.Center, fill: headerFill);

      put(lc, rResto, 'Restaurant SKY', bold());
      put(ac, rResto, moneyCents(resto), normal(align: HorizontalAlign.Center));
      put(lc, rTerr, 'Terrasse SKY', bold());
      put(ac, rTerr, moneyCents(terr), normal(align: HorizontalAlign.Center));
      if (hasHotel) {
        put(lc, rHotel, 'Hôtel SKY', bold());
        put(ac, rHotel, moneyCents(hotel),
            normal(align: HorizontalAlign.Center));
      }
      put(lc, rCredit, 'Crédit SKY', bold());
      put(ac, rCredit, moneyCents(creditTotal),
          normal(align: HorizontalAlign.Center));

      // Total Cash Vendu (Restaurant + Terrasse + Hôtel).
      put(lc, rTotalCash, 'Total Cash Vendu :', normal(fill: totalFill));
      put(ac, rTotalCash, moneyCents(resto + terr + hotel),
          bold(align: HorizontalAlign.Center, fill: totalFill));

      // Détails Crédit.
      sh.merge(CellIndex.indexByColumnRow(columnIndex: lc, rowIndex: rDetails),
          CellIndex.indexByColumnRow(columnIndex: ac, rowIndex: rDetails),
          customValue: TextCellValue('Détails Crédit'));
      sh
          .cell(CellIndex.indexByColumnRow(columnIndex: lc, rowIndex: rDetails))
          .cellStyle = bold(align: HorizontalAlign.Center);

      for (int k = 0; k < credits.length; k++) {
        final s = credits[k];
        final who = s.sale.roomNumber != null
            ? 'Chambre ${s.sale.roomNumber}'
            : (s.sale.customerName ?? 'Client');
        final items =
            s.lines.map((l) => '${l.qty} ${l.articleName}').join(' + ');
        final line = '$who : $items = ${moneyCents(s.totalCents)}'
            '${s.sale.settledAt != null ? " (payé)" : ""}';
        final r = rDetailStart + k;
        sh.merge(CellIndex.indexByColumnRow(columnIndex: lc, rowIndex: r),
            CellIndex.indexByColumnRow(columnIndex: ac, rowIndex: r),
            customValue: TextCellValue(line));
        sh
            .cell(CellIndex.indexByColumnRow(columnIndex: lc, rowIndex: r))
            .cellStyle = normal(size: 10, align: HorizontalAlign.Left);
      }

      // Total Crédit (ligne alignée pour tous les jours).
      put(lc, rTotalCredit, 'Total Crédit :', normal(fill: totalFill));
      put(ac, rTotalCredit, moneyCents(creditTotal),
          bold(align: HorizontalAlign.Center, fill: totalFill));
    }

    final bytes = xl.encode();
    if (bytes == null) return null;
    final ts =
        DateFormat("yyyyMMddHHmm").format(aLubumbashi(Horloge.maintenant()));
    final path = await getSaveLocation(
      suggestedName: 'rapport_ventes_$ts.xlsx',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (path == null) return null;
    await File(path.path).writeAsBytes(bytes);
    return path.path;
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
