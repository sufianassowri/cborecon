import 'package:flutter_riverpod/legacy.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/utils/excel_exporter_util.dart';
import '../../domain/entities/terminal_recon_row.dart';
import '../../domain/usecases/reconcile_cbo_terminal_usecase.dart';
import '../../domain/usecases/reconcile_cbe_terminal_usecase.dart';

class TerminalReconState {
  final List<List<dynamic>> cbsRaw;
  final List<List<dynamic>> settlementRaw;
  final List<TerminalReconRow> reconciledRows;
  final List<PlutoRow> plutoRows;
  final List<String> cbsHeaders;
  final List<String> setHeaders;
  final bool isProcessing;
  final String? errorMessage;

  const TerminalReconState({
    this.cbsRaw = const [],
    this.settlementRaw = const [],
    this.reconciledRows = const [],
    this.plutoRows = const [],
    this.cbsHeaders = const [],
    this.setHeaders = const [],
    this.isProcessing = false,
    this.errorMessage,
  });

  TerminalReconState copyWith({
    List<List<dynamic>>? cbsRaw,
    List<List<dynamic>>? settlementRaw,
    List<TerminalReconRow>? reconciledRows,
    List<PlutoRow>? plutoRows,
    List<String>? cbsHeaders,
    List<String>? setHeaders,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return TerminalReconState(
      cbsRaw: cbsRaw ?? this.cbsRaw,
      settlementRaw: settlementRaw ?? this.settlementRaw,
      reconciledRows: reconciledRows ?? this.reconciledRows,
      plutoRows: plutoRows ?? this.plutoRows,
      cbsHeaders: cbsHeaders ?? this.cbsHeaders,
      setHeaders: setHeaders ?? this.setHeaders,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class TerminalReconNotifier extends StateNotifier<TerminalReconState> {
  final bool isCbeMode;
  final ReconcileCboTerminalUseCase _cboUseCase = ReconcileCboTerminalUseCase();
  final ReconcileCbeTerminalUseCase _cbeUseCase = ReconcileCbeTerminalUseCase();

  TerminalReconNotifier({this.isCbeMode = false}) : super(const TerminalReconState());

  void clear() {
    state = const TerminalReconState();
  }

  void setCbsData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(cbsRaw: data, cbsHeaders: headers);
    _reconcile();
  }

  void setSettlementData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(settlementRaw: data, setHeaders: headers);
    _reconcile();
  }

  void appendMultiSettlementData(List<List<List<dynamic>>> datasets) {
    if (datasets.isEmpty) return;

    List<List<dynamic>> combined = [];
    List<String> unifiedHeaders = [];

    for (final data in datasets) {
      if (data.isEmpty) continue;
      if (unifiedHeaders.isEmpty) {
        unifiedHeaders = data[0].map((e) => e.toString().trim()).toList();
        combined.add(data[0]);
      }
      combined.addAll(data.skip(1));
    }

    if (combined.isEmpty) return;
    state = state.copyWith(settlementRaw: combined, setHeaders: unifiedHeaders);
    _reconcile();
  }

  void _reconcile() {
    if (state.cbsRaw.isEmpty || state.settlementRaw.isEmpty) return;

    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final List<TerminalReconRow> result = isCbeMode
          ? _cbeUseCase(cbsData: state.cbsRaw, settlementData: state.settlementRaw)
          : _cboUseCase(cbsData: state.cbsRaw, settlementData: state.settlementRaw);

      final List<PlutoRow> pRows = [];
      for (final r in result) {
        final Map<String, PlutoCell> cells = {
          'status': PlutoCell(value: r.statusLabel),
          'rrn': PlutoCell(value: r.rrn),
        };

        for (final h in state.cbsHeaders) {
          cells['cbs_$h'] = PlutoCell(value: r.cbsData[h]?.toString() ?? '');
        }

        for (final h in state.setHeaders) {
          cells['set_$h'] = PlutoCell(value: r.settlementData[h]?.toString() ?? '');
        }

        pRows.add(PlutoRow(cells: cells));
      }

      state = state.copyWith(
        reconciledRows: result,
        plutoRows: pRows,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> exportCsv() async {
    if (state.plutoRows.isEmpty) return false;
    try {
      final List<List<dynamic>> csvData = [];
      final List<String> allHeaders = [
        'STATUS',
        'RRN',
        ...state.cbsHeaders.map((h) => 'CBS_$h'),
        ...state.setHeaders.map((h) => 'SET_$h'),
      ];
      csvData.add(allHeaders);

      for (final row in state.plutoRows) {
        final List<dynamic> rowData = [
          row.cells['status']?.value ?? '',
          row.cells['rrn']?.value ?? '',
          ...state.cbsHeaders.map((h) => row.cells['cbs_$h']?.value ?? ''),
          ...state.setHeaders.map((h) => row.cells['set_$h']?.value ?? ''),
        ];
        csvData.add(rowData);
      }

      final csvStr = CsvParserUtil.convertToCsv(csvData);
      await FileSaverUtil.saveCsv(
        baseName: isCbeMode ? 'CBE_Recon_Report' : 'CBO_Terminal_Recon',
        csvContent: csvStr,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> exportExcel() async {
    if (state.plutoRows.isEmpty) return false;
    try {
      final List<String> allHeaders = [
        'STATUS',
        'RRN',
        ...state.cbsHeaders.map((h) => 'CBS_$h'),
        ...state.setHeaders.map((h) => 'SET_$h'),
      ];

      final List<List<dynamic>> dataRows = [];
      for (final row in state.plutoRows) {
        final List<dynamic> rowData = [
          row.cells['status']?.value ?? '',
          row.cells['rrn']?.value ?? '',
          ...state.cbsHeaders.map((h) => row.cells['cbs_$h']?.value ?? ''),
          ...state.setHeaders.map((h) => row.cells['set_$h']?.value ?? ''),
        ];
        dataRows.add(rowData);
      }

      final bytes = ExcelExporterUtil.createExcelWithTextCells(
        sheetName: 'Reconciliation',
        headers: allHeaders,
        rows: dataRows,
      );

      await FileSaverUtil.saveExcel(
        baseName: isCbeMode ? 'CBE_Terminal_Recon' : 'CBO_Terminal_Recon',
        bytes: bytes,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final cboTerminalReconProvider =
    StateNotifierProvider.autoDispose<TerminalReconNotifier, TerminalReconState>((ref) {
  return TerminalReconNotifier(isCbeMode: false);
});

final cbeTerminalReconProvider =
    StateNotifierProvider.autoDispose<TerminalReconNotifier, TerminalReconState>((ref) {
  return TerminalReconNotifier(isCbeMode: true);
});
