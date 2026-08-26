class TopUpRecord {
  final String transactionDate;
  final String clientId;
  final String pan;
  final double initialBalance;
  final double? annualFee;
  final double remainingAmount;

  const TopUpRecord({
    required this.transactionDate,
    required this.clientId,
    required this.pan,
    required this.initialBalance,
    this.annualFee,
    required this.remainingAmount,
  });
}