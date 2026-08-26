import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/master_card_account.dart';
import '../../domain/usecases/process_initial_topup_usecase.dart';
import '../../domain/usecases/process_mastercard_tsv_usecase.dart';
import '../../domain/usecases/negative_balance_warning.dart';
import '../../data/parsers/tsv_file_parser.dart';
import '../../data/parsers/excel_topup_parser.dart';
import '../../data/datasources/reconciliation_back4app_datasource.dart';
import '../../data/repositories/reconciliation_repository_impl.dart';

final back4appDataSourceProvider =
    Provider<ReconciliationBack4AppDataSource>((ref) {
  return ReconciliationBack4AppDataSource();
});

final reconciliationRepositoryProvider =
    Provider<ReconciliationRepositoryImpl>((ref) {
  return ReconciliationRepositoryImpl(ref.watch(back4appDataSourceProvider));
});

final processMasterCardTsvUseCaseProvider =
    Provider<ProcessMasterCardTsvUseCase>((ref) {
  return ProcessMasterCardTsvUseCase(
      ref.watch(reconciliationRepositoryProvider));
});

final processInitialTopUpUseCaseProvider =
    Provider<ProcessInitialTopupUseCase>((ref) {
  return ProcessInitialTopupUseCase(
      ref.watch(reconciliationRepositoryProvider));
});

final masterCardAccountProvider = NotifierProvider<ReconciliationNotifier,
    AsyncValue<List<MasterCardAccount>>>(
  ReconciliationNotifier.new,
);

class ReconciliationNotifier
    extends Notifier<AsyncValue<List<MasterCardAccount>>> {
  late final ProcessMasterCardTsvUseCase _processTsvUseCase;
  late final ProcessInitialTopupUseCase _processTopUpUseCase;
  late final ReconciliationRepositoryImpl _repository;

  @override
  AsyncValue<List<MasterCardAccount>> build() {
    _processTsvUseCase = ref.watch(processMasterCardTsvUseCaseProvider);
    _processTopUpUseCase = ref.watch(processInitialTopUpUseCaseProvider);
    _repository = ref.watch(reconciliationRepositoryProvider);

    loadAccounts();
    return const AsyncValue.loading();
  }

  Future<void> loadAccounts() async {
    try {
      final accounts = await _repository.fetchAllAccounts();
      state = AsyncData(accounts);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Upload and process a TopUp Excel/CSV file.
  ///
  /// Parses raw rows via [ExcelTopUpParser], then delegates to the TopUp use case.
  Future<void> uploadTopUpRows(List<List<dynamic>> rows,
      {required String fileId}) async {
    state = const AsyncLoading();
    try {
      final parsedData = ExcelTopUpParser.parseRows(rows);
      await _processTopUpUseCase.execute(parsedData, fileId: fileId);
      await loadAccounts();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Upload and process a Mastercard TSV settlement file.
  ///
  /// Parses content via [TsvFileParser], then delegates to the TSV use case.
  /// Returns [TsvProcessingResult] so the UI can handle warnings/confirmations.
  Future<TsvProcessingResult> uploadMastercardTsv(String fileContent,
      {required String fileId}) async {
    state = const AsyncLoading();
    try {
      final parsedRows = TsvFileParser.parseTsvContent(fileContent);
      final result =
          await _processTsvUseCase.execute(parsedRows, fileId: fileId);
      await loadAccounts();
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Confirm and save accounts/transactions that had negative balance warnings.
  ///
  /// Called after user clicks "Confirm Negative Balance" in the warning dialog.
  Future<void> confirmAndSavePendingTsv({
    required List<dynamic> accounts,
    required List<dynamic> transactions,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.saveBatchAccounts(accounts.cast());
      await _repository.saveBatchTransactions(transactions.cast());
      await loadAccounts();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Save all current accounts to Back4App.
  Future<void> saveAllAccounts() async {
    final currentList = state.value ?? [];
    if (currentList.isEmpty) return;
    try {
      await _repository.saveBatchAccounts(currentList);
      await loadAccounts();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// In-place update of a topup value from the grid (for inline editing).
  void updateTopUpInState(String clientId, double newTopup) {
    state.whenData((accounts) {
      final updatedList = accounts.map((acc) {
        if (acc.clientId == clientId) {
          final diff = newTopup - acc.topupamount;
          return acc.copyWith(
            topupamount: newTopup,
            currentBalance: acc.currentBalance + diff,
            updatedAt: DateTime.now(),
          );
        }
        return acc;
      }).toList();
      state = AsyncData(updatedList);
    });
  }
}