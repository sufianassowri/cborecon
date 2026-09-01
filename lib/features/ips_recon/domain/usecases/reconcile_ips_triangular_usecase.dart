import '../../../../core/utils/normalization_util.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ips_recon_models.dart';

class IpsTriangularResult {
  final List<Map<String, dynamic>> pairedRows;
  final List<String> ecHeaders;
  final List<String> etHeaders;
  final List<String> crHeaders;
  final IpsTriangularSummary summary;

  const IpsTriangularResult({
    required this.pairedRows,
    required this.ecHeaders,
    required this.etHeaders,
    required this.crHeaders,
    required this.summary,
  });
}

class ReconcileIpsTriangularUseCase {
  String _cleanReference(String ref) {
    final normalized = NormalizationUtil.normalize(ref);
    if (normalized.contains('\\')) {
      return normalized.split('\\').first.trim();
    }
    return normalized;
  }

  IpsTriangularResult call({
    required List<List<dynamic>> ebirrCbsData,
    required List<List<dynamic>> ebirrSettlementData,
    required List<List<dynamic>> cbsReportData,
  }) {
    if (ebirrCbsData.isEmpty || ebirrSettlementData.isEmpty || cbsReportData.isEmpty) {
      throw const ReconciliationFailure('All three files (Ebirr CBS, Settlement, CBS Report) must be uploaded.');
    }

    final ecH = ebirrCbsData[0].map((e) => e.toString().trim()).toList();
    final etH = ebirrSettlementData[0].map((e) => e.toString().trim()).toList();
    final crH = cbsReportData[0].map((e) => e.toString().trim()).toList();

    final int ecRefIdx = ecH.indexOf('TRANS REFERENCE');
    final int ecThirdIdx = ecH.indexOf('THIRD_PARTY_REFERENCE');
    final int ecAmtIdx = ecH.indexOf('DEBIT AMT');

    final int etIdIdx = etH.indexOf('Ebirr TRANSFERID');
    final int etAmtIdx = etH.indexOf('DEBIT');

    final int crRefIdx = crH.indexWhere((h) => h.toLowerCase().contains('reference'));
    final int crAmtIdx = crH.indexWhere((h) => h.toLowerCase().contains('debit'));

    if (ecRefIdx == -1 || ecThirdIdx == -1 || ecAmtIdx == -1 || etIdIdx == -1 || etAmtIdx == -1 || crRefIdx == -1 || crAmtIdx == -1) {
      throw const ReconciliationFailure('Required column headers missing across the 3 triangular datasets.');
    }

    final etMap = {
      for (final r in ebirrSettlementData.skip(1))
        if (r.length > etIdIdx) NormalizationUtil.normalize(r[etIdIdx]): r
    };

    final crMap = {
      for (final r in cbsReportData.skip(1))
        if (r.length > crRefIdx) _cleanReference(r[crRefIdx]): r
    };

    double totalMatchedAmount = 0.0;
    int matchedCount = 0;
    int unmatchedCount = 0;
    final List<Map<String, dynamic>> pairedRows = [];
    final List<Map<String, dynamic>> unmatchedList = [];

    for (final ecRow in ebirrCbsData.skip(1)) {
      if (ecRow.length <= ecRefIdx || ecRow.length <= ecThirdIdx || ecRow.length <= ecAmtIdx) continue;

      final String bankRef = _cleanReference(ecRow[ecRefIdx]);
      final String thirdRef = NormalizationUtil.normalize(ecRow[ecThirdIdx]);
      final double amt = NormalizationUtil.parseAmount(ecRow[ecAmtIdx]).abs();

      final etMatch = etMap[thirdRef];
      final crMatch = crMap[bankRef];

      final bool isEtValid = etMatch != null &&
          etMatch.length > etAmtIdx &&
          NormalizationUtil.amountsEqual(NormalizationUtil.parseAmount(etMatch[etAmtIdx]).abs(), amt);

      final bool isCrValid = crMatch != null &&
          crMatch.length > crAmtIdx &&
          NormalizationUtil.amountsEqual(NormalizationUtil.parseAmount(crMatch[crAmtIdx]).abs(), amt);

      final bool isFullyMatched = isEtValid && isCrValid;

      String statusLabel = 'OK';
      if (!isFullyMatched) {
        if (etMatch == null && crMatch == null) {
          statusLabel = 'MISSING_IN_BOTH';
        } else if (etMatch == null) {
          statusLabel = 'MISSING_IN_SETTLE';
        } else if (crMatch == null) {
          statusLabel = 'MISSING_IN_REPORT';
        } else {
          statusLabel = 'MISMATCH_AMOUNT';
        }
      }

      if (isFullyMatched) {
        totalMatchedAmount += amt;
        matchedCount++;
      } else {
        unmatchedCount++;
        unmatchedList.add({'reference': bankRef, 'amount': amt, 'status': statusLabel});
      }

      pairedRows.add({
        'isMatched': isFullyMatched,
        'statusLabel': statusLabel,
        'isEtValid': isEtValid,
        'isCrValid': isCrValid,
        'key': bankRef,
        'ecRow': ecRow,
        'etRow': etMatch,
        'crRow': crMatch,
      });
    }

    return IpsTriangularResult(
      pairedRows: pairedRows,
      ecHeaders: ecH,
      etHeaders: etH,
      crHeaders: crH,
      summary: IpsTriangularSummary(
        totalMatchedAmount: totalMatchedAmount,
        totalCount: pairedRows.length,
        matchedCount: matchedCount,
        unmatchedCount: unmatchedCount,
        unmatchedEc: unmatchedList,
      ),
    );
  }
}
