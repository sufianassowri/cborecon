import '../../../../core/utils/normalization_util.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mobile_recon_row.dart';

class ReconcileEbirrUseCase {
  List<MobileReconRow> call({
    required List<List<dynamic>> cbsData,
    required List<List<dynamic>> ebirrData,
  }) {
    if (cbsData.isEmpty || ebirrData.isEmpty) return [];

    final List<String> cbsHeaders = cbsData[0].map((e) => e.toString().trim()).toList();
    final List<String> ebirrHeaders = ebirrData[0].map((e) => e.toString().trim()).toList();

    final int cbsRefIdx = cbsHeaders.indexOf('THIRD_PARTY_REFERENCE');
    final int ebirrRefIdx = ebirrHeaders.indexOf('Bank TRANSFERID');

    if (cbsRefIdx == -1 || ebirrRefIdx == -1) {
      throw const ReconciliationFailure("Missing key columns: 'THIRD_PARTY_REFERENCE' in CBS or 'Bank TRANSFERID' in Ebirr.");
    }

    final Map<String, List<dynamic>> cbsMap = {};
    final Map<String, List<dynamic>> ebirrMap = {};

    for (final row in cbsData.skip(1)) {
      if (row.length > cbsRefIdx) {
        final key = NormalizationUtil.normalize(row[cbsRefIdx]);
        if (key.isNotEmpty) cbsMap[key] = row;
      }
    }

    for (final row in ebirrData.skip(1)) {
      if (row.length > ebirrRefIdx) {
        final key = NormalizationUtil.normalize(row[ebirrRefIdx]);
        if (key.isNotEmpty) ebirrMap[key] = row;
      }
    }

    final Set<String> allKeys = {...cbsMap.keys, ...ebirrMap.keys};
    final List<MobileReconRow> resultRows = [];

    for (final key in allKeys) {
      if (key.isEmpty) continue;

      final cbsRow = cbsMap[key];
      final ebirrRow = ebirrMap[key];

      MobileReconStatus status;
      if (cbsRow != null && ebirrRow != null) {
        status = MobileReconStatus.ok;
      } else if (cbsRow != null) {
        status = MobileReconStatus.missingInWallet;
      } else {
        status = MobileReconStatus.missingInCbs;
      }

      final Map<String, dynamic> cData = {};
      if (cbsRow != null) {
        for (int i = 0; i < cbsHeaders.length; i++) {
          if (i < cbsRow.length) cData[cbsHeaders[i]] = cbsRow[i];
        }
      }

      final Map<String, dynamic> wData = {};
      if (ebirrRow != null) {
        for (int i = 0; i < ebirrHeaders.length; i++) {
          if (i < ebirrRow.length) wData[ebirrHeaders[i]] = ebirrRow[i];
        }
      }

      resultRows.add(MobileReconRow(
        status: status,
        key: key,
        cbsData: cData,
        walletData: wData,
        rawCbsRow: cbsRow,
        rawWalletRow: ebirrRow,
      ));
    }

    // Sort: Mismatches at the top
    resultRows.sort((a, b) {
      final bool aMismatch = a.status != MobileReconStatus.ok;
      final bool bMismatch = b.status != MobileReconStatus.ok;
      if (aMismatch && !bMismatch) return -1;
      if (!aMismatch && bMismatch) return 1;
      return a.key.compareTo(b.key);
    });

    return resultRows;
  }
}
