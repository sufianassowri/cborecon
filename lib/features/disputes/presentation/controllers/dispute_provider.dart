import 'package:cborecon/features/disputes/data/model/transaction_model.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'dispute_provider.g.dart';
@riverpod
class DisputeList extends _$DisputeList {
  @override
  Future<List<DisputeTrxn>> build() async {
    final query = QueryBuilder<ParseObject>(ParseObject("DisputeTrxn"));
    final response = await query.query();

    if (response.success && response.results != null) {
      return response.results!
          .map((e) => DisputeTrxn.fromJson(e.toJson()))
          .toList();
    }
    return [];
  }

  // --- CRUD Methods ---

  Future<void> addDispute(DisputeTrxn dispute) async {
    final parseObject = ParseObject('DisputeTrxn')..fromJson(dispute.toJson());
    final response = await parseObject.save();

    if (response.success && response.result != null) {
      final newEntry = DisputeTrxn.fromJson(response.result.toJson());

      // Update local state by appending the new entry
      state = AsyncData([...state.value ?? [], newEntry]);
    }
  }
  Future<void> updateDispute(DisputeTrxn updatedDispute) async {
    // Assuming your model has an 'objectId' field from Parse
    final parseObject = ParseObject('DisputeTrxn')
      ..objectId = updatedDispute.objectId
      ..fromJson(updatedDispute.toJson());

    final response = await parseObject.save();

    if (response.success) {
      state = AsyncData([
        for (final item in state.value ?? [])
          if (item.objectId == updatedDispute.objectId) updatedDispute else item
      ]);
    }
  }

  Future<void> deleteDispute(String objectId) async {
    final parseObject = ParseObject('DisputeTrxn')..objectId = objectId;
    final response = await parseObject.delete();

    if (response.success) {
      state = AsyncData([
        for (final item in state.value ?? [])
          if (item.objectId != objectId) item
      ]);
    }
  }
}