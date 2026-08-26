import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/widgets/cbo_file_dropzone.dart';
import '../../../../core/widgets/cbo_metric_card.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../providers/terminal_recon_provider.dart';
import '../../domain/entities/terminal_recon_row.dart';

class CboTerminalReconPage extends ConsumerStatefulWidget {
  const CboTerminalReconPage({super.key});

  @override
  ConsumerState<CboTerminalReconPage> createState() => _CboTerminalReconPageState();
}

class _CboTerminalReconPageState extends ConsumerState<CboTerminalReconPage> {
  String? _cbsFileName;
  String? _settleFileName;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'CBO ATM/POS Reconciliation Guide',
      modulePurpose: 'Matches Core Banking (CBS) general ledger transaction exports against Switch settlement files using Retrieval Reference Numbers (RRN). Identifies amount discrepancies and missing settlement legs.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load CBS Terminal Extract',
          format: '.CSV',
          description: 'Export containing CBO core banking transactions.',
          expectedColumns: ['RRN / Reference', 'Amount', 'Date', 'Account Number'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Switch Settlement File',
          format: '.CSV',
          description: 'Payment Switch settlement ledger with authorization codes.',
          expectedColumns: ['RRN', 'Txn Amount', 'Terminal ID', 'Response Code'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Execute Automated Reconciliation',
          format: 'Instant',
          description: 'System automatically groups, matches, and color-codes matched, amount mismatch, and missing items.',
        ),
      ],
      tips: const [
        'Ensure RRN values are normalized without leading/trailing spaces.',
        'Export full CSV or Excel reports directly from the top navigation bar.',
      ],
    );
  }

  Future<void> _pickCbsFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _cbsFileName = result.files.single.name);
      ref.read(cboTerminalReconProvider.notifier).setCbsData(parsed);
    }
  }

  Future<void> _pickSettleFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _settleFileName = result.files.single.name);
      ref.read(cboTerminalReconProvider.notifier).setSettlementData(parsed);
    }
  }

  List<PlutoColumn> _buildColumns(TerminalReconState state) {
    final List<PlutoColumn> cols = [
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final val = rendererContext.cell.value.toString();
          Color bg = CboColors.statusOkBg;
          Color fg = CboColors.statusOkText;

          if (val == 'MISSING_IN_SETTLE' || val == 'MISSING_IN_CBS' || val == 'MISSING') {
            bg = CboColors.statusMissingBg;
            fg = CboColors.statusMissingText;
          } else if (val == 'AMT_MISMATCH') {
            bg = CboColors.statusMismatchBg;
            fg = CboColors.statusMismatchText;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              val,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'RRN',
        field: 'rrn',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
    ];

    for (final h in state.cbsHeaders) {
      cols.add(PlutoColumn(
        title: 'CBS: $h',
        field: 'cbs_$h',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ));
    }

    for (final h in state.setHeaders) {
      cols.add(PlutoColumn(
        title: 'SETTLE: $h',
        field: 'set_$h',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final reconState = ref.watch(cboTerminalReconProvider);
    final totalCount = reconState.reconciledRows.length;
    final matchedCount = reconState.reconciledRows.where((r) => r.status == TerminalReconStatus.ok).length;
    final mismatchCount = totalCount - matchedCount;

    return ResponsiveShell(
      currentRoute: '/terminal_cbo',
      title: 'CBO ATM/POS Reconciliation',
      subtitle: 'Core Banking System vs Payment Switch Settlement',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.primaryCyan),
          tooltip: 'Operation Guide',
          onPressed: _showGuide,
        ),
        if (reconState.plutoRows.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.table_view_rounded, color: CboColors.bankGreen),
            tooltip: 'Export Excel (.xlsx)',
            onPressed: () => ref.read(cboTerminalReconProvider.notifier).exportExcel(),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: CboColors.slateDark),
            tooltip: 'Export CSV',
            onPressed: () => ref.read(cboTerminalReconProvider.notifier).exportCsv(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _cbsFileName = null;
                _settleFileName = null;
              });
              ref.read(cboTerminalReconProvider.notifier).clear();
            },
          ),
        ],
      ],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload & Dropzone Area
            Row(
              children: [
                Expanded(
                  child: CboFileDropzone(
                    title: '1. CBS Terminal File',
                    subtitle: 'Drop or select core banking CSV export',
                    fileName: _cbsFileName,
                    icon: Icons.account_balance_rounded,
                    onTap: _pickCbsFile,
                    onClear: () {
                      setState(() => _cbsFileName = null);
                      ref.read(cboTerminalReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Switch Settlement File',
                    subtitle: 'Drop or select payment switch CSV report',
                    fileName: _settleFileName,
                    icon: Icons.swap_horiz_rounded,
                    onTap: _pickSettleFile,
                    onClear: () {
                      setState(() => _settleFileName = null);
                      ref.read(cboTerminalReconProvider.notifier).clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Bar
            if (totalCount > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: CboMetricCard(
                      title: 'Total Processed',
                      value: '$totalCount',
                      icon: Icons.list_alt_rounded,
                      color: CboColors.slateDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Fully Matched',
                      value: '$matchedCount',
                      subtitle: totalCount > 0 ? '${((matchedCount / totalCount) * 100).toStringAsFixed(1)}% match rate' : null,
                      icon: Icons.check_circle_rounded,
                      color: CboColors.bankGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Exceptions / Mismatches',
                      value: '$mismatchCount',
                      subtitle: 'Requires action',
                      icon: Icons.warning_amber_rounded,
                      color: mismatchCount > 0 ? CboColors.alertRed : CboColors.slateMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // PlutoGrid Table Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: reconState.isProcessing
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: CboColors.primaryCyan),
                            SizedBox(height: 14),
                            Text('Reconciling Terminal Transaction Matrices...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : reconState.plutoRows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 48, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting Settlement Files',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload both CBS and Switch CSV files to generate reconciliation ledger.',
                                  style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: PlutoGrid(
                              columns: _buildColumns(reconState),
                              rows: reconState.plutoRows,
                              configuration: const PlutoGridConfiguration(
                                style: PlutoGridStyleConfig(
                                  enableGridBorderShadow: false,
                                  gridBorderColor: CboColors.cardBorder,
                                  rowHeight: 42,
                                  columnHeight: 42,
                                  columnTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: CboColors.slateDark),
                                  cellTextStyle: TextStyle(fontSize: 12, color: CboColors.slateDark),
                                ),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
