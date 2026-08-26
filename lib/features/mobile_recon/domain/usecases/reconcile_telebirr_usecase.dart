import '../../../../core/utils/normalization_util.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mobile_recon_row.dart';

enum TelebirrMode { cashIn, cashOut }

class ReconcileTelebirrUseCase {
  List<MobileReconRow> call({
    required List<List<dynamic>> cbsData,
    required List<List<dynamic>> telebirrData,
    required TelebirrMode mode,
  }) {
    if (cbsData.isEmpty || telebirrData.isEmpty) return [];

    final List<String> cbsHeaders = cbsData[0].map((e) => e.toString().trim()).toList();
    final List<String> teleHeaders = telebirrData[0].map((e) => e.toString().trim()).toList();

    final String cbsTargetCol = mode == TelebirrMode.cashIn ? 'THIRD_PARTY_REFERENCE' : 'DESCRIPTION';
    const String teleTargetCol = 'ORDER_ID';

    final int cbsRefIdx = cbsHeaders.indexOf(cbsTargetCol);
    final int teleRefIdx = teleHeaders.indexOf(teleTargetCol);

    if (cbsRefIdx == -1 || teleRefIdx == -1) {
      throw ReconciliationFailure("Missing matching column '$cbsTargetCol' in CBS or '$teleTargetCol' in Telebirr.");
    }

    final Map<String, List<dynamic>> cbsMap = {};
    final Map<String, List<dynamic>> teleMap = {};

    for (final row in cbsData.skip(1)) {
      if (row.length > cbsRefIdx) {
        final key = NormalizationUtil.normalize(row[cbsRefIdx]);
        if (key.isNotEmpty) cbsMap[key] = row;
      }
    }

    for (final row in telebirrData.skip(1)) {
      if (row.length > teleRefIdx) {
        final key = NormalizationUtil.normalize(row[teleRefIdx]);
        if (key.isNotEmpty) teleMap[key] = row;
      }
    }

    final Set<String> allKeys = {...cbsMap.keys, ...teleMap.keys};
    final List<MobileReconRow> resultRows = [];

    for (final key in allKeys) {
      if (key.isEmpty) continue;

      final cbsRow = cbsMap[key];
      final teleRow = teleMap[key];

      MobileReconStatus status;
      if (cbsRow != null && teleRow != null) {
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
      if (teleRow != null) {
        for (int i = 0; i < teleHeaders.length; i++) {
          if (i < teleRow.length) wData[teleHeaders[i]] = teleRow[i];
        }
      }

      resultRows.add(MobileReconRow(
        status: status,
        key: key,
        cbsData: cData,
        walletData: wData,
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
