import 'normalization_util.dart';

class PanMaskerUtil {
  PanMaskerUtil._();

  /// Masks a 16-19 digit card PAN for PCI-DSS compliance (e.g. 604102******1234)
  static String mask(String? pan) => maskPan(pan);

  static String maskPan(String? pan) {
    if (pan == null || pan.isEmpty) return '';
    final String clean = pan.replaceAll(RegExp(r'\s+'), '');
    if (clean.length <= 8) return clean;
    final String first6 = clean.substring(0, 6);
    final String last4 = clean.substring(clean.length - 4);
    final int middleLen = clean.length - 10;
    return '$first6${'*' * (middleLen > 0 ? middleLen : 6)}$last4';
  }

  /// Verifies if the first 4 and last 4 digits of two PAN strings match
  static bool isPanMatch(dynamic pan1, dynamic pan2) {
    final String p1 =
        NormalizationUtil.normalize(pan1).replaceAll(RegExp(r'\s+'), '');
    final String p2 =
        NormalizationUtil.normalize(pan2).replaceAll(RegExp(r'\s+'), '');

    if (p1.length < 8 || p2.length < 8) return false;

    final String p1First4 = p1.substring(0, 4);
    final String p1Last4 = p1.substring(p1.length - 4);

    final String p2First4 = p2.substring(0, 4);
    final String p2Last4 = p2.substring(p2.length - 4);

    return (p1First4 == p2First4) && (p1Last4 == p2Last4);
  }
}
