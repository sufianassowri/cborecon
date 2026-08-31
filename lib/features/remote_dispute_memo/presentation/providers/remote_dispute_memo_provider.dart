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
  }) {
    state = state.copyWith(
      disputedAtmAcc: disputedAtmAcc,
      commPayableAcc: commPayableAcc,
      disasterRiskAcc: disasterRiskAcc,
      preparedBy: preparedBy,
      checkedBy: checkedBy,
    );
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
