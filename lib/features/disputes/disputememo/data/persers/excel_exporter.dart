import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../domain/models/memo_format_type.dart';
import '../../presentation/providers/dispute_memo_provider.dart';

class ExcelExporter {
  static Future<String?> exportMemoToExcel({
    required DisputeMemoState state,
  }) async {
    final summary = state.summary;
    if (summary == null) return null;
    final format = state.memoFormat;
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet()!];
    List<String> headers = [];

    if (format == MemoFormatType.fahmi) {
      headers = [
        'CustomerName',
        'PAN',
        'Transaction Date',
        'branch',
        'TRANSREFERANCE',
        'DEBIT ATM Acc',
        'DEBIT VAT ACC',
        'DEBIT E.D.F Acc',
        'Customer_Account',
        'amount',
        '62174',
        'VAT_Amount',
        'E.D.Amount',
        'total',
        'RRN',
      ];
    } else {
      // Geda Format
      headers = [
        'TRANSREFERANCE',
        'Branch',
        'CustomerAccount',
        'amount',
        'CustomerName',
        'PAN',
        'Transaction Date',
        'EDRRF Acount',
        'EDRRF amount',
        'DR ACOUNT',
        'vat acount',
        'vat amount',
        'pl(62174)',
        'total',
        'RETRIEVAL.REF.NO',
      ];
    }

    // 1. Write headers
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // 2. Write Data Rows
    for (var item in summary.items) {
      List<CellValue> row = [];
      if (format == MemoFormatType.fahmi) {
        row = [
          TextCellValue(item.customerName),
          TextCellValue(item.pan),
          TextCellValue(item.transactionDate),
          TextCellValue(item.branch),
          TextCellValue(item.transRef),
          TextCellValue(item.debitAtmAcc),
          TextCellValue(item.debitVatAcc),
          TextCellValue(item.debitEdfAcc),
          TextCellValue(item.customerAccount),
          DoubleCellValue(item.amount),
          DoubleCellValue(item.pl62174),
          DoubleCellValue(item.vatAmount),
          DoubleCellValue(item.edrrfAmount),
          DoubleCellValue(item.total),
          TextCellValue(item.rrn),
        ];
      } else {
        row = [
          TextCellValue(item.transRef),
          TextCellValue(item.branch),
          TextCellValue(item.customerAccount),
          DoubleCellValue(item.amount),
          TextCellValue(item.customerName),
          TextCellValue(item.pan),
          TextCellValue(item.transactionDate),
          TextCellValue(item.debitEdfAcc),
          DoubleCellValue(item.edrrfAmount),
          TextCellValue(item.debitAtmAcc),
          TextCellValue(item.debitVatAcc),
          DoubleCellValue(item.vatAmount),
          DoubleCellValue(item.pl62174),
          DoubleCellValue(item.total),
          TextCellValue(item.rrn),
        ];
      }
      sheet.appendRow(row);
    }

    // 3. Write Summary Total Row
    List<CellValue> totalRow = [];
    if (format == MemoFormatType.fahmi) {
      totalRow = [
        TextCellValue('TOTAL'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(summary.totalAmount),
        DoubleCellValue(summary.totalPl62174),
        DoubleCellValue(summary.totalVatAmount),
        DoubleCellValue(summary.totalEdrfAmount),
        DoubleCellValue(summary.grandTotal),
        TextCellValue(''),
      ];
    } else {
      totalRow = [
        TextCellValue('TOTAL'),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(summary.totalAmount),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(summary.totalEdrfAmount),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(summary.totalVatAmount),
        DoubleCellValue(summary.totalPl62174),
        DoubleCellValue(summary.grandTotal),
        TextCellValue(''),
      ];
    }
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