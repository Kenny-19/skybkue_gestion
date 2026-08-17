import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../core/cat_ui.dart';
import '../data/database.dart';
import '../data/repos.dart';

class BackupService {
  BackupService._();

  /// Copie le fichier .db vers un chemin choisi par l'utilisateur.
  static Future<String?> exportDatabase() async {
    final src = await AppDatabase.dbFile();
    if (!src.existsSync()) return null;
    final ts = DateFormat("yyyyMMddHHmm").format(DateTime.now());
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

  /// Génère un fichier .xlsx avec 3 onglets : Ventes, Lignes, Résumé.
  static Future<String?> exportSalesExcel(List<SaleWithLines> sales) async {
    final xl = Excel.createExcel();
    xl.delete('Sheet1');

    // Onglet Ventes
    final ventes = xl['Ventes'];
    ventes.appendRow(_row(['ID', 'Date', 'Heure', 'Emplacement', 'Client',
                            'Serveur', 'Paiement', 'Nb articles', 'Total (\$)',
                            'Note']));
    for (final s in sales) {
      ventes.appendRow(_row([
        s.sale.id,
        DateFormat('yyyy-MM-dd').format(s.sale.soldAt),
        DateFormat('HH:mm:ss').format(s.sale.soldAt),
        s.sale.location.label,
        s.sale.customerName ?? '',
        s.server?.fullName ?? '—',
        s.sale.payment.label,
        s.itemsCount,
        (s.totalCents / 100).toStringAsFixed(2),
        s.sale.note ?? '',
      ]));
    }

    // Onglet par emplacement
    final parLieu = xl['Par emplacement'];
    parLieu.appendRow(_row(['Emplacement', 'Ventes', 'Total (\$)']));
    final byLoc = <String, List<SaleWithLines>>{};
    for (final s in sales) {
      byLoc.putIfAbsent(s.sale.location.label, () => []).add(s);
    }
    for (final e in byLoc.entries) {
      final total = e.value.fold<int>(0, (a, b) => a + b.totalCents);
      parLieu.appendRow(_row([
        e.key,
        e.value.length,
        (total / 100).toStringAsFixed(2),
      ]));
    }

    // Onglet Lignes
    final lignes = xl['Lignes'];
    lignes.appendRow(_row(['Vente ID', 'Date', 'Article', 'Qté',
                             'Prix U. (\$)', 'Total ligne (\$)']));
    for (final s in sales) {
      for (final l in s.lines) {
        lignes.appendRow(_row([
          s.sale.id,
          DateFormat('yyyy-MM-dd HH:mm').format(s.sale.soldAt),
          l.articleName,
          l.qty,
          (l.unitPriceCents / 100).toStringAsFixed(2),
          (l.unitPriceCents * l.qty / 100).toStringAsFixed(2),
        ]));
      }
    }

    // Onglet Résumé par jour
    final resume = xl['Résumé'];
    resume.appendRow(_row(['Date', 'Ventes', 'Total (\$)']));
    final byDay = <String, List<SaleWithLines>>{};
    for (final s in sales) {
      final k = DateFormat('yyyy-MM-dd').format(s.sale.soldAt);
      byDay.putIfAbsent(k, () => []).add(s);
    }
    final days = byDay.keys.toList()..sort();
    for (final d in days) {
      final entries = byDay[d]!;
      final total = entries.fold<int>(0, (s, e) => s + e.totalCents);
      resume.appendRow(_row([
        d,
        entries.length,
        (total / 100).toStringAsFixed(2),
      ]));
    }

    final bytes = xl.encode();
    if (bytes == null) return null;

    final ts = DateFormat("yyyyMMddHHmm").format(DateTime.now());
    final path = await getSaveLocation(
      suggestedName: 'rapport_ventes_excel_$ts.xlsx',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (path == null) return null;
    await File(path.path).writeAsBytes(bytes);
    return path.path;
  }

  static List<CellValue> _row(List<Object?> values) {
    return values.map<CellValue>((v) {
      if (v == null) return TextCellValue('');
      if (v is int) return IntCellValue(v);
      if (v is double) return DoubleCellValue(v);
      return TextCellValue(v.toString());
    }).toList();
  }
}
