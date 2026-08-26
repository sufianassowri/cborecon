import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../domain/entities/master_card_account.dart';

class MasterCardAccountModel extends MasterCardAccount {
  MasterCardAccountModel({
    required super.clientId,
    required super.pan,
    required super.topupamount,
    super.baseamount,
    super.extraamount,
    super.TotalUsed,
    super.annualfee,
    required super.currentBalance,
    required super.updatedAt,
  });

  factory MasterCardAccountModel.fromParse(ParseObject object) {
    return MasterCardAccountModel(
      clientId: object.get<String>('clientId') ?? '',
      pan: object.get<String>('pan') ?? '',
      topupamount: (object.get<num>('topupamount') ?? 0.0).toDouble(),
      baseamount: (object.get<num>('baseamount') ?? 0.0).toDouble(),
      extraamount: (object.get<num>('extraamount') ?? 0.0).toDouble(),
      TotalUsed: (object.get<num>('TotalUsed') ??
              object.get<num>('annualfeeAndTotalUsed') ??
              0.0)
          .toDouble(),
      annualfee: (object.get<num>('annualfee') ?? 0.0).toDouble(),
      currentBalance: (object.get<num>('currentBalance') ?? 0.0).toDouble(),
      updatedAt: object.updatedAt ?? DateTime.now(),
    );
  }
  ParseObject toParseObject([String? objectId]) {
    final parseObject = ParseObject('MasterCardAccount');
    if (objectId != null) parseObject.objectId = objectId;
    return parseObject
      ..set('clientId', clientId)
      ..set('pan', pan)
      ..set('topupamount',topupamount)
      ..set('baseamount',baseamount)
      ..set('extraamount',extraamount)
      ..set('annualfee',annualfee)
      ..set('TotalUsed',totalUsed)
      ..set('currentBalance',currentBalance);
  }
}