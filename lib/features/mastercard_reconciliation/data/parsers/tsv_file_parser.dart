import 'extra_amount_parser.dart';

/// Parses raw Mastercard settlement TSV file content into structured row maps.
///
/// Column offset mapping (0-indexed):
///   - Col A  (0):  Record Type (TX, MF, FH, FT)
///   - Col H  (7):  Transaction Date
///   - Col J  (9):  Settlement Item ID (for composite key)
///   - Col K  (10): Client ID (MF records)
///   - Col L  (11): PAN (MF records)
///   - Col Q  (16): Client ID (TX records)
///   - Col R  (17): PAN (TX) / Annual Fee Tag (MF)
///   - Col S  (18): Transaction Description (MF)
///   - Col AI (34): Debit/Credit indicator (D/C)
///   - Col AP (41): Base Amount
///   - Col AS (44): Extra Fee String (TX records)
class TsvFileParser {
  /// Parse the full TSV file content and return structured row data.
  ///
  /// Only processes rows with Record Type `TX` or `MF`.
  /// Each returned map includes:
  ///   - `recordType`: String ('TX' or 'MF')
  ///   - `settlementItemId`: String (Column J)
  ///   - `transactionDate`: String (Column H)
  ///   - `clientId`: String
  ///   - `pan`: String
  ///   - `debitCredit`: String ('D' or 'C')
  ///   - `baseAmount`: double
  ///   - `extraAmount`: double (TX only, from regex parsing)
  ///   - `annualFeeAmount`: double (MF only, from regex parsing)
  ///   - `description`: String (MF only, Column S)
  static List<Map<String, dynamic>> parseTsvContent(String content) {
    final List<Map<String, dynamic>> parsedRows = [];
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final cols = line.split('\t');
      if (cols.isEmpty) continue;

      final recordType = cols[0].trim(); // Index 0 (Col A)

      // Only process TX (card spend) and MF (fees) records
      if (recordType != 'TX' && recordType != 'MF') continue;

      // Settlement Item ID — Column J (index 9)
      final settlementItemId = cols.length > 9 ? cols[9].trim() : '';
      if (settlementItemId.isEmpty) continue;

      // Transaction Date — Column H (index 7)
      final transactionDate = cols.length > 7 ? cols[7].trim() : '';

      String clientId = '';
      String pan = '';
      double baseAmount = 0.0;
      double extraAmount = 0.0;
      double annualFeeAmount = 0.0;
      String debitCredit = 'D';
      String description = '';

      // Debit/Credit indicator — Column AI (index 34)
      if (cols.length > 34) {
        debitCredit = cols[34].trim().toUpperCase();
        if (debitCredit != 'D' && debitCredit != 'C') debitCredit = 'D';
      }

      // Base Amount — Column AP (index 41)
      if (cols.length > 41) {
        baseAmount =
            double.tryParse(cols[41].replaceAll(',', '').trim()) ?? 0.0;
      }

      if (recordType == 'TX') {
        // TX: Client ID from Col Q (16), PAN from Col R (17)
        if (cols.length > 16) clientId = cols[16].trim();
        if (cols.length > 17) pan = cols[17].trim();

        // Extra fees from Col AS (44) — regex parsed
        final rawExtraStr = cols.length > 44 ? cols[44].trim() : '';
        extraAmount = ExtraAmountParser.parseTxExtraAmount(rawExtraStr);

        // TX merchant/description from Col Y (24) if available
        if (cols.length > 24) description = cols[24].trim();
      } else if (recordType == 'MF') {
        // MF: Client ID from Col K (10), PAN from Col L (11)
        if (cols.length > 10) clientId = cols[10].trim();
        if (cols.length > 11) pan = cols[11].trim();

        // Annual Fee from Col R (17) — regex parsed
        final rawAnnualFeeStr = cols.length > 17 ? cols[17].trim() : '';
        annualFeeAmount = ExtraAmountParser.parseMfAnnualFee(rawAnnualFeeStr);

        // Description from Col S (18)
        if (cols.length > 18) description = cols[18].trim();
      }

      if (clientId.isEmpty) continue;

      parsedRows.add({
        'recordType': recordType,
        'settlementItemId': settlementItemId,
        'transactionDate': transactionDate,
        'clientId': clientId,
        'pan': pan,
        'debitCredit': debitCredit,
        'baseAmount': baseAmount,
        'extraAmount': extraAmount,
        'annualFeeAmount': annualFeeAmount,
        'description': description,
      });
    }

    return parsedRows;
  }
}