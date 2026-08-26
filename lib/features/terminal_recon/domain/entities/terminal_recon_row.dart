enum TerminalReconStatus {
  ok,
  amountMismatch,
  missingInSettlement,
  missingInCbs,
  missing,
}

class TerminalReconRow {
  final TerminalReconStatus status;
  final String rrn;
  final Map<String, dynamic> cbsData;
  final Map<String, dynamic> settlementData;

  const TerminalReconRow({
    required this.status,
    required this.rrn,
    this.cbsData = const {},
    this.settlementData = const {},
  });

  String get statusLabel {
    switch (status) {
      case TerminalReconStatus.ok:
        return 'OK';
      case TerminalReconStatus.amountMismatch:
        return 'AMT_MISMATCH';
      case TerminalReconStatus.missingInSettlement:
        return 'MISSING_IN_SETTLE';
      case TerminalReconStatus.missingInCbs:
        return 'MISSING_IN_CBS';
      case TerminalReconStatus.missing:
        return 'MISSING';
    }
  }
}
