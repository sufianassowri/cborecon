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
import '../providers/ips_two_recon_provider.dart';
import '../../domain/entities/ips_recon_models.dart';

class IpsTwoReconPage extends ConsumerStatefulWidget {
  const IpsTwoReconPage({super.key});

  @override
  ConsumerState<IpsTwoReconPage> createState() => _IpsTwoReconPageState();
}

class _IpsTwoReconPageState extends ConsumerState<IpsTwoReconPage> {
  String? _ipsFileName;
  String? _settleFileName;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'IPS Two-File Reconciliation Guide',
      modulePurpose: 'Direct 2-way comparison between EthSwitch Instant Payment System (IPS) portal transaction reports and internal settlement ledgers using Bank Transfer ID.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load IPS Portal Export',
          format: '.CSV',
          description: 'EthSwitch IPS portal report containing Bank Transfer ID and amounts.',
          expectedColumns: ['Bank Transfer ID / Ref', 'Amount', 'Date', 'Payer/Payee'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Settlement Ledger File',
          format: '.CSV',
          description: 'Internal core banking or payment switch settlement extract.',
          expectedColumns: ['Transfer ID', 'Debit/Credit Amount', 'Channel'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Automated 2-Way Pairing',
          format: 'Instant',
          description: 'Validates presence, amount equality, and discrepancy status.',
        ),
      ],
      tips: const [
        'Matches records on primary Transfer ID keys with whitespace trim.',
        'Export full reconciliation reports directly to CSV.',
      ],
    );
  }

  Future<void> _pickIpsFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _ipsFileName = result.files.single.name);
      ref.read(ipsTwoReconProvider.notifier).setIpsData(parsed);
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
      ref.read(ipsTwoReconProvider.notifier).setSettlementData(parsed);
    }
  }

  List<PlutoColumn> _buildColumns(IpsTwoReconState state) {
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
        title: 'Bank Transfer ID',
        field: 'transferId',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
      ),
    ];

    for (final h in state.ipsHeaders) {
      cols.add(PlutoColumn(
        title: 'IPS: $h',
        field: 'ips_$h',
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
    final reconState = ref.watch(ipsTwoReconProvider);
    final totalCount = reconState.reconciledRows.length;
    final matchedCount = reconState.reconciledRows.where((r) => r.status == IpsReconStatus.ok).length;
    final mismatchCount = totalCount - matchedCount;

    return ResponsiveShell(
      currentRoute: '/ips_two',
      title: 'IPS Two-File Reconciliation',
      subtitle: 'IPS Reports vs Settlement Reports by Transfer ID',
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
            onPressed: () => ref.read(ipsTwoReconProvider.notifier).exportCsv(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _ipsFileName = null;
                _settleFileName = null;
              });
              ref.read(ipsTwoReconProvider.notifier).clear();
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
                    title: '1. IPS Portal Export File',
                    subtitle: 'Drop or select EthSwitch IPS portal CSV',
                    fileName: _ipsFileName,
                    icon: Icons.rule_folder_rounded,
                    onTap: _pickIpsFile,
                    onClear: () {
                      setState(() => _ipsFileName = null);
                      ref.read(ipsTwoReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Settlement Ledger File',
                    subtitle: 'Drop or select internal settlement CSV report',
                    fileName: _settleFileName,
                    icon: Icons.account_balance_rounded,
                    onTap: _pickSettleFile,
                    onClear: () {
                      setState(() => _settleFileName = null);
                      ref.read(ipsTwoReconProvider.notifier).clear();
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
                      title: 'Total IPS Records',
                      value: '$totalCount',
                      icon: Icons.hub_rounded,
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
                      title: 'Missing in Settlement',
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
                            CircularProgressIndicator(color: Color(0xFF283593)),
                            SizedBox(height: 14),
                            Text('Reconciling IPS Portal vs Settlement...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : reconState.plutoRows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.rule_folder_outlined, size: 48, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting IPS Transaction Files',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload both IPS portal report and settlement ledger CSV files.',
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
