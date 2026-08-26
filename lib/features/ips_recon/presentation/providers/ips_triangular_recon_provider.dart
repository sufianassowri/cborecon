import 'package:flutter_riverpod/legacy.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../domain/entities/ips_recon_models.dart';
import '../../domain/usecases/reconcile_ips_triangular_usecase.dart';

class IpsTriangularState {
  final List<List<dynamic>> ecRaw;
  final List<List<dynamic>> etRaw;
  final List<List<dynamic>> crRaw;
  final List<PlutoRow> plutoRows;
  final List<String> ecHeaders;
  final List<String> etHeaders;
  final List<String> crHeaders;
  final IpsTriangularSummary summary;
  final bool isProcessing;
  final String? errorMessage;

  const IpsTriangularState({
    this.ecRaw = const [],
    this.etRaw = const [],
    this.crRaw = const [],
    this.plutoRows = const [],
    this.ecHeaders = const [],
    this.etHeaders = const [],
    this.crHeaders = const [],
    this.summary = const IpsTriangularSummary(),
    this.isProcessing = false,
    this.errorMessage,
  });

  IpsTriangularState copyWith({
    List<List<dynamic>>? ecRaw,
    List<List<dynamic>>? etRaw,
    List<List<dynamic>>? crRaw,
    List<PlutoRow>? plutoRows,
    List<String>? ecHeaders,
    List<String>? etHeaders,
    List<String>? crHeaders,
    IpsTriangularSummary? summary,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return IpsTriangularState(
      ecRaw: ecRaw ?? this.ecRaw,
      etRaw: etRaw ?? this.etRaw,
      crRaw: crRaw ?? this.crRaw,
      plutoRows: plutoRows ?? this.plutoRows,
      ecHeaders: ecHeaders ?? this.ecHeaders,
      etHeaders: etHeaders ?? this.etHeaders,
      crHeaders: crHeaders ?? this.crHeaders,
      summary: summary ?? this.summary,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class IpsTriangularNotifier extends StateNotifier<IpsTriangularState> {
  final ReconcileIpsTriangularUseCase _useCase = ReconcileIpsTriangularUseCase();

  IpsTriangularNotifier() : super(const IpsTriangularState());

  void clear() {
    state = const IpsTriangularState();
  }

  void setEbirrCbsData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    state = state.copyWith(ecRaw: data);
    _reconcile();
  }

  void setEbirrSettlementData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    state = state.copyWith(etRaw: data);
    _reconcile();
  }

  void setCbsReportData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    state = state.copyWith(crRaw: data);
    _reconcile();
  }

  void setCboReconData(List<List<dynamic>> data) {
    setCbsReportData(data);
  }

  void _reconcile() {
    if (state.ecRaw.isEmpty || state.etRaw.isEmpty || state.crRaw.isEmpty) return;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final result = _useCase(
        ebirrCbsData: state.ecRaw,
        ebirrSettlementData: state.etRaw,
        cbsReportData: state.crRaw,
      );

      final List<PlutoRow> pRows = [];
      for (final p in result.pairedRows) {
        final bool isMatched = p['isMatched'] as bool;
        final ecRow = p['ecRow'] as List<dynamic>;
        final etRow = p['etRow'] as List<dynamic>?;
        final crRow = p['crRow'] as List<dynamic>?;

        final Map<String, PlutoCell> cells = {
          'status': PlutoCell(value: isMatched ? 'MATCHED' : 'UNMATCHED'),
        };

        for (int i = 0; i < result.ecHeaders.length; i++) {
          cells['ec_$i'] = PlutoCell(value: i < ecRow.length ? ecRow[i].toString() : '');
        }

        for (int i = 0; i < result.etHeaders.length; i++) {
          cells['et_$i'] = PlutoCell(value: etRow != null && i < etRow.length ? etRow[i].toString() : '');
        }

        for (int i = 0; i < result.crHeaders.length; i++) {
          cells['cr_$i'] = PlutoCell(value: crRow != null && i < crRow.length ? crRow[i].toString() : '');
        }

        pRows.add(PlutoRow(cells: cells));
      }

      state = state.copyWith(
        plutoRows: pRows,
        ecHeaders: result.ecHeaders,
        etHeaders: result.etHeaders,
        crHeaders: result.crHeaders,
        summary: result.summary,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
    }
  }

  Future<bool> exportCsv() async {
    if (state.plutoRows.isEmpty) return false;
    try {
      final List<List<dynamic>> csvData = [];
      final List<String> allHeaders = [
        'TRIANGULAR_STATUS',
        ...state.ecHeaders.map((h) => 'EC_$h'),
        ...state.etHeaders.map((h) => 'ET_$h'),
        ...state.crHeaders.map((h) => 'CR_$h'),
      ];
      csvData.add(allHeaders);

      for (final row in state.plutoRows) {
        final List<dynamic> rowData = [
          row.cells['status']?.value ?? '',
          ...List.generate(state.ecHeaders.length, (i) => row.cells['ec_$i']?.value ?? ''),
          ...List.generate(state.etHeaders.length, (i) => row.cells['et_$i']?.value ?? ''),
          ...List.generate(state.crHeaders.length, (i) => row.cells['cr_$i']?.value ?? ''),
        ];
        csvData.add(rowData);
      }

      final csvStr = CsvParserUtil.convertToCsv(csvData);
      await FileSaverUtil.saveCsv(
        baseName: 'IPS_Triangular_Reconciliation',
        csvContent: csvStr,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final ipsTriangularReconProvider =
    StateNotifierProvider.autoDispose<IpsTriangularNotifier, IpsTriangularState>((ref) {
  return IpsTriangularNotifier();
});
