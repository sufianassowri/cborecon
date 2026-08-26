import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../constants/remote_dispute_payable_tables.dart';

class ImportResult {
  final int added;
  final int skipped;
  final bool success;
  final String? message;
  final List<dynamic> duplicates; // Added parameter

  ImportResult({
    required this.added,
    required this.skipped,
    required this.success,
    this.message,
    this.duplicates = const [],
  });
}

class RemoteDisputePayableImporter {
  static Future<ImportResult> importPayableCsv(String className) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return ImportResult(added: 0, skipped: 0, success: false, message: "No file selected.");
    }

    final bytes = result.files.single.bytes!;
    final base64File = base64Encode(bytes);

    final ParseCloudFunction function = ParseCloudFunction(RemoteDisputePayableTables.importCsvFunction);

    final Map<String, dynamic> params = {
      'base64File': base64File,
      'className': className,
    };

    final ParseResponse response = await function.execute(parameters: params);

    if (response.success && response.result != null) {
      final res = response.result;
      return ImportResult(
        added: res['added'] ?? 0,
        skipped: res['skipped'] ?? 0,
        success: true,
        duplicates: res['duplicates'] ?? [],
      );
    } else {
      return ImportResult(
        added: 0,
        skipped: 0,
        success: false,
        message: response.error?.message ?? "Cloud processing failed.",
      );
    }
  }
}