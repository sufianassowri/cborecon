import 'mc_transaction.dart';
import 'topup_record.dart';

enum ReconStatus { matched, amountMismatch, missingInTsv, missingInTopUp }

class ReconciledSummary {
  final String clientId;
  final String pan;
  final double initialBalance;
  final double totalBaseAmount;
  final double annualFee;
  final double expectedRemaining;
  final double actualRemaining;
  final double variance;
  final ReconStatus status;
  final TopUpRecord? topUpRecord;
  final List<McTransaction> matchedTransactions;

  const ReconciledSummary({
    required this.clientId,
    required this.pan,
    required this.initialBalance,
    required this.totalBaseAmount,
    required this.annualFee,
    required this.expectedRemaining,
    required this.actualRemaining,
    required this.variance,
    required this.status,
    this.topUpRecord,
    required this.matchedTransactions,
  });
}