import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/master_card_account_model.dart';
import '../models/card_transaction_model.dart';

/// Back4App (Parse Server) data source for MasterCard reconciliation.
///
/// Provides CRUD operations for `MasterCardAccount` and `CardTransaction` tables.
class ReconciliationBack4AppDataSource {
  /// Fetch all records from a given Back4App class name.
  Future<List<ParseObject>> fetchAll(String className) async {
    final query = QueryBuilder<ParseObject>(ParseObject(className))
      ..orderByDescending('updatedAt')
      ..setLimit(1000);
    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results as List<ParseObject>;
    }
    return [];
  }

  /// Fetch a single record by a specific field value.
  Future<ParseObject?> fetchByField(
      String className, String field, String value) async {
    final query = QueryBuilder<ParseObject>(ParseObject(className))
      ..whereEqualTo(field, value);
    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return response.results!.first as ParseObject;
    }
    return null;
  }

  /// Check if a transaction with the given composite reference_id already exists.
  ///
  /// Used for deduplication: `referenceId = RecordType + "_" + SettlementItemId`
  Future<bool> existsTransactionReference(String referenceId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('CardTransaction'))
      ..whereEqualTo('referenceId', referenceId)
      ..setLimit(1);
    final response = await query.query();
    return response.success &&
        response.results != null &&
        response.results!.isNotEmpty;
  }

  /// Save a single MasterCardAccount (upsert by objectId if present).
  Future<void> saveAccount(MasterCardAccountModel account,
      [String? objectId]) async {
    await account.toParseObject(objectId).save();
  }

  /// Save a single CardTransaction.
  Future<void> saveTransaction(CardTransactionModel transaction) async {
    await transaction.toParseObject().save();
  }

  /// Save a list of ParseObjects in batches of 40 for rate-limiting.
  Future<void> saveBatch(List<ParseObject> objects) async {
    for (var i = 0; i < objects.length; i += 40) {
      final end = (i + 40 < objects.length) ? i + 40 : objects.length;
      final chunk = objects.sublist(i, end);
      await Future.wait(chunk.map((obj) => obj.save()));
    }
  }
}