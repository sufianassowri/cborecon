import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../domain/entities/card_transaction.dart';

class CardTransactionModel extends CardTransaction {
  CardTransactionModel({
    super.id,
    required super.referenceId,
    required super.clientId,
    required super.pan,
    required super.rawRecordType,
    required super.txnType,
    required super.debitCredit,
    required super.baseAmount,
    required super.extraAmount,
    required super.annualFeeAmount,
    required super.totalTransactionAmount,
    super.description,
    super.fileId,
    required super.transactionDate,
  });

  factory CardTransactionModel.fromParse(ParseObject object) {
    final rawTxnType = object.get<String>('txnType') ?? 'topup';
    final txnTypeEnum = TransactionType.values.firstWhere(
          (e) => e.name == rawTxnType,
      orElse: () => TransactionType.topup,
    );

    final rawDc = object.get<String>('debitCredit') ?? 'debit';
    final debitCreditEnum = DebitCredit.values.firstWhere(
          (e) => e.name == rawDc,
      orElse: () => DebitCredit.debit,
    );

    return CardTransactionModel(
      id: object.objectId,
      referenceId: object.get<String>('referenceId') ?? '',
      clientId: object.get<String>('clientId') ?? '',
      pan: object.get<String>('pan') ?? '',
      rawRecordType: object.get<String>('rawRecordType') ?? '',
      txnType: txnTypeEnum,
      debitCredit: debitCreditEnum,
      baseAmount: (object.get<num>('baseAmount') ?? 0.0).toDouble(),
      extraAmount: (object.get<num>('extraAmount') ?? 0.0).toDouble(),
      annualFeeAmount: (object.get<num>('annualFeeAmount') ?? 0.0).toDouble(),
      totalTransactionAmount: (object.get<num>('totalTransactionAmount') ?? 0.0).toDouble(),
      description: object.get<String>('description'),
      fileId: object.get<String>('fileId'),
      transactionDate: object.get<DateTime>('transactionDate') ?? DateTime.now(),
    );
  }

  ParseObject toParseObject([String? objectId]) {
    final parseObject = ParseObject('CardTransaction');
    if (objectId != null) parseObject.objectId = objectId;

    return parseObject
      ..set('referenceId', referenceId)
      ..set('clientId', clientId)
      ..set('pan', pan)
      ..set('rawRecordType', rawRecordType)
      ..set('txnType', txnType.name)
      ..set('debitCredit', debitCredit.name)
      ..set('baseAmount', baseAmount)
      ..set('extraAmount', extraAmount)
      ..set('annualFeeAmount', annualFeeAmount)
      ..set('totalTransactionAmount', totalTransactionAmount)
      ..set('description', description)
      ..set('fileId', fileId)
      ..set('transactionDate', transactionDate);
  }
}