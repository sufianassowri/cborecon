class McTransaction {
  final String trxnType;
  final String trxnDate;
  final String clientId;
  final String pan;
  final double baseAmount;
  final String debitOrCredit;
  final double extraAmount; // Changed to double
  final double annualFeeAmount;
  final String description;

  const McTransaction({
    required this.trxnType,
    required this.trxnDate,
    required this.clientId,
    required this.pan,
    required this.baseAmount,
    required this.debitOrCredit,
    required this.extraAmount,
    required this.annualFeeAmount,
    required this.description,
  });
}