import 'dart:io';
import 'package:excel/excel.dart';
import '../../../../core/utils/excel_sanitizer.dart';
import '../../domain/entities/reconciled_summary.dart';
import '../models/mc_transaction_model.dart';
import '../models/topup_record_model.dart';

abstract class McReconciliationLocalDataSource {
  Future<List<TopUpRecordModel>> readTopUpExcelFile(String filePath);
  Future<List<McTransactionModel>> readTsvFile(String filePath);
  Future<void> exportSummaryExcel(
      List<ReconciledSummary> summaries,
      String outputPath,
      );
}

class McReconciliationLocalDataSourceImpl
    implements McReconciliationLocalDataSource {
  @override
  Future<List<TopUpRecordModel>> readTopUpExcelFile(String filePath) async {
    final file = File(filePath);
    final rawBytes = await file.readAsBytes();

    // Pass raw bytes through sanitizer to strip custom numFmt tags
    final sanitizedBytes = sanitizeExcelBytes(rawBytes);
    final excel = Excel.decodeBytes(sanitizedBytes);

    final List<TopUpRecordModel> records = [];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows <= 1) continue;

      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final firstCell = row[0];
        if (firstCell == null || firstCell.value == null) continue;

        try {
          final record = TopUpRecordModel.fromExcelRow(row);
          records.add(record);
        } catch (_) {}
      }
    }
    return records;
  }

  @override
  Future<List<McTransactionModel>> readTsvFile(String filePath) async {
    final file = File(filePath);
    final lines = await file.readAsLines();
    final List<McTransactionModel> transactions = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split('\t');
      try {
        final transaction = McTransactionModel.fromTsvRow(columns);
        transactions.add(transaction);
      } catch (_) {}
    }

    return transactions;
  }

  @override
  Future<void> exportSummaryExcel(
      List<ReconciledSummary> summaries,
      String outputPath,
      ) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Reconciliation Summary'];
    excel.setDefaultSheet('Reconciliation Summary');

    // Headers
    sheet.appendRow([
      TextCellValue('Client ID'),
      TextCellValue('PAN'),
      TextCellValue('Initial Balance'),
      TextCellValue('Total Base Amount'),
      TextCellValue('Annual Fee'),
      TextCellValue('Expected Rem.'),
      TextCellValue('Actual Rem.'),
      TextCellValue('Variance'),
      TextCellValue('Status'),
    ]);

    // Data rows
    for (final summary in summaries) {
      sheet.appendRow([
        TextCellValue(summary.clientId),
        TextCellValue(summary.pan),
        DoubleCellValue(summary.initialBalance),
        DoubleCellValue(summary.totalBaseAmount),
        DoubleCellValue(summary.annualFee),
        DoubleCellValue(summary.expectedRemaining),
        DoubleCellValue(summary.actualRemaining),
        DoubleCellValue(summary.variance),
        TextCellValue(summary.status.name),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(outputPath);
      await file.writeAsBytes(fileBytes);
    }
  }
}