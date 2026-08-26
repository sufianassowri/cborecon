class MasterCardAccount {
  final String clientId;
  final String pan;
  final double topupamount;
  final double baseamount;
  final double extraamount;
  final double TotalUsed;
  final double annualfee;
  final double currentBalance;
  final DateTime updatedAt;

  const MasterCardAccount({
    required this.clientId,
    required this.pan,
    required this.topupamount,
    this.baseamount = 0.0,
    this.extraamount = 0.0,
    this.annualfee = 0.0,
    this.TotalUsed = 0.0,
    required this.currentBalance,
    required this.updatedAt,
  });

  double get totalTopUp => topupamount;
  double get baseAmount => baseamount;
  double get extraAmount => extraamount;
  double get totalUsed => TotalUsed;

  MasterCardAccount copyWith({
    String? clientId,
    String? pan,
    double? topupamount,
    double? baseamount,
    double? extraamount,
    double? annualfee,
    double? annualfeeAndTotalUsed,
    double? currentBalance,
    DateTime? updatedAt,
  }) {
    return MasterCardAccount(
      clientId: clientId ?? this.clientId,
      pan: pan ?? this.pan,
      topupamount: topupamount ?? this.topupamount,
      baseamount: baseamount ?? this.baseamount,
      extraamount: extraamount ?? this.extraamount,
      annualfee: annualfee ?? this.annualfee,
      TotalUsed: annualfeeAndTotalUsed ?? this.TotalUsed,
      currentBalance: currentBalance ?? this.currentBalance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}