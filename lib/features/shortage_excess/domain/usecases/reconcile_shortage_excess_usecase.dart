import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/normalization_util.dart';
import '../entities/shortage_models.dart';

class ClassifyAtmHardwareUseCase {
  AtmHardwareType call(String terminalId) {
    if (terminalId.isEmpty) return AtmHardwareType.unknown;
    final upperId = terminalId.toUpperCase();
    int letterIndex = -1;

    for (int i = upperId.length - 1; i >= 0; i--) {
      if (upperId[i] == 'N' || upperId[i] == 'C') {
        letterIndex = i;
        break;
      }
    }

    if (letterIndex == -1) return AtmHardwareType.unknown;
    return upperId[letterIndex] == 'N' ? AtmHardwareType.ncr : AtmHardwareType.crm;
  }

  String getTypeName(AtmHardwareType type) {
    switch (type) {
      case AtmHardwareType.ncr:
        return 'NCR';
      case AtmHardwareType.crm:
        return 'CRM';
      case AtmHardwareType.unknown:
        return 'UNKNOWN';
    }
  }
}

class GenerateAtmAccountUseCase {
  String call(String terminalId) {
    if (terminalId.isEmpty) return '';
    final upperId = terminalId.toUpperCase();
    int letterIndex = -1;

    for (int i = upperId.length - 1; i >= 0; i--) {
      if (upperId[i] == 'N' || upperId[i] == 'C') {
        letterIndex = i;
        break;
      }
    }

    if (letterIndex == -1 || letterIndex + 1 >= upperId.length) return 'INVALID';
    final typeChar = upperId[letterIndex];
    final int? orderDigit = int.tryParse(upperId[letterIndex + 1]);
    if (orderDigit == null) return 'INVALID';

    final String suffix = upperId.length >= 3 ? upperId.substring(upperId.length - 3) : upperId.padLeft(3, '0');
    final String basePrefix = (typeChar == 'N') ? AppConstants.ncrAccountPrefix : AppConstants.crmAccountPrefix;

    return 'ETB$basePrefix${orderDigit + 1}0$suffix';
  }
}

class ReconcileShortageExcessUseCase {
  final ClassifyAtmHardwareUseCase _classifier = ClassifyAtmHardwareUseCase();
  final GenerateAtmAccountUseCase _accountGen = GenerateAtmAccountUseCase();

  // Standard CBS Headers:
  // TRANS.REF, VALUE.DATE, DEBIT.ACCT.NO, CREDIT.ACCT.NO, TXN.AMOUNT, CARD.ACC.ID, RETRIEVAL.REF.NO
  // Standard Settlement / Switch Headers:
  // Issuer, Acquirer, Card_Number, Amount, Transaction_Date, Terminal_ID, Transaction_Description, Refnum_F37

  static dynamic _getVal(Map<String, dynamic> row, List<String> possibleKeys) {
    for (final k in possibleKeys) {
      if (row.containsKey(k) && row[k] != null && row[k].toString().trim().isNotEmpty) {
        return row[k];
      }
    }
    // Case-insensitive / format-tolerant lookup
    for (final k in possibleKeys) {
      final cleanK = k.replaceAll(RegExp(r'[\s._]'), '').toUpperCase();
      for (final entry in row.entries) {
        final cleanKey = entry.key.replaceAll(RegExp(r'[\s._]'), '').toUpperCase();
        if (cleanKey == cleanK && entry.value != null && entry.value.toString().trim().isNotEmpty) {
          return entry.value;
        }
      }
    }
    return '';
  }

  ShortageExcessResult call(
    List<Map<String, dynamic>> cbsData,
    List<Map<String, dynamic>> switchData,
  ) {
    // 1. Index Switch/Settlement data by composite key: RRN (Refnum_F37) + Amount + Terminal_ID
    final Map<String, List<Map<String, dynamic>>> swMap = {};
    for (final sw in switchData) {
      final swRrn = _getVal(sw, ['Refnum_F37', 'REFNUM_F37', 'RETRIEVAL.REF.NO', 'RRN']);
      final swAmt = _getVal(sw, ['Amount', 'AMOUNT', 'TXN.AMOUNT']);
      final swTerm = _getVal(sw, ['Terminal_ID', 'TERMINAL_ID', 'CARD.ACC.ID', 'Terminal ID']);

      final key = _genKey(swRrn, swAmt, swTerm);
      swMap.putIfAbsent(key, () => []).add(sw);
    }

    final List<Map<String, dynamic>> cbsOnly = [];
    final List<Map<String, dynamic>> matched = [];

    // 2. Iterate through CBS records and match with 3 criteria:
    // Criteria 1: TXN.AMOUNT (CBS) == Amount (Settlement)
    // Criteria 2: CARD.ACC.ID (CBS) == Terminal_ID (Settlement)
    // Criteria 3: RETRIEVAL.REF.NO (CBS) == Refnum_F37 (Settlement)
    for (final cbs in cbsData) {
      final cbsRrn = _getVal(cbs, ['RETRIEVAL.REF.NO', 'REFNUM_F37', 'RRN', 'TRANS.REF']);
      final cbsAmt = _getVal(cbs, ['TXN.AMOUNT', 'Amount', 'AMOUNT']);
      final cbsTerm = _getVal(cbs, ['CARD.ACC.ID', 'Terminal_ID', 'TERMINAL']);

      final key = _genKey(cbsRrn, cbsAmt, cbsTerm);
      final terminalId = NormalizationUtil.normalize(cbsTerm);
      final atmType = _classifier.getTypeName(_classifier(terminalId));
      final atmAcc = _accountGen(terminalId);

      if (swMap.containsKey(key) && swMap[key]!.isNotEmpty) {
        // All 3 criteria matched
        final swMatch = swMap[key]!.removeAt(0);

        final cbsCopy = Map<String, dynamic>.from(cbs);
        final swCopy = Map<String, dynamic>.from(swMatch);

        cbsCopy['ATM_TYPE'] = atmType;
        cbsCopy['ATM_ACC'] = atmAcc;
        cbsCopy['STATUS'] = 'MATCHED';

        final swTermId = NormalizationUtil.normalize(_getVal(swMatch, ['Terminal_ID', 'TERMINAL_ID', 'CARD.ACC.ID']));
        swCopy['ATM_TYPE'] = _classifier.getTypeName(_classifier(swTermId));
        swCopy['ATM_ACC'] = _accountGen(swTermId);
        swCopy['STATUS'] = 'MATCHED';

        matched.add({
          'cbs': cbsCopy,
          'sw': swCopy,
          'STATUS': 'MATCHED',
          'ATM_TYPE': atmType,
          'ATM_ACC': atmAcc,
          'TERMINAL_ID': terminalId,
          'RRN': NormalizationUtil.normalize(cbsRrn),
          'AMOUNT': NormalizationUtil.parseAmount(cbsAmt),
        });
      } else {
        // In CBS but not in Switch -> Categorized as CBS side only (UNMATCHED_CBS)
        final row = Map<String, dynamic>.from(cbs);
        row['ATM_TYPE'] = atmType;
        row['ATM_ACC'] = atmAcc;
        row['STATUS'] = 'UNMATCHED_CBS';
        row['TERMINAL_ID'] = terminalId;
        row['RRN'] = NormalizationUtil.normalize(cbsRrn);
        row['AMOUNT'] = NormalizationUtil.parseAmount(cbsAmt);
        cbsOnly.add(row);
      }
    }

    // 3. Remaining Switch records -> Categorized as Switch side only (UNMATCHED_SW)
    final List<Map<String, dynamic>> swOnly = [];
    swMap.forEach((key, list) {
      for (final sw in list) {
        final row = Map<String, dynamic>.from(sw);
        final swTerm = _getVal(sw, ['Terminal_ID', 'TERMINAL_ID', 'CARD.ACC.ID', 'Terminal ID']);
        final swRrn = _getVal(sw, ['Refnum_F37', 'REFNUM_F37', 'RETRIEVAL.REF.NO', 'RRN']);
        final swAmt = _getVal(sw, ['Amount', 'AMOUNT', 'TXN.AMOUNT']);

        final terminalId = NormalizationUtil.normalize(swTerm);
        final atmType = _classifier.getTypeName(_classifier(terminalId));
        final atmAcc = _accountGen(terminalId);

        row['ATM_TYPE'] = atmType;
        row['ATM_ACC'] = atmAcc;
        row['STATUS'] = 'UNMATCHED_SW';
        row['TERMINAL_ID'] = terminalId;
        row['RRN'] = NormalizationUtil.normalize(swRrn);
        row['AMOUNT'] = NormalizationUtil.parseAmount(swAmt);
        swOnly.add(row);
      }
    });

    final cbsHeaders = cbsData.isNotEmpty ? cbsData.first.keys.toList() : <String>[];
    final switchHeaders = switchData.isNotEmpty ? switchData.first.keys.toList() : <String>[];

    return ShortageExcessResult(
      cbsOnly: cbsOnly,
      switchOnly: swOnly,
      matched: matched,
      cbsHeaders: cbsHeaders,
      switchHeaders: switchHeaders,
    );
  }

  static String _normRrn(dynamic val) {
    if (val == null) return '';
    String s = val.toString().trim();
    if (s.contains('E') || s.contains('e')) {
      final double? d = double.tryParse(s);
      if (d != null) s = d.toStringAsFixed(0);
    }
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    s = s.replaceAll(RegExp(r'[^\w]'), '');
    // Strip leading zeros for purely numeric RRNs so 000622504566580 equals 622504566580
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final stripped = s.replaceFirst(RegExp(r'^0+'), '');
      return stripped.isEmpty ? '0' : stripped;
    }
    return s.toUpperCase();
  }

  static String _normAmt(dynamic val) {
    if (val == null) return '0.00';
    final double amt = NormalizationUtil.parseAmount(val).abs();
    return amt.toStringAsFixed(2);
  }

  static String _normTerm(dynamic val) {
    if (val == null) return '';
    String s = val.toString().trim().toUpperCase();
    return s.replaceAll(RegExp(r'[\s._-]'), '');
  }

  String _genKey(dynamic rrn, dynamic amount, dynamic terminal) {
    final normRrn = _normRrn(rrn);
    final normAmt = _normAmt(amount);
    final normTerm = _normTerm(terminal);
    return '${normRrn}_${normAmt}_$normTerm';
  }
}
