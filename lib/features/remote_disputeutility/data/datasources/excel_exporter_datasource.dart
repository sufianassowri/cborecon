import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/dispute_reconciliation_row.dart';

class ExcelExporterDatasource {
  static Future<bool> exportToExcel(List<DisputeReconciliationRow> rows) async {
    try {
      if (rows.isEmpty) return false;

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      List<String> settlementHeaders = rows.first.settlementHeaders;

      List<String> headers = [
        'RECON_STATUS',
        'Id',
        'Branch',
        'FU_Dispute_Id',
        'Account',
        'Amount',
        'Customer',
        'Acquirer Bank',
        'PAN',
        'Transaction Date',
        'Card_Number',
        'Refnum_F37(RRN)',
        'Fe_utrnno',
        ...settlementHeaders,
      ];

      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var row in rows) {
        List<CellValue> rowValues = [
          TextCellValue(row.statusText),
          TextCellValue(row.id),
          TextCellValue(row.branch),
          TextCellValue(row.fuDisputeId),
          TextCellValue(row.account),
          TextCellValue(row.amount),
          TextCellValue(row.customer),
          TextCellValue(row.acquirerBank),
          TextCellValue(row.pan),
          TextCellValue(row.transactionDate),
          TextCellValue(row.cardNumber),
          TextCellValue(row.refnumF37Rrn),
          TextCellValue(row.feUtrnno),
        ];

        for (var h in settlementHeaders) {
          rowValues.add(TextCellValue(row.settlementExtraFields[h] ?? ''));
        }

        sheetObject.appendRow(rowValues);
      }

      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Dispute Reconciliation Report',
        fileName: 'Remote_Dispute_Reconciliation_Report.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        final bytes = excel.encode();
        if (bytes != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}