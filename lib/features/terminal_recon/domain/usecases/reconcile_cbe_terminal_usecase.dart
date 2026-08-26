import '../../../../core/utils/normalization_util.dart';
import '../../../../core/utils/pan_masker_util.dart';
import '../../../../core/errors/failures.dart';
import '../entities/terminal_recon_row.dart';
class ReconcileCbeTerminalUseCase {
  List<TerminalReconRow> call({
    required List<List<dynamic>> cbsData,
    required List<List<dynamic>> settlementData,
  }) {
    if (cbsData.isEmpty || settlementData.isEmpty) return [];
    final List<String> cbsHeaders = cbsData[0].map((e) => e.toString().trim()).toList();
    final List<String> setHeaders = settlementData[0].map((e) => e.toString().trim()).toList();
    final int cbsRrnIdx = cbsHeaders.indexWhere((h) => h.toUpperCase().contains('RETRIEVAL.REF.NO') || h.toUpperCase().contains('RRN'));
    final int cbsAmtIdx = cbsHeaders.indexWhere((h) => h.toUpperCase().contains('TXN.AMOUNT'));
    final int cbsPanIdx = cbsHeaders.indexWhere((h) => h.toUpperCase().contains('PAN.NUMBER') || h.toUpperCase().contains('PAN'));
    final int setRrnIdx = setHeaders.indexWhere((h) => h.toUpperCase().contains('REFNUM_F37') || h.toUpperCase().contains('RRN'));
    final int setAmtIdx = setHeaders.indexWhere((h) => h.toUpperCase().contains('AMOUNT'));
    final int setPanIdx = setHeaders.indexWhere((h) => h.toUpperCase().contains('CARD_NUMBER') || h.toUpperCase().contains('PAN'));

    if (cbsRrnIdx == -1 || setRrnIdx == -1) {
      throw const ReconciliationFailure('RRN column missing in CBE reconciliation datasets.');
    }
    final Map<String, List<dynamic>> cbsMap = {};
    for (final row in cbsData.skip(1)) {
      if (row.length > cbsRrnIdx) {
        final rrn = NormalizationUtil.normalize(row[cbsRrnIdx]);
        if (rrn.isNotEmpty) cbsMap[rrn] = row;
      }
    }

    final Map<String, List<dynamic>> setMap = {};
    for (final row in settlementData.skip(1)) {
      if (row.length > setRrnIdx) {
        final rrn = NormalizationUtil.normalize(row[setRrnIdx]);
        if (rrn.isNotEmpty) setMap[rrn] = row;
      }
    }
    final Set<String> allRrns = {...cbsMap.keys, ...setMap.keys};
    final List<TerminalReconRow> resultRows = [];

    for (final rrn in allRrns) {
      if (rrn.isEmpty) continue;

      final cbsRow = cbsMap[rrn];
      final setRow = setMap[rrn];

      TerminalReconStatus status;
      if (cbsRow != null && setRow != null) {
        // Compare Amount & PAN
        bool isOk = true;
        if (cbsAmtIdx != -1 && setAmtIdx != -1 && cbsRow.length > cbsAmtIdx && setRow.length > setAmtIdx) {
          final cAmt = NormalizationUtil.normalize(cbsRow[cbsAmtIdx]);
          final sAmt = NormalizationUtil.normalize(setRow[setAmtIdx]);
          if (cAmt.isNotEmpty && sAmt.isNotEmpty && cAmt != sAmt) {
            isOk = false;
          }
        }
        if (cbsPanIdx != -1 && setPanIdx != -1 && cbsRow.length > cbsPanIdx && setRow.length > setPanIdx) {
          final cPan = PanMaskerUtil.mask(cbsRow[cbsPanIdx]?.toString() ?? '');
          final sPan = PanMaskerUtil.mask(setRow[setPanIdx]?.toString() ?? '');
          if (cPan.isNotEmpty && sPan.isNotEmpty && cPan != sPan) {
            isOk = false;
          }
        }
        status = isOk ? TerminalReconStatus.ok : TerminalReconStatus.amountMismatch;
      } else if (cbsRow != null && setRow == null) {
        status = TerminalReconStatus.missingInSettlement;
      } else {
        status = TerminalReconStatus.missingInCbs;
      }
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
