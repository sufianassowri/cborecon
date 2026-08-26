import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_time_util.dart';
import '../../../../core/utils/normalization_util.dart';
import '../entities/reversal_models.dart';

class MatchReversalsWithToleranceUseCase {
  final double commissionLow;
  final double commissionHigh;
  final double amountEpsilon;

  const MatchReversalsWithToleranceUseCase({
    this.commissionLow = AppConstants.defaultCommissionLow,
    this.commissionHigh = AppConstants.defaultCommissionHigh,
    this.amountEpsilon = AppConstants.amountEpsilon,
  });

  ReversalMatchResult call(
    List<OutgoingTxn> outgoings,
    List<ReversalTxn> reversals,
  ) {
    final availableReversals = List<ReversalTxn>.from(reversals);
    final matchedPairs = <MatchedReversalPair>[];

    for (final outgoing in outgoings) {
      ReversalTxn? matchedRev;
      int? matchedIndex;

      // 1. Exact amount match on same date
      for (int i = 0; i < availableReversals.length; i++) {
        final rev = availableReversals[i];
        if (DateTimeUtil.isSameDate(outgoing.date, rev.date) &&
            NormalizationUtil.amountsEqual(outgoing.amount, rev.amount, epsilon: amountEpsilon)) {
          matchedRev = rev;
          matchedIndex = i;
          break;
        }
      }

      // 2. Commission tolerance match (0.46% - 0.60% interchange)
      if (matchedRev == null) {
        for (int i = 0; i < availableReversals.length; i++) {
          final rev = availableReversals[i];
          if (DateTimeUtil.isSameDate(outgoing.date, rev.date) &&
              _isInCommissionRange(outgoing.amount, rev.amount)) {
            matchedRev = rev;
            matchedIndex = i;
            break;
          }
        }
      }

      if (matchedRev != null && matchedIndex != null) {
        double? commission;
        if (!NormalizationUtil.amountsEqual(outgoing.amount, matchedRev.amount, epsilon: amountEpsilon)) {
          commission = (matchedRev.amount / outgoing.amount) - 1.0;
        }

        matchedPairs.add(MatchedReversalPair(
          outgoing: outgoing,
          reversal: matchedRev,
          commission: commission,
        ));
        availableReversals.removeAt(matchedIndex);
      }
    }

    final matchedFts = matchedPairs.map((p) => p.outgoing.ft).toSet();
    final unmatchedOutgoings = outgoings.where((o) => !matchedFts.contains(o.ft)).toList();

    return ReversalMatchResult(
      matchedPairs: matchedPairs,
      unmatchedOutgoings: unmatchedOutgoings,
      unmatchedReversals: availableReversals,
    );
  }

  bool _isInCommissionRange(double outgoingAmount, double reversalAmount) {
    if (reversalAmount < outgoingAmount) return false;
    final ratio = reversalAmount / outgoingAmount;
    final commission = ratio - 1.0;
    return commission >= commissionLow && commission <= commissionHigh;
  }
}
