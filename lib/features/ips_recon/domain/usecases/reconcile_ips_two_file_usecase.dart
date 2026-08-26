import '../../../../core/utils/normalization_util.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ips_recon_models.dart';

class ReconcileIpsTwoFileUseCase {
  List<IpsTwoFileRow> call({
    required List<List<dynamic>> ipsData,
    required List<List<dynamic>> settlementData,
  }) {
    if (ipsData.isEmpty || settlementData.isEmpty) return [];

    final List<String> ipsHeaders = ipsData[0].map((e) => e.toString().trim()).toList();
    final List<String> setHeaders = settlementData[0].map((e) => e.toString().trim()).toList();

    final int ipsIdIdx = ipsHeaders.indexOf('Bank TRANSFERID');
    final int setIdIdx = setHeaders.indexOf('IP Original transaction ID');

    if (ipsIdIdx == -1 || setIdIdx == -1) {
      throw const ReconciliationFailure("Missing key column 'Bank TRANSFERID' in IPS or 'IP Original transaction ID' in Settlement.");
    }

    final Map<String, List<dynamic>> ipsMap = {};
    final Map<String, List<dynamic>> setMap = {};

    for (final row in ipsData.skip(1)) {
      if (row.length > ipsIdIdx) {
        final id = NormalizationUtil.normalize(row[ipsIdIdx]);
        if (id.isNotEmpty) ipsMap[id] = row;
      }
    }

    for (final row in settlementData.skip(1)) {
      if (row.length > setIdIdx) {
        final id = NormalizationUtil.normalize(row[setIdIdx]);
        if (id.isNotEmpty) setMap[id] = row;
      }
    }

    final Set<String> allKeys = {...ipsMap.keys, ...setMap.keys};
    final List<IpsTwoFileRow> resultRows = [];

    for (final key in allKeys) {
      if (key.isEmpty) continue;

      final ipsRow = ipsMap[key];
      final setRow = setMap[key];

      IpsReconStatus status;
      if (ipsRow != null && setRow != null) {
        status = IpsReconStatus.ok;
      } else if (ipsRow != null) {
        status = IpsReconStatus.missingInSettlement;
      } else {
        status = IpsReconStatus.missingInIps;
      }

      final Map<String, dynamic> iData = {};
      if (ipsRow != null) {
        for (int i = 0; i < ipsHeaders.length; i++) {
          if (i < ipsRow.length) iData[ipsHeaders[i]] = ipsRow[i];
        }
      }

      final Map<String, dynamic> sData = {};
      if (setRow != null) {
        for (int i = 0; i < setHeaders.length; i++) {
          if (i < setRow.length) sData[setHeaders[i]] = setRow[i];
        }
      }

      resultRows.add(IpsTwoFileRow(
        status: status,
        transferId: key,
        ipsData: iData,
        settlementData: sData,
      ));
    }

    // Sort: Mismatches at the top
    resultRows.sort((a, b) {
      final bool aMismatch = a.status != IpsReconStatus.ok;
      final bool bMismatch = b.status != IpsReconStatus.ok;
      if (aMismatch && !bMismatch) return -1;
      if (!aMismatch && bMismatch) return 1;
      return a.transferId.compareTo(b.transferId);
    });

    return resultRows;
  }
}
