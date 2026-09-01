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

class CbeTerminalReconPage extends ConsumerStatefulWidget {
  const CbeTerminalReconPage({super.key});

  @override
  ConsumerState<CbeTerminalReconPage> createState() => _CbeTerminalReconPageState();
}

class _CbeTerminalReconPageState extends ConsumerState<CbeTerminalReconPage> {
  String? _cbsFileName;
  String? _settleFileName;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'CBE Multi-Batch Terminal Reconciliation Guide',
      modulePurpose: 'Handles multi-batch cross-settlement pairing between Commercial Bank of Ethiopia (CBE) switch files and internal transaction accounts using masked PAN, Amount, and RRN verification.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Select CBE Channel Extract',
          format: '.CSV',
          description: 'CBE partner ATM/POS export file with masked PAN and amounts.',
          expectedColumns: ['PAN', 'Amount', 'Date', 'RRN / Auth Code'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Select Core Banking Settlement File',
          format: '.CSV',
          description: 'Internal CBO settlement batch extract.',
          expectedColumns: ['PAN', 'Debit / Credit Amount', 'Terminal ID'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Auto-Match & Cross-Reconcile',
          format: 'Instant',
          description: 'Groups multiple batches and computes exact match rate with discrepancy ledger.',
        ),
      ],
      tips: const [
        'Supports standard 16-digit card numbers with 6-digit prefix masking (e.g. 605141******1234).',
        'Use the quick export button to extract Excel or CSV audit records.',
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
      ref.read(cbeTerminalReconProvider.notifier).setCbsData(parsed);
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
      ref.read(cbeTerminalReconProvider.notifier).setSettlementData(parsed);
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
        title: 'RRN / PAN',
        field: 'rrn',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
    ];

    for (final h in state.cbsHeaders) {
      cols.add(PlutoColumn(
        title: 'CBE: $h',
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
    final reconState = ref.watch(cbeTerminalReconProvider);
    final totalCount = reconState.reconciledRows.length;
    // Calculate matching rate based ONLY on items that exist in CBS
    final totalCbsCount = reconState.reconciledRows.where((r) => r.status != TerminalReconStatus.missingInCbs).length;
    final matchedCount = reconState.reconciledRows.where((r) => r.status == TerminalReconStatus.ok).length;
    final mismatchCount = totalCount - matchedCount;

    return ResponsiveShell(
      currentRoute: '/terminal_cbe',
      title: 'CBE ATM/POS Reconciliation',
      subtitle: 'Multi-Settlement Batch Reconciliation Engine',
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
            onPressed: () async {
              final success = await ref.read(cbeTerminalReconProvider.notifier).exportExcel();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Excel Report Exported Successfully!' : 'Failed to Export Excel Report.'),
                    backgroundColor: success ? CboColors.statusOkBg : CboColors.statusMismatchBg,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: CboColors.slateDark),
            tooltip: 'Export CSV',
            onPressed: () async {
              final success = await ref.read(cbeTerminalReconProvider.notifier).exportCsv();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'CSV Report Exported Successfully!' : 'Failed to Export CSV Report.'),
                    backgroundColor: success ? CboColors.statusOkBg : CboColors.statusMismatchBg,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _cbsFileName = null;
                _settleFileName = null;
              });
              ref.read(cbeTerminalReconProvider.notifier).clear();
            },
          ),
        ],
      ],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropzones
            Row(
              children: [
                Expanded(
                  child: CboFileDropzone(
                    title: '1. CBE Transaction Batch',
                    subtitle: 'Drop or select CBE channel CSV export',
                    fileName: _cbsFileName,
                    icon: Icons.credit_card_rounded,
                    onTap: _pickCbsFile,
                    onClear: () {
                      setState(() => _cbsFileName = null);
                      ref.read(cbeTerminalReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Settlement Batch File',
                    subtitle: 'Drop or select settlement clearing CSV report',
                    fileName: _settleFileName,
                    icon: Icons.sync_alt_rounded,
                    onTap: _pickSettleFile,
                    onClear: () {
                      setState(() => _settleFileName = null);
                      ref.read(cbeTerminalReconProvider.notifier).clear();
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
                      subtitle: totalCbsCount > 0 ? '${((matchedCount / totalCbsCount) * 100).toStringAsFixed(1)}% match rate' : null,
                      icon: Icons.verified_rounded,
                      color: CboColors.bankGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Discrepancies',
                      value: '$mismatchCount',
                      subtitle: 'Requires investigation',
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
                            Text('Cross-Verifying CBE Transaction Batches...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
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
                                  'Awaiting CBE Settlement Batches',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload both CBE partner extract and settlement batch CSV files.',
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
