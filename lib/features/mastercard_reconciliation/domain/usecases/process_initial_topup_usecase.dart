import '../entities/master_card_account.dart';
import '../entities/card_transaction.dart';
import '../repositories/reconciliation_repository.dart';

/// Processes initial TopUp uploads (Excel/CSV).
///
/// For each row:
/// - If client is new: creates account with topupamount = deposit, currentBalance = deposit
/// - If client exists: adds deposit to topupamount, recalculates currentBalance
/// - Creates a TOPUP ledger entry in CardTransaction
class ProcessInitialTopupUseCase {
  final ReconciliationRepository repository;

  ProcessInitialTopupUseCase(this.repository);

  Future<void> execute(List<Map<String, dynamic>> topUpRows,
      {required String fileId}) async {
    final List<MasterCardAccount> accountUpdates = [];
    final List<CardTransaction> ledgerTransactions = [];
    for (int i = 0; i < topUpRows.length; i++) {
      final row = topUpRows[i];
      final String clientId = row['clientId'] ?? '';
      final String pan = row['pan'] ?? '';
      final double depositAmount =
          (row['topUpAmount'] as num?)?.toDouble() ?? 0.0;

      if (clientId.isEmpty || pan.isEmpty) continue;

      final existingAccount =
          await repository.getAccountByClientId(clientId);

      if (existingAccount != null) {
        // Existing client: add deposit to topupamount
        final newTotalTopUp = existingAccount.topupamount + depositAmount;
        // currentBalance = totalTopUp - totalUsed
        final newBalance = newTotalTopUp - existingAccount.TotalUsed;

        accountUpdates.add(existingAccount.copyWith(
          topupamount: newTotalTopUp,
          currentBalance: newBalance,
          updatedAt: DateTime.now(),
        ));
      } else {
        // New client: create fresh account
        accountUpdates.add(MasterCardAccount(
          clientId: clientId,
          pan: pan,
          topupamount: depositAmount,
          currentBalance: depositAmount,
          updatedAt: DateTime.now(),
        ));
      }

      // Create immutable TOPUP ledger entry
      final refId =
          'TOPUP_${clientId}_${DateTime.now().millisecondsSinceEpoch}_$i';
      ledgerTransactions.add(CardTransaction(
        referenceId: refId,
        clientId: clientId,
        pan: pan,
        rawRecordType: 'TOPUP',
        txnType: TransactionType.topup,
        debitCredit: DebitCredit.credit,
        baseAmount: 0.0,
        extraAmount: 0.0,
        annualFeeAmount: 0.0,
        totalTransactionAmount: depositAmount,
        description: 'Card TopUp Deposit',
        fileId: fileId,
        transactionDate: DateTime.now(),
      ));
    }

    if (accountUpdates.isNotEmpty) {
      await repository.saveBatchAccounts(accountUpdates);
    }
    if (ledgerTransactions.isNotEmpty) {
      await repository.saveBatchTransactions(ledgerTransactions);
    }
  }
}