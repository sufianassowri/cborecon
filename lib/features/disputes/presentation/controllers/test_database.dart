class Transaction {
  final String terminalCode;
  final String? ejUrl;
  final String? confUrl;
  final String? receiptUrl;

  Transaction({
    required this.terminalCode,
    this.ejUrl,
    this.confUrl,
    this.receiptUrl,
  });
}