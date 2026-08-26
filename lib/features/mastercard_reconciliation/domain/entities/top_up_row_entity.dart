class TopUpRowEntity {
  final String clientId;
  final String pan;
  final double topUpAmount;

  const TopUpRowEntity({
    required this.clientId,
    required this.pan,
    required this.topUpAmount,
  });
}