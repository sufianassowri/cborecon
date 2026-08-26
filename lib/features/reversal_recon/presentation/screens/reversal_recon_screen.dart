import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/date_time_util.dart';
import '../../../../core/utils/excel_exporter_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/utils/normalization_util.dart';
import '../../../../core/widgets/cbo_file_dropzone.dart';
import '../../../../core/widgets/cbo_metric_card.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../domain/entities/reversal_models.dart';
import '../../domain/usecases/match_reversals_with_tolerance_usecase.dart';

class ReversalReconScreen extends StatefulWidget {
  const ReversalReconScreen({super.key});

  @override
  State<ReversalReconScreen> createState() => _ReversalReconScreenState();
}

class _ReversalReconScreenState extends State<ReversalReconScreen> {
  final MatchReversalsWithToleranceUseCase _useCase = const MatchReversalsWithToleranceUseCase();

  List<OutgoingTxn> _outgoings = [];
  List<ReversalTxn> _reversals = [];
  String? _outgoingFileName;
  String? _reversalFileName;

  ReversalMatchResult? _matchResult;
  bool _isProcessing = false;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Reversal & Interchange Tolerance Matcher Guide',
      modulePurpose: 'Specialized tolerance matching engine for reversal transactions. Detects 0.46% to 0.60% interchange fee commissions and handles multi-day reversal settlement lags.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load Outgoing Transactions',
          format: '.CSV',
          description: 'Core banking outgoing transfer ledger with FT reference and amounts.',
          expectedColumns: ['FT / Ref', 'Date', 'Amount'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Reversal Transactions',
          format: '.CSV',
          description: 'Switch or clearing partner reversal journal.',
          expectedColumns: ['Account', 'Date', 'Reversal Amount'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Execute Tolerance Matching',
          format: 'Instant',
          description: 'First attempts exact matches, then runs interchange tolerance calculations (0.46% - 0.60%).',
        ),
      ],
      tips: const [
        'Interchange commission percentages are calculated dynamically and displayed with status badges.',
        'Export full reconciliation reports directly to Excel or CSV.',
      ],
    );
  }

  Future<void> _pickOutgoingFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final rows = CsvParserUtil.parseBytes(res.files.single.bytes!);
      if (rows.isEmpty) return;

      final headers = rows[0].map((e) => e.toString().trim().toUpperCase()).toList();
      final int ftIdx = headers.indexWhere((h) => h.contains('FT') || h.contains('REF'));
      final int dateIdx = headers.indexWhere((h) => h.contains('DATE'));
      final int amtIdx = headers.indexWhere((h) => h.contains('AMOUNT') || h.contains('AMT'));

      final List<OutgoingTxn> list = [];
      for (final r in rows.skip(1)) {
        if (r.length <= ftIdx || r.length <= amtIdx) continue;
        final ft = NormalizationUtil.normalize(r[ftIdx]);
        final amt = NormalizationUtil.parseAmount(r[amtIdx]);
        DateTime dt = DateTime.now();
        if (dateIdx != -1 && r.length > dateIdx) {
          dt = DateTime.tryParse(r[dateIdx].toString()) ?? DateTime.now();
        }
        if (ft.isNotEmpty && amt > 0) {
          list.add(OutgoingTxn(ft: ft, date: dt, amount: amt));
        }
      }

      setState(() {
        _outgoings = list;
        _outgoingFileName = res.files.single.name;
        _matchResult = null;
      });
    }
  }

  Future<void> _pickReversalFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final rows = CsvParserUtil.parseBytes(res.files.single.bytes!);
      if (rows.isEmpty) return;

      final headers = rows[0].map((e) => e.toString().trim().toUpperCase()).toList();
      final int accIdx = headers.indexWhere((h) => h.contains('ACC') || h.contains('ACCOUNT') || h.contains('REF'));
      final int dateIdx = headers.indexWhere((h) => h.contains('DATE'));
      final int amtIdx = headers.indexWhere((h) => h.contains('AMOUNT') || h.contains('AMT'));

      final List<ReversalTxn> list = [];
      for (final r in rows.skip(1)) {
        if (r.length <= accIdx || r.length <= amtIdx) continue;
        final acc = NormalizationUtil.normalize(r[accIdx]);
        final amt = NormalizationUtil.parseAmount(r[amtIdx]);
        DateTime dt = DateTime.now();
        if (dateIdx != -1 && r.length > dateIdx) {
          dt = DateTime.tryParse(r[dateIdx].toString()) ?? DateTime.now();
        }
        if (acc.isNotEmpty && amt > 0) {
          list.add(ReversalTxn(id: acc, account: acc, date: dt, amount: amt));
        }
      }

      setState(() {
        _reversals = list;
        _reversalFileName = res.files.single.name;
        _matchResult = null;
      });
    }
  }

  void _runMatching() {
    if (_outgoings.isEmpty || _reversals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both Outgoing and Reversal CSV files.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final result = _useCase(_outgoings, _reversals);
    setState(() {
      _matchResult = result;
      _isProcessing = false;
    });
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: 'Match Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        renderer: (ctx) {
          final val = ctx.cell.value.toString();
          Color bg = CboColors.statusOkBg;
          Color fg = CboColors.statusOkText;

          if (val.contains('TOLERANCE')) {
            bg = CboColors.statusMismatchBg;
            fg = CboColors.statusMismatchText;
          } else if (val.contains('UNMATCHED')) {
            bg = CboColors.statusMissingBg;
            fg = CboColors.statusMissingText;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
            child: Text(val, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
          );
        },
      ),
      PlutoColumn(
        title: 'Outgoing FT',
        field: 'out_ft',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Outgoing Date',
        field: 'out_date',
        type: PlutoColumnType.text(),
        width: 130,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Outgoing Amount',
        field: 'out_amt',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Reversal Account',
        field: 'rev_acc',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Reversal Amount',
        field: 'rev_amt',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Interchange %',
        field: 'commission',
        type: PlutoColumnType.text(),
        width: 130,
        enableEditingMode: false,
      ),
    ];
  }

  List<PlutoRow> _buildRows() {
    if (_matchResult == null) return [];
    final List<PlutoRow> rows = [];

    for (final p in _matchResult!.matchedPairs) {
      final commStr = p.commission != null ? '${(p.commission! * 100).toStringAsFixed(2)}%' : '0.00% (Exact)';
      final statusStr = p.commission != null ? 'TOLERANCE MATCH' : 'EXACT MATCH';

      rows.add(PlutoRow(cells: {
        'status': PlutoCell(value: statusStr),
        'out_ft': PlutoCell(value: p.outgoing.ft),
        'out_date': PlutoCell(value: DateTimeUtil.formatDate(p.outgoing.date)),
        'out_amt': PlutoCell(value: p.outgoing.amount.toStringAsFixed(2)),
        'rev_acc': PlutoCell(value: p.reversal.account),
        'rev_amt': PlutoCell(value: p.reversal.amount.toStringAsFixed(2)),
        'commission': PlutoCell(value: commStr),
      }));
    }

    for (final o in _matchResult!.unmatchedOutgoings) {
      rows.add(PlutoRow(cells: {
        'status': PlutoCell(value: 'UNMATCHED OUTGOING'),
        'out_ft': PlutoCell(value: o.ft),
        'out_date': PlutoCell(value: DateTimeUtil.formatDate(o.date)),
        'out_amt': PlutoCell(value: o.amount.toStringAsFixed(2)),
        'rev_acc': PlutoCell(value: '-'),
        'rev_amt': PlutoCell(value: '-'),
        'commission': PlutoCell(value: '-'),
      }));
    }

    for (final r in _matchResult!.unmatchedReversals) {
      rows.add(PlutoRow(cells: {
        'status': PlutoCell(value: 'UNMATCHED REVERSAL'),
        'out_ft': PlutoCell(value: '-'),
        'out_date': PlutoCell(value: '-'),
        'out_amt': PlutoCell(value: '-'),
        'rev_acc': PlutoCell(value: r.account),
        'rev_amt': PlutoCell(value: r.amount.toStringAsFixed(2)),
        'commission': PlutoCell(value: '-'),
      }));
    }

    return rows;
  }

  Future<void> _exportResults() async {
    final rows = _buildRows();
    if (rows.isEmpty) return;

    final headers = ['Status', 'Outgoing FT', 'Outgoing Date', 'Outgoing Amount', 'Reversal Account', 'Reversal Amount', 'Interchange %'];
    final data = rows.map((r) => [
      r.cells['status']?.value,
      r.cells['out_ft']?.value,
      r.cells['out_date']?.value,
      r.cells['out_amt']?.value,
      r.cells['rev_acc']?.value,
      r.cells['rev_amt']?.value,
      r.cells['commission']?.value,
    ]).toList();

    final bytes = ExcelExporterUtil.exportToExcel(
      headers: headers,
      rows: data,
      sheetName: 'Reversal_Tolerance_Recon',
    );

    await FileSaverUtil.saveBytes(
      bytes: bytes,
      fileName: 'Reversal_Tolerance_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reversal Tolerance report exported successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int matchedCount = _matchResult?.matchedPairs.length ?? 0;
    final int unmatchedOut = _matchResult?.unmatchedOutgoings.length ?? 0;
    final int unmatchedRev = _matchResult?.unmatchedReversals.length ?? 0;

    return ResponsiveShell(
      currentRoute: '/reversal_recon',
      title: 'Reversal & Interchange Tolerance Matcher',
      subtitle: 'Tolerance-Based Matching with 0.46%-0.60% Interchange Detection',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.primaryCyan),
          tooltip: 'Operation Guide',
          onPressed: _showGuide,
        ),
        if (_matchResult != null) ...[
          IconButton(
            icon: const Icon(Icons.download_rounded, color: CboColors.slateDark),
            tooltip: 'Export Excel Report',
            onPressed: _exportResults,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CboColors.alertRed),
            tooltip: 'Reset Engine',
            onPressed: () {
              setState(() {
                _outgoings = [];
                _reversals = [];
                _outgoingFileName = null;
                _reversalFileName = null;
                _matchResult = null;
              });
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
                    title: '1. Outgoing Transactions',
                    subtitle: 'Drop or select core outgoing CSV report',
                    fileName: _outgoingFileName,
                    icon: Icons.outbox_rounded,
                    onTap: _pickOutgoingFile,
                    onClear: () => setState(() {
                      _outgoings = [];
                      _outgoingFileName = null;
                      _matchResult = null;
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Reversal Transactions',
                    subtitle: 'Drop or select reversal partner CSV report',
                    fileName: _reversalFileName,
                    icon: Icons.published_with_changes_rounded,
                    onTap: _pickReversalFile,
                    onClear: () => setState(() {
                      _reversals = [];
                      _reversalFileName = null;
                      _matchResult = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Execute Button
            if (_outgoings.isNotEmpty && _reversals.isNotEmpty && _matchResult == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ElevatedButton.icon(
                  onPressed: _runMatching,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Execute Tolerance-Based Matching'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFAD1457),
                  ),
                ),
              ),

            // Metrics Bar
            if (_matchResult != null) ...[
              Row(
                children: [
                  Expanded(
                    child: CboMetricCard(
                      title: 'Matched Pairs',
                      value: '$matchedCount',
                      subtitle: 'Exact & Tolerance Pairs',
                      icon: Icons.check_circle_rounded,
                      color: CboColors.bankGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Unmatched Outgoings',
                      value: '$unmatchedOut',
                      subtitle: 'Missing reversal',
                      icon: Icons.warning_amber_rounded,
                      color: unmatchedOut > 0 ? CboColors.alertRed : CboColors.slateMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CboMetricCard(
                      title: 'Unmatched Reversals',
                      value: '$unmatchedRev',
                      subtitle: 'Missing outgoing debit',
                      icon: Icons.published_with_changes_rounded,
                      color: unmatchedRev > 0 ? const Color(0xFFAD1457) : CboColors.slateMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // PlutoGrid Table Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: _isProcessing
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFAD1457)),
                            SizedBox(height: 14),
                            Text('Evaluating Tolerance & Interchange Math...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : _matchResult == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.published_with_changes_outlined, size: 48, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting Reversal Matcher Ingestion',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload both Outgoing and Reversal CSV files to calculate tolerance pairings.',
                                  style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: PlutoGrid(
                              columns: _buildColumns(),
                              rows: _buildRows(),
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
