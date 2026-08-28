import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../entities/settlement_row_entity.dart';

class MergedSettlementResult {
  final List<SettlementRowEntity> allMergedRows;
  final Map<String, List<SettlementRowEntity>> categorizedSheets;
  final int totalFilesProcessed;
  final int totalRowsBefore;
  final int totalRowsAfter;
  final int emptyRowsPurged;
  final int duplicateHeadersRemoved;
  final double totalVolumeAmount;
  final Duration processingTime;

  MergedSettlementResult({
    required this.allMergedRows,
    required this.categorizedSheets,
    required this.totalFilesProcessed,
    required this.totalRowsBefore,
    required this.totalRowsAfter,
    required this.emptyRowsPurged,
    required this.duplicateHeadersRemoved,
    required this.totalVolumeAmount,
    required this.processingTime,
  });
}

class SettlementMergerEngine {
  /// Sanitize Excel Sheet names: max 31 chars, remove forbidden chars (\ / ? * : [ ])
  static String sanitizeSheetName(String rawName) {
    if (rawName.trim().isEmpty) return 'Other';
    var clean = rawName
        .replaceAll(RegExp(r'[\\/\?\*:\(\)\[\]]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    // Map common long names to clean concise sheet titles
    final lower = clean.toLowerCase();
    if (lower.contains('atm_cw') || lower.contains('atm_cash_withdrawal')) {
      clean = 'ATM_CW';
    } else if (lower.contains('balance_enquiry') || lower.contains('balance_inquiry')) {
      clean = 'Balance_Enquiry';
    } else if (lower.contains('dispute') && lower.contains('chargeback')) {
      clean = 'Dispute_Chargeback';
    } else if (lower.contains('pos_pur')) {
      clean = 'POS_PUR';
    } else if (lower.contains('europay') || lower.contains('retail_chargeback')) {
      clean = 'Europay_Chargeback';
    }

    if (clean.length > 31) {
      clean = clean.substring(0, 31);
    }
    return clean;
  }

  /// Process multiple PlatformFiles and merge into unified sorted dataset + category groups
  static Future<MergedSettlementResult> mergeFiles({
    required List<PlatformFile> files,
    Function(String status, double progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final List<SettlementRowEntity> allRows = [];
    int totalRowsCounted = 0;
    int emptyRowsPurged = 0;
    int duplicateHeadersRemoved = 0;

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final progressFraction = i / files.length;
      if (onProgress != null) {
        onProgress('Reading file ${i + 1}/${files.length}: ${file.name}', progressFraction);
      }

      final rawRows = await _extractRowsFromFile(file);
      totalRowsCounted += rawRows.length;

      if (rawRows.isEmpty) continue;

      // 1. Detect Header Row
      int headerRowIdx = -1;
      Map<String, int> headerMap = {};

      for (int r = 0; r < rawRows.length && r < 15; r++) {
        if (SettlementHeaders.isHeaderRow(rawRows[r])) {
          headerRowIdx = r;
          final headerList = rawRows[r];
          for (int c = 0; c < headerList.length; c++) {
            final colName = headerList[c]?.toString().toLowerCase().trim().replaceAll(' ', '_') ?? '';
            if (colName.isNotEmpty) {
              headerMap[colName] = c;
            }
          }
          break;
        }
      }

      // If no explicit header detected, map default positional columns
      if (headerMap.isEmpty) {
        headerMap = {
          'issuer': 0,
          'acquirer': 1,
          'mti': 2,
          'card_number': 3,
          'amount': 4,
          'currency': 5,
          'transaction_date': 6,
          'transaction_description': 7,
          'terminal_id': 8,
          'transaction_place': 9,
          'stan_f11': 10,
          'refnum_f37': 11,
          'authidresp_f38': 12,
          'fe_utrnno': 13,
          'bo_utrnno': 14,
        };
      }

      // 2. Parse data rows starting after header (or from 0 if no header row)
      final startIdx = headerRowIdx >= 0 ? headerRowIdx + 1 : 0;
      for (int r = startIdx; r < rawRows.length; r++) {
        final row = rawRows[r];

        // Check if row is completely empty
        final isBlank = row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty);
        if (isBlank) {
          emptyRowsPurged++;
          continue;
        }

        // Check if this row is an accidental duplicate header inside the file
        if (SettlementHeaders.isHeaderRow(row)) {
          duplicateHeadersRemoved++;
          continue;
        }

        final entity = SettlementRowEntity.fromRawRow(row, headerMap);
        allRows.add(entity);
      }
    }

    if (onProgress != null) {
      onProgress('Sorting ${allRows.length} transactions chronologically...', 0.85);
    }

    // 3. Sort chronologically by Transaction_Date (Ascending: 28th -> 30th -> 31st)
    allRows.sort((a, b) {
      if (a.parsedDate != null && b.parsedDate != null) {
        return a.parsedDate!.compareTo(b.parsedDate!);
      }
      if (a.parsedDate != null) return -1;
      if (b.parsedDate != null) return 1;
      return a.transactionDate.compareTo(b.transactionDate);
    });

    if (onProgress != null) {
      onProgress('Categorizing into multi-sheet groups...', 0.95);
    }

    // 4. Segment into sheets by Transaction_Description
    final Map<String, List<SettlementRowEntity>> categorized = {};
    double totalVolume = 0.0;

    for (final row in allRows) {
      totalVolume += row.amount;
      final rawCategory = row.transactionDescription.trim().isEmpty ? 'Uncategorized' : row.transactionDescription.trim();
      final sheetKey = sanitizeSheetName(rawCategory);

      categorized.putIfAbsent(sheetKey, () => []).add(row);
    }

    stopwatch.stop();

    if (onProgress != null) {
      onProgress('Merge complete! ${allRows.length} records ready.', 1.0);
    }

    return MergedSettlementResult(
      allMergedRows: allRows,
      categorizedSheets: categorized,
      totalFilesProcessed: files.length,
      totalRowsBefore: totalRowsCounted,
      totalRowsAfter: allRows.length,
      emptyRowsPurged: emptyRowsPurged,
      duplicateHeadersRemoved: duplicateHeadersRemoved,
      totalVolumeAmount: totalVolume,
      processingTime: stopwatch.elapsed,
    );
  }

  /// Extract raw rows from .xls, .xlsx, .csv, .tsv or .txt
  static Future<List<List<dynamic>>> _extractRowsFromFile(PlatformFile file) async {
    List<List<dynamic>> rows = [];

    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      final f = File(file.path!);
      if (await f.exists()) {
        bytes = await f.readAsBytes();
      }
    }

    if (bytes == null || bytes.isEmpty) return rows;

    final ext = file.extension?.toLowerCase() ?? '';
    if (ext == 'xlsx' || ext == 'xls') {
      try {
        final excel = Excel.decodeBytes(bytes);
        for (final table in excel.tables.keys) {
          final tableRows = excel.tables[table]?.rows ?? [];
          for (final row in tableRows) {
            rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
          }
          if (rows.isNotEmpty) break; // Process the primary active sheet
        }
      } catch (_) {
        // If binary xls fail, attempt fallback text reading (many bank reports are tab-delimited text named .xls)
        try {
          final text = utf8.decode(bytes, allowMalformed: true);
          rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(text);
        } catch (_) {}
      }
    } else {
      // CSV / TSV / TXT
      final text = utf8.decode(bytes, allowMalformed: true);
      String delimiter = ',';
      final firstLine = text.split('\n').first;
      if (firstLine.contains('\t')) {
        delimiter = '\t';
      } else if (firstLine.contains(';')) {
        delimiter = ';';
      }

      rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(text);
    }

    return rows;
  }
}
