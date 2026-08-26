import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/widgets/cbo_file_dropzone.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../domain/usecases/reconcile_shortage_excess_usecase.dart';

enum ShortageFilter { matched, cbsOnly, switchOnly, all }

class StatsGroup {
  int crmCount = 0;
  double crmSum = 0.0;
  int ncrCount = 0;
  double ncrSum = 0.0;
  int totalCount = 0;
  double totalSum = 0.0;

  void add(String type, double amt) {
    totalCount++;
    totalSum += amt;
    final upper = type.toUpperCase();
    if (upper == 'CRM') {
      crmCount++;
      crmSum += amt;
    } else if (upper == 'NCR') {
      ncrCount++;
      ncrSum += amt;
    }
  }
}

class ShortageExcessDashboard extends StatefulWidget {
  const ShortageExcessDashboard({super.key});

  @override
  State<ShortageExcessDashboard> createState() => _ShortageExcessDashboardState();
}

class _ShortageExcessDashboardState extends State<ShortageExcessDashboard> {
  final ReconcileShortageExcessUseCase _useCase = ReconcileShortageExcessUseCase();

  List<Map<String, dynamic>> _cbsRaw = [];
  List<Map<String, dynamic>> _swRaw = [];
  String? _cbsFileName;
  String? _swFileName;

  List<Map<String, dynamic>> _cbsOnly = [];
  List<Map<String, dynamic>> _swOnly = [];
  List<Map<String, dynamic>> _matched = [];
  List<String> _cbsHeaders = [];
  List<String> _swHeaders = [];

  bool _isProcessing = false;
  bool _hasExecuted = false;
  ShortageFilter _selectedFilter = ShortageFilter.matched;

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Shortage & Excess Hardware Tracker Guide',
      modulePurpose: 'Reconciles CBS Core Banking GL extracts with Payment Switch / Settlement journals on 3 strict criteria: TXN.AMOUNT = Amount, CARD.ACC.ID = Terminal_ID, and RETRIEVAL.REF.NO = Refnum_F37. Classifies hardware (NCR/CRM) and auto-derives 13-digit GL accounts.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load CBS GL Extract',
          format: '.CSV / .XLSX',
          description: 'Extract with columns: TRANS.REF, VALUE.DATE, DEBIT.ACCT.NO, CREDIT.ACCT.NO, TXN.AMOUNT, CARD.ACC.ID, RETRIEVAL.REF.NO.',
          expectedColumns: ['TXN.AMOUNT', 'CARD.ACC.ID', 'RETRIEVAL.REF.NO'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Settlement / Switch Journal',
          format: '.CSV / .XLSX',
          description: 'Settlement file with columns: Issuer, Acquirer, Card_Number, Amount, Transaction_Date, Terminal_ID, Transaction_Description, Refnum_F37.',
          expectedColumns: ['Amount', 'Terminal_ID', 'Refnum_F37'],
        ),
        ReconStepGuide(
          step: 3,
          title: '3-Way Criteria Validation',
          format: 'Automatic',
          description: 'Matches when (1) TXN.AMOUNT = Amount, (2) CARD.ACC.ID = Terminal_ID, and (3) RETRIEVAL.REF.NO = Refnum_F37. If any fail, categorizes as CBS side only or Switch side only.',
        ),
      ],
      tips: const [
        'Matches require all 3 fields to align simultaneously.',
        'NCR ATMs generate ETB1000100... accounts, CRM ATMs generate ETB1000200... accounts.',
        'Switch between Matched (Side by Side), CBS Only, Switch Only, and All view tabs.',
      ],
    );
  }

  List<List<dynamic>> _parseBytesToTable(Uint8List bytes, String fileName) {
    if (fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')) {
      try {
        final excel = excel_pkg.Excel.decodeBytes(bytes);
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null && sheet.rows.isNotEmpty) {
            return sheet.rows.map((row) {
              return row.map((cell) => cell?.value?.toString().trim() ?? '').toList();
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('Excel decoding fallback to CSV: $e');
      }
    }
    return CsvParserUtil.parseBytes(bytes);
  }

  Future<void> _pickFile(bool isCbs) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final fileName = res.files.single.name;
      final data = _parseBytesToTable(res.files.single.bytes!, fileName);
      if (data.isEmpty) return;

      final headers = data[0].map((e) => e.toString().trim()).toList();
      final mapped = data.skip(1).map((row) {
        final m = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          if (i < row.length) m[headers[i]] = row[i];
        }
        return m;
      }).toList();

      setState(() {
        _hasExecuted = false;
        if (isCbs) {
          _cbsRaw = mapped;
          _cbsFileName = fileName;
          _cbsHeaders = headers;
        } else {
          _swRaw = mapped;
          _swFileName = fileName;
          _swHeaders = headers;
        }
      });
    }
  }

  void _runReconciliation() {
    if (_cbsRaw.isEmpty || _swRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both CBS and Settlement/Switch files.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final result = _useCase(_cbsRaw, _swRaw);

    setState(() {
      _cbsOnly = result.cbsOnly;
      _swOnly = result.switchOnly;
      _matched = result.matched;
      if (result.cbsHeaders.isNotEmpty) _cbsHeaders = result.cbsHeaders;
      if (result.switchHeaders.isNotEmpty) _swHeaders = result.switchHeaders;
      _isProcessing = false;
      _hasExecuted = true;
      _selectedFilter = ShortageFilter.matched;
    });
  }

  StatsGroup _computeStats(List<Map<String, dynamic>> list, {bool isMatched = false}) {
    final stats = StatsGroup();
    for (final item in list) {
      final String type = item['ATM_TYPE'] ?? 'UNKNOWN';
      final double amt = (item['AMOUNT'] is num)
          ? (item['AMOUNT'] as num).toDouble()
          : (double.tryParse(item['AMOUNT']?.toString() ?? '0') ?? 0.0);
      stats.add(type, amt);
    }
    return stats;
  }

  List<PlutoColumn> _buildColumns() {
    switch (_selectedFilter) {
      case ShortageFilter.matched:
        return _buildMatchedSideBySideColumns();
      case ShortageFilter.cbsOnly:
        return _buildCbsOnlyColumns();
      case ShortageFilter.switchOnly:
        return _buildSwitchOnlyColumns();
      case ShortageFilter.all:
        return _buildAllUnifiedColumns();
    }
  }

  List<PlutoColumn> _buildMatchedSideBySideColumns() {
    final List<PlutoColumn> cols = [
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        renderer: (ctx) => _statusBadge(ctx.cell.value.toString()),
      ),
      PlutoColumn(
        title: 'ATM Hardware',
        field: 'atm_type',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Derived GL Account',
        field: 'atm_acc',
        type: PlutoColumnType.text(),
        width: 170,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Matched Terminal',
        field: 'terminal_id',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Matched RRN',
        field: 'rrn',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Matched Amount',
        field: 'amount',
        type: PlutoColumnType.currency(symbol: 'ETB '),
        width: 140,
        enableEditingMode: false,
      ),
    ];

    // CBS Side Columns
    for (final h in _cbsHeaders) {
      cols.add(PlutoColumn(
        title: 'CBS: $h',
        field: 'cbs_$h',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    // Settlement / Switch Side Columns
    for (final h in _swHeaders) {
      cols.add(PlutoColumn(
        title: 'SETTLE: $h',
        field: 'sw_$h',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  List<PlutoColumn> _buildCbsOnlyColumns() {
    final List<PlutoColumn> cols = [
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 130,
        enableEditingMode: false,
        renderer: (ctx) => _statusBadge(ctx.cell.value.toString()),
      ),
      PlutoColumn(
        title: 'ATM Hardware',
        field: 'atm_type',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Derived GL Account',
        field: 'atm_acc',
        type: PlutoColumnType.text(),
        width: 170,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Terminal ID',
        field: 'terminal_id',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'RRN',
        field: 'rrn',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'TXN.AMOUNT',
        field: 'amount',
        type: PlutoColumnType.currency(symbol: 'ETB '),
        width: 140,
        enableEditingMode: false,
      ),
    ];

    for (final h in _cbsHeaders) {
      cols.add(PlutoColumn(
        title: 'CBS: $h',
        field: 'cbs_$h',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  List<PlutoColumn> _buildSwitchOnlyColumns() {
    final List<PlutoColumn> cols = [
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 130,
        enableEditingMode: false,
        renderer: (ctx) => _statusBadge(ctx.cell.value.toString()),
      ),
      PlutoColumn(
        title: 'ATM Hardware',
        field: 'atm_type',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Derived GL Account',
        field: 'atm_acc',
        type: PlutoColumnType.text(),
        width: 170,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Terminal ID',
        field: 'terminal_id',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Refnum_F37 (RRN)',
        field: 'rrn',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'amount',
        type: PlutoColumnType.currency(symbol: 'ETB '),
        width: 140,
        enableEditingMode: false,
      ),
    ];

    for (final h in _swHeaders) {
      cols.add(PlutoColumn(
        title: 'SETTLE: $h',
        field: 'sw_$h',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ));
    }

    return cols;
  }

  List<PlutoColumn> _buildAllUnifiedColumns() {
    return [
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 130,
        enableEditingMode: false,
        renderer: (ctx) => _statusBadge(ctx.cell.value.toString()),
      ),
      PlutoColumn(
        title: 'ATM Hardware',
        field: 'atm_type',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Derived GL Account',
        field: 'atm_acc',
        type: PlutoColumnType.text(),
        width: 170,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Terminal ID',
        field: 'terminal_id',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'RRN / Ref',
        field: 'rrn',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'amount',
        type: PlutoColumnType.currency(symbol: 'ETB '),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Source',
        field: 'source',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
    ];
  }

  Widget _statusBadge(String val) {
    final bool isMatch = val == 'MATCHED';
    final bool isCbsOnly = val == 'UNMATCHED_CBS';
    Color bg = isMatch ? CboColors.statusOkBg : CboColors.statusMissingBg;
    Color fg = isMatch ? CboColors.statusOkText : CboColors.statusMissingText;
    String label = isMatch ? 'MATCHED' : (isCbsOnly ? 'CBS ONLY' : 'SWITCH ONLY');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  List<PlutoRow> _buildRows() {
    switch (_selectedFilter) {
      case ShortageFilter.matched:
        return _buildMatchedRows();
      case ShortageFilter.cbsOnly:
        return _buildCbsOnlyRows();
      case ShortageFilter.switchOnly:
        return _buildSwitchOnlyRows();
      case ShortageFilter.all:
        return _buildAllUnifiedRows();
    }
  }

  List<PlutoRow> _buildMatchedRows() {
    final List<PlutoRow> rows = [];
    for (final m in _matched) {
      final cbs = m['cbs'] as Map<String, dynamic>? ?? {};
      final sw = m['sw'] as Map<String, dynamic>? ?? {};

      final Map<String, PlutoCell> cells = {
        'status': PlutoCell(value: 'MATCHED'),
        'atm_type': PlutoCell(value: m['ATM_TYPE'] ?? 'UNKNOWN'),
        'atm_acc': PlutoCell(value: m['ATM_ACC'] ?? sw['ATM_ACC'] ?? '-'),
        'terminal_id': PlutoCell(value: m['TERMINAL_ID'] ?? sw['Terminal_ID'] ?? ''),
        'rrn': PlutoCell(value: m['RRN'] ?? sw['Refnum_F37'] ?? ''),
        'amount': PlutoCell(value: m['AMOUNT'] ?? 0.0),
      };

      for (final h in _cbsHeaders) {
        cells['cbs_$h'] = PlutoCell(value: cbs[h]?.toString() ?? '');
      }

      for (final h in _swHeaders) {
        cells['sw_$h'] = PlutoCell(value: sw[h]?.toString() ?? '');
      }

      rows.add(PlutoRow(cells: cells));
    }
    return rows;
  }

  List<PlutoRow> _buildCbsOnlyRows() {
    final List<PlutoRow> rows = [];
    for (final r in _cbsOnly) {
      final Map<String, PlutoCell> cells = {
        'status': PlutoCell(value: 'UNMATCHED_CBS'),
        'atm_type': PlutoCell(value: r['ATM_TYPE'] ?? 'UNKNOWN'),
        'atm_acc': PlutoCell(value: r['ATM_ACC'] ?? '-'),
        'terminal_id': PlutoCell(value: r['TERMINAL_ID'] ?? r['CARD.ACC.ID'] ?? r['Terminal_ID'] ?? ''),
        'rrn': PlutoCell(value: r['RRN'] ?? r['RETRIEVAL.REF.NO'] ?? r['TRANS.REF'] ?? ''),
        'amount': PlutoCell(value: r['AMOUNT'] ?? 0.0),
      };

      for (final h in _cbsHeaders) {
        cells['cbs_$h'] = PlutoCell(value: r[h]?.toString() ?? '');
      }

      rows.add(PlutoRow(cells: cells));
    }
    return rows;
  }

  List<PlutoRow> _buildSwitchOnlyRows() {
    final List<PlutoRow> rows = [];
    for (final r in _swOnly) {
      final Map<String, PlutoCell> cells = {
        'status': PlutoCell(value: 'UNMATCHED_SW'),
        'atm_type': PlutoCell(value: r['ATM_TYPE'] ?? 'UNKNOWN'),
        'atm_acc': PlutoCell(value: r['ATM_ACC'] ?? '-'),
        'terminal_id': PlutoCell(value: r['TERMINAL_ID'] ?? r['Terminal_ID'] ?? ''),
        'rrn': PlutoCell(value: r['RRN'] ?? r['Refnum_F37'] ?? ''),
        'amount': PlutoCell(value: r['AMOUNT'] ?? 0.0),
      };

      for (final h in _swHeaders) {
        cells['sw_$h'] = PlutoCell(value: r[h]?.toString() ?? '');
      }

      rows.add(PlutoRow(cells: cells));
    }
    return rows;
  }

  List<PlutoRow> _buildAllUnifiedRows() {
    final List<PlutoRow> rows = [];

    // 1. Exceptions first
    for (final r in _cbsOnly) {
      rows.add(PlutoRow(cells: {
        'status': PlutoCell(value: 'UNMATCHED_CBS'),
        'atm_type': PlutoCell(value: r['ATM_TYPE'] ?? 'UNKNOWN'),
        'atm_acc': PlutoCell(value: r['ATM_ACC'] ?? '-'),
        'terminal_id': PlutoCell(value: r['TERMINAL_ID'] ?? r['CARD.ACC.ID'] ?? ''),
        'rrn': PlutoCell(value: r['RRN'] ?? r['RETRIEVAL.REF.NO'] ?? ''),
        'amount': PlutoCell(value: r['AMOUNT'] ?? 0.0),
        'source': PlutoCell(value: 'CBS ONLY'),
      }));
    }

    for (final r in _swOnly) {
      rows.add(PlutoRow(cells: {
        'status': PlutoCell(value: 'UNMATCHED_SW'),
        'atm_type': PlutoCell(value: r['ATM_TYPE'] ?? 'UNKNOWN'),
        'atm_acc': PlutoCell(value: r['ATM_ACC'] ?? '-'),
        'terminal_id': PlutoCell(value: r['TERMINAL_ID'] ?? r['Terminal_ID'] ?? ''),
        'rrn': PlutoCell(value: r['RRN'] ?? r['Refnum_F37'] ?? ''),
        'amount': PlutoCell(value: r['AMOUNT'] ?? 0.0),
        'source': PlutoCell(value: 'SWITCH ONLY'),
      }));
    }

    // 2. Matched
    for (final m in _matched) {
      rows.add(PlutoRow(cells: {
        'status': PlutoCell(value: 'MATCHED'),
        'atm_type': PlutoCell(value: m['ATM_TYPE'] ?? 'UNKNOWN'),
        'atm_acc': PlutoCell(value: m['ATM_ACC'] ?? '-'),
        'terminal_id': PlutoCell(value: m['TERMINAL_ID'] ?? ''),
        'rrn': PlutoCell(value: m['RRN'] ?? ''),
        'amount': PlutoCell(value: m['AMOUNT'] ?? 0.0),
        'source': PlutoCell(value: 'CBS = SWITCH'),
      }));
    }

    return rows;
  }

  Future<void> _exportResults() async {
    if (!_hasExecuted) return;

    final excel = excel_pkg.Excel.createExcel();
    final headers = ['Status', 'ATM Hardware', 'Derived GL Account', 'Terminal ID', 'RRN', 'Amount'];

    void appendDataRows(excel_pkg.Sheet sheet, List<Map<String, dynamic>> items, String defaultStatus, bool isMatched) {
      for (final r in items) {
        final String status = isMatched ? 'MATCHED' : (r['STATUS'] ?? defaultStatus);
        final String atmType = r['ATM_TYPE'] ?? 'UNKNOWN';
        final String atmAcc = r['ATM_ACC'] ?? '-';
        final String termId = r['TERMINAL_ID'] ?? r['CARD.ACC.ID'] ?? r['Terminal_ID'] ?? '';
        final String rrn = r['RRN'] ?? r['RETRIEVAL.REF.NO'] ?? r['Refnum_F37'] ?? r['TRANS.REF'] ?? '';
        final String amt = r['AMOUNT'] != null ? r['AMOUNT'].toString() : (r['TXN.AMOUNT'] ?? r['Amount'] ?? '');

        sheet.appendRow([
          excel_pkg.TextCellValue(status),
          excel_pkg.TextCellValue(atmType),
          excel_pkg.TextCellValue(atmAcc),
          excel_pkg.TextCellValue(termId),
          excel_pkg.TextCellValue(rrn),
          excel_pkg.TextCellValue(amt),
        ]);
      }
    }

    // 1. Matched Pairs Sheet (Side by Side)
    if (_matched.isNotEmpty) {
      final matchedSheet = excel['Matched_Side_By_Side'];
      final List<String> sideBySideHeaders = [
        'Status', 'ATM_Hardware', 'Derived_GL_Account', 'Terminal_ID', 'RRN', 'Amount',
        ..._cbsHeaders.map((h) => 'CBS_$h'),
        ..._swHeaders.map((h) => 'SETTLE_$h'),
      ];
      matchedSheet.appendRow(sideBySideHeaders.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final m in _matched) {
        final cbs = m['cbs'] as Map<String, dynamic>? ?? {};
        final sw = m['sw'] as Map<String, dynamic>? ?? {};

        final List<excel_pkg.CellValue> rowCells = [
          excel_pkg.TextCellValue('MATCHED'),
          excel_pkg.TextCellValue(m['ATM_TYPE'] ?? 'UNKNOWN'),
          excel_pkg.TextCellValue(m['ATM_ACC'] ?? sw['ATM_ACC'] ?? '-'),
          excel_pkg.TextCellValue(m['TERMINAL_ID'] ?? sw['Terminal_ID'] ?? ''),
          excel_pkg.TextCellValue(m['RRN'] ?? sw['Refnum_F37'] ?? ''),
          excel_pkg.TextCellValue(m['AMOUNT'] != null ? m['AMOUNT'].toString() : (sw['Amount'] ?? '')),
          ..._cbsHeaders.map((h) => excel_pkg.TextCellValue(cbs[h]?.toString() ?? '')),
          ..._swHeaders.map((h) => excel_pkg.TextCellValue(sw[h]?.toString() ?? '')),
        ];
        matchedSheet.appendRow(rowCells);
      }
    }

    // 2. CBS Only Sheet
    if (_cbsOnly.isNotEmpty) {
      final cbsSheet = excel['CBS_Only'];
      final List<String> cbsFullHeaders = [
        'Status', 'ATM_Hardware', 'Derived_GL_Account', 'Terminal_ID', 'RRN', 'Amount',
        ..._cbsHeaders.map((h) => 'CBS_$h'),
      ];
      cbsSheet.appendRow(cbsFullHeaders.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final r in _cbsOnly) {
        final List<excel_pkg.CellValue> rowCells = [
          excel_pkg.TextCellValue('UNMATCHED_CBS'),
          excel_pkg.TextCellValue(r['ATM_TYPE'] ?? 'UNKNOWN'),
          excel_pkg.TextCellValue(r['ATM_ACC'] ?? '-'),
          excel_pkg.TextCellValue(r['TERMINAL_ID'] ?? r['CARD.ACC.ID'] ?? ''),
          excel_pkg.TextCellValue(r['RRN'] ?? r['RETRIEVAL.REF.NO'] ?? ''),
          excel_pkg.TextCellValue(r['AMOUNT'] != null ? r['AMOUNT'].toString() : (r['TXN.AMOUNT'] ?? '')),
          ..._cbsHeaders.map((h) => excel_pkg.TextCellValue(r[h]?.toString() ?? '')),
        ];
        cbsSheet.appendRow(rowCells);
      }
    }

    // 3. Switch Only Sheet
    if (_swOnly.isNotEmpty) {
      final swSheet = excel['Switch_Only'];
      final List<String> swFullHeaders = [
        'Status', 'ATM_Hardware', 'Derived_GL_Account', 'Terminal_ID', 'RRN', 'Amount',
        ..._swHeaders.map((h) => 'SETTLE_$h'),
      ];
      swSheet.appendRow(swFullHeaders.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final r in _swOnly) {
        final List<excel_pkg.CellValue> rowCells = [
          excel_pkg.TextCellValue('UNMATCHED_SW'),
          excel_pkg.TextCellValue(r['ATM_TYPE'] ?? 'UNKNOWN'),
          excel_pkg.TextCellValue(r['ATM_ACC'] ?? '-'),
          excel_pkg.TextCellValue(r['TERMINAL_ID'] ?? r['Terminal_ID'] ?? ''),
          excel_pkg.TextCellValue(r['RRN'] ?? r['Refnum_F37'] ?? ''),
          excel_pkg.TextCellValue(r['AMOUNT'] != null ? r['AMOUNT'].toString() : (r['Amount'] ?? '')),
          ..._swHeaders.map((h) => excel_pkg.TextCellValue(r[h]?.toString() ?? '')),
        ];
        swSheet.appendRow(rowCells);
      }
    }

    // 4. All Records Summary Sheet
    final allSheet = excel['All_Summary'];
    allSheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());
    appendDataRows(allSheet, _cbsOnly, 'UNMATCHED_CBS', false);
    appendDataRows(allSheet, _swOnly, 'UNMATCHED_SW', false);
    appendDataRows(allSheet, _matched, 'MATCHED', true);

    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await FileSaverUtil.saveBytes(
        bytes: Uint8List.fromList(fileBytes),
        fileName: 'Shortage_Excess_SideBySide_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Multi-Sheet Side-by-Side Shortage & Excess report exported successfully!')),
        );
      }
    }
  }

  Widget _buildSummaryBanner(StatsGroup cbsStats, StatsGroup matchedStats, StatsGroup swStats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0077C8), // Vibrant CBO Blue header from design
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsColumn('CBS only:', cbsStats),
                const Divider(color: Colors.white24, height: 18),
                _buildStatsColumn('Matched:(CBS=SWITCH)', matchedStats),
                const Divider(color: Colors.white24, height: 18),
                _buildStatsColumn('SWITCH ONLY:', swStats),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStatsColumn('CBS only:', cbsStats)),
              Container(width: 1, height: 70, color: Colors.white30),
              Expanded(child: _buildStatsColumn('Matched:(CBS=SWITCH)', matchedStats)),
              Container(width: 1, height: 70, color: Colors.white30),
              Expanded(child: _buildStatsColumn('SWITCH ONLY:', swStats)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsColumn(String title, StatsGroup stats) {
    final numFormat = NumberFormat('#,##0.00', 'en_US');
    final countFormat = NumberFormat('#,##0', 'en_US');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'CRM: ${countFormat.format(stats.crmCount)} | sum: ${numFormat.format(stats.crmSum)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'NCR: ${countFormat.format(stats.ncrCount)} | sum: ${numFormat.format(stats.ncrSum)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Total: ${countFormat.format(stats.totalCount)} | Total: ${numFormat.format(stats.totalSum)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cbsStats = _computeStats(_cbsOnly);
    final matchedStats = _computeStats(_matched, isMatched: true);
    final swStats = _computeStats(_swOnly);

    return ResponsiveShell(
      currentRoute: '/shortage_excess',
      title: 'Shortage & Excess Hardware GL Tracker',
      subtitle: 'Side-by-Side Validation, ATM Hardware Classification & Auto-Derived GLs',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.primaryCyan),
          tooltip: 'Operation Guide',
          onPressed: _showGuide,
        ),
        if (_hasExecuted) ...[
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
                _cbsRaw = [];
                _swRaw = [];
                _cbsFileName = null;
                _swFileName = null;
                _cbsOnly = [];
                _swOnly = [];
                _matched = [];
                _cbsHeaders = [];
                _swHeaders = [];
                _hasExecuted = false;
              });
            },
          ),
        ],
      ],
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Ingestion / Controls Row
            Row(
              children: [
                Expanded(
                  child: CboFileDropzone(
                    title: '1. CBS GL Extract',
                    subtitle: _cbsRaw.isNotEmpty ? '${_cbsRaw.length} rows loaded' : 'Drop or select CBS file (.csv / .xlsx)',
                    fileName: _cbsFileName,
                    icon: Icons.account_balance_rounded,
                    onTap: () => _pickFile(true),
                    onClear: () => setState(() {
                      _cbsRaw = [];
                      _cbsFileName = null;
                      _hasExecuted = false;
                    }),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: CboFileDropzone(
                    title: '2. Settlement / Switch Log',
                    subtitle: _swRaw.isNotEmpty ? '${_swRaw.length} rows loaded' : 'Drop or select settlement file (.csv / .xlsx)',
                    fileName: _swFileName,
                    icon: Icons.atm_rounded,
                    onTap: () => _pickFile(false),
                    onClear: () => setState(() {
                      _swRaw = [];
                      _swFileName = null;
                      _hasExecuted = false;
                    }),
                  ),
                ),
                if (_cbsRaw.isNotEmpty && _swRaw.isNotEmpty && !_hasExecuted) ...[
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: _runReconciliation,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                      backgroundColor: const Color(0xFFF27000), // Orange RUN button from design
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'RUN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Summary Analytics Banner
            if (_hasExecuted) ...[
              _buildSummaryBanner(cbsStats, matchedStats, swStats),
              const SizedBox(height: 14),

              // Filter Switcher Segmented Buttons
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: CboColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SegmentedButton<ShortageFilter>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF0077C8).withValues(alpha: 0.15);
                        }
                        return Colors.transparent;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF005A9E);
                        }
                        return CboColors.slateDark;
                      }),
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: ShortageFilter.matched,
                        label: Text('Matched (${NumberFormat('#,##0').format(_matched.length)})'),
                        icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: ShortageFilter.cbsOnly,
                        label: Text('CBS Only (${NumberFormat('#,##0').format(_cbsOnly.length)})'),
                        icon: const Icon(Icons.account_balance_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ShortageFilter.switchOnly,
                        label: Text('Switch Only (${NumberFormat('#,##0').format(_swOnly.length)})'),
                        icon: const Icon(Icons.atm_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ShortageFilter.all,
                        label: Text('All (${NumberFormat('#,##0').format(_matched.length + _cbsOnly.length + _swOnly.length)})'),
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                      ),
                    ],
                    selected: {_selectedFilter},
                    onSelectionChanged: (s) => setState(() => _selectedFilter = s.first),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // PlutoGrid Table Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: _isProcessing
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0077C8)),
                            SizedBox(height: 14),
                            Text('Reconciling CBS & Settlement Data...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : !_hasExecuted
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.compare_arrows_rounded, size: 52, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                const Text(
                                  'Awaiting CBS & Settlement Files',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload both CBS GL extract and Switch Settlement log (.csv / .xlsx), then click RUN.',
                                  style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PlutoGrid(
                              key: ValueKey('${_selectedFilter.name}_${_matched.length}_${_cbsOnly.length}_${_swOnly.length}'),
                              columns: _buildColumns(),
                              rows: _buildRows(),
                              configuration: const PlutoGridConfiguration(
                                style: PlutoGridStyleConfig(
                                  enableGridBorderShadow: false,
                                  gridBorderColor: CboColors.cardBorder,
                                  rowHeight: 40,
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
