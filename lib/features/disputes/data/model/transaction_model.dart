class DisputeTrxn {
  final String? objectId;
  final String debitAcc;
  final String creditAcc;
  final double amount;
  final String terminalCode;
  final String transactionTime;

  DisputeTrxn({
    this.objectId,
    required this.debitAcc,
    required this.creditAcc,
    required this.amount,
    required this.terminalCode,
    required this.transactionTime,
  });

  factory DisputeTrxn.fromJson(Map<String, dynamic> json) {
    return DisputeTrxn(
      objectId: json['objectId'],
      debitAcc: json['debitAcc'] ?? '',
      creditAcc: json['creditAcc'] ?? '',
      // Parsing amount as double safely
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      // Note: Ensure these keys match your Back4App column names exactly
      terminalCode: json['terminalCode'] ?? json['terminalcode'] ?? '',
      transactionTime: json['transactionTime'] ?? json['transactiontime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // We often omit objectId when creating a new record,
      // but include it if you're sending an update.
      if (objectId != null) 'objectId': objectId,
      'debitAcc': debitAcc,
      'creditAcc': creditAcc,
      'amount': amount,
      'terminalCode': terminalCode,
      'transactionTime': transactionTime,
    };
  }
}