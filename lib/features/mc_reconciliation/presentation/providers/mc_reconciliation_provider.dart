import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/datasources/mc_reconciliation_local_datasource.dart';
import '../../data/repositories/mc_reconciliation_repository_impl.dart';
import '../../domain/entities/mc_transaction.dart';
import '../../domain/entities/reconciled_summary.dart';
import '../../domain/entities/topup_record.dart';
import '../../domain/repositories/mc_reconciliation_repository.dart';

final mcDataSourceProvider = Provider<McReconciliationLocalDataSource>((ref) {
  return McReconciliationLocalDataSourceImpl();
});

final mcRepositoryProvider = Provider<McReconciliationRepository>((ref) {
  return McReconciliationRepositoryImpl(ref.read(mcDataSourceProvider));
});

class McReconciliationState {
  final bool isLoading;
  final List<TopUpRecord> topUpRecords;
  final List<McTransaction> tsvTransactions;
  final List<ReconciledSummary> summaries;
  final String? errorMessage;
  final String? successMessage;

  McReconciliationState({
    this.isLoading = false,
    this.topUpRecords = const [],
    this.tsvTransactions = const [],
    this.summaries = const [],
    this.errorMessage,
    this.successMessage,
  });

  McReconciliationState copyWith({
    bool? isLoading,
    List<TopUpRecord>? topUpRecords,
    List<McTransaction>? tsvTransactions,
    List<ReconciledSummary>? summaries,
    String? errorMessage,
    String? successMessage,
  }) {
    return McReconciliationState(
      isLoading: isLoading ?? this.isLoading,
      topUpRecords: topUpRecords ?? this.topUpRecords,
      tsvTransactions: tsvTransactions ?? this.tsvTransactions,
      summaries: summaries ?? this.summaries,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class McReconciliationNotifier extends StateNotifier<McReconciliationState> {
  final McReconciliationRepository repository;

  McReconciliationNotifier(this.repository) : super(McReconciliationState());

  Future<void> loadTopUpFile(String path) async {

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {

      final records = await repository.parseTopUpExcel(path);
      print('Loaded TopUp File count: ${records.length}');
      state = state.copyWith(isLoading: false, topUpRecords: records);
      _autoReconcile();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'TopUp Load Error: $e');
    }
  }

  Future<void> loadTsvFile(String path) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final transactions = await repository.parseMasterCardTsv(path);
      print('Loaded TSV File count: ${transactions.length}');
      state = state.copyWith(isLoading: false, tsvTransactions: transactions);
      _autoReconcile();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'TSV Load Error: $e');
    }
  }

  void _autoReconcile() {
    if (state.topUpRecords.isNotEmpty) {
      final results = repository.reconcile(state.topUpRecords, state.tsvTransactions);
      print('Auto-reconcile produced ${results.length} rows.');
      state = state.copyWith(summaries: results);
    }
    else{
      print('Skipping auto-reconcile: TopUp records list is empty.');
    }
  }

  Future<void> exportResults(String outputPath) async {
    try {
      await repository.exportToExcel(state.summaries, outputPath);
      state = state.copyWith(successMessage: 'Successfully exported to $outputPath');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Export Failed: $e');
    }
  }
}

final mcReconciliationProvider =
StateNotifierProvider<McReconciliationNotifier, McReconciliationState>((ref) {
  return McReconciliationNotifier(ref.read(mcRepositoryProvider));
});