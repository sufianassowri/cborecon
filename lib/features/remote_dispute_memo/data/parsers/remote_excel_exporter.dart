import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../presentation/providers/remote_dispute_memo_provider.dart';

class RemoteExcelExporter {
  static Future<String?> exportMemoToExcel({
    required RemoteDisputeMemoState state,
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
      'FU Dispute ID', // Added after RRN for Remote On-Us
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
        TextCellValue(item.fuDisputeId), // FU Dispute ID value right after RRN
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
      TextCellValue(''), // Empty spacing cell under RRN
      TextCellValue(''), // Empty spacing cell under FU Dispute ID
    ];
    sheet.appendRow(totalRow);

    // Spacer rows
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('')]);

    // 4. Append Custom Footer for Remote On-Us
    sheet.appendRow([
      TextCellValue(state.disputedAtmAcc),
      DoubleCellValue(summary.totalAmount),
      TextCellValue(''),
      TextCellValue('CUSTOMER ACCOUNT'),
      DoubleCellValue(summary.grandTotal),
    ]);
    sheet.appendRow([
      TextCellValue(state.commPayableAcc),
      DoubleCellValue(summary.totalPl62174),
      TextCellValue(''),
      TextCellValue('Checked By :-${state.checkedBy}'),
    ]);
    sheet.appendRow([
      TextCellValue(state.disasterRiskAcc),
      DoubleCellValue(summary.totalEdrfAmount),
    ]);
    sheet.appendRow([
      TextCellValue('Prepared By: ${state.preparedBy}'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Signature :-  ___________'),
    ]);
    sheet.appendRow([
      TextCellValue('Signature :-  ___________'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Date :$currentDate'),
    ]);
    sheet.appendRow([
      TextCellValue('Date :$currentDate'),
    ]);

    // Save File
    final outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Remote Dispute Memo Excel File',
      fileName: 'RemoteOnUs_Dispute_Memo.xlsx',
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
