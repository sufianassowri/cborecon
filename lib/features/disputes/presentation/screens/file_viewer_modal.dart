import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class FileViewerModal extends StatefulWidget {
  final String title;
  final Uint8List? fileBytes;
  final VoidCallback onClose;

  const FileViewerModal({super.key, required this.title, this.fileBytes, required this.onClose});

  @override
  State<FileViewerModal> createState() => _FileViewerModalState();
}

class _FileViewerModalState extends State<FileViewerModal> {
  bool _isTextFile = false;
  String _textContent = '';
  PdfDocument? _document;
  PdfPageImage? _pageImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _handleFileDisplay();
  }

  // Main logic to determine how to display the file bytes
  Future<void> _handleFileDisplay() async {
    if (widget.fileBytes == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Logic based on filename/content
    final lowerTitle = widget.title.toLowerCase();
    if (lowerTitle.contains('.txt') || lowerTitle.contains('ej')) {
      // It's a text file (Electronic Journal log)
      setState(() {
        _textContent = String.fromCharCodes(widget.fileBytes!);
        _isTextFile = true;
        _isLoading = false;
      });
    } else if (lowerTitle.contains('.pdf')) {
      // It's a PDF document
      await _loadPdfFromBytes(widget.fileBytes!);
    } else {
      // Assume it's an image (JPG/PNG)
      setState(() {
        _isTextFile = false;
        _pageImage = null; // We'll render directly in the build method
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPdfFromBytes(Uint8List bytes) async {
    try {
      _document = await PdfDocument.openData(bytes);
      final page = await _document!.getPage(1); // Render the first page
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,
      );

      setState(() {
        _pageImage = pageImage;
        _isTextFile = false;
        _isLoading = false;
      });
      await page.close(); // Important to prevent memory leaks
    } catch (e) {
      setState(() {
        _isTextFile = false;
        _isLoading = false;
      });
      debugPrint('Error parsing PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white, // Light modal against dark UI
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: const BorderRadius.vertical(top: Radius.circular(7))),
            child: Row(
              children: [
                const Icon(Icons.description, size: 18, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black))),
                InkWell(onTap: widget.onClose, child: const Icon(Icons.close, size: 18, color: Colors.grey)),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : widget.fileBytes == null
                ? const Center(child: Text('File not found.', style: TextStyle(color: Colors.black54)))
                : _isTextFile
                ? SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Text(_textContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black87)),
            )
                : _pageImage != null
                ? InteractiveViewer(child: Image.memory(_pageImage!.bytes)) // Display PDF Page
                : InteractiveViewer(child: Image.memory(widget.fileBytes!)), // Display standard Image
          ),
        ],
      ),
    );
  }
}