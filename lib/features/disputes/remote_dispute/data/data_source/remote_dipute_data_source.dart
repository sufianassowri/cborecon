import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
//Updated Controller Logic (file_upload_service.dart)
class FileUploadService {
  static Future<void> pickAndProcessFile({
    required Function(String status) onStatusUpdate,
    required Function(String successMessage) onSuccess,
    required Function(String errorMessage) onError,
    required Function() onCancel,
  }) async {
    try {
      // 1. Pick any of your allowed file types
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.single.path == null) {
        onCancel();
        return;
      }

      File localFile = File(result.files.single.path!);
      String fileName = p.basename(localFile.path);
      String fileExtension = p.extension(localFile.path).toLowerCase().replaceAll('.', '');

      onStatusUpdate("Uploading '$fileName' to Back4app secure storage...");

      // 2. Upload the raw file directly to Back4app storage
      ParseFile parseFile = ParseFile(localFile, name: fileName);
      ParseResponse uploadResponse = await parseFile.save();

      if (!uploadResponse.success || uploadResponse.result == null) {
        onError("File upload failed: ${uploadResponse.error?.message}");
        return;
      }

      ParseFile uploadedFile = uploadResponse.result as ParseFile;
      String? fileUrl = uploadedFile.url;

      if (fileUrl == null) {
        onError("Failed to retrieve file URL from backend.");
        return;
      }

      onStatusUpdate("File saved. Triggering Back4app Cloud Code parser...");

      // 3. Trigger the Cloud Code function to handle the heavy lifting
      final ParseCloudFunction cloudFunction = ParseCloudFunction('processUploadedFile');

      final Map<String, dynamic> params = {
        'fileUrl': fileUrl,
        'fileType': fileExtension,
        'fileName': fileName,
      };

      final ParseResponse cloudResponse = await cloudFunction.execute(parameters: params);

      if (cloudResponse.success) {
        // Look for the clean string map message returned by your JS function
        final resultData = cloudResponse.result;
        String successDetail = "File processed successfully.";
        if (resultData is Map && resultData.containsKey('message')) {
          successDetail = resultData['message'];
        }
        onSuccess(successDetail);
      } else {
        onError("Server Processing Error: ${cloudResponse.error?.message}");
      }
    } catch (e) {
      onError("An unexpected error occurred: $e");
    }
  }
}