import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../domain/entities/settlement_row_entity.dart';
import '../../domain/services/settlement_merger_engine.dart';

class ExcelWorkbookExporter {
  /// Builds a multi-sheet .xlsx workbook and prompts native OS save dialog
  static Future<String?> exportMultiSheetWorkbook({
    required MergedSettlementResult mergeResult,
    required String baseFileName,
  }) async {
    // Offload heavy excel creation to background isolate
    final bytes = await compute(_isolateBuildExcel, mergeResult);

    return await FileSaverUtil.saveExcel(
      baseName: baseFileName,
      bytes: bytes,
    );
  }

  static Future<Uint8List> _isolateBuildExcel(MergedSettlementResult mergeResult) async {
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

    final bytesList = excel.encode();
    if (bytesList == null) {
      throw Exception('Failed to encode Excel workbook');
    }
    return Uint8List.fromList(bytesList);
  }

  /// Populate header and rows for a given sheet
  static void _populateSheet(
    Excel excel,
    String sheetName,
    List<SettlementRowEntity> rows,
  ) {
    final sheet = excel[sheetName];

    String sanitize(String input) {
      // Strip control characters that corrupt XML (keep tabs, newlines, carriage returns)
      return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '').trim();
    }

    // Header Row
    final headers = SettlementHeaders.standard;
    final List<CellValue> headerCells = headers.map((h) => TextCellValue(sanitize(h))).toList();
    sheet.appendRow(headerCells);

    // Data Rows
    for (final r in rows) {
      final List<CellValue> rowCells = [
        TextCellValue(sanitize(r.issuer)),
        TextCellValue(sanitize(r.acquirer)),
        TextCellValue(sanitize(r.mti)),
        TextCellValue(sanitize(r.cardNumber)), // TextCellValue preserves PAN exactly!
        DoubleCellValue(r.amount),
        TextCellValue(sanitize(r.currency)),
        TextCellValue(sanitize(r.transactionDate)),
        TextCellValue(sanitize(r.transactionDescription)),
        TextCellValue(sanitize(r.terminalId)),
        TextCellValue(sanitize(r.transactionPlace)),
        TextCellValue(sanitize(r.stanF11)), // Preserves STAN without exponent
        TextCellValue(sanitize(r.refnumF37)), // Preserves RRN without exponent
        TextCellValue(sanitize(r.authidrespF38)),
        TextCellValue(sanitize(r.feUtrnno)), // Preserves Fe_utrnno
        TextCellValue(sanitize(r.boUtrnno)), // Preserves Bo_utrnno
      ];
      sheet.appendRow(rowCells);
    }
  }

  /// Export master merged CSV for lightweight processing
  static Future<String?> exportMasterCsv({
    required List<SettlementRowEntity> rows,
    required String baseFileName,
  }) async {
    // Offload heavy CSV string building to background isolate
    final csvContent = await compute(_isolateBuildCsv, rows);

    return await FileSaverUtil.saveCsv(
      baseName: baseFileName,
      csvContent: csvContent,
    );
  }

  static Future<String> _isolateBuildCsv(List<SettlementRowEntity> rows) async {
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

    return buffer.toString();
  }
}
