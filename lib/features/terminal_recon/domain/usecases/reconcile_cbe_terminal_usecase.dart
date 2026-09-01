import '../../../../core/utils/normalization_util.dart';
import '../../../../core/errors/failures.dart';
import '../entities/terminal_recon_row.dart';

class ReconcileCbeTerminalUseCase {
  List<TerminalReconRow> call({
    required List<List<dynamic>> cbsData,
    required List<List<dynamic>> settlementData,
  }) {
    if (cbsData.isEmpty || settlementData.isEmpty) return [];
    final List<String> cbsHeaders =
        cbsData[0].map((e) => e.toString().trim()).toList();
    final List<String> setHeaders =
        settlementData[0].map((e) => e.toString().trim()).toList();
    final int cbsRrnIdx = cbsHeaders.indexWhere((h) =>
        h.toUpperCase().contains('RETRIEVAL.REF.NO') ||
        h.toUpperCase().contains('RRN'));
    final int cbsAmtIdx =
        cbsHeaders.indexWhere((h) => h.toUpperCase().contains('TXN.AMOUNT'));
    final int cbsPanIdx = cbsHeaders.indexWhere((h) =>
        h.toUpperCase().contains('PAN.NUMBER') ||
        h.toUpperCase().contains('PAN'));
    final int setRrnIdx = setHeaders.indexWhere((h) =>
        h.toUpperCase().contains('REFNUM_F37') ||
        h.toUpperCase().contains('RRN'));
    final int setAmtIdx =
        setHeaders.indexWhere((h) => h.toUpperCase().contains('AMOUNT'));
    final int setPanIdx = setHeaders.indexWhere((h) =>
        h.toUpperCase().contains('CARD_NUMBER') ||
        h.toUpperCase().contains('PAN'));

    if (cbsRrnIdx == -1 || setRrnIdx == -1) {
      throw const ReconciliationFailure(
          'RRN column missing in CBE reconciliation datasets.');
    }
    final Map<String, List<List<dynamic>>> cbsMap = {};
    for (final row in cbsData.skip(1)) {
      if (row.length > cbsRrnIdx) {
        final rrn = NormalizationUtil.normalize(row[cbsRrnIdx]);
        if (rrn.isNotEmpty) {
          cbsMap.putIfAbsent(rrn, () => []).add(row);
        }
      }
    }

    final Map<String, List<List<dynamic>>> setMap = {};
    for (final row in settlementData.skip(1)) {
      if (row.length > setRrnIdx) {
        final rrn = NormalizationUtil.normalize(row[setRrnIdx]);
        if (rrn.isNotEmpty) {
          setMap.putIfAbsent(rrn, () => []).add(row);
        }
      }
    }
    final Set<String> allRrns = {...cbsMap.keys, ...setMap.keys};
    final List<TerminalReconRow> resultRows = [];

    void addResultRow(
      String rrn,
      TerminalReconStatus status,
      List<dynamic>? cbsRow,
      List<dynamic>? setRow,
    ) {
      final Map<String, dynamic> cbsMapData = {};
      if (cbsRow != null) {
        for (int i = 0; i < cbsHeaders.length; i++) {
          if (i < cbsRow.length) cbsMapData[cbsHeaders[i]] = cbsRow[i];
        }
      }
      final Map<String, dynamic> setMapData = {};
      if (setRow != null) {
        for (int i = 0; i < setHeaders.length; i++) {
          if (i < setRow.length) setMapData[setHeaders[i]] = setRow[i];
        }
      }
      resultRows.add(TerminalReconRow(
        status: status,
        rrn: rrn,
        cbsData: cbsMapData,
        settlementData: setMapData,
      ));
    }

    for (final rrn in allRrns) {
      if (rrn.isEmpty) continue;

      final List<List<dynamic>> cbsRows = cbsMap[rrn] ?? [];
      final List<List<dynamic>> setRows = setMap[rrn] ?? [];

      final List<List<dynamic>> unmatchedCbsRows = [];
      final List<List<dynamic>> unmatchedSetRows = List.from(setRows);

      for (final cRow in cbsRows) {
        bool matched = false;
        if (cbsAmtIdx != -1 && setAmtIdx != -1 && cRow.length > cbsAmtIdx) {
          final double cAmt = NormalizationUtil.parseAmount(cRow[cbsAmtIdx]);
          
          int matchIdx = -1;
          for (int i = 0; i < unmatchedSetRows.length; i++) {
            final sRow = unmatchedSetRows[i];
            if (sRow.length > setAmtIdx) {
              final double sAmt = NormalizationUtil.parseAmount(sRow[setAmtIdx]);
              if (NormalizationUtil.amountsEqual(cAmt, sAmt)) {
                matchIdx = i;
                break;
              }
            }
          }
          if (matchIdx != -1) {
            final sRow = unmatchedSetRows.removeAt(matchIdx);
            addResultRow(rrn, TerminalReconStatus.ok, cRow, sRow);
            matched = true;
          }
        }
        
        // If amount parsing fails or no match found by amount, we keep it as unmatched
        if (!matched) {
          unmatchedCbsRows.add(cRow);
        }
      }

      int i = 0;
      while (i < unmatchedCbsRows.length && i < unmatchedSetRows.length) {
        addResultRow(rrn, TerminalReconStatus.amountMismatch, unmatchedCbsRows[i], unmatchedSetRows[i]);
        i++;
      }

      while (i < unmatchedCbsRows.length) {
        addResultRow(rrn, TerminalReconStatus.missingInSettlement, unmatchedCbsRows[i], null);
        i++;
      }

      for (int j = i; j < unmatchedSetRows.length; j++) {
        addResultRow(rrn, TerminalReconStatus.missingInCbs, null, unmatchedSetRows[j]);
      }
    }

    // Sort: Exceptions at top
    resultRows.sort((a, b) {
      final bool aMissing = a.status != TerminalReconStatus.ok;
      final bool bMissing = b.status != TerminalReconStatus.ok;

      if (aMissing && !bMissing) return -1;
      if (!aMissing && bMissing) return 1;
      return a.rrn.compareTo(b.rrn);
    });

    return resultRows;
  }
}
