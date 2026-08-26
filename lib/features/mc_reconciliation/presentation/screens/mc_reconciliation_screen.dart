import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../providers/mc_reconciliation_provider.dart';

class McReconciliationScreen extends ConsumerWidget {
  const McReconciliationScreen({super.key});

  void _showGuide(BuildContext context) {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Mastercard Ledger & Variance Reconciliation Guide',
      modulePurpose: 'Performs cardholder-level financial reconciliation between TopUp statements and raw TSV transaction logs. Computes expected vs actual remaining balances, annual fees, and detects overdraft risks.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load Mastercard TopUp File',
          format: '.XLSX / .XLS',
          description: 'Cardholder account initial balances and top-up allocations.',
          expectedColumns: ['Client ID', 'PAN', 'Initial Balance'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Mastercard TSV Clearing Feed',
          format: '.TSV / .TXT',
          description: 'Raw settlement transactions feed with base amounts and annual fees.',
        ),
        ReconStepGuide(
          step: 3,
          title: 'Compute Balance Variance & Risk',
          format: 'Instant',
          description: 'Evaluates variance (Expected Rem. vs Actual Rem.) and highlights OVERDRAFT risk.',
        ),
      ],
      tips: const [
        'Overdrafts are color-coded in crimson and require immediate card suspension review.',
        'Export full Excel reconciliation reports using the top action button.',
      ],
    );
  }

  List<PlutoColumn> _getColumns() {
    return [
      PlutoColumn(title: 'Client ID', field: 'client_id', type: PlutoColumnType.text(), width: 130),
      PlutoColumn(title: 'PAN', field: 'pan', type: PlutoColumnType.text(), width: 170),
      PlutoColumn(title: 'Initial Balance', field: 'initial_bal', type: PlutoColumnType.currency(symbol: '\$'), width: 130),
      PlutoColumn(title: 'Base Amount', field: 'base_amount', type: PlutoColumnType.currency(symbol: '\$'), width: 130),
      PlutoColumn(title: 'Annual Fee', field: 'annual_fee', type: PlutoColumnType.currency(symbol: '\$'), width: 120),
      PlutoColumn(title: 'Expected Rem.', field: 'exp_rem', type: PlutoColumnType.currency(symbol: '\$'), width: 140),
      PlutoColumn(title: 'Actual Rem.', field: 'act_rem', type: PlutoColumnType.currency(symbol: '\$'), width: 140),
      PlutoColumn(title: 'Variance', field: 'variance', type: PlutoColumnType.currency(symbol: '\$'), width: 130),
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 140,
        renderer: (ctx) {
          final val = ctx.cell.value.toString();
          Color bg = CboColors.statusOkBg;
          Color fg = CboColors.statusOkText;

          if (val.contains('OVERDRAFT') || val.contains('MISMATCH')) {
            bg = CboColors.statusMissingBg;
            fg = CboColors.statusMissingText;
          } else if (val.contains('VARIANCE')) {
            bg = CboColors.statusMismatchBg;
            fg = CboColors.statusMismatchText;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
            child: Text(val, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
          );
        },
      ),
    ];
  }

  List<PlutoRow> _getRows(WidgetRef ref) {
    final state = ref.watch(mcReconciliationProvider);
    return state.summaries.map((s) {
      return PlutoRow(
        cells: {
          'client_id': PlutoCell(value: s.clientId),
          'pan': PlutoCell(value: s.pan),
          'initial_bal': PlutoCell(value: s.initialBalance),
          'base_amount': PlutoCell(value: s.totalBaseAmount),
          'annual_fee': PlutoCell(value: s.annualFee),
          'exp_rem': PlutoCell(value: s.expectedRemaining),
          'act_rem': PlutoCell(value: s.actualRemaining),
          'variance': PlutoCell(value: s.variance),
          'status': PlutoCell(value: s.status.name.toUpperCase()),
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mcReconciliationProvider);

    return ResponsiveShell(
      currentRoute: '/mastercard_reconciliation',
      title: 'Mastercard Ledger & Variance Reconciliation',
      subtitle: 'Cardholder Balance Projection & Overdraft Risk Monitor',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.primaryCyan),
          tooltip: 'Operation Guide',
          onPressed: () => _showGuide(context),
        ),
        if (state.summaries.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.download_rounded, color: CboColors.slateDark),
            tooltip: 'Export Excel Report',
            onPressed: () async {
              String? path = await FilePicker.saveFile(
                dialogTitle: 'Save Reconciliation Report',
                fileName: 'mc_reconciliation_report.xlsx',
              );
              if (path != null) {
                ref.read(mcReconciliationProvider.notifier).exportResults(path);
              }
            },
          ),
      ],
      body: state.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4527A0)),
                  SizedBox(height: 16),
                  Text('Calculating Mastercard Ledger Projections...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : Column(
              children: [
                // Action Buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: CboColors.cardBorder)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4527A0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.table_chart_rounded, size: 18),
                            label: const Text('1. Load TopUp File (.xlsx)'),
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['xlsx', 'xls'],
                              );
                              if (result?.files.single.path != null) {
                                ref.read(mcReconciliationProvider.notifier).loadTopUpFile(result!.files.single.path!);
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4527A0),
                              side: const BorderSide(color: Color(0xFF4527A0)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.description_rounded, size: 18),
                            label: const Text('2. Load TSV Feed'),
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['tsv', 'txt'],
                              );
                              if (result?.files.single.path != null) {
                                ref.read(mcReconciliationProvider.notifier).loadTsvFile(result!.files.single.path!);
                              }
                            },
                          ),
                        ],
                      ),
                      if (state.summaries.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: CboColors.primaryCyanUltraLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${state.summaries.length} Cardholders Reconciled',
                            style: const TextStyle(
                              color: CboColors.primaryCyanDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (state.errorMessage != null)
                  Container(
                    color: Colors.red.shade50,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: CboColors.alertRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.errorMessage!, style: const TextStyle(color: CboColors.alertRed))),
                      ],
                    ),
                  ),

                Expanded(
                  child: state.summaries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pie_chart_outline_rounded, size: 56, color: CboColors.slateLight),
                              const SizedBox(height: 14),
                              const Text(
                                'Awaiting Mastercard Ledger Data',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload both TopUp file and clearing TSV feed to compute balance variance.',
                                style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PlutoGrid(
                              key: ValueKey('pluto_grid_${state.summaries.length}'),
                              columns: _getColumns(),
                              rows: _getRows(ref),
                              configuration: const PlutoGridConfiguration(
                                style: PlutoGridStyleConfig(
                                  enableGridBorderShadow: false,
                                  gridBorderColor: CboColors.cardBorder,
                                  rowHeight: 42,
                                  columnHeight: 42,
                                  columnTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: CboColors.slateDark),
                                  cellTextStyle: TextStyle(fontSize: 12, color: CboColors.slateDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}