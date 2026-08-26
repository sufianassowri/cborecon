enum MobileReconStatus { ok, mismatch, missingInWallet, missingInCbs }

class MobileReconRow {
  final MobileReconStatus status;
  final String key;
  final Map<String, dynamic> cbsData;
  final Map<String, dynamic> walletData;
  final List<dynamic>? rawCbsRow;
  final List<dynamic>? rawWalletRow;

  const MobileReconRow({
    required this.status,
    required this.key,
    this.cbsData = const {},
    this.walletData = const {},
    this.rawCbsRow,
    this.rawWalletRow,
  });

  String get statusLabel {
    switch (status) {
      case MobileReconStatus.ok:
        return 'OK';
      case MobileReconStatus.mismatch:
        return 'MISMATCH';
      case MobileReconStatus.missingInWallet:
        return 'MISSING_IN_WALLET';
      case MobileReconStatus.missingInCbs:
        return 'MISSING_IN_CBS';
    }
  }
}
