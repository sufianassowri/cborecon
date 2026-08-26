enum IpsReconStatus { ok, missingInSettlement, missingInIps, mismatch }

class IpsTwoFileRow {
  final IpsReconStatus status;
  final String transferId;
  final Map<String, dynamic> ipsData;
  final Map<String, dynamic> settlementData;

  const IpsTwoFileRow({
    required this.status,
    required this.transferId,
    this.ipsData = const {},
    this.settlementData = const {},
  });

  String get statusLabel {
    switch (status) {
      case IpsReconStatus.ok:
        return 'OK';
      case IpsReconStatus.missingInSettlement:
        return 'MISSING_IN_SETTLE';
      case IpsReconStatus.missingInIps:
        return 'MISSING_IN_IPS';
      case IpsReconStatus.mismatch:
        return 'MISMATCH';
    }
  }
}

class IpsTriangularSummary {
  final double totalMatchedAmount;
  final int totalCount;
  final int matchedCount;
  final int unmatchedCount;
  final List<Map<String, dynamic>> unmatchedEc;

  const IpsTriangularSummary({
    this.totalMatchedAmount = 0.0,
    this.totalCount = 0,
    this.matchedCount = 0,
    this.unmatchedCount = 0,
    this.unmatchedEc = const [],
  });
}
