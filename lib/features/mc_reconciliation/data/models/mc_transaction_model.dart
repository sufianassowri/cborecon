import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/mc_transaction.dart';

class McTransactionModel extends McTransaction {
  const McTransactionModel({
    required super.trxnType,
    required super.trxnDate,
    required super.clientId,
    required super.pan,
    required super.baseAmount,
    required super.debitOrCredit,
    required super.extraAmount,
    required super.annualFeeAmount,
    required super.description,
  });

  factory McTransactionModel.fromTsvRow(List<dynamic> row) {
    String safeGet(int index) {
      if (index < row.length && row[index] != null) {
        return row[index].toString().trim();
      }
      return '';
    }

    double safeParseDouble(int index) {
      final str = safeGet(index);
      return double.tryParse(str) ?? 0.0;
    }

    // Helper method to parse extra amount from Column AS
    double parseExtraAmount(String rawAsColumn) {
      if (rawAsColumn.isEmpty) return 0.0;

      // Matches any bracket pattern like [FXF/-1/D/840] or [A1F/-2.98/D/840]
      // Group 1 captures the number (e.g., -1, -2.98, 1, 3.94)
      final regExp = RegExp(r'\[[A-Za-z0-9]*/?(-?\d+(?:\.\d+)?)/[DC]/\d+\]');
      final matches = regExp.allMatches(rawAsColumn);

      double total = 0.0;
      for (final match in matches) {
        final numStr = match.group(1);
        if (numStr != null) {
          final val = double.tryParse(numStr) ?? 0.0;
          // Absolute value so signs (+ or -) are added together as positive fees
          total += val.abs();
        }
      }
      return total;
    }

    final type = safeGet(McTsvIndices.trxnType);
    final isMx = type.toUpperCase() == 'MX';

    final clientId = isMx ? safeGet(McTsvIndices.mxClientId) : safeGet(McTsvIndices.txClientId);
    final pan = isMx ? safeGet(McTsvIndices.mxPan) : safeGet(McTsvIndices.txPan);
    final desc = isMx ? safeGet(McTsvIndices.mxDescription) : safeGet(McTsvIndices.txMerchantName);

    // Extract raw string from Column AS (McTsvIndices.extraAmount)
    final rawExtraStr = safeGet(McTsvIndices.extraAmount);

    return McTransactionModel(
      trxnType: type,
      trxnDate: safeGet(McTsvIndices.trxnDate),
      clientId: clientId,
      pan: pan,
      baseAmount: safeParseDouble(McTsvIndices.baseAmount),
      debitOrCredit: safeGet(McTsvIndices.debitOrCreditFlag),
      extraAmount: parseExtraAmount(rawExtraStr), // Calculated double value
      annualFeeAmount: isMx ? safeParseDouble(McTsvIndices.mxAnnualFeeAmnt) : 0.0,
      description: desc,
    );
  }
}