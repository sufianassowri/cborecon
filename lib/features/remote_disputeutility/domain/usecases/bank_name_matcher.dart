class BankNameMatcher {
  BankNameMatcher._();

  static const Map<String, List<String>> _bankAliases = {
    'CBE': [
      'COMMERCIAL BANK OF ETHIOPIA',
      'COMMERCIAL BANK OF ETHIOPIA S.C',
      'CBE',
      'CBE ETS SETTL',
      'CBE SETTL',
      'COMMERCIAL BANK',
      'ETHIOPIAN COMMERCIAL BANK',
    ],
    'ABYSSINIA': [
      'BANK OF ABYSSINIA S.C',
      'BANK OF ABYSSINIA',
      'ABYSSINIA',
      'ABYSSINIA BANK',
      'BOA',
    ],
    'AWASH': [
      'AWASH BANK',
      'AWASH BANK S.C',
      'AWASH INTERNATIONAL BANK',
      'AWASH',
      'AIB',
    ],
    'DASHEN': [
      'DASHEN BANK',
      'DASHEN BANK S.C',
      'DASHEN',
      'DB',
    ],
    'HIBRET': [
      'HIBRET BANK (UNITED BANK)',
      'HIBRET BANK',
      'UNITED BANK',
      'UNITED BANK S.C',
      'HIBRET',
      'UNITED',
      'UB',
    ],
    'WEGAGEN': [
      'WEGAGEN BANK',
      'WEGAGEN BANK S.C',
      'WEGAGEN',
      'WB',
    ],
    'NIB': [
      'NIB INTERNATIONAL BANK',
      'NIB INTERNATIONAL BANK S.C',
      'NIB BANK',
      'NIB',
      'NIB INTERNATIONAL',
    ],
    'CBO': [
      'COOPERATIVE BANK OF OROMIA',
      'COOPERATIVE BANK OF OROMIA S.C',
      'COOPERATIVE BANK',
      'COOP BANK',
      'COOP',
      'CBO',
    ],
    'OROMIA': [
      'OROMIA BANK',
      'OROMIA INTERNATIONAL BANK',
      'OROMIA INTERNATIONAL BANK S.C',
      'OROMIA',
      'OIB',
    ],
    'ZEMEN': [
      'ZEMEN BANK',
      'ZEMEN BANK S.C',
      'ZEMEN',
      'ZB',
    ],
    'BUNNA': [
      'BUNNA INTERNATIONAL BANK',
      'BUNNA INTERNATIONAL BANK S.C',
      'BUNNA BANK',
      'BUNNA',
    ],
    'ABAY': [
      'ABAY BANK',
      'ABAY BANK S.C',
      'ABAY',
    ],
    'BERHAN': [
      'BERHAN BANK',
      'BERHAN INTERNATIONAL BANK',
      'BERHAN INTERNATIONAL BANK S.C',
      'BERHAN',
    ],
    'GLOBAL': [
      'GLOBAL BANK ETHIOPIA',
      'GLOBAL BANK ETHIOPIA S.C',
      'DEBUB GLOBAL BANK',
      'GLOBAL BANK',
      'GLOBAL',
    ],
    'LION': [
      'LION INTERNATIONAL BANK',
      'LION INTERNATIONAL BANK S.C',
      'LION BANK',
      'LION',
      'LIB',
    ],
    'ENAT': [
      'ENAT BANK',
      'ENAT BANK S.C',
      'ENAT',
    ],
    'AMHARA': [
      'AMHARA BANK',
      'AMHARA BANK S.C',
      'AMHARA',
    ],
    'SIINQEE': [
      'SIINQEE BANK',
      'SIINQEE BANK S.C',
      'SINQEE BANK',
      'SIINQEE',
      'SINQEE',
    ],
    'TSEDEY': [
      'TSEDEY BANK',
      'TSEDEY BANK S.C',
      'TSEDEY',
    ],
    'ZAMZAM': [
      'ZAMZAM',
      'ZAMZAM BANK',
      'ZAMZAM BANK S.C',
      'ZAM ZAM',
    ],
    'HIJRA': [
      'HIJRA BANK',
      'HIJRA BANK S.C',
      'HIJRA',
    ],
    'SHABELLE': [
      'SHABELLE BANK',
      'SHABELLE BANK S.C',
      'SOMALI MICROFINANCE',
      'SHABELLE',
    ],
    'AHADU': [
      'AHADU BANK',
      'AHADU BANK S.C',
      'AHADU',
    ],
    'GOH': [
      'GOH BETOCH BANK',
      'GOH BETOCH BANK S.C',
      'GOH BANK',
      'GOH',
      'GOH BETOCH',
    ],
    'RAMMIS': [
      'BANK RAMMIS',
      'RAMMIS BANK',
      'RAMMIS BANK S.C',
      'RAMMIS',
    ],
    'SIDAMA': [
      'BANK SIDAMA',
      'SIDAMA BANK',
      'SIDAMA BANK S.C',
      'SIDAMA',
    ],
    'SIKET': [
      'SIKET BANK',
      'SIKET BANK S.C',
      'SIKET',
    ],
    'OMO': [
      'OMO BANK',
      'OMO BANK S.C',
      'OMO',
    ],
  };

  /// Returns the canonical bank code (e.g. 'CBE', 'ABYSSINIA') for a given bank name string.
  static String getCanonicalBank(String? bankName) {
    if (bankName == null) return '';
    String clean = bankName.trim().toUpperCase().replaceAll(RegExp(r'[\.\,\-_]'), ' ');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '';

    for (final entry in _bankAliases.entries) {
      final code = entry.key;
      final aliases = entry.value;

      if (clean == code) return code;

      for (final alias in aliases) {
        final cleanAlias = alias.toUpperCase().replaceAll(RegExp(r'[\.\,\-_]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (clean == cleanAlias || clean.contains(cleanAlias) || cleanAlias.contains(clean)) {
          return code;
        }
      }
    }

    return clean;
  }

  /// Determines if two bank name strings represent the same banking institution.
  /// If [rrnMatched] is true, bank names automatically align per business rule.
  static bool isBankMatch(String? cbsBank, String? settlementBank, {bool rrnMatched = false}) {
    if (rrnMatched) return true;
    if (cbsBank == null || settlementBank == null) return false;
    if (cbsBank.trim().isEmpty || settlementBank.trim().isEmpty) return false;

    final can1 = getCanonicalBank(cbsBank);
    final can2 = getCanonicalBank(settlementBank);

    if (can1.isNotEmpty && can2.isNotEmpty && can1 == can2) {
      return true;
    }

    final norm1 = cbsBank.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final norm2 = settlementBank.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (norm1 == norm2 || norm1.contains(norm2) || norm2.contains(norm1)) {
      return true;
    }

    return false;
  }
}
