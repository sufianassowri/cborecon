import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class ExcelParserDatasource {
  /// Reads a single file (.xlsx or .csv) preserving large numeric strings
  static Future<List<List<dynamic>>> parseFile(PlatformFile file) async {
    List<List<dynamic>> rows = [];

    if (file.extension == 'xlsx' || file.extension == 'xls') {
      final bytes = await File(file.path!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          rows.add(row.map((cell) => cell?.value?.toString() ?? "").toList());
        }
        break; // Parse first sheet
      }
    } else if (file.extension == 'csv') {
      final input = await File(file.path!).readAsString();
      rows = const CsvToListConverter().convert(input, eol: '\n');
    }

    return rows;
  }

  /// Picks and parses multiple Settlement files
  static Future<List<List<List<dynamic>>>> pickMultipleFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result == null) return [];

    List<List<List<dynamic>>> allParsedData = [];
    for (var file in result.files) {
      if (file.path != null) {
        var parsed = await parseFile(file);
        if (parsed.isNotEmpty) {
          allParsedData.add(parsed);
        }
      }
    }

    return allParsedData;
  }
}