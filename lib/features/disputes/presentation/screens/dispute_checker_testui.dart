import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:http/http.dart' as http;
// Import the file viewer modal and providers we define next
import '../controllers/test_database.dart';
import '../controllers/testui_providers.dart';
import 'file_viewer_modal.dart';
class CheckerUI extends ConsumerStatefulWidget {
  const CheckerUI({super.key});

  @override
  ConsumerState<CheckerUI> createState() => _CheckerUIState();
}

class _CheckerUIState extends ConsumerState<CheckerUI> {
  final List<PlutoColumn> columns = [];
  final List<PlutoRow> rows = [];
  bool _isFileViewerVisible = false;
  String _currentFileTitle = '';
  Uint8List? _currentFileBytes;

  @override
  void initState() {
    super.initState();
    _buildColumns();
  }

  // Definition of the grid structure
  void _buildColumns() {
    columns.addAll([
      PlutoColumn(
        title: 'Terminal code',
        field: 'terminalcode',
        type: PlutoColumnType.text(),
        width: 150,
      ),
      // Icon columns for file viewing
      _buildFileViewColumn('View EJ', 'ej_file_icon', 'EJ Log.txt'),
      _buildFileViewColumn('View Confirmn', 'conf_file_icon', 'Confirmation.pdf'),
      _buildFileViewColumn('cr,dr recipt', 'receipt_file_icon', 'Receipt.png'),
    ]);
  }

  // Helper function to create the non-icon text button mapping
  PlutoColumn _buildFileViewColumn(String title, String field, String viewName) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.text(),
      width: 120,
      enableEditingMode: false,
      renderer: (rendererContext) {
        final fileUrl = rendererContext.cell.value.toString();
        if (fileUrl.isEmpty) return const SizedBox.shrink();

        return TextButton(
          onPressed: () => _openViewerFromUrl(fileUrl, viewName),
          child: const Text('View', style: TextStyle(fontSize: 10, color: Color(0xFF00E5FF))),
        );
      },
    );
  }

  // The logic that downloads the file from Back4App and shows the modal
  Future<void> _openViewerFromUrl(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _currentFileTitle = 'File Viewer: $fileName';
          _currentFileBytes = response.bodyBytes;
          _isFileViewerVisible = true;
        });
      } else {
        throw Exception("Failed to load file");
      }
    } catch (e) {
      debugPrint("Error loading file: $e");
    }
  }

  // Map the ParseObjects from Back4App into PlutoRows
// Change List<ParseObject> to List<Transaction>
  void _mapDataToRows(List<Transaction> transactions) {
    rows.clear();
    for (var item in transactions) {
      rows.add(PlutoRow(cells: {
        // Use your model's properties directly
        'terminalcode': PlutoCell(value: item.terminalCode),
        'ej_file_icon': PlutoCell(value: item.ejUrl),
        'conf_file_icon': PlutoCell(value: item.confUrl),
        'receipt_file_icon': PlutoCell(value: item.receiptUrl),
      }));
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Listen to the provider which now returns List<Transaction>
    final transactionAsync = ref.watch(transactionListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("Checker UI", style: TextStyle(color: Color(0xFF00E5FF)))),
      body: Stack(
        children: [
          // 1. The main grid data
          transactionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
            error: (err, stack) => Center(child: Text('Error loading transactions: $err')),
            // CHANGED: Update the type here from ParseObject to Transaction
            data: (List<Transaction> transactions) {
              _mapDataToRows(transactions);
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: PlutoGrid(
                  columns: columns,
                  rows: rows,
                  configuration: PlutoGridConfiguration(
                    style: PlutoGridStyleConfig(
                      gridBorderColor: Colors.white24,
                      columnTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      cellTextStyle: const TextStyle(color: Colors.white70),
                      // Added to ensure dark theme visibility in the grid
                      activatedColor: Colors.blueGrey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. The File Viewer Modal (overlay)
          if (_isFileViewerVisible)
            Positioned(
              bottom: 40,
              right: 20,
              width: 380,
              child: FileViewerModal(
                title: _currentFileTitle,
                fileBytes: _currentFileBytes,
                onClose: () => setState(() => _isFileViewerVisible = false),
              ),
            ),
        ],
      ),
    );
  }
}