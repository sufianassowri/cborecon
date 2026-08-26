import '../entities/master_card_account.dart';
import '../entities/card_transaction.dart';

abstract class ReconciliationRepository {
  Future<List<MasterCardAccount>> fetchAllAccounts();
  Future<MasterCardAccount?> getAccountByClientId(String clientId);
  Future<bool> isFileAlreadyUploaded(String fileId);
  Future<bool> existsTransactionReference(String referenceId);
  Future<void> saveAccount(MasterCardAccount account);
  Future<void> saveBatchAccounts(List<MasterCardAccount> accounts);
  Future<void> saveBatchTransactions(List<CardTransaction> transactions);
}