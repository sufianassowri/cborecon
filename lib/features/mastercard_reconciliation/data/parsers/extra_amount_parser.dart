/// Parses extra fee amounts from Mastercard TSV settlement columns.
///
/// TX rows (Column AS, index 44): Contains fee blocks like
///   `[FXF/-1/D/840] [A1F/-2.98/D/840]`
///   → extraAmount = Σ|FXF values| + Σ|A1F values| = 1 + 2.98 = 3.98
///
/// MF rows (Column R, index 17): Contains annual fee tags like
///   `[/-3/D/840]`
///   → annualFeeAmount = |extracted value| = 3.00
class ExtraAmountParser {
  /// Regex for TX extra fees: matches [FXF/value/D_or_C/...] and [A1F/value/D_or_C/...]
  static final RegExp _txExtraRegex = RegExp(
    r'\[(?:FXF|A1F)\/([+-]?\d*(?:\.\d+)?)\/[DC]\/',
  );

  /// Regex for MF annual fees: matches [/value/D_or_C/...] or [/-value/D_or_C/...]
  static final RegExp _mfAnnualFeeRegex = RegExp(
    r'\[\/?([+-]?\d*(?:\.\d+)?)\/[DC]\/',
  );

  /// Parse extra amount from Column AS for TX records.
  ///
  /// Extracts all [FXF/...] and [A1F/...] blocks and sums their absolute values.
  /// Returns 0.0 if the input is empty or contains no matching patterns.
  static double parseTxExtraAmount(String? rawExtra) {
    if (rawExtra == null || rawExtra.trim().isEmpty) return 0.0;

    double sum = 0.0;
    final matches = _txExtraRegex.allMatches(rawExtra);
    for (final m in matches) {
      final valStr = m.group(1);
      if (valStr != null && valStr.isNotEmpty) {
        final val = double.tryParse(valStr) ?? 0.0;
        sum += val.abs();
      }
    }
    return sum;
  }

  /// Parse annual fee from Column R for MF records.
  ///
  /// Extracts the first numeric value from patterns like `[/-3/D/840]`.
  /// Returns the absolute value, e.g. -3 → 3.00.
  static double parseMfAnnualFee(String? rawFee) {
    if (rawFee == null || rawFee.trim().isEmpty) return 0.0;

    final match = _mfAnnualFeeRegex.firstMatch(rawFee);
    if (match != null) {
      final valStr = match.group(1);
      if (valStr != null && valStr.isNotEmpty) {
        return (double.tryParse(valStr) ?? 0.0).abs();
      }
    }
    return 0.0;
  }
}