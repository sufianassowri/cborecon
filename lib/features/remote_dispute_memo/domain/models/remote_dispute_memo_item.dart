import 'dart:math';

class RemoteDisputeMemoItem {
  // Optional ATM ENQ @ID Field
  final String? id;

  // Required Dispute Report Fields
  final String transRef; // Id
  final String branch;
  final String customerAccount; // Account
  final double amount; // Amount
  final String customerName; // Customer
  final String pan;
  final String transactionDate;

  // Matching ATM ENQ / Optional Fields
  final String retrievalRefNo; // RETRIEVAL.REF.NO
  final String drAccount; // CREDIT.ACCT.NO / DEBIT.ACCT.NO from ATM ENQ
  final String acquirerBank;
  final String fuDisputeId;
  final String edrrfAccount;

  // Optional Meta Fields
  final String valueDate;
  final String bookingDate;
  final String procCode;
  final String mtiCode;
  final String binReference;
  final String drCustomerId;
  final String merchantId;
  final String timestamp;
  final String cardAccId;
  final String investigationStatus;
  final String requestedDate;
  final String assignedDate;

  RemoteDisputeMemoItem({
    this.id,
    required this.transRef,
    required this.branch,
    required this.customerAccount,
    required this.amount,
    required this.customerName,
    required this.pan,
    required this.transactionDate,
    required this.retrievalRefNo,
    required this.drAccount,
    this.acquirerBank = 'CBE ETS SETTL',
    this.fuDisputeId = '',
    this.edrrfAccount = 'ETB1759500010001',
    this.valueDate = '',
    this.bookingDate = '',
    this.procCode = '',
    this.mtiCode = '',
    this.binReference = '',
    this.drCustomerId = '',
    this.merchantId = '',
    this.timestamp = '',
    this.cardAccId = '',
    this.investigationStatus = '',
    this.requestedDate = '',
    this.assignedDate = '',
  });

  // Business Logic Calculations

  /// Calculates PL Commission (COM) for Remote On-Us:
  /// - on/after May 22, 2026: 0.6% (0.006)
  /// - before May 22, 2026: 0.5% (0.005)
  double get pl62174 {
    double rate = 0.005;

    final parsedDate = _parseTransactionDate(transactionDate);
    final cutoffDate = DateTime(2026, 5, 22);

    if (parsedDate != null && !parsedDate.isBefore(cutoffDate)) {
      rate = 0.006;
    }

    return _roundUp(amount * rate, 2);
  }

  /// Calculates Disaster / EDRRF (DIS): =ROUNDUP(0.05 * COM, 2)
  double get edrrfAmount => _roundUp(pl62174 * 0.05, 2);

  /// Calculates VAT: =ROUNDUP(0.15 * COM, 2)
  double get vatAmount => _roundUp(pl62174 * 0.15, 2);

  /// Calculates Total:
  double get total => _roundUp(amount + edrrfAmount + vatAmount + pl62174, 2);

  /// Implements Excel formula: =REPLACE(B2, 1, 4, "ETB17212000")
  String get vatAccount {
    final trimmedBranch = branch.trim();
    if (trimmedBranch.length >= 4) {
      return 'ETB17212000${trimmedBranch.substring(4)}';
    } else {
      return 'ETB17212000$trimmedBranch';
    }
  }

  // Compatibility Getters
  String get rrn => retrievalRefNo;
  String get debitAtmAcc => drAccount;
  String get debitVatAcc => vatAccount;
  String get debitEdfAcc => edrrfAccount;

  /// Performs robust ROUNDUP matching Excel's =ROUNDUP(val, decimals)
  static double _roundUp(double value, int decimals) {
    num mod = pow(10, decimals);
    double fixedVal = double.parse((value * mod).toStringAsFixed(8));
    return fixedVal.ceil() / mod;
  }

  /// Parses standard ISO dates (`YYYY-MM-DD`) and common raw logs (`DD/MM/YYYY` or `DD-MM-YYYY`)
  static DateTime? _parseTransactionDate(String dateStr) {
    final directParsed = DateTime.tryParse(dateStr);
    if (directParsed != null) return directParsed;

    final parts = dateStr.split(RegExp(r'[/.-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }
}

class RemoteDisputeMemoSummary {
  final List<RemoteDisputeMemoItem> items;
  final double totalAmount;
  final double totalEdrrfAmount;
  final double totalVatAmount;
  final double totalPl62174;
  final double totalOverall;

  double get totalEdrfAmount => totalEdrrfAmount;
  double get grandTotal => totalOverall;

  RemoteDisputeMemoSummary({
    required this.items,
    required this.totalAmount,
    required this.totalEdrrfAmount,
    required this.totalVatAmount,
    required this.totalPl62174,
    required this.totalOverall,
  });

  factory RemoteDisputeMemoSummary.fromItems(List<RemoteDisputeMemoItem> items) {
    double amt = 0, edrrf = 0, vat = 0, pl = 0, tot = 0;
    for (var item in items) {
      amt += item.amount;
      edrrf += item.edrrfAmount;
      vat += item.vatAmount;
      pl += item.pl62174;
      tot += item.total;
    }
    return RemoteDisputeMemoSummary(
      items: items,
      totalAmount: amt,
      totalEdrrfAmount: edrrf,
      totalVatAmount: vat,
      totalPl62174: pl,
      totalOverall: tot,
    );
  }
}
