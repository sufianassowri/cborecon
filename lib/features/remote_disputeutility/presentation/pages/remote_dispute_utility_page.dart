import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../data/datasources/excel_parser_datasource.dart';
import '../providers/dispute_reconciliation_provider.dart';

class RemoteDisputeUtilityPage extends ConsumerWidget {
  const RemoteDisputeUtilityPage({super.key});

  void _showGuide(BuildContext context) {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Remote Dispute Utility Reconciliation Guide',
      modulePurpose: 'Multi-criteria matching engine with dynamic header mapping. Compares core CBS dispute records against arbitrary remote settlement file formats (CSV or XLSX).',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Upload CBS Dispute File',
          format: '.XLSX / .CSV',
          description: 'Core banking dispute report with customer accounts, RRN, PAN, and amounts.',
          expectedColumns: ['Account', 'Amount', 'Refnum_F37(RRN)', 'PAN / Card_Number'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Upload Remote Settlement File(s)',
          format: '.XLSX / .CSV',
          description: 'Partner bank or clearing gateway remote settlement reports.',
        ),
        ReconStepGuide(
          step: 3,
          title: 'Dynamic Header Synthesis',
          format: 'Instant',
          description: 'Automatically aligns arbitrary column headers and evaluates dispute status.',
        ),
      ],
      tips: const [
        'Supports uploading multiple remote settlement files simultaneously.',
        'Color codes AMT_MISMATCH (red) and MISSING (yellow) automatically.',
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(remoteDisputeProvider);

    return ResponsiveShell(
      currentRoute: '/remote_dispute_utility',
      title: 'Remote Dispute Utility Reconciliation',
      subtitle: 'Multi-Criteria Dynamic Header Mapping & Batch Reconciliation Engine',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.primaryCyan),
          tooltip: 'Operation Guide',
          onPressed: () => _showGuide(context),
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded, color: CboColors.slateDark),
          tooltip: 'Export Excel (.xlsx)',
          onPressed: () => _handleExport(context, ref),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 600;

          return Column(
            children: [
              Expanded(
                child: rowsAsync.when(
                  data: (entityRows) {
                    if (entityRows.isEmpty) return _buildEmptyState(context);

                    final plutoRows = entityRows.map((e) => e.toPlutoRow()).toList();
                    final settlementHeaders = entityRows.first.settlementHeaders;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PlutoGrid(
                        columns: _buildTargetColumns(settlementHeaders),
                        rows: plutoRows,
                        rowColorCallback: (rowContext) {
                          final status = rowContext.row.cells['reconcile_status']?.value.toString();
                          if (status == 'AMT_MISMATCH') {
                            return Colors.red.withValues(alpha: 0.15);
                          } else if (status == 'MISSING') {
                            return Colors.amber.withValues(alpha: 0.15);
                          }
                          return Colors.white;
                        },
                        configuration: const PlutoGridConfiguration(
                          style: PlutoGridStyleConfig(
                            enableGridBorderShadow: false,
                            gridBorderColor: CboColors.cardBorder,
                            activatedColor: Color(0x1A009688),
                          ),
                          columnSize: PlutoGridColumnSizeConfig(
                            resizeMode: PlutoResizeMode.pushAndPull,
                            autoSizeMode: PlutoAutoSizeMode.scale,
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: CboColors.primaryCyan)),
                  error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: CboColors.cardBorder)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _UploadButton(
                      label: "1. Upload CBS File",
                      icon: Icons.account_balance_rounded,
                      onPressed: () => _pickCbsFile(ref),
                      color: CboColors.primaryCyan,
                      isFullWidth: isMobile,
                    ),
                    _UploadButton(
                      label: "2. Upload Settlement File(s)",
                      icon: Icons.cloud_upload_rounded,
                      onPressed: () => _pickSettlementFiles(ref),
                      color: const Color(0xFF00838F),
                      isFullWidth: isMobile,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 64, color: CboColors.slateLight),
          const SizedBox(height: 16),
          const Text(
            "Upload CBS and Settlement report(s) (.xlsx / .csv) to start",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CboColors.slateMedium),
          ),
          const SizedBox(height: 6),
          const Text(
            "Supports dynamic schema mapping across varied core and switch formats.",
            style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
          ),
        ],
      ),
    );
  }

  List<PlutoColumn> _buildTargetColumns(List<String> settlementHeaders) {
    List<PlutoColumn> columns = [
      PlutoColumn(title: 'RECON_STATUS', field: 'reconcile_status', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'Id', field: 'id', type: PlutoColumnType.text(), width: 110),
      PlutoColumn(title: 'Branch', field: 'branch', type: PlutoColumnType.text(), width: 110),
      PlutoColumn(title: 'FU_Dispute_Id', field: 'fu_dispute_id', type: PlutoColumnType.text(), width: 130),
      PlutoColumn(title: 'Account', field: 'account', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'Amount', field: 'amount', type: PlutoColumnType.text(), width: 110),
      PlutoColumn(title: 'Customer', field: 'customer', type: PlutoColumnType.text(), width: 150),
      PlutoColumn(title: 'Acquirer Bank', field: 'acquirer_bank', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'PAN', field: 'pan', type: PlutoColumnType.text(), width: 160),
      PlutoColumn(title: 'Transaction Date', field: 'transaction_date', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'Card_Number', field: 'card_number', type: PlutoColumnType.text(), width: 160),
      PlutoColumn(title: 'Refnum_F37(RRN)', field: 'refnum_f37_rrn', type: PlutoColumnType.text(), width: 160),
      PlutoColumn(title: 'Fe_utrnno', field: 'fe_utrnno', type: PlutoColumnType.text(), width: 180),
    ];

    for (final header in settlementHeaders) {
      columns.add(
        PlutoColumn(
          title: header,
          field: 'settlement_$header',
          type: PlutoColumnType.text(),
          width: 140,
        ),
      );
    }
    return columns;
  }

  Future<void> _pickCbsFile(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final parsed = await ExcelParserDatasource.parseFile(file);
      if (parsed.isNotEmpty) {
        ref.read(remoteDisputeProvider.notifier).updateCbsData(parsed);
      }
    }
  }

  Future<void> _pickSettlementFiles(WidgetRef ref) async {
    final datasets = await ExcelParserDatasource.pickMultipleFiles();
    if (datasets.isNotEmpty) {
      ref.read(remoteDisputeProvider.notifier).updateSettlementData(datasets);
    }
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final success = await ref.read(remoteDisputeProvider.notifier).exportToExcel();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Excel Export completed successfully!" : "Export was cancelled or had no data"),
            backgroundColor: success ? CboColors.bankGreen : CboColors.alertRed,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: CboColors.alertRed),
        );
      }
    }
  }
}

class _UploadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final bool isFullWidth;

  const _UploadButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.isFullWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : 260,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: onPressed,
      ),
    );
  }
}