import 'dart:io';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

void main() {
  final file = File('test_file2.xls');
  final bytes = file.readAsBytesSync();
  try {
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    print('Tables: ${decoder.tables.keys}');
    for (var table in decoder.tables.keys) {
      final sheet = decoder.tables[table]!;
      print('Max rows: ${sheet.maxRows}');
      for (int i = 0; i < sheet.maxRows && i < 10; i++) {
        print(sheet.rows[i]);
      }
    }
  } catch (e) {
    print('Failed with spreadsheet_decoder: $e');
  }
}
