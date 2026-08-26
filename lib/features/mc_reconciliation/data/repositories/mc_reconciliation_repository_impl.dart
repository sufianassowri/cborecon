import '../../domain/entities/mc_transaction.dart';
import '../../domain/entities/reconciled_summary.dart';
import '../../domain/entities/topup_record.dart';
import '../../domain/repositories/mc_reconciliation_repository.dart';
import '../datasources/mc_reconciliation_local_datasource.dart';

class McReconciliationRepositoryImpl implements McReconciliationRepository {
  final McReconciliationLocalDataSource localDataSource;

  McReconciliationRepositoryImpl(this.localDataSource);

  @override
  Future<List<McTransaction>> parseMasterCardTsv(String filePath) async {
    return await localDataSource.readTsvFile(filePath);
  }
  @override
  Future<List<TopUpRecord>> parseTopUpExcel(String filePath) async {
    return await localDataSource.readTopUpExcelFile(filePath);
  }
  @override
  @override
  List<ReconciledSummary> reconcile(
      List<TopUpRecord> topUpList,
      List<McTransaction> tsvList,
      ) {
    final List<ReconciledSummary> summaries = [];

    // Index TSV transactions by PAN and Client ID
    final Map<String, List<McTransaction>> tsvByPan = {};
    for (var tx in tsvList) {
      final cleanPan = tx.pan.trim();
      if (cleanPan.isNotEmpty) {
        tsvByPan.putIfAbsent(cleanPan, () => []).add(tx);
      }
    }

    for (var topUp in topUpList) {
      final cleanPan = topUp.pan.trim();
      final matchedTxns = tsvByPan[cleanPan] ?? [];

      double totalBaseAndExtra = 0.0;

      for (var tx in matchedTxns) {
        final combinedAmount = tx.baseAmount + tx.extraAmount;

        if (tx.debitOrCredit.toUpperCase() == 'C') {
          // Credit (C): Add to balance
          totalBaseAndExtra -= combinedAmount;
        } else {
          // Debit (D): Subtract from balance
          totalBaseAndExtra += combinedAmount;
        }
      }

      final annualFee = topUp.annualFee ?? 0.0;
      // Remaining Balance = Initial Balance - (BaseAmount + ExtraAmount) - AnnualFee
      final expectedRemaining = topUp.initialBalance - totalBaseAndExtra - annualFee;
      final actualRemaining = topUp.remainingAmount;
      final variance = actualRemaining - expectedRemaining;
      final status = (variance.abs() < 0.01)
          ? ReconStatus.matched
          : ReconStatus.amountMismatch;

      summaries.add(
        ReconciledSummary(
          clientId: topUp.clientId,
          pan: topUp.pan,
          initialBalance: topUp.initialBalance,
          totalBaseAmount: totalBaseAndExtra,
          annualFee: annualFee,
          expectedRemaining: expectedRemaining,
          actualRemaining: actualRemaining,
          variance: variance,
          status: status,
          topUpRecord: topUp,
          matchedTransactions: matchedTxns,
        ),
      );
    }

    return summaries;
  }
  @override
  Future<void> exportToExcel(
      List<ReconciledSummary> summaryList,
      String outputPath,
      ) async {
    await localDataSource.exportSummaryExcel(summaryList, outputPath);
  }
}