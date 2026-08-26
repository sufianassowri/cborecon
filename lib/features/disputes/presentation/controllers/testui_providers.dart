import 'package:cborecon/features/disputes/presentation/controllers/test_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

final transactionListProvider = FutureProvider<List<Transaction>>((ref) async {
  final query = QueryBuilder<ParseObject>(ParseObject('DisputeTransaction'));
  final response = await query.query();

  if (response.success && response.results != null) {
    final rawResults = response.results as List<ParseObject>;

    // Map each ParseObject to a Transaction object
    return rawResults.map((parseObj) {
      return Transaction(
        // Assuming your Transaction class properties match these
        terminalCode: parseObj.get<String>('terminalCode') ?? 'N/A',
        ejUrl: parseObj.get<ParseFileBase>('ejFile')?.url,
        confUrl: parseObj.get<ParseFileBase>('confFile')?.url,
        receiptUrl: parseObj.get<ParseFileBase>('receiptFile')?.url,
      );
    }).toList();
  }
  return [];
});