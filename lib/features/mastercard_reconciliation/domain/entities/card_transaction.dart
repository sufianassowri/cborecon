enum TransactionType { topup, spend }
enum DebitCredit { debit, credit }

class CardTransaction {
  final String? id;
  final String referenceId; // Composite PK: RecordType_ColJ
  final String clientId;
  final String pan;
  final TransactionType txnType;
  final DebitCredit debitCredit;
  final double baseAmount;
  final double extraAmount;
  final double annualFeeAmount;
  final double totalTransactionAmount;
  final String rawRecordType;
  final String? description;
  final DateTime transactionDate;
  final String? fileId;

  CardTransaction({
    this.id,
    required this.referenceId,
    required this.clientId,
    required this.pan,
    required this.txnType,
    required this.debitCredit,
    required this.baseAmount,
    required this.extraAmount,
    required this.annualFeeAmount,
    required this.totalTransactionAmount,
    required this.rawRecordType,
    this.description,
    required this.transactionDate,
    this.fileId,
  });
}
