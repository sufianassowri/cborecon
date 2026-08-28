import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

/// 15 Standard Switch Settlement Headers
class SettlementHeaders {
  static const List<String> standard = [
    'Issuer',
    'Acquirer',
    'MTI',
    'Card_Number',
    'Amount',
    'Currency',
    'Transaction_Date',
    'Transaction_Description',
    'Terminal_ID',
    'Transaction_Place',
    'STAN_F11',
    'Refnum_F37',
    'Authidresp_F38',
    'Fe_utrnno',
    'Bo_utrnno',
  ];

  static bool isHeaderRow(List<dynamic> row) {
    if (row.isEmpty) return false;
    final text = row.map((e) => e?.toString().toLowerCase().trim() ?? '').join(' ');
    return (text.contains('issuer') && text.contains('acquirer')) ||
        (text.contains('card_number') || text.contains('card number') || text.contains('pan')) ||
        (text.contains('refnum') || text.contains('rrn') || text.contains('stan'));
  }
}

/// Represents a single clean 1-to-1 settlement transaction row
class SettlementRowEntity {
  final String issuer;
  final String acquirer;
  final String mti;
  final String cardNumber;
  final double amount;
  final String amountRaw;
  final String currency;
  final String transactionDate;
  final DateTime? parsedDate;
  final String transactionDescription;
  final String terminalId;
  final String transactionPlace;
  final String stanF11;
  final String refnumF37;
  final String authidrespF38;
  final String feUtrnno;
  final String boUtrnno;

  SettlementRowEntity({
    required this.issuer,
    required this.acquirer,
    required this.mti,
    required this.cardNumber,
    required this.amount,
    required this.amountRaw,
    required this.currency,
    required this.transactionDate,
    this.parsedDate,
    required this.transactionDescription,
    required this.terminalId,
    required this.transactionPlace,
    required this.stanF11,
    required this.refnumF37,
    required this.authidrespF38,
    required this.feUtrnno,
    required this.boUtrnno,
  });

  /// Robust date parser supporting various bank settlement formats:
  /// e.g. '2026-08-28', '28/08/2026', '28-AUG-2026', '20260828', '28-08-2026 14:30:00'
  static DateTime? parseFlexibleDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();

    // 1. Direct ISO
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;

    // 2. YYYYMMDD
    if (RegExp(r'^\d{8}$').hasMatch(clean)) {
      final y = int.tryParse(clean.substring(0, 4)) ?? 2026;
      final m = int.tryParse(clean.substring(4, 6)) ?? 1;
      final d = int.tryParse(clean.substring(6, 8)) ?? 1;
      return DateTime(y, m, d);
    }

    // 3. Common Bank Formats
    final formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'dd/MM/yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm:ss',
      'yyyy-MM-dd HH:mm:ss',
      'dd-MMM-yyyy',
      'dd-MMM-yyyy HH:mm:ss',
      'd/M/yyyy',
      'd-M-yyyy',
      'MM/dd/yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(clean);
      } catch (_) {}
    }

    // 4. Fallback extract first day numbers (e.g. "28" or "30")
    final match = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})').firstMatch(clean);
    if (match != null) {
      final d = int.tryParse(match.group(1)!) ?? 1;
      final m = int.tryParse(match.group(2)!) ?? 1;
      var y = int.tryParse(match.group(3)!) ?? 2026;
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    }

    return null;
  }

  /// Create entity from raw row and header index mapping
  factory SettlementRowEntity.fromRawRow(
    List<dynamic> row,
    Map<String, int> headerMap,
  ) {
    String getVal(String key) {
      final index = headerMap[key.toLowerCase()];
      if (index != null && index >= 0 && index < row.length) {
        final val = row[index];
        if (val == null) return '';
        var str = val.toString().trim();
        // Remove trailing .0 if a numeric ID was read as double e.g. 12345.0
        if (str.endsWith('.0') && !str.contains('e') && !str.contains('E') && str.length > 2) {
          final beforeDot = str.substring(0, str.length - 2);
          if (int.tryParse(beforeDot) != null) {
            str = beforeDot;
          }
        }
        return str;
      }
      return '';
    }

    final amountStr = getVal('amount').replaceAll(',', '');
    final amountVal = double.tryParse(amountStr) ?? 0.0;
    final dateStr = getVal('transaction_date').isEmpty ? getVal('date') : getVal('transaction_date');

    return SettlementRowEntity(
      issuer: getVal('issuer'),
      acquirer: getVal('acquirer'),
      mti: getVal('mti'),
      cardNumber: getVal('card_number').isEmpty ? getVal('pan') : getVal('card_number'),
      amount: amountVal,
      amountRaw: getVal('amount'),
      currency: getVal('currency').isEmpty ? 'ETB' : getVal('currency'),
      transactionDate: dateStr,
      parsedDate: parseFlexibleDate(dateStr),
      transactionDescription: getVal('transaction_description').isEmpty
          ? (getVal('description').isEmpty ? 'UNKNOWN' : getVal('description'))
          : getVal('transaction_description'),
      terminalId: getVal('terminal_id').isEmpty ? getVal('terminal') : getVal('terminal_id'),
      transactionPlace: getVal('transaction_place').isEmpty ? getVal('place') : getVal('transaction_place'),
      stanF11: getVal('stan_f11').isEmpty ? getVal('stan') : getVal('stan_f11'),
      refnumF37: getVal('refnum_f37').isEmpty ? (getVal('rrn').isEmpty ? getVal('refnum') : getVal('rrn')) : getVal('refnum_f37'),
      authidrespF38: getVal('authidresp_f38').isEmpty ? getVal('authid') : getVal('authidresp_f38'),
      feUtrnno: getVal('fe_utrnno').isEmpty ? getVal('fe_utrn') : getVal('fe_utrnno'),
      boUtrnno: getVal('bo_utrnno').isEmpty ? getVal('bo_utrn') : getVal('bo_utrnno'),
    );
  }

  /// Exports row into clean List ordered by standard 15 headers
  List<dynamic> toStandardRowList() {
    return [
      issuer,
      acquirer,
      mti,
      cardNumber,
      amount,
      currency,
      transactionDate,
      transactionDescription,
      terminalId,
      transactionPlace,
      stanF11,
      refnumF37,
      authidrespF38,
      feUtrnno,
      boUtrnno,
    ];
  }

  /// Converts to PlutoRow for rich data grid viewing
  PlutoRow toPlutoRow() {
    return PlutoRow(
      cells: {
        'issuer': PlutoCell(value: issuer),
        'acquirer': PlutoCell(value: acquirer),
        'mti': PlutoCell(value: mti),
        'card_number': PlutoCell(value: cardNumber),
        'amount': PlutoCell(value: amount),
        'currency': PlutoCell(value: currency),
        'transaction_date': PlutoCell(value: transactionDate),
        'transaction_description': PlutoCell(value: transactionDescription),
        'terminal_id': PlutoCell(value: terminalId),
        'transaction_place': PlutoCell(value: transactionPlace),
        'stan_f11': PlutoCell(value: stanF11),
        'refnum_f37': PlutoCell(value: refnumF37),
        'authidresp_f38': PlutoCell(value: authidrespF38),
        'fe_utrnno': PlutoCell(value: feUtrnno),
        'bo_utrnno': PlutoCell(value: boUtrnno),
      },
    );
  }
}
