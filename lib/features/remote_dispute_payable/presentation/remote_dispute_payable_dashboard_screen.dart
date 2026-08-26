import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:csv/csv.dart';
import '../constants/remote_dispute_payable_tables.dart';
import '../services/remote_dispute_payable_importer.dart';

class RemoteDisputePayableDashboardScreen extends StatefulWidget {
  const RemoteDisputePayableDashboardScreen({super.key});

  @override
  State<RemoteDisputePayableDashboardScreen> createState() => _RemoteDisputePayableDashboardScreenState();
}

class _RemoteDisputePayableDashboardScreenState extends State<RemoteDisputePayableDashboardScreen> {
  bool _isUploading = false;
  int _savedCount = 0;
  int _duplicateCount = 0;
  bool _hasExecuted = false;

  List<PlutoColumn> columns = [];
  List<PlutoRow> rows = [];
  PlutoGridStateManager? stateManager;
  List<dynamic> _rawDuplicatesList = [];

  @override
  void initState() {
    super.initState();
    _initializeGridHeaders();
  }

  void _initializeGridHeaders() {
    columns = [
      PlutoColumn(
        title: 'Transaction Ref',
        field: 'TRANSREF',
        type: PlutoColumnType.text(),
        enableRowChecked: true,
      ),
      PlutoColumn(
        title: 'Card PAN Number',
        field: 'PANNUMBER',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Value Date',
        field: 'VALUEDATE',
        type: PlutoColumnType.text(),
        width: 120,
      ),
      PlutoColumn(
        title: 'Debit Account',
        field: 'DEBITACCTNO',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'TXNAMOUNT',
        type: PlutoColumnType.number(format: '#,###.00'),
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Retrieval Ref (RRN)',
        field: 'RETRIEVALREFNO',
        type: PlutoColumnType.text(),
      ),
    ];
  }

  void _populateGridRows(List<dynamic> duplicates) {
    _rawDuplicatesList = duplicates;
    List<PlutoRow> newRows = duplicates.map((rowMap) {
      return PlutoRow(
        cells: {
          'TRANSREF': PlutoCell(value: rowMap['TRANSREF']?.toString() ?? ''),
          'PANNUMBER': PlutoCell(value: rowMap['PANNUMBER']?.toString() ?? ''),
          'VALUEDATE': PlutoCell(value: rowMap['VALUEDATE']?.toString() ?? ''),
          'DEBITACCTNO': PlutoCell(value: rowMap['DEBITACCTNO']?.toString() ?? ''),
          'TXNAMOUNT': PlutoCell(value: double.tryParse(rowMap['TXNAMOUNT']?.toString() ?? '0') ?? 0.0),
          'RETRIEVALREFNO': PlutoCell(value: rowMap['RETRIEVALREFNO']?.toString() ?? ''),
        },
      );
    }).toList();

    if (stateManager != null) {
      stateManager!.removeRows(stateManager!.rows);
      stateManager!.appendRows(newRows);
    } else {
      setState(() {
        rows = newRows;
      });
    }
  }

  /// Compiles raw string payloads into downloadable comma-separated documents
  Future<void> _downloadDuplicatesCsv() async {
    if (_rawDuplicatesList.isEmpty) return;

    final List<String> csvHeaders = [
      'TRANSREF',
      'PANNUMBER',
      'VALUEDATE',
      'DEBITACCTNO',
      'TXNAMOUNT',
      'RETRIEVALREFNO'
    ];

    // 1. Build a multi-dimensional array representing rows and columns
    List<List<dynamic>> csvMatrix = [];

    // Append the header columns
    csvMatrix.add(csvHeaders);

    // Append the row values mapped safely by column keys
    for (var row in _rawDuplicatesList) {
      List<dynamic> rowValues = csvHeaders.map((header) {
        return row[header] ?? '';
      }).toList();
      csvMatrix.add(rowValues);
    }

    // 2. Format the matrix using the ListToCsvConverter
    // This safely wraps strings containing commas, quotes, or newlines in double quotes
    String csvContent = const ListToCsvConverter().convert(csvMatrix);
    Uint8List fileBytes = Uint8List.fromList(utf8.encode(csvContent));

    try {
      // 3. Hand off the raw bytes to file_saver to initiate the download dialogue window
      await FileSaver.instance.saveFile(
        name: 'duplicate_settlements_investigation',
        bytes: fileBytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Duplicates exported successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to export file: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: const Text('Remote Dispute Payable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaction Settlement Sync',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload settlement files to synchronize databases safely. System verifies duplicates using TRANSREF and RRN arrays.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Execution Analytics Metric Cards Display
                if (_hasExecuted) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                            title: "Records Synchronized",
                            count: _savedCount,
                            color: Colors.green,
                            icon: Icons.cloud_done
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricTile(
                            title: "Duplicates Detected",
                            count: _duplicateCount,
                            color: Colors.orange,
                            icon: Icons.copy
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isUploading ? null : () async {
                      setState(() => _isUploading = true);

                      try {
                        final result = await RemoteDisputePayableImporter.importPayableCsv(
                          RemoteDisputePayableTables.remoteDisputePayableClass,
                        );

                        if (mounted && result.success) {
                          setState(() {
                            _savedCount = result.added;
                            _duplicateCount = result.skipped;
                            _hasExecuted = true;
                          });
                          _populateGridRows(result.duplicates);
                        } else if (mounted && result.message != "No file selected.") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Import Error: ${result.message}"), backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Critical Core Error: $e"), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isUploading = false);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.upload_file, size: 28, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Upload Settlement CSV File",
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text("Click to select template file and evaluate matches",
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          if (_isUploading)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Dynamic PlutoGrid Table Container Area Layout
                if (_hasExecuted && _duplicateCount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Duplicate Records Logs Window ($_duplicateCount items)",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _downloadDuplicatesCsv,
                        icon: const Icon(Icons.download_for_offline, size: 18),
                        label: const Text("Export Duplicates (.CSV)"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PlutoGrid(
                          columns: columns,
                          rows: rows,
                          onChanged: (PlutoGridOnChangedEvent event) {},
                          onLoaded: (PlutoGridOnLoadedEvent event) {
                            stateManager = event.stateManager;
                            stateManager!.setShowColumnFilter(true); // Enables inline grid data searches
                          },
                          configuration: const PlutoGridConfiguration(
                            style: PlutoGridStyleConfig(
                              gridBorderColor: Colors.amber,
                              rowHeight: 45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (_hasExecuted && _duplicateCount == 0) ...[
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified, size: 48, color: Colors.green),
                          SizedBox(height: 12),
                          Text("Perfect Reconciliation Sync!", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Zero structural duplicate references identified inside payload", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Expanded(
                    child: Center(
                      child: Text("Select an application reconciliation spreadsheet file to begin logging dashboards.",
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                ],
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 16),
                        Text("Verifying duplicate logs. Synchronizing balances...",
                            style: TextStyle(fontWeight: FontWeight.w200, fontSize: 14))
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String title, required int count, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text(
                  count.toString(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)
              ),
            ],
          )
        ],
      ),
    );
  }
}