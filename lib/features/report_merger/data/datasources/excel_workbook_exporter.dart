import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../domain/entities/settlement_row_entity.dart';
import '../../domain/services/settlement_merger_engine.dart';

class ExcelWorkbookExporter {
  /// Builds a multi-sheet .xlsx workbook and prompts native OS save dialog
  static Future<String?> exportMultiSheetWorkbook({
    required MergedSettlementResult mergeResult,
    required String baseFileName,
  }) async {
    final excel = Excel.createExcel();

    // Default sheet name created by excel package is 'Sheet1'
    const String defaultSheet = 'Sheet1';

    // 1. Build Master Sheet: 'All_Merged'
    const String masterSheetName = 'All_Merged';
    excel.rename(defaultSheet, masterSheetName);
    _populateSheet(excel, masterSheetName, mergeResult.allMergedRows);

    // 2. Build Category Sheets (e.g. 'ATM_CW', 'Dispute_Chargeback', 'Balance_Enquiry', etc.)
    for (final entry in mergeResult.categorizedSheets.entries) {
      final sheetName = entry.key;
      if (sheetName == masterSheetName) continue;

      _populateSheet(excel, sheetName, entry.value);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel workbook');
    }

    return await FileSaverUtil.saveExcel(
      baseName: baseFileName,
      bytes: Uint8List.fromList(bytes),
    );
  }

  /// Populate header and rows for a given sheet
  static void _populateSheet(
    Excel excel,
    String sheetName,
    List<SettlementRowEntity> rows,
  ) {
    final sheet = excel[sheetName];

    // Header Row
    final headers = SettlementHeaders.standard;
    final List<CellValue> headerCells = headers.map((h) => TextCellValue(h)).toList();
    sheet.appendRow(headerCells);

    // Data Rows
    for (final r in rows) {
      final List<CellValue> rowCells = [
        TextCellValue(r.issuer),
        TextCellValue(r.acquirer),
        TextCellValue(r.mti),
        TextCellValue(r.cardNumber), // TextCellValue preserves PAN exactly!
        DoubleCellValue(r.amount),
        TextCellValue(r.currency),
        TextCellValue(r.transactionDate),
        TextCellValue(r.transactionDescription),
        TextCellValue(r.terminalId),
        TextCellValue(r.transactionPlace),
        TextCellValue(r.stanF11), // Preserves STAN without exponent
        TextCellValue(r.refnumF37), // Preserves RRN without exponent
        TextCellValue(r.authidrespF38),
        TextCellValue(r.feUtrnno), // Preserves Fe_utrnno
        TextCellValue(r.boUtrnno), // Preserves Bo_utrnno
      ];
      sheet.appendRow(rowCells);
    }
  }

  /// Export master merged CSV for lightweight processing
  static Future<String?> exportMasterCsv({
    required List<SettlementRowEntity> rows,
    required String baseFileName,
  }) async {
    final buffer = StringBuffer();
    // 1. Single Header Row
    buffer.writeln(SettlementHeaders.standard.join(','));

    // 2. Data Rows
    for (final r in rows) {
      final cleanValues = [
        '"${r.issuer.replaceAll('"', '""')}"',
        '"${r.acquirer.replaceAll('"', '""')}"',
        '"${r.mti.replaceAll('"', '""')}"',
        '"${r.cardNumber.replaceAll('"', '""')}"',
        r.amount.toStringAsFixed(2),
        '"${r.currency.replaceAll('"', '""')}"',
        '"${r.transactionDate.replaceAll('"', '""')}"',
        '"${r.transactionDescription.replaceAll('"', '""')}"',
        '"${r.terminalId.replaceAll('"', '""')}"',
        '"${r.transactionPlace.replaceAll('"', '""')}"',
        '"${r.stanF11.replaceAll('"', '""')}"',
        '"${r.refnumF37.replaceAll('"', '""')}"',
        '"${r.authidrespF38.replaceAll('"', '""')}"',
        '"${r.feUtrnno.replaceAll('"', '""')}"',
        '"${r.boUtrnno.replaceAll('"', '""')}"',
      ];
      buffer.writeln(cleanValues.join(','));
    }

    return await FileSaverUtil.saveCsv(
      baseName: baseFileName,
      csvContent: buffer.toString(),
    );
  }
}
