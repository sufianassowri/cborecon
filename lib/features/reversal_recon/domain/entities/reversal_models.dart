class OutgoingTxn {
  final String ft;
  final DateTime date;
  final double amount;
  final String? account;
  final String? description;

  const OutgoingTxn({
    required this.ft,
    required this.date,
    required this.amount,
    this.account,
    this.description,
  });
}

class ReversalTxn {
  final String id;
  final DateTime date;
  final double amount;
  final String? reference;
  final String? account;

  const ReversalTxn({
    required this.id,
    required this.date,
    required this.amount,
    this.reference,
    this.account,
  });
}

class MatchedReversalPair {
  final OutgoingTxn outgoing;
  final ReversalTxn reversal;
  final double? commission; // Interchange commission percentage

  const MatchedReversalPair({
    required this.outgoing,
    required this.reversal,
    this.commission,
  });
}

class ReversalMatchResult {
  final List<MatchedReversalPair> matchedPairs;
  final List<OutgoingTxn> unmatchedOutgoings;
  final List<ReversalTxn> unmatchedReversals;

  const ReversalMatchResult({
    required this.matchedPairs,
    required this.unmatchedOutgoings,
    required this.unmatchedReversals,
  });
}
