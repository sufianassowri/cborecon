import '../entities/mc_transaction.dart';
import '../entities/reconciled_summary.dart';
import '../entities/topup_record.dart';
import '../repositories/mc_reconciliation_repository.dart';

class ReconcileTransactions {
  final McReconciliationRepository repository;

  ReconcileTransactions(this.repository);

  List<ReconciledSummary> call(
      List<TopUpRecord> topUpList,
      List<McTransaction> tsvList,
      ) {
    return repository.reconcile(topUpList, tsvList);
  }
}