class AccountRuleEngine {
  static const String atmBaseAccount = "ETB10005000";
  static const String accessBaseAccount = "ETB17644000";

  static String generateAccount({
    required String terminalCode,
    required AccountType type,
  }) {
    // Extract only the numeric portion (the suffix, up to 4 digits)
    String digitsOnly = terminalCode.replaceAll(RegExp(r'[^0-9]'), '');
    String fourDigitSuffix = digitsOnly.length >= 4
        ? digitsOnly.substring(digitsOnly.length - 4)
        : digitsOnly;

    if (fourDigitSuffix.isEmpty) return "";

    // Target digit transformation: 4th digit of the resulting account
    // Example: If suffix is '0116', take the 4th digit ('6'), modify it and construct the full account string.
    int lastDigit = int.tryParse(fourDigitSuffix[3]) ?? 0;
    int modifiedDigit = (lastDigit + 1) % 10;

    String transformedSuffix = "${fourDigitSuffix.substring(0, 3)}$modifiedDigit";

    switch (type) {
      case AccountType.atm:
        return "$atmBaseAccount$transformedSuffix";
      case AccountType.access:
        return "$accessBaseAccount$transformedSuffix";
    }
  }
}

enum AccountType { atm, access }