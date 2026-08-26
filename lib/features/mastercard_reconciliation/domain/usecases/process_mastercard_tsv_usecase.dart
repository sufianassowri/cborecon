import '../entities/card_transaction.dart';
import '../entities/master_card_account.dart';
import '../repositories/reconciliation_repository.dart';
import 'negative_balance_warning.dart';

/// Core business logic for processing Mastercard TSV settlement files.
///
/// For each TSV row:
/// 1. Forms composite reference_id = RecordType + "_" + SettlementItemId
/// 2. Checks deduplication — skips if reference_id already exists
/// 3. Computes totalTransactionAmount per D/C formula:
///    - D (Debit):  totalUsed += baseAmount + extraAmount + annualFee
///    - C (Credit): totalUsed -= (baseAmount - extraAmount + annualFee)
/// 4. Updates or creates MasterCardAccount with new balances
/// 5. Separates results into auto-approved (positive balance + MF-only negatives)
///    vs user-confirmation-needed (TX negatives)
class ProcessMasterCardTsvUseCase {
  final ReconciliationRepository repository;

  ProcessMasterCardTsvUseCase(this.repository);

  Future<TsvProcessingResult> execute(
    List<Map<String, dynamic>> parsedTsvRows, {
    String? fileId,
  }) async {
    if (fileId != null && await repository.isFileAlreadyUploaded(fileId)) {
      return TsvProcessingResult(isDuplicateFile: true);
    }

    // Track running account state in memory for multi-row aggregation
    final Map<String, MasterCardAccount> accountCache = {};

    // Collections for results
    final List<MasterCardAccount> autoApprovedAccounts = [];
    final List<CardTransaction> autoApprovedTransactions = [];
    final List<MasterCardAccount> warningAccounts = [];
    final List<CardTransaction> warningTransactions = [];
    final List<NegativeBalanceWarning> warnings = [];

    for (final row in parsedTsvRows) {
      final String recordType = row['recordType'] ?? '';
      final String settlementItemId = row['settlementItemId'] ?? '';

      if (settlementItemId.isEmpty) continue;

      // 1. Form composite primary key
      final referenceId = '${recordType}_$settlementItemId';

      // 2. Deduplication check
      final isDuplicate =
          await repository.existsTransactionReference(referenceId);
      if (isDuplicate) continue;

      final String clientId = row['clientId'] ?? '';
      final String pan = row['pan'] ?? '';
      final String debitCredit = row['debitCredit'] ?? 'D';
      final double baseAmount =
          (row['baseAmount'] as num?)?.toDouble() ?? 0.0;
      final double extraAmount =
          (row['extraAmount'] as num?)?.toDouble() ?? 0.0;
      final double annualFeeAmount =
          (row['annualFeeAmount'] as num?)?.toDouble() ?? 0.0;
      final String description = row['description'] ?? '';
      final String transactionDate = row['transactionDate'] ?? '';

      if (clientId.isEmpty) continue;

      // 3. Compute total transaction amount
      double totalTransactionAmount;
      if (debitCredit == 'D') {
        totalTransactionAmount = baseAmount + extraAmount + annualFeeAmount;
      } else {
        // Credit: baseAmount - extraAmount + annualFee
        totalTransactionAmount = baseAmount - extraAmount + annualFeeAmount;
        if (totalTransactionAmount < 0) {
          totalTransactionAmount = totalTransactionAmount.abs();
        }
      }

      // 4. Get or create account (check cache first, then DB)
      MasterCardAccount? account = accountCache[clientId];
      account ??= await repository.getAccountByClientId(clientId);

      bool isNewAccount = false;
      if (account == null) {
        // New client not in DB — create with topupamount=0
        isNewAccount = true;
        account = MasterCardAccount(
          clientId: clientId,
          pan: pan,
          topupamount: 0.0,
          currentBalance: 0.0,
          updatedAt: DateTime.now(),
        );
      }

      // 5. Update account balances
      double newTotalUsed = account.TotalUsed;
      double newBaseAmount = account.baseamount;
      double newExtraAmount = account.extraamount;
      double newAnnualFee = account.annualfee;

      // Accumulate per-field amounts
      newBaseAmount += baseAmount;
      newExtraAmount += extraAmount;
      newAnnualFee += annualFeeAmount;

      if (debitCredit == 'D') {
        newTotalUsed += totalTransactionAmount;
      } else {
        newTotalUsed -= totalTransactionAmount;
      }

      final newCurrentBalance = account.topupamount - newTotalUsed;

      final updatedAccount = account.copyWith(
        pan: pan.isNotEmpty ? pan : null,
        baseamount: newBaseAmount,
        extraamount: newExtraAmount,
        annualfee: newAnnualFee,
        annualfeeAndTotalUsed: newTotalUsed,
        currentBalance: newCurrentBalance,
        updatedAt: DateTime.now(),
      );

      // Cache the updated account for subsequent rows of same client
      accountCache[clientId] = updatedAccount;

      // Create ledger transaction
      final transaction = CardTransaction(
        referenceId: referenceId,
        clientId: clientId,
        pan: pan,
        rawRecordType: recordType,
        txnType: TransactionType.spend,
        debitCredit:
            debitCredit == 'C' ? DebitCredit.credit : DebitCredit.debit,
        baseAmount: baseAmount,
        extraAmount: extraAmount,
        annualFeeAmount: annualFeeAmount,
        totalTransactionAmount: totalTransactionAmount,
        description: description,
        fileId: fileId,
        transactionDate: DateTime.tryParse(transactionDate) ?? DateTime.now(),
      );

      // 6. Classify: auto-approve or needs user confirmation
      if (newCurrentBalance < 0) {
        final bool isMfOnly = recordType == 'MF';

        if (isMfOnly) {
          // Annual fee can go negative — auto-approve silently
          autoApprovedAccounts.add(updatedAccount);
          autoApprovedTransactions.add(transaction);
        } else if (isNewAccount && account.topupamount == 0.0) {
          // TX with no top-up ever — needs confirmation
          warnings.add(NegativeBalanceWarning(
            clientId: clientId,
            pan: pan,
            currentBalance: 0.0,
            projectedBalance: newCurrentBalance,
            totalUsed: newTotalUsed,
            annualFee: newAnnualFee,
            hasTopUp: false,
          ));
          warningAccounts.add(updatedAccount);
          warningTransactions.add(transaction);
        } else {
          // TX with insufficient balance — needs confirmation
          warnings.add(NegativeBalanceWarning(
            clientId: clientId,
            pan: pan,
            currentBalance: account.currentBalance,
            projectedBalance: newCurrentBalance,
            totalUsed: newTotalUsed,
            annualFee: newAnnualFee,
            hasTopUp: account.topupamount > 0,
          ));
          warningAccounts.add(updatedAccount);
          warningTransactions.add(transaction);
        }
      } else {
        autoApprovedAccounts.add(updatedAccount);
        autoApprovedTransactions.add(transaction);
      }
    }

    // Deduplicate accounts (keep latest per clientId)
    final Map<String, MasterCardAccount> dedupedAutoAccounts = {};
    for (final acc in autoApprovedAccounts) {
      dedupedAutoAccounts[acc.clientId] = acc;
    }
    final Map<String, MasterCardAccount> dedupedWarningAccounts = {};
    for (final acc in warningAccounts) {
      dedupedWarningAccounts[acc.clientId] = acc;
    }

    // Auto-save the auto-approved items immediately
    if (dedupedAutoAccounts.isNotEmpty) {
      await repository
          .saveBatchAccounts(dedupedAutoAccounts.values.toList());
    }
    if (autoApprovedTransactions.isNotEmpty) {
      await repository.saveBatchTransactions(autoApprovedTransactions);
    }

    if (warnings.isEmpty) {
      return TsvProcessingResult(
        pendingAccounts: dedupedAutoAccounts.values.toList(),
        pendingTransactions: autoApprovedTransactions,
      );
    }

    // Deduplicate warnings by clientId (keep latest projection)
    final Map<String, NegativeBalanceWarning> dedupedWarnings = {};
    for (final w in warnings) {
      dedupedWarnings[w.clientId] = w;
    }

    return TsvProcessingResult(
      warnings: dedupedWarnings.values.toList(),
      pendingAccounts: dedupedAutoAccounts.values.toList(),
      pendingTransactions: autoApprovedTransactions,
      warningAccounts: dedupedWarningAccounts.values.toList(),
      warningTransactions: warningTransactions,
    );
  }
}