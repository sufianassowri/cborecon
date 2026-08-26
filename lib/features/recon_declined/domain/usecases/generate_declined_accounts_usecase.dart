import '../entities/recon_declined_models.dart';

class DerivedAccounts {
  final String excessAccount;
  final String atmAccount;
  final DeclinedAtmHardwareType hardwareType;
  final bool isValid;

  const DerivedAccounts({
    required this.excessAccount,
    required this.atmAccount,
    required this.hardwareType,
    required this.isValid,
  });

  static const invalid = DerivedAccounts(
    excessAccount: 'INVALID',
    atmAccount: 'INVALID',
    hardwareType: DeclinedAtmHardwareType.unknown,
    isValid: false,
  );
}

class ClassifyDeclinedHardwareUseCase {
  DeclinedAtmHardwareType call(String identifier) {
    if (identifier.trim().isEmpty) return DeclinedAtmHardwareType.unknown;
    final upper = identifier.trim().toUpperCase();

    // Check account number patterns first
    if (upper.startsWith('ETB10002') ||
        upper.startsWith('10002') ||
        upper.startsWith('ETB17643') ||
        upper.startsWith('17643')) {
      return DeclinedAtmHardwareType.ncr;
    }
    if (upper.startsWith('ETB10005') ||
        upper.startsWith('10005') ||
        upper.startsWith('ETB17644') ||
        upper.startsWith('17644')) {
      return DeclinedAtmHardwareType.crm;
    }

    // Check terminal ID pattern (search for 'N' or 'C')
    int letterIndex = -1;
    for (int i = upper.length - 1; i >= 0; i--) {
      if (upper[i] == 'N' || upper[i] == 'C') {
        letterIndex = i;
        break;
      }
    }

    if (letterIndex == -1) return DeclinedAtmHardwareType.unknown;
    return upper[letterIndex] == 'N'
        ? DeclinedAtmHardwareType.ncr
        : DeclinedAtmHardwareType.crm;
  }

  String getTypeName(DeclinedAtmHardwareType type) {
    switch (type) {
      case DeclinedAtmHardwareType.ncr:
        return 'NCR';
      case DeclinedAtmHardwareType.crm:
        return 'CRM';
      case DeclinedAtmHardwareType.unknown:
        return 'UNKNOWN';
    }
  }
}

class GenerateDeclinedAccountsUseCase {
  static const String ncrAtmPrefix = '10002000';
  static const String crmAtmPrefix = '10005000';
  static const String ncrExcessPrefix = '17643000';
  static const String crmExcessPrefix = '17644000';

  DerivedAccounts call(String identifier) {
    if (identifier.trim().isEmpty) return DerivedAccounts.invalid;
    final upperId = identifier.trim().toUpperCase();

    // 1. Check if identifier is already an ATM Account (CREDIT.ACCT.NO) or Excess Account
    String cleanAcc = upperId;
    if (cleanAcc.startsWith('ETB')) {
      cleanAcc = cleanAcc.substring(3);
    }

    // ATM Account for NCR (10002...)
    if (cleanAcc.startsWith('10002')) {
      final suffix = cleanAcc.substring(5);
      final excessAcc = 'ETB17643$suffix';
      final atmAcc = 'ETB10002$suffix';
      return DerivedAccounts(
        excessAccount: excessAcc,
        atmAccount: atmAcc,
        hardwareType: DeclinedAtmHardwareType.ncr,
        isValid: true,
      );
    }

    // ATM Account for CRM (10005...)
    if (cleanAcc.startsWith('10005')) {
      final suffix = cleanAcc.substring(5);
      final excessAcc = 'ETB17644$suffix';
      final atmAcc = 'ETB10005$suffix';
      return DerivedAccounts(
        excessAccount: excessAcc,
        atmAccount: atmAcc,
        hardwareType: DeclinedAtmHardwareType.crm,
        isValid: true,
      );
    }

    // Excess Account for NCR (17643...)
    if (cleanAcc.startsWith('17643')) {
      final suffix = cleanAcc.substring(5);
      final excessAcc = 'ETB17643$suffix';
      final atmAcc = 'ETB10002$suffix';
      return DerivedAccounts(
        excessAccount: excessAcc,
        atmAccount: atmAcc,
        hardwareType: DeclinedAtmHardwareType.ncr,
        isValid: true,
      );
    }

    // Excess Account for CRM (17644...)
    if (cleanAcc.startsWith('17644')) {
      final suffix = cleanAcc.substring(5);
      final excessAcc = 'ETB17644$suffix';
      final atmAcc = 'ETB10005$suffix';
      return DerivedAccounts(
        excessAccount: excessAcc,
        atmAccount: atmAcc,
        hardwareType: DeclinedAtmHardwareType.crm,
        isValid: true,
      );
    }

    // 2. Standard Terminal ID derivation (e.g. WFDC3732, SFDN4056, EFDN0073)
    int letterIndex = -1;
    for (int i = upperId.length - 1; i >= 0; i--) {
      if (upperId[i] == 'N' || upperId[i] == 'C') {
        letterIndex = i;
        break;
      }
    }

    if (letterIndex == -1 || letterIndex + 1 >= upperId.length) {
      return DerivedAccounts.invalid;
    }

    final typeChar = upperId[letterIndex];
    final int? orderDigit = int.tryParse(upperId[letterIndex + 1]);
    if (orderDigit == null) return DerivedAccounts.invalid;

    final String suffix = upperId.length >= 3
        ? upperId.substring(upperId.length - 3)
        : upperId.padLeft(3, '0');

    final hardwareType = (typeChar == 'N')
        ? DeclinedAtmHardwareType.ncr
        : DeclinedAtmHardwareType.crm;

    final String atmBase = (typeChar == 'N') ? ncrAtmPrefix : crmAtmPrefix;
    final String excessBase = (typeChar == 'N') ? ncrExcessPrefix : crmExcessPrefix;

    final int transformedOrder = orderDigit + 1;
    final String atmAcc = 'ETB$atmBase${transformedOrder}0$suffix';
    final String excessAcc = 'ETB$excessBase${transformedOrder}0$suffix';

    return DerivedAccounts(
      excessAccount: excessAcc,
      atmAccount: atmAcc,
      hardwareType: hardwareType,
      isValid: true,
    );
  }
}
