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
import '../providers/ebirr_recon_provider.dart';
import '../../domain/entities/mobile_recon_row.dart';

class EbirrReconPage extends ConsumerStatefulWidget {
  const EbirrReconPage({super.key});

  @override
  ConsumerState<EbirrReconPage> createState() => _EbirrReconPageState();
}

class _EbirrReconPageState extends ConsumerState<EbirrReconPage> {
  String? _cbsFileName;
  String? _ebirrFileName;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Ebirr Mobile Money Reconciliation Guide',
      modulePurpose: 'Synchronizes CBO Core Banking third-party references with Ebirr wallet platform statement transfer IDs. Detects unmatched wallet credits and ledger variance.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load CBS Ebirr Ledger Extract',
          format: '.CSV',
          description: 'Core banking CSV containing THIRD_PARTY_REFERENCE or remark keys.',
          expectedColumns: ['THIRD_PARTY_REFERENCE', 'Amount', 'Value Date', 'Account'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Ebirr Statement Report',
          format: '.CSV',
          description: 'Ebirr partner ledger containing TRANSFERID or transaction reference.',
          expectedColumns: ['TRANSFERID', 'Amount', 'Date', 'Sender/Receiver'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Automated Wallet Matching',
          format: 'Instant',
          description: 'Instant pairing by normalized transaction ID with status indicators.',
        ),
      ],
      tips: const [
        'Trailing zeros and special delimiters are automatically stripped during normalization.',
        'Matched records can be exported directly to Excel or CSV.',
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
      ref.read(ebirrReconProvider.notifier).setCbsData(parsed);
    }
  }

  Future<void> _pickEbirrFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _ebirrFileName = result.files.single.name);
      ref.read(ebirrReconProvider.notifier).setEbirrData(parsed);
    }
  }

  List<PlutoColumn> _buildColumns(EbirrReconState state) {
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
        title: 'Reference Key',
        field: 'key',
        type: PlutoColumnType.text(),
        width: 170,
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

    for (int i = 0; i < state.ebirrHeaders.length; i++) {
      final h = state.ebirrHeaders[i];
      cols.add(PlutoColumn(
        title: 'EBIRR: $h',
        field: 'ebirr_$i',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final reconState = ref.watch(ebirrReconProvider);
    final totalCount = reconState.reconciledRows.length;
    final matchedCount = reconState.reconciledRows.where((r) => r.status == MobileReconStatus.ok).length;
    final mismatchCount = totalCount - matchedCount;

    return ResponsiveShell(
      currentRoute: '/mobile_ebirr',
      title: 'Ebirr Mobile Money Reconciliation',
      subtitle: 'CBS THIRD_PARTY_REFERENCE vs Ebirr Bank TRANSFERID',
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
            onPressed: () => ref.read(ebirrReconProvider.notifier).exportCsv(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _cbsFileName = null;
                _ebirrFileName = null;
              });
              ref.read(ebirrReconProvider.notifier).clear();
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
                    title: '1. CBS Statement File',
                    subtitle: 'Drop or select core banking CSV statement',
                    fileName: _cbsFileName,
                    icon: Icons.account_balance_rounded,
                    onTap: _pickCbsFile,
                    onClear: () {
                      setState(() => _cbsFileName = null);
                      ref.read(ebirrReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Ebirr Statement File',
                    subtitle: 'Drop or select Ebirr wallet CSV statement',
                    fileName: _ebirrFileName,
                    icon: Icons.phone_android_rounded,
                    onTap: _pickEbirrFile,
                    onClear: () {
                      setState(() => _ebirrFileName = null);
                      ref.read(ebirrReconProvider.notifier).clear();
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
                      title: 'Total Records',
                      value: '$totalCount',
                      icon: Icons.receipt_long_rounded,
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
                      subtitle: 'Requires settlement follow-up',
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
                            Text('Reconciling Ebirr Wallet Ledger...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : reconState.plutoRows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_android_rounded, size: 48, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting Ebirr Statements',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload both CBS ledger and Ebirr partner statement CSV files.',
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
