import '../entities/mc_transaction.dart';
import '../entities/reconciled_summary.dart';
import '../entities/topup_record.dart';

abstract class McReconciliationRepository {
  Future<List<McTransaction>> parseMasterCardTsv(String filePath);
  Future<List<TopUpRecord>> parseTopUpExcel(String filePath);
  List<ReconciledSummary> reconcile(
      List<TopUpRecord> topUpList,
      List<McTransaction> tsvList,
      );
  Future<void> exportToExcel(List<ReconciledSummary> summaryList, String outputPath);
}