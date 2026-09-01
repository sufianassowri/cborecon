import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../presentation/providers/dispute_memo_provider.dart';

class ExcelExporter {
  static Future<String?> exportMemoToExcel({
    required DisputeMemoState state,
  }) async {
    final summary = state.summary;
    if (summary == null) return null;
    
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet()!];
    
    final List<String> headers = [
      'TRANS_REFERANCE',
      'PAN',
      'Transaction Date',
      'CustomerAccount',
      'Customer Name',
      'Acquirer Bank',
      'Branch',
      'VAT Account',
      'Amount',
      'Com_amount',
      'Disaster commission',
      'VAT amount',
      'TOTAL',
      'RRN',
    ];

    // 1. Write headers
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // 2. Write Data Rows
    for (var item in summary.items) {
      final List<CellValue> row = [
        TextCellValue(item.transRef),
        TextCellValue(item.pan),
        TextCellValue(item.transactionDate),
        TextCellValue(item.customerAccount),
        TextCellValue(item.customerName),
        TextCellValue(item.acquirerBank),
        TextCellValue(item.branch),
        TextCellValue(item.debitVatAcc),
        DoubleCellValue(item.amount),
        DoubleCellValue(item.pl62174),
        DoubleCellValue(item.edrrfAmount),
        DoubleCellValue(item.vatAmount),
        DoubleCellValue(item.total),
        TextCellValue(item.rrn),
      ];
      sheet.appendRow(row);
    }

    // 3. Write Summary Total Row
    final List<CellValue> totalRow = [
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(summary.totalAmount),
      DoubleCellValue(summary.totalPl62174),
      DoubleCellValue(summary.totalEdrfAmount),
      DoubleCellValue(summary.totalVatAmount),
      DoubleCellValue(summary.grandTotal),
      TextCellValue(''), 
    ];
    sheet.appendRow(totalRow);

    // Spacer rows
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('')]);

    // 4. Append Custom Footer based on Dispute Type

      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Prepared By: ${state.preparedBy}'),
        TextCellValue(''),
        TextCellValue('Checked By: ${state.checkedBy}'),
      ]);
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Signature :-  ___________'),
        TextCellValue(''),
        TextCellValue('Signature :-  ___________'),
      ]);
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Date: $currentDate'),
        TextCellValue(''),
        TextCellValue('Date: $currentDate'),
      ]);

    // Save File
    final outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Dispute Memo Excel File',
      fileName: 'OnUs_Dispute_Memo.xlsx',
      allowedExtensions: ['xlsx'],
      type: FileType.custom,
    );

    if (outputFile != null) {
      final bytes = excel.save();
      if (bytes != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        return outputFile;
      }
    }
    return null;
  }
}