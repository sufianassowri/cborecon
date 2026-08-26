import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelExporterUtil {
  ExcelExporterUtil._();

  /// Convenience wrapper for exporting 2D data matrix to Excel bytes
  static Uint8List exportToExcel({
    required List<String> headers,
    required List<List<dynamic>> rows,
    String sheetName = 'Sheet1',
  }) {
    return createExcelWithTextCells(
      sheetName: sheetName,
      headers: headers,
      rows: rows,
    );
  }

  /// Creates an Excel byte stream preserving exact text format for numeric strings
  static Uint8List createExcelWithTextCells({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[sheetName];

    // Append Header Row
    sheet.appendRow(headers.map((h) => TextCellValue(h.toString())).toList());

    // Append Data Rows as TextCellValue (prevents scientific notation for card/account numbers)
    for (final row in rows) {
      final List<CellValue> cells = row.map((val) {
        return TextCellValue(val != null ? val.toString() : '');
      }).toList();
      sheet.appendRow(cells);
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Creates a multi-tab workbook
  static Uint8List createMultiSheetExcel(Map<String, List<List<dynamic>>> sheetDataMap) {
    final excel = Excel.createExcel();

    for (final entry in sheetDataMap.entries) {
      final sheetName = entry.key;
      final rows = entry.value;
      final Sheet sheet = excel[sheetName];

      for (final row in rows) {
        final List<CellValue> cells = row.map((val) {
          return TextCellValue(val != null ? val.toString() : '');
        }).toList();
        sheet.appendRow(cells);
      }
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }
}
