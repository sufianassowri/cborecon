import 'package:flutter_riverpod/legacy.dart';
import '../../domain/models/remote_dispute_memo_item.dart';
import '../../data/datasources/remote_dispute_memo_parser.dart';

class RemoteDisputeMemoState {
  final String? atmEnqPath;
  final String? disputeReportPath;
  final RemoteDisputeMemoSummary? summary;
  final bool isLoading;
  final String? error;

  // Account Input Fields
  final String disputedAtmAcc;
  final String commPayableAcc;
  final String disasterRiskAcc;
  final String preparedBy;
  final String checkedBy;

  // Rate Input Fields
  final double commissionRate;
  final double disasterRate;
  final double vatRate;
  final double otherCommissionRate;

  RemoteDisputeMemoState({
    this.atmEnqPath,
    this.disputeReportPath,
    this.summary,
    this.isLoading = false,
    this.error,
    this.disputedAtmAcc = 'ETB1763400170001',
    this.commPayableAcc = 'ETB1763400360473',
    this.disasterRiskAcc = 'ETB1759500010001',
    this.preparedBy = 'Sufian Aliyyii kedir',
    this.checkedBy = 'Shemsia Hamid Aman',
    this.commissionRate = 0.006,
    this.disasterRate = 0.05,
    this.vatRate = 0.15,
    this.otherCommissionRate = 0.0,
  });

  RemoteDisputeMemoState copyWith({
    String? atmEnqPath,
    String? disputeReportPath,
    RemoteDisputeMemoSummary? summary,
    bool? isLoading,
    String? error,
    String? disputedAtmAcc,
    String? commPayableAcc,
    String? disasterRiskAcc,
    String? preparedBy,
    String? checkedBy,
    double? commissionRate,
    double? disasterRate,
    double? vatRate,
    double? otherCommissionRate,
  }) {
    return RemoteDisputeMemoState(
      atmEnqPath: atmEnqPath ?? this.atmEnqPath,
      disputeReportPath: disputeReportPath ?? this.disputeReportPath,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      disputedAtmAcc: disputedAtmAcc ?? this.disputedAtmAcc,
      commPayableAcc: commPayableAcc ?? this.commPayableAcc,
      disasterRiskAcc: disasterRiskAcc ?? this.disasterRiskAcc,
      preparedBy: preparedBy ?? this.preparedBy,
      checkedBy: checkedBy ?? this.checkedBy,
      commissionRate: commissionRate ?? this.commissionRate,
      disasterRate: disasterRate ?? this.disasterRate,
      vatRate: vatRate ?? this.vatRate,
      otherCommissionRate: otherCommissionRate ?? this.otherCommissionRate,
    );
  }
}

class RemoteDisputeMemoNotifier extends StateNotifier<RemoteDisputeMemoState> {
  RemoteDisputeMemoNotifier() : super(RemoteDisputeMemoState());

  void setAtmEnqPath(String path) {
    state = state.copyWith(atmEnqPath: path);
    _process();
  }

  void setDisputeReportPath(String path) {
    state = state.copyWith(disputeReportPath: path);
    _process();
  }

  void updateAccounts({
    String? disputedAtmAcc,
    String? commPayableAcc,
    String? disasterRiskAcc,
    String? preparedBy,
    String? checkedBy,
    double? commissionRate,
    double? disasterRate,
    double? vatRate,
    double? otherCommissionRate,
  }) {
    state = state.copyWith(
      disputedAtmAcc: disputedAtmAcc,
      commPayableAcc: commPayableAcc,
      disasterRiskAcc: disasterRiskAcc,
      preparedBy: preparedBy,
      checkedBy: checkedBy,
      commissionRate: commissionRate,
      disasterRate: disasterRate,
      vatRate: vatRate,
      otherCommissionRate: otherCommissionRate,
    );
    // When rates change, we should re-process the summary if data is loaded
    if (state.atmEnqPath != null && state.disputeReportPath != null && state.summary != null) {
      _process();
    }
  }

  Future<void> _process() async {
    final currentAtmPath = state.atmEnqPath;
    final currentDisputePath = state.disputeReportPath;

    if (currentAtmPath == null || currentDisputePath == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final matched = await RemoteDisputeMemoParser.parseAndMatchReports(
        atmEnqPath: currentAtmPath,
        disputeReportPath: currentDisputePath,
      );

      final summary = RemoteDisputeMemoParser.generateMemoData(
        matchedData: matched,
        commissionRate: state.commissionRate,
        disasterRate: state.disasterRate,
        vatRate: state.vatRate,
        otherCommissionRate: state.otherCommissionRate,
      );

      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final remoteDisputeMemoProvider =
StateNotifierProvider<RemoteDisputeMemoNotifier, RemoteDisputeMemoState>((ref) {
  return RemoteDisputeMemoNotifier();
});
