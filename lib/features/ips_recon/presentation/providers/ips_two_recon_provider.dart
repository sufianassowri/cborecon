import 'package:flutter_riverpod/legacy.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../domain/entities/ips_recon_models.dart';
import '../../domain/usecases/reconcile_ips_two_file_usecase.dart';

class IpsTwoReconState {
  final List<List<dynamic>> ipsRaw;
  final List<List<dynamic>> settlementRaw;
  final List<IpsTwoFileRow> reconciledRows;
  final List<PlutoRow> plutoRows;
  final List<String> ipsHeaders;
  final List<String> setHeaders;
  final bool isProcessing;
  final String? errorMessage;

  const IpsTwoReconState({
    this.ipsRaw = const [],
    this.settlementRaw = const [],
    this.reconciledRows = const [],
    this.plutoRows = const [],
    this.ipsHeaders = const [],
    this.setHeaders = const [],
    this.isProcessing = false,
    this.errorMessage,
  });

  IpsTwoReconState copyWith({
    List<List<dynamic>>? ipsRaw,
    List<List<dynamic>>? settlementRaw,
    List<IpsTwoFileRow>? reconciledRows,
    List<PlutoRow>? plutoRows,
    List<String>? ipsHeaders,
    List<String>? setHeaders,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return IpsTwoReconState(
      ipsRaw: ipsRaw ?? this.ipsRaw,
      settlementRaw: settlementRaw ?? this.settlementRaw,
      reconciledRows: reconciledRows ?? this.reconciledRows,
      plutoRows: plutoRows ?? this.plutoRows,
      ipsHeaders: ipsHeaders ?? this.ipsHeaders,
      setHeaders: setHeaders ?? this.setHeaders,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class IpsTwoReconNotifier extends StateNotifier<IpsTwoReconState> {
  final ReconcileIpsTwoFileUseCase _useCase = ReconcileIpsTwoFileUseCase();

  IpsTwoReconNotifier() : super(const IpsTwoReconState());

  void clear() {
    state = const IpsTwoReconState();
  }

  void setIpsData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(ipsRaw: data, ipsHeaders: headers);
    _reconcile();
  }

  void setSettlementData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    final headers = data[0].map((e) => e.toString().trim()).toList();
    state = state.copyWith(settlementRaw: data, setHeaders: headers);
    _reconcile();
  }

  void _reconcile() {
    if (state.ipsRaw.isEmpty || state.settlementRaw.isEmpty) return;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final List<IpsTwoFileRow> result = _useCase(
        ipsData: state.ipsRaw,
        settlementData: state.settlementRaw,
      );

      final List<PlutoRow> pRows = [];
      for (final r in result) {
        final Map<String, PlutoCell> cells = {
          'status': PlutoCell(value: r.statusLabel),
          'transferId': PlutoCell(value: r.transferId),
        };

        for (final h in state.ipsHeaders) {
          cells['ips_$h'] = PlutoCell(value: r.ipsData[h]?.toString() ?? '');
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
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
    }
  }

  Future<bool> exportCsv() async {
    if (state.plutoRows.isEmpty) return false;
    try {
      final List<List<dynamic>> csvData = [];
      final List<String> allHeaders = [
        'STATUS',
        'BANK_TRANSFER_ID',
        ...state.ipsHeaders.map((h) => 'IPS_$h'),
        ...state.setHeaders.map((h) => 'SETTLE_$h'),
      ];
      csvData.add(allHeaders);

      for (final row in state.plutoRows) {
        final List<dynamic> rowData = [
          row.cells['status']?.value ?? '',
          row.cells['transferId']?.value ?? '',
          ...state.ipsHeaders.map((h) => row.cells['ips_$h']?.value ?? ''),
          ...state.setHeaders.map((h) => row.cells['set_$h']?.value ?? ''),
        ];
        csvData.add(rowData);
      }

      final csvStr = CsvParserUtil.convertToCsv(csvData);
      await FileSaverUtil.saveCsv(
        baseName: 'IPS_Settlement_Recon',
        csvContent: csvStr,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final ipsTwoReconProvider =
    StateNotifierProvider.autoDispose<IpsTwoReconNotifier, IpsTwoReconState>((ref) {
  return IpsTwoReconNotifier();
});
