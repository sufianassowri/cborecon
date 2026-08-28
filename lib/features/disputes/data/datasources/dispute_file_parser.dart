import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../model/dispute_batch_model.dart';
import '../model/transaction_model.dart';

class ParsedDisputeBatchResult {
  final DisputeBatch batch;
  final List<DisputeTrxn> items;

  ParsedDisputeBatchResult({
    required this.batch,
    required this.items,
  });
}

class DisputeFileParser {
  /// Generate a unique, professional Batch Ticket ID (e.g. DC262394004038000)
  static String generateBatchTicketId() {
    final now = DateTime.now();
    // 2-digit year (e.g. 26) + Day of year + Hour + Minute + Second + Millis
    final dayOfYear = int.parse(DateFormat("D").format(now)).toString().padLeft(3, '0');
    final timeStr = DateFormat("HHmmss").format(now);
    final randomSuffix = (now.microsecond % 900 + 100).toString();
    return "DC${DateFormat('yy').format(now)}$dayOfYear$timeStr$randomSuffix";
  }

  /// Generate sub-DC item ID based on batch ID and 1-based index (e.g. DC262394004038001)
  static String generateItemId(String batchTicketId, int index) {
    if (batchTicketId.length >= 14) {
      final base = batchTicketId.substring(0, batchTicketId.length - 3);
      return "$base${index.toString().padLeft(3, '0')}";
    }
    return "${batchTicketId}_${index.toString().padLeft(3, '0')}";
  }

  /// Parse plain text or raw 6-line dispute content
  /// Format per record:
  /// Line 1: Account (e.g. ETB1764400020478 or 1051800016565)
  /// Line 2: Debit/Credit (D or C)
  /// Line 3: Amount (e.g. 38400)
  /// Line 4: Txn Code (e.g. 1, 51)
  /// Line 5: Narrative 1 (e.g. Deposit Dispute)
  /// Line 6: Narrative 2 (e.g. Deposit Dispute)
  static ParsedDisputeBatchResult parseRawText({
    required String rawText,
    required String fileName,
    required String makerUsername,
    String? customBatchId,
  }) {
    final batchTicketId = customBatchId ?? generateBatchTicketId();
    final valueDateStr = DateFormat('yyyyMMdd').format(DateTime.now());

    final rawLines = const LineSplitter().convert(rawText);
    // Filter out completely empty or comment lines
    final lines = rawLines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    final List<DisputeTrxn> items = [];
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    // Check if it's a delimited text (CSV / TSV) with commas, tabs or semicolons
    if (lines.isNotEmpty && (lines.first.contains(',') || lines.first.contains('\t') || lines.first.contains(';'))) {
      return parseCsvLines(
        lines: lines,
        fileName: fileName,
        makerUsername: makerUsername,
        batchTicketId: batchTicketId,
      );
    }

    // Otherwise, parse as consecutive 6-line records
    int recordIndex = 1;
    for (int i = 0; i < lines.length; i += 6) {
      if (i + 2 >= lines.length) {
        // Less than minimum 3 required fields (Account, D/C, Amount)
        break;
      }

      final account = lines[i];
      final typeRaw = (i + 1 < lines.length) ? lines[i + 1].toUpperCase() : 'D';
      final type = (typeRaw.startsWith('C') || typeRaw == 'CREDIT') ? 'C' : 'D';

      final amountRaw = (i + 2 < lines.length) ? lines[i + 2].replaceAll(',', '') : '0';
      final amount = double.tryParse(amountRaw) ?? 0.0;

      final txnCode = (i + 3 < lines.length) ? lines[i + 3] : (type == 'D' ? '1' : '51');
      final narrative1 = (i + 4 < lines.length) ? lines[i + 4] : 'Deposit Dispute';
      final narrative2 = (i + 5 < lines.length) ? lines[i + 5] : 'Deposit Dispute';

      final itemId = generateItemId(batchTicketId, recordIndex);

      if (type == 'D') {
        totalDebit += amount;
      } else {
        totalCredit += amount;
      }

      items.add(DisputeTrxn(
        batchId: null,
        batchNumber: batchTicketId,
        transactionId: itemId,
        debitAcc: type == 'D' ? account : '',
        creditAcc: type == 'C' ? account : '',
        type: type,
        amount: amount,
        txnCode: txnCode,
        narrative1: narrative1,
        narrative2: narrative2,
        valueDate: valueDateStr,
        recordStatus: 'INAU',
        currency: 'ETB',
        positionType: 'TR',
      ));

      recordIndex++;
    }

    // Check balance with double precision tolerance (e.g. 0.001)
    final isBalanced = (totalDebit - totalCredit).abs() < 0.01;

    final batch = DisputeBatch(
      batchNumber: batchTicketId,
      fileName: fileName,
      transactionCount: items.length,
      totalDebitAmount: totalDebit,
      totalCreditAmount: totalCredit,
      isBalanced: isBalanced,
      status: 'NEW',
      madeBy: makerUsername,
      madeAt: DateTime.now(),
    );

    return ParsedDisputeBatchResult(batch: batch, items: items);
  }

  /// Parse CSV or TSV lines
  static ParsedDisputeBatchResult parseCsvLines({
    required List<String> lines,
    required String fileName,
    required String makerUsername,
    required String batchTicketId,
  }) {
    final valueDateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final List<DisputeTrxn> items = [];
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    int startIndex = 0;
    // Check for header row
    if (lines.first.toLowerCase().contains('acc') ||
        lines.first.toLowerCase().contains('amount') ||
        lines.first.toLowerCase().contains('debit')) {
      startIndex = 1;
    }

    int recordIndex = 1;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> cols;
      if (line.contains('\t')) {
        cols = line.split('\t');
      } else if (line.contains(';')) {
        cols = line.split(';');
      } else {
        cols = line.split(',');
      }

      cols = cols.map((c) => c.trim().replaceAll('"', '')).toList();
      if (cols.isEmpty) continue;

      final account = cols.isNotEmpty ? cols[0] : '';
      final typeRaw = cols.length > 1 ? cols[1].toUpperCase() : 'D';
      final type = (typeRaw.startsWith('C') || typeRaw == 'CREDIT') ? 'C' : 'D';
      final amountRaw = cols.length > 2 ? cols[2].replaceAll(',', '') : '0';
      final amount = double.tryParse(amountRaw) ?? 0.0;
      final txnCode = cols.length > 3 ? cols[3] : (type == 'D' ? '1' : '51');
      final narrative1 = cols.length > 4 ? cols[4] : 'Deposit Dispute';
      final narrative2 = cols.length > 5 ? cols[5] : 'Deposit Dispute';

      final itemId = generateItemId(batchTicketId, recordIndex);

      if (type == 'D') {
        totalDebit += amount;
      } else {
        totalCredit += amount;
      }

      items.add(DisputeTrxn(
        batchId: null,
        batchNumber: batchTicketId,
        transactionId: itemId,
        debitAcc: type == 'D' ? account : '',
        creditAcc: type == 'C' ? account : '',
        type: type,
        amount: amount,
        txnCode: txnCode,
        narrative1: narrative1,
        narrative2: narrative2,
        valueDate: valueDateStr,
        recordStatus: 'INAU',
        currency: 'ETB',
        positionType: 'TR',
      ));

      recordIndex++;
    }

    final isBalanced = (totalDebit - totalCredit).abs() < 0.01;

    final batch = DisputeBatch(
      batchNumber: batchTicketId,
      fileName: fileName,
      transactionCount: items.length,
      totalDebitAmount: totalDebit,
      totalCreditAmount: totalCredit,
      isBalanced: isBalanced,
      status: 'NEW',
      madeBy: makerUsername,
      madeAt: DateTime.now(),
    );

    return ParsedDisputeBatchResult(batch: batch, items: items);
  }

  /// Parse Excel file bytes
  static ParsedDisputeBatchResult parseExcelBytes({
    required Uint8List bytes,
    required String fileName,
    required String makerUsername,
    String? customBatchId,
  }) {
    final batchTicketId = customBatchId ?? generateBatchTicketId();
    final excel = Excel.decodeBytes(bytes);
    final valueDateStr = DateFormat('yyyyMMdd').format(DateTime.now());

    final List<DisputeTrxn> items = [];
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (var table in excel.tables.keys) {
      final rows = excel.tables[table]?.rows ?? [];
      if (rows.isEmpty) continue;

      int startIndex = 0;
      final firstRowValues = rows.first.map((c) => c?.value?.toString().toLowerCase() ?? '').join(' ');
      if (firstRowValues.contains('acc') || firstRowValues.contains('amount') || firstRowValues.contains('debit')) {
        startIndex = 1;
      }

      int recordIndex = 1;
      for (int i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final account = row.isNotEmpty ? row[0]?.value?.toString().trim() ?? '' : '';
        if (account.isEmpty) continue;

        final typeRaw = row.length > 1 ? (row[1]?.value?.toString().trim().toUpperCase() ?? 'D') : 'D';
        final type = (typeRaw.startsWith('C') || typeRaw == 'CREDIT') ? 'C' : 'D';
        final amountRaw = row.length > 2 ? (row[2]?.value?.toString().replaceAll(',', '').trim() ?? '0') : '0';
        final amount = double.tryParse(amountRaw) ?? 0.0;
        final txnCode = row.length > 3 ? (row[3]?.value?.toString().trim() ?? (type == 'D' ? '1' : '51')) : (type == 'D' ? '1' : '51');
        final narrative1 = row.length > 4 ? (row[4]?.value?.toString().trim() ?? 'Deposit Dispute') : 'Deposit Dispute';
        final narrative2 = row.length > 5 ? (row[5]?.value?.toString().trim() ?? 'Deposit Dispute') : 'Deposit Dispute';

        final itemId = generateItemId(batchTicketId, recordIndex);

        if (type == 'D') {
          totalDebit += amount;
        } else {
          totalCredit += amount;
        }

        items.add(DisputeTrxn(
          batchId: null,
          batchNumber: batchTicketId,
          transactionId: itemId,
          debitAcc: type == 'D' ? account : '',
          creditAcc: type == 'C' ? account : '',
          type: type,
          amount: amount,
          txnCode: txnCode,
          narrative1: narrative1,
          narrative2: narrative2,
          valueDate: valueDateStr,
          recordStatus: 'INAU',
          currency: 'ETB',
          positionType: 'TR',
        ));

        recordIndex++;
      }
      break; // Process the first relevant sheet
    }

    final isBalanced = (totalDebit - totalCredit).abs() < 0.01;

    final batch = DisputeBatch(
      batchNumber: batchTicketId,
      fileName: fileName,
      transactionCount: items.length,
      totalDebitAmount: totalDebit,
      totalCreditAmount: totalCredit,
      isBalanced: isBalanced,
      status: 'NEW',
      madeBy: makerUsername,
      madeAt: DateTime.now(),
    );

    return ParsedDisputeBatchResult(batch: batch, items: items);
  }
}
