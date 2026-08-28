import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/model/dispute_batch_model.dart';
import '../../data/model/transaction_model.dart';
import '../../data/repository_impl/dispute_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Repository Provider
final disputeRepositoryProvider = Provider<DisputeRepositoryImpl>((ref) {
  return DisputeRepositoryImpl();
});

// Selected Batch Provider (for Checker / Auditor drill-down)
final selectedDisputeBatchProvider = StateProvider<DisputeBatch?>((ref) => null);

// Batch Filter (Status: ALL, NEW, ASSIGNED, AUTHORIZED, REJECTED)
final disputeBatchFilterProvider = StateProvider<String>((ref) => 'ALL');

// Selected Checker Filter
final selectedCheckerFilterProvider = StateProvider<String?>((ref) => null);

// Search Query Filter
final disputeSearchQueryProvider = StateProvider<String>((ref) => '');

// Checkers List Provider
final checkersListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(disputeRepositoryProvider);
  return repo.fetchCheckersList();
});

// Batches List StateNotifier/AsyncNotifier
class DisputeBatchesNotifier extends AsyncNotifier<List<DisputeBatch>> {
  @override
  Future<List<DisputeBatch>> build() async {
    final repo = ref.watch(disputeRepositoryProvider);
    return repo.fetchBatches();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(disputeRepositoryProvider);
      return repo.fetchBatches();
    });
  }

  Future<DisputeBatch> uploadBatch({
    required DisputeBatch batch,
    required List<DisputeTrxn> items,
    Function(int current, int total)? onProgress,
  }) async {
    final repo = ref.read(disputeRepositoryProvider);
    final saved = await repo.uploadDisputeBatch(
      batch: batch,
      items: items,
      onProgress: onProgress,
    );
    await refresh();
    return saved;
  }

  Future<void> assignBatch({
    required String batchObjectId,
    required String checkerUsername,
  }) async {
    final repo = ref.read(disputeRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);
    final managerName = currentUser?.username ?? 'Operations_Manager';

    await repo.assignBatch(
      batchObjectId: batchObjectId,
      checkerUsername: checkerUsername,
      managerUsername: managerName,
    );
    await refresh();
  }

  Future<void> authorizeBatch({
    required String batchObjectId,
  }) async {
    final repo = ref.read(disputeRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);
    final checkerName = currentUser?.username ?? 'Checker_Officer';

    await repo.authorizeBatch(
      batchObjectId: batchObjectId,
      checkerUsername: checkerName,
    );
    await refresh();
  }

  Future<void> rejectBatch({
    required String batchObjectId,
    required String comment,
  }) async {
    final repo = ref.read(disputeRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);
    final checkerName = currentUser?.username ?? 'Checker_Officer';

    await repo.rejectBatch(
      batchObjectId: batchObjectId,
      checkerUsername: checkerName,
      comment: comment,
    );
    await refresh();
  }
}

final disputeBatchesNotifierProvider =
    AsyncNotifierProvider<DisputeBatchesNotifier, List<DisputeBatch>>(() {
  return DisputeBatchesNotifier();
});

// Backward compatibility alias for views expecting disputeListProvider
final disputeListProvider = FutureProvider<List<DisputeTrxn>>((ref) async {
  final selected = ref.watch(selectedDisputeBatchProvider);
  if (selected == null) return [];
  final repo = ref.watch(disputeRepositoryProvider);
  return repo.fetchBatchTransactions(
    batchIdOrNumber: selected.objectId ?? selected.batchNumber,
  );
});

// Batch Transactions Provider (Child Line Items)
final batchTransactionsProvider =
    FutureProvider.family<List<DisputeTrxn>, String>((ref, batchIdOrNumber) async {
  final repo = ref.watch(disputeRepositoryProvider);
  return repo.fetchBatchTransactions(batchIdOrNumber: batchIdOrNumber);
});

// Audit SLA Analytics Model
class DisputeAuditAnalytics {
  final int totalBatches;
  final int pendingBatches;
  final int assignedBatches;
  final int authorizedBatches;
  final int rejectedBatches;
  final double totalVolumeDebit;
  final double totalVolumeCredit;
  final Duration averageMadeToAssigned;
  final Duration averageAssignedToAuthorized;
  final Duration averageTotalTurnaround;

  DisputeAuditAnalytics({
    required this.totalBatches,
    required this.pendingBatches,
    required this.assignedBatches,
    required this.authorizedBatches,
    required this.rejectedBatches,
    required this.totalVolumeDebit,
    required this.totalVolumeCredit,
    required this.averageMadeToAssigned,
    required this.averageAssignedToAuthorized,
    required this.averageTotalTurnaround,
  });
}

// Analytics Provider
final disputeAnalyticsProvider = Provider<DisputeAuditAnalytics>((ref) {
  final batchesAsync = ref.watch(disputeBatchesNotifierProvider);
  final batches = batchesAsync.value ?? [];

  int pending = 0;
  int assigned = 0;
  int authorized = 0;
  int rejected = 0;
  double volDebit = 0.0;
  double volCredit = 0.0;

  List<int> madeToAssignedSeconds = [];
  List<int> assignedToAuthSeconds = [];
  List<int> totalTurnaroundSeconds = [];

  for (var b in batches) {
    volDebit += b.totalDebitAmount;
    volCredit += b.totalCreditAmount;

    if (b.status == 'NEW' || b.status == 'PENDING_ASSIGNMENT') {
      pending++;
    } else if (b.status == 'ASSIGNED') {
      assigned++;
    } else if (b.status == 'AUTHORIZED') {
      authorized++;
    } else if (b.status == 'REJECTED') {
      rejected++;
    }

    if (b.durationMadeToAssigned != null) {
      madeToAssignedSeconds.add(b.durationMadeToAssigned!.inSeconds);
    }
    if (b.durationAssignedToAuthorized != null) {
      assignedToAuthSeconds.add(b.durationAssignedToAuthorized!.inSeconds);
    }
    if (b.totalTurnaroundDuration != null) {
      totalTurnaroundSeconds.add(b.totalTurnaroundDuration!.inSeconds);
    }
  }

  Duration computeAvg(List<int> list) {
    if (list.isEmpty) return Duration.zero;
    final total = list.reduce((a, b) => a + b);
    return Duration(seconds: (total / list.length).round());
  }

  return DisputeAuditAnalytics(
    totalBatches: batches.length,
    pendingBatches: pending,
    assignedBatches: assigned,
    authorizedBatches: authorized,
    rejectedBatches: rejected,
    totalVolumeDebit: volDebit,
    totalVolumeCredit: volCredit,
    averageMadeToAssigned: computeAvg(madeToAssignedSeconds),
    averageAssignedToAuthorized: computeAvg(assignedToAuthSeconds),
    averageTotalTurnaround: computeAvg(totalTurnaroundSeconds),
  );
});