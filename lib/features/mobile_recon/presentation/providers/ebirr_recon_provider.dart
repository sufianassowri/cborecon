import 'package:flutter_riverpod/legacy.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/services/postgres_service.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../domain/entities/mobile_recon_row.dart';
import '../../domain/usecases/reconcile_ebirr_usecase.dart';

class EbirrReconState {
  final List<List<dynamic>> cbsRaw;
  final List<List<dynamic>> ebirrRaw;
  final List<MobileReconRow> reconciledRows;
  final List<PlutoRow> plutoRows;
  final List<String> cbsHeaders;
  final List<String> ebirrHeaders;
  final bool isProcessing;
  final String? errorMessage;

  const EbirrReconState({
    this.cbsRaw = const [],
    this.ebirrRaw = const [],
    this.reconciledRows = const [],
    this.plutoRows = const [],
    this.cbsHeaders = const [],
    this.ebirrHeaders = const [],
    this.isProcessing = false,
    this.errorMessage,
  });

  EbirrReconState copyWith({
    List<List<dynamic>>? cbsRaw,
    List<List<dynamic>>? ebirrRaw,
    List<MobileReconRow>? reconciledRows,
    List<PlutoRow>? plutoRows,
    List<String>? cbsHeaders,
    List<String>? ebirrHeaders,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return EbirrReconState(
      cbsRaw: cbsRaw ?? this.cbsRaw,
      ebirrRaw: ebirrRaw ?? this.ebirrRaw,
      reconciledRows: reconciledRows ?? this.reconciledRows,
      plutoRows: plutoRows ?? this.plutoRows,
      cbsHeaders: cbsHeaders ?? this.cbsHeaders,
      ebirrHeaders: ebirrHeaders ?? this.ebirrHeaders,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class EbirrReconNotifier extends StateNotifier<EbirrReconState> {
  final ReconcileEbirrUseCase _useCase = ReconcileEbirrUseCase();

  EbirrReconNotifier() : super(const EbirrReconState());

  void clear() {
    state = const EbirrReconState();
  }

  void setCbsData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(cbsRaw: data, cbsHeaders: headers);
    _reconcile();
  }

  void setEbirrData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(ebirrRaw: data, ebirrHeaders: headers);
    _reconcile();
  }

  void _reconcile() {
    if (state.cbsRaw.isEmpty || state.ebirrRaw.isEmpty) return;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final List<MobileReconRow> result = _useCase(
        cbsData: state.cbsRaw,
        ebirrData: state.ebirrRaw,
      );

      final List<PlutoRow> pRows = [];
      for (final r in result) {
        final Map<String, PlutoCell> cells = {
          'status': PlutoCell(value: r.statusLabel),
          'key': PlutoCell(value: r.key),
        };

        for (int i = 0; i < state.cbsHeaders.length; i++) {
          final val = (r.rawCbsRow != null && i < r.rawCbsRow!.length)
              ? r.rawCbsRow![i]?.toString() ?? ''
              : (r.cbsData[state.cbsHeaders[i]]?.toString() ?? '');
          cells['cbs_$i'] = PlutoCell(value: val);
        }

        for (int i = 0; i < state.ebirrHeaders.length; i++) {
          final val = (r.rawWalletRow != null && i < r.rawWalletRow!.length)
              ? r.rawWalletRow![i]?.toString() ?? ''
              : (r.walletData[state.ebirrHeaders[i]]?.toString() ?? '');
          cells['ebirr_$i'] = PlutoCell(value: val);
        }

        pRows.add(PlutoRow(cells: cells));
      }

      state = state.copyWith(
        reconciledRows: result,
        plutoRows: pRows,
        isProcessing: false,
      );

      final matched = result.where((r) => r.status == MobileReconStatus.ok).length;
      final unmatched = result.length - matched;
      PostgresService.instance.logReconciliation(
        moduleName: 'Ebirr Reconciliation',
        totalRecords: result.length,
        matchedPairs: matched,
        unmatchedExceptions: unmatched,
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
        'STATUS',
        'REFERENCE_KEY',
        ...state.cbsHeaders.map((h) => 'CBS_$h'),
        ...state.ebirrHeaders.map((h) => 'EBIRR_$h'),
      ];
      csvData.add(allHeaders);

      for (final row in state.plutoRows) {
        final List<dynamic> rowData = [
          row.cells['status']?.value ?? '',
          row.cells['key']?.value ?? '',
          ...List.generate(state.cbsHeaders.length, (i) => row.cells['cbs_$i']?.value ?? ''),
          ...List.generate(state.ebirrHeaders.length, (i) => row.cells['ebirr_$i']?.value ?? ''),
        ];
        csvData.add(rowData);
      }

      final csvStr = CsvParserUtil.convertToCsv(csvData);
      await FileSaverUtil.saveCsv(
        baseName: 'Ebirr_Reconciliation',
        csvContent: csvStr,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final ebirrReconProvider =
    StateNotifierProvider.autoDispose<EbirrReconNotifier, EbirrReconState>((ref) {
  return EbirrReconNotifier();
});
