import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../../core/widgets/responsive_shell.dart';
import '../../../../../core/widgets/responsive_row.dart';
import '../../data/persers/excel_exporter.dart';
import '../../domain/models/dispute_memo_item.dart';
import '../../domain/models/memo_format_type.dart';
import '../providers/dispute_memo_provider.dart';

class DisputeMemoPage extends ConsumerStatefulWidget {
  const DisputeMemoPage({Key? key}) : super(key: key);
  @override
  ConsumerState<DisputeMemoPage> createState() => _DisputeMemoPageState();
}

class _DisputeMemoPageState extends ConsumerState<DisputeMemoPage> {
  late TextEditingController _preparedByController;
  late TextEditingController _checkedByController;
  late TextEditingController _atmAccController;
  late TextEditingController _commAccController;
  late TextEditingController _disasterAccController;
  @override
  void initState() {
    super.initState();
    final state = ref.read(disputeMemoProvider);
    _preparedByController = TextEditingController(text: state.preparedBy);
    _checkedByController = TextEditingController(text: state.checkedBy);
    _atmAccController = TextEditingController(text: state.disputedAtmAcc);
    _commAccController = TextEditingController(text: state.commPayableAcc);
    _disasterAccController = TextEditingController(text: state.disasterRiskAcc);
  }

  /// Complete reset helper to clear provider state and UI text fields
  void _resetState() {
    ref.invalidate(disputeMemoProvider);
    _preparedByController.clear();
    _checkedByController.clear();
    _atmAccController.clear();
    _commAccController.clear();
    _disasterAccController.clear();
  }

  @override
  void dispose() {
    _preparedByController.dispose();
    _checkedByController.dispose();
    _atmAccController.dispose();
    _commAccController.dispose();
    _disasterAccController.dispose();

    ref.invalidate(disputeMemoProvider);
    super.dispose();
  }

  Future<void> _pickFile(bool isAtmEnq) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final notifier = ref.read(disputeMemoProvider.notifier);
      if (isAtmEnq) {
        notifier.setAtmEnqPath(path);
      } else {
        notifier.setDisputeReportPath(path);
      }
    }
  }

  Future<void> _downloadExcel() async {
    final state = ref.read(disputeMemoProvider);
    if (state.summary == null) return;
    try {
      final savedPath = await ExcelExporter.exportMemoToExcel(
        state: state,
      );
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Memo successfully saved to: $savedPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Custom Cell Renderer that bolds text for the TOTAL row
  Widget _cellRenderer(PlutoColumnRendererContext context,
      {bool isNumber = false}) {
    final isTotalRow = context.row.cells['name']?.value == 'TOTAL' ||
        context.row.cells['ref']?.value == 'TOTAL';

    final value = context.cell.value;
    String displayValue = '';

    if (value != null) {
      if (isNumber && value is num) {
        displayValue = value.toStringAsFixed(2);
      } else {
        displayValue = value.toString();
      }
    }

    return Align(
      alignment: isNumber ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        displayValue,
        style: TextStyle(
          fontWeight: isTotalRow ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(disputeMemoProvider);

    return ResponsiveShell(
      currentRoute: '/dispute_memo',
      title: 'Dispute Memo Generator',
      subtitle: 'On-Us & Remote On-Us Accounting Memo Utility',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reset Form & Data',
          onPressed: _resetState,
        ),
        if (state.summary != null)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _downloadExcel,
              icon: const Icon(Icons.download),
              label: const Text('Export Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickFile(true),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        state.atmEnqPath == null
                            ? 'Load ATM ENQ File'
                            : 'ATM ENQ Loaded',
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickFile(false),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        state.disputeReportPath == null
                            ? 'Load Dispute File'
                            : 'Dispute Loaded',
                      ),
                    ),
                    // Removed MemoFormatType dropdown
                    OutlinedButton.icon(
                      onPressed: _resetState,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Error: ${state.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.summary == null
                      ? const Center(
                          child: Text(
                            'Select ATM ENQ and Dispute reports to Prepare memo.',
                          ),
                        )
                      : PlutoGrid(
                          rowColorCallback:
                              (PlutoRowColorContext rowColorContext) {
                            final isTotalRow =
                                rowColorContext.row.cells['name']?.value ==
                                        'TOTAL' ||
                                    rowColorContext.row.cells['ref']?.value ==
                                        'TOTAL';
                            if (isTotalRow) {
                              return Colors.grey.shade300;
                            }
                            return Colors.white;
                          },
                          configuration: PlutoGridConfiguration(
                            columnSize: const PlutoGridColumnSizeConfig(
                              autoSizeMode: PlutoAutoSizeMode.scale,
                              resizeMode: PlutoResizeMode.pushAndPull,
                            ),
                            style: PlutoGridStyleConfig(
                              evenRowColor: Colors.green,
                              gridBackgroundColor: Colors.black,
                              columnTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              cellTextStyle: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          key: const ValueKey('onUs'),
                          columns: _buildColumns(),
                          rows: _buildRows(state.summary!),
                        ),
            ),
            const SizedBox(height: 12),
            if (state.summary != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildOnUsFooter(state),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Simple Prepared By / Checked By Footer for On-Us
  Widget _buildOnUsFooter(DisputeMemoState state) {
    return ResponsiveRow(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _preparedByController,
                onChanged: (val) => ref.read(disputeMemoProvider.notifier).updateAccounts(preparedBy: val),
                decoration: const InputDecoration(labelText: 'Prepared By', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _checkedByController,
                onChanged: (val) => ref.read(disputeMemoProvider.notifier).updateAccounts(checkedBy: val),
                decoration: const InputDecoration(labelText: 'Checked By', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: (state.commissionRate * 100).toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Commission Rate (%)', border: OutlineInputBorder()),
                onChanged: (val) {
                  final rate = double.tryParse(val);
                  if (rate != null) {
                    ref.read(disputeMemoProvider.notifier).updateAccounts(commissionRate: rate / 100);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: (state.disasterRate * 100).toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Disaster Rate (%)', border: OutlineInputBorder()),
                onChanged: (val) {
                  final rate = double.tryParse(val);
                  if (rate != null) {
                    ref.read(disputeMemoProvider.notifier).updateAccounts(disasterRate: rate / 100);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: (state.vatRate * 100).toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'VAT Rate (%)', border: OutlineInputBorder()),
                onChanged: (val) {
                  final rate = double.tryParse(val);
                  if (rate != null) {
                    ref.read(disputeMemoProvider.notifier).updateAccounts(vatRate: rate / 100);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: (state.otherCommissionRate * 100).toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Other Comm Rate (%)', border: OutlineInputBorder()),
                onChanged: (val) {
                  final rate = double.tryParse(val);
                  if (rate != null) {
                    ref.read(disputeMemoProvider.notifier).updateAccounts(otherCommissionRate: rate / 100);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: 'TRANS_REFERANCE',
        field: 'ref',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'PAN',
        field: 'pan',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'Transaction Date',
        field: 'date',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'CustomerAccount',
        field: 'account',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'Customer Name',
        field: 'name',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'Acquirer Bank',
        field: 'acquirer',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'Branch',
        field: 'branch',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'VAT Account',
        field: 'vat_acc',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'amount',
        type: PlutoColumnType.number(),
        renderer: (ctx) => _cellRenderer(ctx, isNumber: true),
      ),
      PlutoColumn(
        title: 'Com_amount',
        field: 'pl',
        type: PlutoColumnType.number(),
        renderer: (ctx) => _cellRenderer(ctx, isNumber: true),
      ),
      PlutoColumn(
        title: 'Disaster commission',
        field: 'edrf',
        type: PlutoColumnType.number(),
        renderer: (ctx) => _cellRenderer(ctx, isNumber: true),
      ),
      PlutoColumn(
        title: 'VAT amount',
        field: 'vat',
        type: PlutoColumnType.number(),
        renderer: (ctx) => _cellRenderer(ctx, isNumber: true),
      ),
      PlutoColumn(
        title: 'TOTAL',
        field: 'total',
        type: PlutoColumnType.number(),
        renderer: (ctx) => _cellRenderer(ctx, isNumber: true),
      ),
      PlutoColumn(
        title: 'RRN',
        field: 'rrn',
        type: PlutoColumnType.text(),
        renderer: (ctx) => _cellRenderer(ctx),
      ),
    ];
  }

  List<PlutoRow> _buildRows(DisputeMemoSummary summary) {
    List<PlutoRow> rows = [];

    for (var item in summary.items) {
      final cells = {
        'ref': PlutoCell(value: item.transRef),
        'pan': PlutoCell(value: item.pan),
        'date': PlutoCell(value: item.transactionDate),
        'account': PlutoCell(value: item.customerAccount),
        'name': PlutoCell(value: item.customerName),
        'acquirer': PlutoCell(value: item.acquirerBank),
        'branch': PlutoCell(value: item.branch),
        'vat_acc': PlutoCell(value: item.debitVatAcc),
        'amount': PlutoCell(value: item.amount),
        'pl': PlutoCell(value: item.pl62174),
        'edrf': PlutoCell(value: item.edrrfAmount),
        'vat': PlutoCell(value: item.vatAmount),
        'total': PlutoCell(value: item.total),
        'rrn': PlutoCell(value: item.rrn),
      };
      rows.add(PlutoRow(cells: cells));
    }

    final totalCells = {
      'ref': PlutoCell(value: 'TOTAL'),
      'pan': PlutoCell(value: ''),
      'date': PlutoCell(value: ''),
      'account': PlutoCell(value: ''),
      'name': PlutoCell(value: ''),
      'acquirer': PlutoCell(value: ''),
      'branch': PlutoCell(value: ''),
      'vat_acc': PlutoCell(value: ''),
      'amount': PlutoCell(value: summary.totalAmount),
      'pl': PlutoCell(value: summary.totalPl62174),
      'edrf': PlutoCell(value: summary.totalEdrfAmount),
      'vat': PlutoCell(value: summary.totalVatAmount),
      'total': PlutoCell(value: summary.grandTotal),
      'rrn': PlutoCell(value: ''),
    };
    rows.add(PlutoRow(cells: totalCells));

    return rows;
  }
}
