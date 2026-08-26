import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/widgets/cbo_file_dropzone.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../providers/ips_triangular_recon_provider.dart';

class IpsTriangularReconPage extends ConsumerStatefulWidget {
  const IpsTriangularReconPage({super.key});

  @override
  ConsumerState<IpsTriangularReconPage> createState() => _IpsTriangularReconPageState();
}

class _IpsTriangularReconPageState extends ConsumerState<IpsTriangularReconPage> {
  String? _ecFileName;
  String? _etFileName;
  String? _crFileName;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'IPS 3-Way Triangular Reconciliation Guide',
      modulePurpose: 'Performs 3-Way Triangular Reconciliation connecting Ebirr CBS statements, partner settlement clearing files, and General Ledger (CR) accounts to guarantee zero undetected clearing variance.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Ingest Ebirr CBS Extract (EC)',
          format: '.CSV',
          description: 'Core banking customer transaction entries.',
          expectedColumns: ['Reference No', 'Amount', 'Date', 'Account Number'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Ingest Partner Settlement (ET)',
          format: '.CSV',
          description: 'Ebirr or Switch settlement clearing matrix.',
          expectedColumns: ['Reference No', 'Settlement Amount', 'Value Date'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Ingest General Ledger CR File',
          format: '.CSV',
          description: 'Central bank / GL clearing account records.',
          expectedColumns: ['Reference No', 'Credit Amount', 'GL Account Code'],
        ),
      ],
      tips: const [
        'Triangular validation checks exact matches across all three legs simultaneously.',
        'Exceptions can be isolated and exported immediately.',
      ],
    );
  }

  Future<void> _pickEcFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _ecFileName = result.files.single.name);
      ref.read(ipsTriangularReconProvider.notifier).setEbirrCbsData(parsed);
    }
  }

  Future<void> _pickEtFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _etFileName = result.files.single.name);
      ref.read(ipsTriangularReconProvider.notifier).setEbirrSettlementData(parsed);
    }
  }

  Future<void> _pickCrFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final parsed = CsvParserUtil.parseBytes(bytes);
      setState(() => _crFileName = result.files.single.name);
      ref.read(ipsTriangularReconProvider.notifier).setCboReconData(parsed);
    }
  }

  List<PlutoColumn> _buildColumns(IpsTriangularState state) {
    final List<PlutoColumn> cols = [
      PlutoColumn(
        title: 'Triangular Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final val = rendererContext.cell.value.toString();
          final bool isOk = val == 'MATCHED';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOk ? CboColors.statusOkBg : CboColors.statusMismatchBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              val,
              style: TextStyle(
                color: isOk ? CboColors.statusOkText : CboColors.statusMismatchText,
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

    for (int i = 0; i < state.ecHeaders.length; i++) {
      cols.add(PlutoColumn(
        title: 'EC: ${state.ecHeaders[i]}',
        field: 'ec_$i',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    for (int i = 0; i < state.etHeaders.length; i++) {
      cols.add(PlutoColumn(
        title: 'ET: ${state.etHeaders[i]}',
        field: 'et_$i',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    for (int i = 0; i < state.crHeaders.length; i++) {
      cols.add(PlutoColumn(
        title: 'CR: ${state.crHeaders[i]}',
        field: 'cr_$i',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final reconState = ref.watch(ipsTriangularReconProvider);

    return ResponsiveShell(
      currentRoute: '/ips_triangular',
      title: 'IPS 3-Way Triangular Reconciliation',
      subtitle: 'Ebirr CBS, Partner Settlement, & General Ledger Triangular Validation',
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
            onPressed: () => ref.read(ipsTriangularReconProvider.notifier).exportCsv(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _ecFileName = null;
                _etFileName = null;
                _crFileName = null;
              });
              ref.read(ipsTriangularReconProvider.notifier).clear();
            },
          ),
        ],
      ],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3-Way Dropzones
            Row(
              children: [
                Expanded(
                  child: CboFileDropzone(
                    title: '1. Ebirr CBS File (EC)',
                    subtitle: 'Drop or select core banking extract',
                    fileName: _ecFileName,
                    icon: Icons.account_balance_rounded,
                    onTap: _pickEcFile,
                    onClear: () {
                      setState(() => _ecFileName = null);
                      ref.read(ipsTriangularReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Ebirr Settlement (ET)',
                    subtitle: 'Drop or select settlement extract',
                    fileName: _etFileName,
                    icon: Icons.swap_horiz_rounded,
                    onTap: _pickEtFile,
                    onClear: () {
                      setState(() => _etFileName = null);
                      ref.read(ipsTriangularReconProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CboFileDropzone(
                    title: '3. CBO Recon / GL (CR)',
                    subtitle: 'Drop or select GL report',
                    fileName: _crFileName,
                    icon: Icons.account_tree_rounded,
                    onTap: _pickCrFile,
                    onClear: () {
                      setState(() => _crFileName = null);
                      ref.read(ipsTriangularReconProvider.notifier).clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                            CircularProgressIndicator(color: Color(0xFF1565C0)),
                            SizedBox(height: 14),
                            Text('Calculating 3-Way Triangular Vectors...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : reconState.plutoRows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_tree_outlined, size: 48, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting Triangular Ingestion',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload EC, ET, and CR files to execute 3-way triangular validation.',
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
