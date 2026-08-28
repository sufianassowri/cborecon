import 'package:flutter/foundation.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../model/dispute_batch_model.dart';
import '../model/transaction_model.dart';

class DisputeRepositoryImpl {
  static const String tableBatch = 'DisputeBatch';
  static const String tableTrxn = 'DisputeTrxn';

  /// Save a complete dispute batch and all its child transactions to Back4App
  Future<DisputeBatch> uploadDisputeBatch({
    required DisputeBatch batch,
    required List<DisputeTrxn> items,
    Function(int current, int total)? onProgress,
  }) async {
    // 1. Save the Batch Header Record
    final batchObject = ParseObject(tableBatch)
      ..set('batchNumber', batch.batchNumber)
      ..set('fileName', batch.fileName)
      ..set('transactionCount', batch.transactionCount)
      ..set('totalDebitAmount', batch.totalDebitAmount)
      ..set('totalCreditAmount', batch.totalCreditAmount)
      ..set('isBalanced', batch.isBalanced)
      ..set('status', 'NEW')
      ..set('madeBy', batch.madeBy)
      ..set('madeAt', batch.madeAt);

    final batchResponse = await batchObject.save();
    if (!batchResponse.success) {
      throw Exception(batchResponse.error?.message ?? 'Failed to save DisputeBatch');
    }

    final savedBatchObjectId = batchResponse.result.objectId as String?;
    final savedBatch = batch.copyWith(objectId: savedBatchObjectId);

    // 2. Save Child Transactions in Batches of 50 for optimal performance
    const int chunkSize = 50;
    for (int i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(
        i,
        (i + chunkSize > items.length) ? items.length : i + chunkSize,
      );

      final List<ParseObject> parseObjects = chunk.map((item) {
        return ParseObject(tableTrxn)
          ..set('batchId', savedBatchObjectId ?? batch.batchNumber)
          ..set('batchNumber', batch.batchNumber)
          ..set('transactionId', item.transactionId)
          ..set('debitAcc', item.debitAcc)
          ..set('creditAcc', item.creditAcc)
          ..set('type', item.type)
          ..set('amount', item.amount)
          ..set('txnCode', item.txnCode)
          ..set('narrative1', item.narrative1)
          ..set('narrative2', item.narrative2)
          ..set('valueDate', item.valueDate)
          ..set('recordStatus', item.recordStatus)
          ..set('currency', item.currency)
          ..set('positionType', item.positionType)
          ..set('customer', item.customer)
          ..set('name', item.name)
          ..set('category', item.category)
          ..set('accountOfficer', item.accountOfficer)
          ..set('ourReference', item.ourReference);
      }).toList();

      for (var obj in parseObjects) {
        await obj.save();
      }

      if (onProgress != null) {
        onProgress(i + chunk.length, items.length);
      }
    }

    return savedBatch;
  }

  /// Fetch batches with optional filters
  Future<List<DisputeBatch>> fetchBatches({
    String? status,
    String? assignedTo,
    String? madeBy,
    int limit = 100,
  }) async {
    final query = QueryBuilder<ParseObject>(ParseObject(tableBatch))
      ..orderByDescending('createdAt')
      ..setLimit(limit);

    if (status != null && status.isNotEmpty && status != 'ALL') {
      query.whereEqualTo('status', status);
    }
    if (assignedTo != null && assignedTo.isNotEmpty) {
      query.whereEqualTo('assignedTo', assignedTo);
    }
    if (madeBy != null && madeBy.isNotEmpty) {
      query.whereEqualTo('madeBy', madeBy);
    }

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.map((e) {
        final json = e.toJson();
        json['objectId'] = e.objectId;
        json['createdAt'] = e.createdAt;
        json['updatedAt'] = e.updatedAt;
        return DisputeBatch.fromJson(json);
      }).toList();
    }
    return [];
  }

  /// Fetch all individual line-item transactions belonging to a batch
  Future<List<DisputeTrxn>> fetchBatchTransactions({
    required String batchIdOrNumber,
    int limit = 1000,
  }) async {
    // Query either by batchId or batchNumber
    final query1 = QueryBuilder<ParseObject>(ParseObject(tableTrxn))..whereEqualTo('batchId', batchIdOrNumber);
    final query2 = QueryBuilder<ParseObject>(ParseObject(tableTrxn))..whereEqualTo('batchNumber', batchIdOrNumber);
    
    final mainQuery = QueryBuilder.or(ParseObject(tableTrxn), [query1, query2])
      ..setLimit(limit)
      ..orderByAscending('transactionId');

    final response = await mainQuery.query();
    if (response.success && response.results != null) {
      return response.results!.map((e) {
        final json = e.toJson();
        json['objectId'] = e.objectId;
        return DisputeTrxn.fromJson(json);
      }).toList();
    }
    return [];
  }

  /// Manager Action: Assign batch to a Checker
  Future<void> assignBatch({
    required String batchObjectId,
    required String checkerUsername,
    required String managerUsername,
  }) async {
    final now = DateTime.now();
    final parseObject = ParseObject(tableBatch)
      ..objectId = batchObjectId
      ..set('assignedTo', checkerUsername)
      ..set('assignedBy', managerUsername)
      ..set('assignedAt', now)
      ..set('status', 'ASSIGNED');

    final response = await parseObject.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to assign batch to checker');
    }
  }

  /// Checker Action: Authorize / Approve a batch
  Future<void> authorizeBatch({
    required String batchObjectId,
    required String checkerUsername,
  }) async {
    final now = DateTime.now();
    final parseObject = ParseObject(tableBatch)
      ..objectId = batchObjectId
      ..set('authorizedBy', checkerUsername)
      ..set('authorizedAt', now)
      ..set('status', 'AUTHORIZED');

    final response = await parseObject.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to authorize batch');
    }

    // Also update child transactions status to AUTH
    _updateBatchItemsStatus(batchObjectId, 'AUTH');
  }

  /// Checker Action: Reject / Send Back with Correction Comment
  Future<void> rejectBatch({
    required String batchObjectId,
    required String checkerUsername,
    required String comment,
  }) async {
    final now = DateTime.now();
    final parseObject = ParseObject(tableBatch)
      ..objectId = batchObjectId
      ..set('rejectedBy', checkerUsername)
      ..set('rejectedAt', now)
      ..set('checkerComment', comment)
      ..set('status', 'REJECTED');

    final response = await parseObject.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to reject batch');
    }

    // Also update child transactions status to REJ
    _updateBatchItemsStatus(batchObjectId, 'REJ');
  }

  Future<void> _updateBatchItemsStatus(String batchId, String newStatus) async {
    try {
      final items = await fetchBatchTransactions(batchIdOrNumber: batchId);
      for (var item in items) {
        if (item.objectId != null) {
          final obj = ParseObject(tableTrxn)
            ..objectId = item.objectId
            ..set('recordStatus', newStatus);
          await obj.save();
        }
      }
    } catch (e) {
      debugPrint("Error updating item statuses: $e");
    }
  }

  /// Fetch list of available Checkers
  Future<List<String>> fetchCheckersList() async {
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
        ..setLimit(50);
      final response = await query.query();
      if (response.success && response.results != null) {
        final users = response.results as List<dynamic>;
        final checkers = users
            .where((u) {
              final role = u.get('role')?.toString().toLowerCase() ?? '';
              return role.contains('checker') || role.contains('supervisor') || role.contains('admin') || role.isEmpty;
            })
            .map((u) => u.get('username')?.toString() ?? '')
            .where((u) => u.isNotEmpty)
            .toList();

        if (checkers.isNotEmpty) return checkers;
      }
    } catch (e) {
      debugPrint("Error fetching checkers: $e");
    }

    // Fallback default system checkers if empty/offline
    return ['Checker_Supervisor_1', 'Checker_Officer_2', 'Sufian_Checker', 'CBO_Dispute_Checker'];
  }

  /// Update single transaction details
  Future<void> updateTransaction(DisputeTrxn updatedTrxn) async {
    if (updatedTrxn.objectId == null) return;
    final parseObject = ParseObject(tableTrxn)
      ..objectId = updatedTrxn.objectId
      ..fromJson(updatedTrxn.toJson());

    final response = await parseObject.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to update transaction');
    }
  }
}
