import 'package:flutter_riverpod/legacy.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/services/postgres_service.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../domain/entities/mobile_recon_row.dart';
import '../../domain/usecases/reconcile_telebirr_usecase.dart';

class TelebirrReconState {
  final List<List<dynamic>> cbsRaw;
  final List<List<dynamic>> telebirrRaw;
  final List<MobileReconRow> reconciledRows;
  final List<PlutoRow> plutoRows;
  final List<String> cbsHeaders;
  final List<String> telebirrHeaders;
  final TelebirrMode mode;
  final bool isProcessing;
  final String? errorMessage;

  const TelebirrReconState({
    this.cbsRaw = const [],
    this.telebirrRaw = const [],
    this.reconciledRows = const [],
    this.plutoRows = const [],
    this.cbsHeaders = const [],
    this.telebirrHeaders = const [],
    this.mode = TelebirrMode.cashIn,
    this.isProcessing = false,
    this.errorMessage,
  });

  TelebirrReconState copyWith({
    List<List<dynamic>>? cbsRaw,
    List<List<dynamic>>? telebirrRaw,
    List<MobileReconRow>? reconciledRows,
    List<PlutoRow>? plutoRows,
    List<String>? cbsHeaders,
    List<String>? telebirrHeaders,
    TelebirrMode? mode,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return TelebirrReconState(
      cbsRaw: cbsRaw ?? this.cbsRaw,
      telebirrRaw: telebirrRaw ?? this.telebirrRaw,
      reconciledRows: reconciledRows ?? this.reconciledRows,
      plutoRows: plutoRows ?? this.plutoRows,
      cbsHeaders: cbsHeaders ?? this.cbsHeaders,
      telebirrHeaders: telebirrHeaders ?? this.telebirrHeaders,
      mode: mode ?? this.mode,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class TelebirrReconNotifier extends StateNotifier<TelebirrReconState> {
  final ReconcileTelebirrUseCase _useCase = ReconcileTelebirrUseCase();

  TelebirrReconNotifier() : super(const TelebirrReconState());

  void setMode(TelebirrMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    _reconcile();
  }

  void reset() {
    state = TelebirrReconState(mode: state.mode);
  }

  void clear() {
    reset();
  }

  void setCbsData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(cbsRaw: data, cbsHeaders: headers);
    _reconcile();
  }

  void setTelebirrData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(telebirrRaw: data, telebirrHeaders: headers);
    _reconcile();
  }

  void _reconcile() {
    if (state.cbsRaw.isEmpty || state.telebirrRaw.isEmpty) return;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final List<MobileReconRow> result = _useCase(
        cbsData: state.cbsRaw,
        telebirrData: state.telebirrRaw,
        mode: state.mode,
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

        for (int i = 0; i < state.telebirrHeaders.length; i++) {
          final val = (r.rawWalletRow != null && i < r.rawWalletRow!.length)
              ? r.rawWalletRow![i]?.toString() ?? ''
              : (r.walletData[state.telebirrHeaders[i]]?.toString() ?? '');
          cells['tele_$i'] = PlutoCell(value: val);
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
        moduleName: 'Telebirr Reconciliation (${state.mode == TelebirrMode.cashIn ? "CashIn" : "CashOut"})',
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
        'ORDER_ID',
        ...state.cbsHeaders.map((h) => 'CBS_$h'),
        ...state.telebirrHeaders.map((h) => 'TELE_$h'),
      ];
      csvData.add(allHeaders);

      for (final row in state.plutoRows) {
        final List<dynamic> rowData = [
          row.cells['status']?.value ?? '',
          row.cells['key']?.value ?? '',
          ...List.generate(state.cbsHeaders.length, (i) => row.cells['cbs_$i']?.value ?? ''),
          ...List.generate(state.telebirrHeaders.length, (i) => row.cells['tele_$i']?.value ?? ''),
        ];
        csvData.add(rowData);
      }

      final modeName = state.mode == TelebirrMode.cashIn ? 'CashIn' : 'CashOut';
      final csvStr = CsvParserUtil.convertToCsv(csvData);
      await FileSaverUtil.saveCsv(
        baseName: 'Telebirr_${modeName}_Recon',
        csvContent: csvStr,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final telebirrReconProvider =
    StateNotifierProvider.autoDispose<TelebirrReconNotifier, TelebirrReconState>((ref) {
  return TelebirrReconNotifier();
});
