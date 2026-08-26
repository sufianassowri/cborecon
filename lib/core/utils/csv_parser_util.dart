import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../errors/failures.dart';

class CsvParserUtil {
  CsvParserUtil._();

  /// Parses raw CSV bytes into 2D table list with error handling
  static List<List<dynamic>> parseBytes(Uint8List bytes) {
    try {
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      // Strip BOM and zero-width/non-printable characters that corrupt headers
      content = content.replaceAll('\uFEFF', ''); // UTF-8 BOM
      content = content.replaceAll('\uFFFE', ''); // UTF-16 LE BOM
      content = content.replaceAll('\u200B', ''); // Zero-width space
      content = content.replaceAll('\u200C', ''); // Zero-width non-joiner
      content = content.replaceAll('\u200D', ''); // Zero-width joiner
      content = content.replaceAll('\u00A0', ' '); // Non-breaking space → regular space
      return const CsvToListConverter(shouldParseNumbers: false).convert(content);
    } catch (e) {
      throw FileParsingFailure('Failed to parse CSV file: $e');
    }
  }

  /// Converts 2D list into a CSV string
  static String convertToCsv(List<List<dynamic>> data) {
    return const ListToCsvConverter().convert(data);
  }

  /// Sanitizes header list by trimming whitespace, replacing empty names, and ensuring uniqueness.
  static List<String> sanitizeHeaders(List<dynamic> rawHeaders) {
    final List<String> result = [];
    final Map<String, int> counts = {};

    for (int i = 0; i < rawHeaders.length; i++) {
      String h = rawHeaders[i]?.toString().trim() ?? '';
      if (h.isEmpty) {
        h = 'Column_${i + 1}';
      }

      if (!counts.containsKey(h)) {
        counts[h] = 1;
        result.add(h);
      } else {
        int count = counts[h]! + 1;
        counts[h] = count;
        String uniqueHeader = '${h}_$count';
        while (result.contains(uniqueHeader) || counts.containsKey(uniqueHeader)) {
          count++;
          uniqueHeader = '${h}_$count';
        }
        counts[uniqueHeader] = 1;
        result.add(uniqueHeader);
      }
    }
    return result;
  }
}
