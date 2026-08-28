class DisputeTrxn {
  final String? objectId;
  final String? batchId;
  final String? batchNumber;
  final String transactionId; // e.g. DC262394004038001
  final String debitAcc;
  final String creditAcc;
  final String type; // 'D' (Debit) or 'C' (Credit)
  final double amount;
  final String terminalCode;
  final String transactionTime;
  final String txnCode; // e.g. '1', '51'
  final String narrative1; // e.g. 'Deposit Dispute', 'Terminations of Obbo Abayeneh'
  final String narrative2; // e.g. 'Deposit Dispute', 'Paid for annual leave'
  final String valueDate; // e.g. '20260827' or '27 AUG 2026'
  final String recordStatus; // 'INAU', 'AUTH', 'REJ'
  final String currency; // 'ETB'
  final String positionType; // 'TR'
  final String customer;
  final String name;
  final String category;
  final String accountOfficer;
  final String ourReference;

  DisputeTrxn({
    this.objectId,
    this.batchId,
    this.batchNumber,
    required this.transactionId,
    required this.debitAcc,
    required this.creditAcc,
    required this.type,
    required this.amount,
    this.terminalCode = '',
    this.transactionTime = '',
    this.txnCode = '1',
    this.narrative1 = '',
    this.narrative2 = '',
    this.valueDate = '',
    this.recordStatus = 'INAU',
    this.currency = 'ETB',
    this.positionType = 'TR',
    this.customer = '',
    this.name = '',
    this.category = '',
    this.accountOfficer = '',
    this.ourReference = '',
  });

  // Account helper to get whichever account is active based on type (D or C)
  String get effectiveAccount => type == 'D' ? debitAcc : creditAcc;

  factory DisputeTrxn.fromJson(Map<String, dynamic> json) {
    String type = json['type'] ?? (json['debitAcc'] != null && (json['creditAcc'] == null || json['creditAcc'].toString().isEmpty) ? 'D' : 'C');
    if (json['debitAcc'] != null && json['debitAcc'].toString().isNotEmpty && (json['creditAcc'] == null || json['creditAcc'].toString().isEmpty)) {
      type = 'D';
    } else if (json['creditAcc'] != null && json['creditAcc'].toString().isNotEmpty && (json['debitAcc'] == null || json['debitAcc'].toString().isEmpty)) {
      type = 'C';
    }

    return DisputeTrxn(
      objectId: json['objectId'],
      batchId: json['batchId'],
      batchNumber: json['batchNumber'],
      transactionId: json['transactionId'] ?? json['trxnId'] ?? '',
      debitAcc: json['debitAcc'] ?? '',
      creditAcc: json['creditAcc'] ?? '',
      type: json['type'] ?? type,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      terminalCode: json['terminalCode'] ?? json['terminalcode'] ?? '',
      transactionTime: json['transactionTime'] ?? json['transactiontime'] ?? '',
      txnCode: json['txnCode'] ?? json['transactionCde'] ?? (type == 'D' ? '1' : '51'),
      narrative1: json['narrative1'] ?? json['narrative_1'] ?? '',
      narrative2: json['narrative2'] ?? json['narrative_2'] ?? '',
      valueDate: json['valueDate'] ?? '',
      recordStatus: json['recordStatus'] ?? 'INAU',
      currency: json['currency'] ?? 'ETB',
      positionType: json['positionType'] ?? 'TR',
      customer: json['customer'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      accountOfficer: json['accountOfficer'] ?? '',
      ourReference: json['ourReference'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (objectId != null) 'objectId': objectId,
      if (batchId != null) 'batchId': batchId,
      if (batchNumber != null) 'batchNumber': batchNumber,
      'transactionId': transactionId,
      'debitAcc': debitAcc,
      'creditAcc': creditAcc,
      'type': type,
      'amount': amount,
      'terminalCode': terminalCode,
      'transactionTime': transactionTime,
      'txnCode': txnCode,
      'narrative1': narrative1,
      'narrative2': narrative2,
      'valueDate': valueDate,
      'recordStatus': recordStatus,
      'currency': currency,
      'positionType': positionType,
      'customer': customer,
      'name': name,
      'category': category,
      'accountOfficer': accountOfficer,
      'ourReference': ourReference,
    };
  }

  DisputeTrxn copyWith({
    String? objectId,
    String? batchId,
    String? batchNumber,
    String? transactionId,
    String? debitAcc,
    String? creditAcc,
    String? type,
    double? amount,
    String? terminalCode,
    String? transactionTime,
    String? txnCode,
    String? narrative1,
    String? narrative2,
    String? valueDate,
    String? recordStatus,
    String? currency,
    String? positionType,
    String? customer,
    String? name,
    String? category,
    String? accountOfficer,
    String? ourReference,
  }) {
    return DisputeTrxn(
      objectId: objectId ?? this.objectId,
      batchId: batchId ?? this.batchId,
      batchNumber: batchNumber ?? this.batchNumber,
      transactionId: transactionId ?? this.transactionId,
      debitAcc: debitAcc ?? this.debitAcc,
      creditAcc: creditAcc ?? this.creditAcc,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      terminalCode: terminalCode ?? this.terminalCode,
      transactionTime: transactionTime ?? this.transactionTime,
      txnCode: txnCode ?? this.txnCode,
      narrative1: narrative1 ?? this.narrative1,
      narrative2: narrative2 ?? this.narrative2,
      valueDate: valueDate ?? this.valueDate,
      recordStatus: recordStatus ?? this.recordStatus,
      currency: currency ?? this.currency,
      positionType: positionType ?? this.positionType,
      customer: customer ?? this.customer,
      name: name ?? this.name,
      category: category ?? this.category,
      accountOfficer: accountOfficer ?? this.accountOfficer,
      ourReference: ourReference ?? this.ourReference,
    );
  }
}