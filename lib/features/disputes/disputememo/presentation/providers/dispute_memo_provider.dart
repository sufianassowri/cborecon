import 'package:flutter_riverpod/legacy.dart';
import '../../domain/models/dispute_memo_item.dart';
import '../../data/datasources/dispute_memo_parser.dart';

class DisputeMemoState {
  final String? atmEnqPath;
  final String? disputeReportPath;
  final DisputeMemoSummary? summary;
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

  DisputeMemoState({
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
    this.commissionRate = 0.005,
    this.disasterRate = 0.05,
    this.vatRate = 0.15,
    this.otherCommissionRate = 0.0,
  });

  DisputeMemoState copyWith({
    String? atmEnqPath,
    String? disputeReportPath,
    DisputeMemoSummary? summary,
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
    return DisputeMemoState(
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

class DisputeMemoNotifier extends StateNotifier<DisputeMemoState> {
  DisputeMemoNotifier() : super(DisputeMemoState());

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
      final matched = await DisputeMemoParser.parseAndMatchReports(
        atmEnqPath: currentAtmPath,
        disputeReportPath: currentDisputePath,
      );

      final summary = DisputeMemoParser.generateMemoData(
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

final disputeMemoProvider =
    StateNotifierProvider<DisputeMemoNotifier, DisputeMemoState>((ref) {
  return DisputeMemoNotifier();
});