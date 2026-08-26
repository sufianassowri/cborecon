import 'package:flutter_riverpod/legacy.dart';
import '../../domain/models/dispute_memo_item.dart';
import '../../domain/models/memo_format_type.dart';
import '../../data/datasources/dispute_memo_parser.dart';

class DisputeMemoState {
  final String? atmEnqPath;
  final String? disputeReportPath;
  final DisputeType disputeType;
  final MemoFormatType memoFormat;
  final DisputeMemoSummary? summary;
  final bool isLoading;
  final String? error;

  // Account Input Fields
  final String disputedAtmAcc;
  final String commPayableAcc;
  final String disasterRiskAcc;
  final String preparedBy;
  final String checkedBy;

  DisputeMemoState({
    this.atmEnqPath,
    this.disputeReportPath,
    this.disputeType = DisputeType.onUs,
    this.memoFormat = MemoFormatType.fahmi,
    this.summary,
    this.isLoading = false,
    this.error,
    this.disputedAtmAcc = 'ETB1763400170001',
    this.commPayableAcc = 'ETB1763400360473',
    this.disasterRiskAcc = 'ETB1759500010001',
    this.preparedBy = 'Sufian Aliyyii kedir',
    this.checkedBy = 'Shemsia Hamid Aman',
  });

  DisputeMemoState copyWith({
    String? atmEnqPath,
    String? disputeReportPath,
    DisputeType? disputeType,
    MemoFormatType? memoFormat,
    DisputeMemoSummary? summary,
    bool? isLoading,
    String? error,
    String? disputedAtmAcc,
    String? commPayableAcc,
    String? disasterRiskAcc,
    String? preparedBy,
    String? checkedBy,
  }) {
    return DisputeMemoState(
      atmEnqPath: atmEnqPath ?? this.atmEnqPath,
      disputeReportPath: disputeReportPath ?? this.disputeReportPath,
      disputeType: disputeType ?? this.disputeType,
      memoFormat: memoFormat ?? this.memoFormat,
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

  void setDisputeType(DisputeType type) {
    state = state.copyWith(disputeType: type);
    _process();
  }

  void setMemoFormat(MemoFormatType format) {
    state = state.copyWith(memoFormat: format);
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
      final matched = await DisputeMemoParser.parseAndMatchReports(
        atmEnqPath: currentAtmPath,
        disputeReportPath: currentDisputePath,
      );

      final summary = DisputeMemoParser.generateMemoData(
        matchedData: matched,
        disputeType: state.disputeType,
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