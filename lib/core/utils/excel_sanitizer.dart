import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Sanitizes raw Excel XLSX bytes by cleaning up `xl/styles.xml`.
/// Removes custom <numFmts> blocks and resets cell format IDs to standard General (0).
Uint8List sanitizeExcelBytes(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sanitizedArchive = Archive();

    for (final file in archive) {
      if (file.isFile && file.name == 'xl/styles.xml') {
        String xmlContent = utf8.decode(file.content as List<int>);

        // 1. Remove custom <numFmts>...</numFmts> block
        xmlContent = xmlContent.replaceAll(
          RegExp(r'<numFmts[^>]*>.*?</numFmts>', dotAll: true),
          '',
        );

        // 2. Remove numFmtsCount attribute from <styleSheet> header
        xmlContent = xmlContent.replaceAll(
          RegExp(r'numFmtsCount="\d+"'),
          '',
        );

        // 3. Reset custom format references (numFmtId >= 43) back to standard General (0)
        xmlContent = xmlContent.replaceAllMapped(
          RegExp(r'numFmtId="(\d+)"'),
          (match) {
            final id = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (id >= 43) {
              return 'numFmtId="0"';
            }
            return match.group(0)!;
          },
        );

        final updatedBytes = utf8.encode(xmlContent);
        sanitizedArchive.addFile(
          ArchiveFile(file.name, updatedBytes.length, updatedBytes),
        );
      } else {
        final content = file.content as List<int>;
        sanitizedArchive.addFile(
          ArchiveFile(file.name, content.length, content),
        );
      }
    }

    final encoded = ZipEncoder().encode(sanitizedArchive);
    return encoded != null ? Uint8List.fromList(encoded) : bytes;
  } catch (_) {
    return bytes;
  }
}
