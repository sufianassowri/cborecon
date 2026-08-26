import '../../domain/entities/master_card_account.dart';
import '../../domain/entities/card_transaction.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import '../datasources/reconciliation_back4app_datasource.dart';
import '../models/master_card_account_model.dart';
import '../models/card_transaction_model.dart';

class ReconciliationRepositoryImpl implements ReconciliationRepository {
  final ReconciliationBack4AppDataSource dataSource;

  ReconciliationRepositoryImpl(this.dataSource);

  @override
  Future<List<MasterCardAccount>> fetchAllAccounts() async {
    final results = await dataSource.fetchAll('MasterCardAccount');
    return results.map((e) => MasterCardAccountModel.fromParse(e)).toList();
  }

  @override
  Future<MasterCardAccount?> getAccountByClientId(String clientId) async {
    final parseObj = await dataSource.fetchByField(
        'MasterCardAccount', 'clientId', clientId);
    if (parseObj != null) return MasterCardAccountModel.fromParse(parseObj);
    return null;
  }

  @override
  Future<bool> isFileAlreadyUploaded(String fileId) async {
    final parseObj =
        await dataSource.fetchByField('CardTransaction', 'fileId', fileId);
    return parseObj != null;
  }

  @override
  Future<bool> existsTransactionReference(String referenceId) async {
    return await dataSource.existsTransactionReference(referenceId);
  }

  @override
  Future<void> saveAccount(MasterCardAccount account) async {
    // Look up existing objectId for upsert
    final existing = await dataSource.fetchByField(
        'MasterCardAccount', 'clientId', account.clientId);
    final model = MasterCardAccountModel(
      clientId: account.clientId,
      pan: account.pan,
      topupamount: account.topupamount,
      baseamount: account.baseamount,
      extraamount: account.extraamount,
      TotalUsed: account.TotalUsed,
      annualfee: account.annualfee,
      currentBalance: account.currentBalance,
      updatedAt: account.updatedAt,
    );
    await model.toParseObject(existing?.objectId).save();
  }

  @override
  Future<void> saveBatchAccounts(List<MasterCardAccount> accounts) async {
    for (var acc in accounts) {
      final existing = await dataSource.fetchByField(
          'MasterCardAccount', 'clientId', acc.clientId);
      final model = MasterCardAccountModel(
        clientId: acc.clientId,
        pan: acc.pan,
        topupamount: acc.topupamount,
        baseamount: acc.baseamount,
        extraamount: acc.extraamount,
        TotalUsed: acc.TotalUsed,
        annualfee: acc.annualfee,
        currentBalance: acc.currentBalance,
        updatedAt: acc.updatedAt,
      );
      await model.toParseObject(existing?.objectId).save();
    }
  }

  @override
  Future<void> saveBatchTransactions(List<CardTransaction> transactions) async {
    for (var t in transactions) {
      final model = CardTransactionModel(
        referenceId: t.referenceId,
        clientId: t.clientId,
        pan: t.pan,
        rawRecordType: t.rawRecordType,
        txnType: t.txnType,
        debitCredit: t.debitCredit,
        baseAmount: t.baseAmount,
        extraAmount: t.extraAmount,
        annualFeeAmount: t.annualFeeAmount,
        totalTransactionAmount: t.totalTransactionAmount,
        description: t.description,
        fileId: t.fileId,
        transactionDate: t.transactionDate,
      );
      await model.toParseObject().save();
    }
  }
}