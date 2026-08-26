import 'extra_amount_parser.dart';

/// Parses annual fee values from Column R in MF (Maintenance Fee) records.
///
/// Example input: `[/-3/D/840]` → extracted fee = 3.00
/// Delegates to [ExtraAmountParser.parseMfAnnualFee] for consistent regex usage.
class AnnualFeeParser {
  /// Extract annual fee value from the raw Column R string.
  ///
  /// Returns the absolute fee amount, or 0.0 if no valid pattern is found.
  static double parse(String? rawR) {
    return ExtraAmountParser.parseMfAnnualFee(rawR);
  }
}