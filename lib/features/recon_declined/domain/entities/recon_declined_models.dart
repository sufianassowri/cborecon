enum DeclinedAtmHardwareType { ncr, crm, unknown }

class ExcessAccountDetail {
  final String accountNo;
  final double accountBalance;
  final String customer;
  final String name;
  final String product;
  final String ccy;
  final String accountOfficer;
  final Map<String, dynamic> rawRow;

  const ExcessAccountDetail({
    required this.accountNo,
    required this.accountBalance,
    this.customer = '',
    this.name = '',
    this.product = '',
    this.ccy = '',
    this.accountOfficer = '',
    this.rawRow = const {},
  });
}

class DeclinedRawRecord {
  final String cardAccId; // Terminal ID
  final double amount;
  final String transRef;
  final String valueDate;
  final String debitAcctNo;
  final String creditAcctNo;
  final String retrievalRefNo;
  final Map<String, dynamic> rawRow;

  const DeclinedRawRecord({
    required this.cardAccId,
    required this.amount,
    this.transRef = '',
    this.valueDate = '',
    this.debitAcctNo = '',
    this.creditAcctNo = '',
    this.retrievalRefNo = '',
    this.rawRow = const {},
  });
}

class MatchedDeclinedSettlement {
  final String cardAccId; // CARD.ACC.ID
  final String excessAccount; // Derived Excess Account
  final double excessDebitAmount; // Debit amount from excess
  final String atmAccount; // Derived ATM Account
  final double atmDebitAmount; // Debit amount from ATM
  final double excessBalance; // Original Excess Account Balance
  final double totalDeclinedAmount; // Total declined transaction amount
  final double difference; // excessBalance - totalDeclinedAmount
  final String differenceFormula; // Formatted formula string
  final DeclinedAtmHardwareType hardwareType;
  final String status; // MATCHED
  final String customer;
  final String name;
  final String product;
  final String ccy;
  final String accountOfficer;
  final int transactionCount;
  final Map<String, dynamic> rawExcessRow;
  final List<Map<String, dynamic>> rawDeclinedRows;

  const MatchedDeclinedSettlement({
    required this.cardAccId,
    required this.excessAccount,
    required this.excessDebitAmount,
    required this.atmAccount,
    required this.atmDebitAmount,
    required this.excessBalance,
    required this.totalDeclinedAmount,
    required this.difference,
    required this.differenceFormula,
    required this.hardwareType,
    this.status = 'MATCHED',
    this.customer = '',
    this.name = '',
    this.product = '',
    this.ccy = '',
    this.accountOfficer = '',
    this.transactionCount = 1,
    this.rawExcessRow = const {},
    this.rawDeclinedRows = const [],
  });

  String get hardwareTypeName {
    switch (hardwareType) {
      case DeclinedAtmHardwareType.ncr:
        return 'NCR';
      case DeclinedAtmHardwareType.crm:
        return 'CRM';
      case DeclinedAtmHardwareType.unknown:
        return 'UNKNOWN';
    }
  }
}

class UnmatchedExcessRecord {
  final String accountNo;
  final double accountBalance;
  final String customer;
  final String name;
  final String product;
  final String ccy;
  final String accountOfficer;
  final String status;
  final Map<String, dynamic> rawRow;

  const UnmatchedExcessRecord({
    required this.accountNo,
    required this.accountBalance,
    this.customer = '',
    this.name = '',
    this.product = '',
    this.ccy = '',
    this.accountOfficer = '',
    this.status = 'EXCESS_ONLY',
    this.rawRow = const {},
  });
}

class UnmatchedDeclinedRecord {
  final String cardAccId;
  final double totalDeclinedAmount;
  final String derivedExcessAccount;
  final String derivedAtmAccount;
  final DeclinedAtmHardwareType hardwareType;
  final int transactionCount;
  final String status;
  final List<Map<String, dynamic>> rawRows;

  const UnmatchedDeclinedRecord({
    required this.cardAccId,
    required this.totalDeclinedAmount,
    required this.derivedExcessAccount,
    required this.derivedAtmAccount,
    required this.hardwareType,
    this.transactionCount = 1,
    this.status = 'DECLINED_ONLY',
    this.rawRows = const [],
  });

  String get hardwareTypeName {
    switch (hardwareType) {
      case DeclinedAtmHardwareType.ncr:
        return 'NCR';
      case DeclinedAtmHardwareType.crm:
        return 'CRM';
      case DeclinedAtmHardwareType.unknown:
        return 'UNKNOWN';
    }
  }
}

class ReconDeclinedResult {
  final List<MatchedDeclinedSettlement> matched;
  final List<UnmatchedExcessRecord> excessOnly;
  final List<UnmatchedDeclinedRecord> declinedOnly;
  final List<String> excessHeaders;
  final List<String> declinedHeaders;

  const ReconDeclinedResult({
    required this.matched,
    required this.excessOnly,
    required this.declinedOnly,
    this.excessHeaders = const [],
    this.declinedHeaders = const [],
  });

  int get totalMatchedCount => matched.length;
  int get totalExcessOnlyCount => excessOnly.length;
  int get totalDeclinedOnlyCount => declinedOnly.length;

  double get totalMatchedDeclinedAmount =>
      matched.fold(0.0, (sum, item) => sum + item.totalDeclinedAmount);

  double get totalMatchedExcessDebitAmount =>
      matched.fold(0.0, (sum, item) => sum + item.excessDebitAmount);

  double get totalMatchedAtmDebitAmount =>
      matched.fold(0.0, (sum, item) => sum + item.atmDebitAmount);

  double get totalExcessOnlyBalance =>
      excessOnly.fold(0.0, (sum, item) => sum + item.accountBalance);

  double get totalDeclinedOnlyAmount =>
      declinedOnly.fold(0.0, (sum, item) => sum + item.totalDeclinedAmount);
}
