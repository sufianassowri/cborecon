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
import '../providers/telebirr_recon_provider.dart';
import '../../domain/entities/mobile_recon_row.dart';
import '../../domain/usecases/reconcile_telebirr_usecase.dart';

class TelebirrReconPage extends ConsumerStatefulWidget {
  const TelebirrReconPage({super.key});

  @override
  ConsumerState<TelebirrReconPage> createState() => _TelebirrReconPageState();
}

class _TelebirrReconPageState extends ConsumerState<TelebirrReconPage> {
  String? _cbsFileName;
  String? _telebirrFileName;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Telebirr Dual-Mode Wallet Reconciliation Guide',
      modulePurpose: 'Dual-mode matching engine for Ethio Telecom Telebirr super-app transactions. Supports CashIn (user wallet deposit) and CashOut (bank withdrawal / merchant payout) matching against core banking ledgers.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Select Mode (CashIn vs CashOut)',
          format: 'Toggle',
          description: 'Switch between CashIn (CBS credit vs Telebirr order) and CashOut (CBS debit vs Telebirr payout).',
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load CBS Telebirr Report',
          format: '.CSV',
          description: 'Core banking CSV containing customer debit/credit logs.',
          expectedColumns: ['Order ID / Reference', 'Amount', 'Date', 'Account Number'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Load Telebirr Statement Export',
          format: '.CSV',
          description: 'Ethio Telecom portal export report.',
          expectedColumns: ['Transaction No / Order ID', 'Amount', 'Fee', 'Status'],
        ),
      ],
      tips: const [
        'Ensure the active mode (CashIn or CashOut) matches the statement batch type before loading.',
        'Use the export button to download reconciliation reports.',
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
      ref.read(telebirrReconProvider.notifier).setCbsData(parsed);
    }
  }

  Future<void> _pickTelebirrFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _telebirrFileName = result.files.single.name);
      ref.read(telebirrReconProvider.notifier).setTelebirrData(parsed);
    }
  }

  List<PlutoColumn> _buildColumns(TelebirrReconState state) {
    final List<PlutoColumn> cols = [
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final val = rendererContext.cell.value.toString();
          final bool isOk = val == 'OK';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOk ? CboColors.statusOkBg : CboColors.statusMissingBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              val,
              style: TextStyle(
                color: isOk ? CboColors.statusOkText : CboColors.statusMissingText,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'Order ID / Key',
        field: 'key',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
      ),
    ];

    for (int i = 0; i < state.cbsHeaders.length; i++) {
      final h = state.cbsHeaders[i];
      cols.add(PlutoColumn(
        title: 'CBS: $h',
        field: 'cbs_$i',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ));
    }

    for (int i = 0; i < state.telebirrHeaders.length; i++) {
      final h = state.telebirrHeaders[i];
      cols.add(PlutoColumn(
        title: 'TELE: $h',
        field: 'tele_$i',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final reconState = ref.watch(telebirrReconProvider);
    final totalCount = reconState.reconciledRows.length;
    final matchedCount = reconState.reconciledRows.where((r) => r.status == MobileReconStatus.ok).length;
    final mismatchCount = totalCount - matchedCount;
    final isCashIn = reconState.mode == TelebirrMode.cashIn;

    return ResponsiveShell(
      currentRoute: '/mobile_telebirr',
      title: 'Telebirr Wallet Reconciliation',
      subtitle: 'CashIn & CashOut Dual-Mode Matching Engine',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.primaryCyan),
          tooltip: 'Operation Guide',
          onPressed: _showGuide,
        ),
        if (reconState.plutoRows.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.download_rounded, color: CboColors.slateDark),
            tooltip: 'Export CSV',
            onPressed: () => ref.read(telebirrReconProvider.notifier).exportCsv(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _cbsFileName = null;
                _telebirrFileName = null;
              });
              ref.read(telebirrReconProvider.notifier).clear();
            },
          ),
        ],
      ],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Selector Toggle
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CboColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => ref.read(telebirrReconProvider.notifier).setMode(TelebirrMode.cashIn),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isCashIn ? const Color(0xFF6A1B9A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 16, color: isCashIn ? Colors.white : CboColors.slateMedium),
                              const SizedBox(width: 8),
                              Text(
                                'CashIn Mode (Wallet Deposits)',
                                style: TextStyle(
                                  color: isCashIn ? Colors.white : CboColors.slateDark,
                                  fontWeight: isCashIn ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => ref.read(telebirrReconProvider.notifier).setMode(TelebirrMode.cashOut),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isCashIn ? const Color(0xFF6A1B9A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 16, color: !isCashIn ? Colors.white : CboColors.slateMedium),
                              const SizedBox(width: 8),
                              Text(
                                'CashOut Mode (Disbursements)',
                                style: TextStyle(
                                  color: !isCashIn ? Colors.white : CboColors.slateDark,
                                  fontWeight: !isCashIn ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dropzones
            Row(
              children: [
                Expanded(
                  child: CboFileDropzone(
                    title: '1. CBS Statement File',
                    subtitle: 'Drop or select core banking CSV extract',
                    fileName: _cbsFileName,
                    icon: Icons.account_balance_rounded,
                    onTap: _pickCbsFile,
                    onClear: () {
                      setState(() => _cbsFileName = null);
                      ref.read(telebirrReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Telebirr Portal File',
                    subtitle: 'Drop or select Ethio Telecom CSV export',
                    fileName: _telebirrFileName,
                    icon: Icons.account_balance_wallet_rounded,
                    onTap: _pickTelebirrFile,
                    onClear: () {
                      setState(() => _telebirrFileName = null);
                      ref.read(telebirrReconProvider.notifier).clear();
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
                      title: 'Total Transactions',
                      value: '$totalCount',
                      icon: Icons.receipt_rounded,
                      color: CboColors.slateDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Matched Pairs',
                      value: '$matchedCount',
                      subtitle: totalCount > 0 ? '${((matchedCount / totalCount) * 100).toStringAsFixed(1)}% match rate' : null,
                      icon: Icons.check_circle_rounded,
                      color: CboColors.bankGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Unmatched Exceptions',
                      value: '$mismatchCount',
                      subtitle: 'Requires settlement audit',
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
                            CircularProgressIndicator(color: Color(0xFF6A1B9A)),
                            SizedBox(height: 14),
                            Text('Matching Telebirr Dual-Mode Batches...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : reconState.plutoRows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, size: 48, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting Telebirr Ingestion',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Select operation mode and upload both CBS and Telebirr CSV files.',
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
