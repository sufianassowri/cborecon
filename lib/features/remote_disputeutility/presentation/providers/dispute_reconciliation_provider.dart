import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/dispute_reconciliation_row.dart';
import '../../data/datasources/excel_exporter_datasource.dart';
import '../../data/repositories/dispute_reconciliation_repository.dart';

part 'dispute_reconciliation_provider.g.dart';

@riverpod
class RemoteDisputeNotifier extends _$RemoteDisputeNotifier {
  final _repository = DisputeReconciliationRepository();

  List<List<dynamic>> _cbsData = [];
  List<List<dynamic>> _settlementData = [];

  @override
  FutureOr<List<DisputeReconciliationRow>> build() => [];

  void updateCbsData(List<List<dynamic>> data) {
    if (data.isEmpty) return;
    _cbsData = data;
    _reconcileAndRefresh();
  }

  void updateSettlementData(List<List<List<dynamic>>> datasets) {
    if (datasets.isEmpty) return;

    List<List<dynamic>> combined = [];
    List<String> headers = [];

    for (var data in datasets) {
      if (data.isEmpty) continue;
      if (headers.isEmpty) {
        headers = data[0].map((e) => e.toString().trim()).toList();
        combined.add(data[0]);
      }
      combined.addAll(data.skip(1));
    }

    if (combined.isEmpty) return;
    _settlementData = combined;
    _reconcileAndRefresh();
  }

  void _reconcileAndRefresh() {
    if (_cbsData.isEmpty || _settlementData.isEmpty) return;
    state = const AsyncValue.loading();
    try {
      final rows = _repository.reconcile(
        cbsData: _cbsData,
        settlementData: _settlementData,
      );
      state = AsyncValue.data(rows);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> exportToExcel() async {
    final rows = state.value ?? [];
    return await ExcelExporterDatasource.exportToExcel(rows);
  }
}