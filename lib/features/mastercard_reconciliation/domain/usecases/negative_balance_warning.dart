import '../entities/master_card_account.dart';
import '../entities/card_transaction.dart';

/// Represents a single client that would go into negative balance
/// after processing a TSV transaction.
class NegativeBalanceWarning {
  final String clientId;
  final String pan;
  final double currentBalance;
  final double projectedBalance;
  final double totalUsed;
  final double annualFee;
  final bool hasTopUp;

  /// Whether this is an MF (annual fee) transaction only.
  /// MF-only transactions are allowed to go negative without confirmation.
  final bool isAnnualFeeOnly;

  NegativeBalanceWarning({
    required this.clientId,
    required this.pan,
    required this.currentBalance,
    required this.projectedBalance,
    required this.totalUsed,
    required this.annualFee,
    required this.hasTopUp,
    this.isAnnualFeeOnly = false,
  });
}

/// Result of processing a Mastercard TSV file.
///
/// Contains warnings for clients that would go negative,
/// and pending data that can be saved after user confirmation.
class TsvProcessingResult {
  final bool isDuplicateFile;

  /// Clients with negative balance that need user confirmation (TX only).
  /// MF-only negative balances are auto-saved and excluded from warnings.
  final List<NegativeBalanceWarning> warnings;

  /// Accounts that are ready to be saved (positive balance or MF auto-approved).
  final List<MasterCardAccount> pendingAccounts;

  /// Transactions ready to be saved.
  final List<CardTransaction> pendingTransactions;

  /// Accounts for clients that need user confirmation before saving.
  final List<MasterCardAccount> warningAccounts;

  /// Transactions for clients that need user confirmation before saving.
  final List<CardTransaction> warningTransactions;

  TsvProcessingResult({
    this.isDuplicateFile = false,
    this.warnings = const [],
    this.pendingAccounts = const [],
    this.pendingTransactions = const [],
    this.warningAccounts = const [],
    this.warningTransactions = const [],
  });
}