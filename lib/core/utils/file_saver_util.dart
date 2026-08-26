import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import '../errors/failures.dart';

class FileSaverUtil {
  FileSaverUtil._();

  /// Saves generic raw bytes with filename
  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : '';
      final name = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

      return await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: ext,
        mimeType: ext == 'xlsx' ? MimeType.microsoftExcel : (ext == 'csv' ? MimeType.csv : MimeType.other),
      );
    } catch (e) {
      throw ReconciliationFailure('Failed to save file: $e');
    }
  }

  /// Saves CSV data using native OS dialog
  static Future<String?> saveCsv({
    required String baseName,
    required String csvContent,
  }) async {
    try {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final String fileName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}';

      return await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (e) {
      throw ReconciliationFailure('Failed to export CSV: $e');
    }
  }

  /// Saves Excel bytes using native OS dialog
  static Future<String?> saveExcel({
    required String baseName,
    required Uint8List bytes,
  }) async {
    try {
      final String fileName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}';

      return await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } catch (e) {
      throw ReconciliationFailure('Failed to export Excel: $e');
    }
  }
}
