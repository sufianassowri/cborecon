import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../providers/reconciliation_provider.dart';
import '../../domain/usecases/negative_balance_warning.dart';
import '../../../../core/widgets/responsive_shell.dart';

class ReconciliationDataGrid extends ConsumerStatefulWidget {
  const ReconciliationDataGrid({super.key});

  @override
  ConsumerState<ReconciliationDataGrid> createState() =>
      _ReconciliationDataGridState();
}

class _ReconciliationDataGridState
    extends ConsumerState<ReconciliationDataGrid> {
  PlutoGridStateManager? stateManager;
  final TextEditingController _searchController = TextEditingController();

  final List<String> csvHeaders = [
    'Client ID',
    'PAN',
    'Total Top-Up',
    'Base Amount',
    'Extra Amount',
    'Annual Fee',
    'Total Used',
    'Current Balance',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (stateManager == null) return;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      stateManager!.setFilter(null);
    } else {
      stateManager!.setFilter((row) {
        return row.cells.values.any((cell) {
          final val = cell.value?.toString().toLowerCase() ?? '';
          return val.contains(q);
        });
      });
    }
  }

  void _exportToCsv(
      BuildContext context, List<List<dynamic>> rows, String filename) {
    final String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);

    FilePicker.saveFile(
      dialogTitle: 'Save Reconciliation Ledger',
      fileName: filename,
      bytes: bytes,
    );
  }

  void _exportToExcel(
      BuildContext context, List<List<dynamic>> rows, String filename) {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      for (int r = 0; r < rows.length; r++) {
        for (int c = 0; c < rows[r].length; c++) {
          var cell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
          var val = rows[r][c];
          if (val is double) {
            cell.value = DoubleCellValue(val);
          } else if (val is int) {
            cell.value = IntCellValue(val);
          } else {
            cell.value = TextCellValue(val?.toString() ?? '');
          }
        }
      }

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final outName =
            filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
        FilePicker.saveFile(
          dialogTitle: 'Save Reconciliation Ledger (Excel)',
          fileName: outName,
          bytes: Uint8List.fromList(fileBytes),
        );
      } else {
        _exportToCsv(context, rows, filename);
      }
    } catch (_) {
      _exportToCsv(context, rows, filename);
    }
  }

  Future<void> _pickAndUploadTopUp(
      BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;

      List<List<dynamic>> rawRows = [];
      final ext = file.extension?.toLowerCase();

      if (ext == 'csv') {
        final csvContent = const Utf8Decoder().convert(bytes);
        rawRows = const CsvToListConverter().convert(csvContent);
      } else {
        final excel = Excel.decodeBytes(bytes);
        final sheetName = excel.tables.keys.first;
        final sheet = excel.tables[sheetName];
        if (sheet != null) {
          rawRows = sheet.rows.map((row) {
            return row.map((cell) => cell?.value?.toString() ?? '').toList();
          }).toList();
        }
      }

      if (rawRows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Selected TopUp file is empty or could not be read.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await ref
          .read(masterCardAccountProvider.notifier)
          .uploadTopUpRows(rawRows, fileId: file.name);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Successfully processed TopUp file: ${file.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing TopUp file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadTsv(
      BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tsv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;

      final tsvContent = const Utf8Decoder().convert(bytes);
      final notifier = ref.read(masterCardAccountProvider.notifier);

      final res =
          await notifier.uploadMastercardTsv(tsvContent, fileId: file.name);

      if (res.isDuplicateFile) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Upload Blocked: File "${file.name}" was already uploaded.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (res.warnings.isNotEmpty) {
        if (context.mounted) {
          final confirm =
              await _showNegativeBalanceWarningDialog(context, res.warnings);
          if (confirm == true) {
            await notifier.confirmAndSavePendingTsv(
              accounts: res.warningAccounts,
              transactions: res.warningTransactions,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'TSV file processed and saved with negative balance entries.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Successfully processed TSV file: ${file.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing TSV file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showNegativeBalanceWarningDialog(
    BuildContext context,
    List<NegativeBalanceWarning> warnings,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Negative Balance Warning',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 750,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following clients have no initial top-up or insufficient balance. '
                'Confirm to apply negative balance:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Summary row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${warnings.length} client(s) will have negative balance',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.grey.shade200,
                child: const Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Client ID',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(
                        flex: 4,
                        child: Text('PAN',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text('Current',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text('Projected',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text('Status',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: warnings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final w = warnings[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(w.clientId,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(w.pan,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              w.currentBalance.toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              w.projectedBalance.toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: w.hasTopUp
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  w.hasTopUp
                                      ? 'Insufficient'
                                      : 'No Top-Up',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: w.hasTopUp
                                        ? Colors.orange.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final List<List<dynamic>> exportRows = [
                [
                  'Client ID',
                  'PAN',
                  'Current Balance',
                  'Projected Balance',
                  'Total Used',
                  'Annual Fee',
                  'Has TopUp'
                ],
                ...warnings.map((w) => <dynamic>[
                      w.clientId,
                      w.pan,
                      w.currentBalance,
                      w.projectedBalance,
                      w.totalUsed,
                      w.annualFee,
                      w.hasTopUp,
                    ]),
              ];
              _exportToExcel(
                  context, exportRows, 'negative_balance_clients.xlsx');
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download Negative Clients'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel Upload'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Negative Balance',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(masterCardAccountProvider);

    return ResponsiveShell(
      currentRoute: '/mastercard_reconciliation',
      title: 'Mastercard Ledger Recon',
      subtitle: 'Back4App MasterCard Ledger Matrix & TopUp Tracker',
      body: accountsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: SelectableText(
            'Error loading accounts: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (accounts) {
          final List<PlutoColumn> columns = [
            PlutoColumn(
              title: 'Client ID',
              field: 'clientId',
              type: PlutoColumnType.text(),
              enableRowChecked: true,
              width: 140,
            ),
            PlutoColumn(
              title: 'PAN',
              field: 'pan',
              type: PlutoColumnType.text(),
              width: 180,
            ),
            PlutoColumn(
              title: 'Total Top-Up',
              field: 'topupamount',
              type: PlutoColumnType.number(format: '#,##0.00'),
              textAlign: PlutoColumnTextAlign.right,
              width: 140,
            ),
            PlutoColumn(
              title: 'Base Amount',
              field: 'baseamount',
              type: PlutoColumnType.number(format: '#,##0.00'),
              textAlign: PlutoColumnTextAlign.right,
              width: 130,
            ),
            PlutoColumn(
              title: 'Extra Amount',
              field: 'extraamount',
              type: PlutoColumnType.number(format: '#,##0.00'),
              textAlign: PlutoColumnTextAlign.right,
              width: 130,
            ),
            PlutoColumn(
              title: 'Annual Fee',
              field: 'annualfee',
              type: PlutoColumnType.number(format: '#,##0.00'),
              textAlign: PlutoColumnTextAlign.right,
              width: 130,
            ),
            PlutoColumn(
              title: 'Total Used',
              field: 'TotalUsed',
              type: PlutoColumnType.number(format: '#,##0.00'),
              textAlign: PlutoColumnTextAlign.right,
              width: 140,
            ),
            PlutoColumn(
              title: 'Current Balance',
              field: 'currentBalance',
              type: PlutoColumnType.number(format: '#,##0.00'),
              textAlign: PlutoColumnTextAlign.right,
              width: 160,
            ),
          ];

          final List<PlutoRow> rows = accounts.map((acc) {
            return PlutoRow(cells: {
              'clientId': PlutoCell(value: acc.clientId),
              'pan': PlutoCell(value: acc.pan),
              'topupamount': PlutoCell(value: acc.topupamount),
              'baseamount': PlutoCell(value: acc.baseamount),
              'extraamount': PlutoCell(value: acc.extraamount),
              'annualfee': PlutoCell(value: acc.annualfee),
              'TotalUsed': PlutoCell(value: acc.TotalUsed),
              'currentBalance': PlutoCell(value: acc.currentBalance),
            });
          }).toList();

          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Title + Search
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'MasterCard Accounts (${accounts.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: SizedBox(
                              height: 38,
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search all columns...',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFF1D5C96)),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                                onChanged: (val) {
                                  _onSearchChanged(val);
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Bottom row: Action buttons (wrapping)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: [
                        // Export All button (Excel .xlsx)
                        OutlinedButton.icon(
                          onPressed: accounts.isEmpty
                              ? null
                              : () {
                                  final List<List<dynamic>> exportRows = [
                                    csvHeaders,
                                    ...accounts.map((a) => <dynamic>[
                                          a.clientId,
                                          a.pan,
                                          a.topupamount,
                                          a.baseamount,
                                          a.extraamount,
                                          a.annualfee,
                                          a.TotalUsed,
                                          a.currentBalance,
                                        ]),
                                  ];
                                  _exportToExcel(context, exportRows,
                                      'all_accounts_reconciliation.xlsx');
                                },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export All'),
                        ),
                        // Download Negative Balance Clients (Excel .xlsx)
                        OutlinedButton.icon(
                          onPressed: accounts.isEmpty
                              ? null
                              : () {
                                  final negativeAccounts = accounts
                                      .where((a) => a.currentBalance < 0)
                                      .toList();
                                  if (negativeAccounts.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'No negative balance clients found.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    return;
                                  }
                                  final List<List<dynamic>> exportRows = [
                                    csvHeaders,
                                    ...negativeAccounts.map((a) => <dynamic>[
                                          a.clientId,
                                          a.pan,
                                          a.topupamount,
                                          a.baseamount,
                                          a.extraamount,
                                          a.annualfee,
                                          a.TotalUsed,
                                          a.currentBalance,
                                        ]),
                                  ];
                                  _exportToExcel(context, exportRows,
                                      'negative_balance_clients.xlsx');
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: const Icon(Icons.warning_amber, size: 18),
                          label: const Text('Download -ve Clients'),
                        ),
                        // Upload TopUp Excel/CSV
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _pickAndUploadTopUp(context, ref),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload TopUp Excel/CSV'),
                        ),
                        // Upload Mastercard TSV
                        ElevatedButton.icon(
                          onPressed: () => _pickAndUploadTsv(context, ref),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Upload Mastercard TSV'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PlutoGrid(
                  columns: columns,
                  rows: rows,
                  onLoaded: (event) {
                    stateManager = event.stateManager;
                    stateManager!.setShowColumnFilter(true);
                    if (_searchController.text.isNotEmpty) {
                      _onSearchChanged(_searchController.text);
                    }
                  },
                  onChanged: (event) {
                    if (event.column.field == 'topupamount') {
                      final clientId =
                          event.row.cells['clientId']?.value?.toString() ??
                              '';
                      final newTopup =
                          double.tryParse(event.value.toString()) ?? 0.0;
                      ref
                          .read(masterCardAccountProvider.notifier)
                          .updateTopUpInState(clientId, newTopup);
                    }
                  },
                  rowColorCallback: (context) {
                    final balCell = context.row.cells['currentBalance'];
                    final double balance = double.tryParse(
                            balCell?.value?.toString() ?? '0') ??
                        0.0;
                    if (balance < 0) {
                      return const Color(0xFFF8D7DA); // Light red for negative
                    }
                    return Colors.white;
                  },
                  configuration: const PlutoGridConfiguration(
                    style: PlutoGridStyleConfig(
                      enableCellBorderVertical: true,
                      enableCellBorderHorizontal: true,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}