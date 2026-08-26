class NormalizationUtil {
  NormalizationUtil._();

  /// Normalizes generic string values, stripping floating point zero suffixes (.0),
  /// scientific exponents, commas, and edge whitespace.
  static String normalize(dynamic val) {
    if (val == null) return '';
    String s = val.toString().trim();
    if (s.contains('E') || s.contains('e')) {
      final double? d = double.tryParse(s);
      if (d != null) s = d.toStringAsFixed(0);
    }
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    return s.replaceAll(',', '');
  }

  /// Parses monetary amounts safely into positive/signed doubles
  static double parseAmount(dynamic val) {
    if (val == null) return 0.0;
    final String clean = val.toString().replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  /// Compares two floating point amounts with epsilon precision
  static bool amountsEqual(double a, double b, {double epsilon = 0.01}) {
    return (a - b).abs() < epsilon;
  }
}
