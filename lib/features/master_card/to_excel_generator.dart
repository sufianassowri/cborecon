import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

/// A utility class to convert data matrices into an Excel (.xlsx) file.
class TsvToExcelConverter {
  /// Converts a data matrix (list of rows) into an Excel file and saves it.
  /// 
  /// [matrix]: The data to write.
  /// [outputFileName]: The name of the file.
  static Future<void> convertMatrixToExcel(List<List<dynamic>> matrix, String outputFileName) async {
    if (matrix.isEmpty) {
      throw Exception("No data to export.");
    }

    var excel = Excel.createExcel();
    String sheetName = "TSV Data";
    
    String firstSheet = excel.sheets.keys.first;
    excel.rename(firstSheet, sheetName);
    Sheet sheet = excel[sheetName];

    // Populate Excel sheet
    for (int rowIndex = 0; rowIndex < matrix.length; rowIndex++) {
      List<CellValue> excelRow = [];
      for (int colIndex = 0; colIndex < matrix[rowIndex].length; colIndex++) {
        final dynamic val = matrix[rowIndex][colIndex];
        // Strictly treat as text to preserve formatting (leading zeros, long IDs)
        excelRow.add(TextCellValue(val?.toString().trim() ?? ''));
      }
      sheet.appendRow(excelRow);
    }

    List<int>? fileBytes = excel.encode();
    if (fileBytes == null) throw Exception("Failed to encode Excel workbook.");

    await FileSaver.instance.saveFile(
      name: outputFileName,
      bytes: Uint8List.fromList(fileBytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
}