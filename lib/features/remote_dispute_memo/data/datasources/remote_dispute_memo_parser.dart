import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

import '../../domain/models/remote_dispute_memo_item.dart';

class RemoteDisputeMemoParser {
  /// Define required keys for ATM ENQ and Dispute reports.
  static const List<String> _requiredAtmEnqKeys = [
    'RETRIEVAL.REF.NO',
    'TRANS.REF',
  ];

  static const List<String> _requiredDisputeKeys = [
    'Amount',
  ];

  /// Parse and match ATM ENQ report and Dispute report matching on TRANS.REF / Id
  static Future<List<Map<String, dynamic>>> parseAndMatchReports({
    required String atmEnqPath,
    required String disputeReportPath,
  }) async {
    final atmEnqRows = await _readReport(atmEnqPath, requiredKeys: _requiredAtmEnqKeys);
    final disputeRows = await _readReport(disputeReportPath, requiredKeys: _requiredDisputeKeys);

    // Build lookup map for ATM ENQ report indexed by RETRIEVAL.REF.NO and TRANS.REF
    final Map<String, Map<String, dynamic>> atmMap = {};
    for (var row in atmEnqRows) {
      final transRef = row['TRANS.REF']?.toString().trim() ?? '';
      final rrn = row['RETRIEVAL.REF.NO']?.toString().trim() ?? '';

      if (rrn.isNotEmpty) atmMap[rrn] = row;
      if (transRef.isNotEmpty) atmMap[transRef] = row;
    }

    final List<Map<String, dynamic>> matched = [];

    for (var disputeRow in disputeRows) {
      final id = disputeRow['Id']?.toString().trim() ??
          disputeRow['id']?.toString().trim() ??
          disputeRow['TRANSREFERANCE']?.toString().trim() ??
          '';

      if (id.isEmpty || !atmMap.containsKey(id)) {
        continue;
      }

      final atmRow = atmMap[id]!;
      matched.add({
        ...disputeRow,
        '@ID': atmRow['@ID']?.toString().trim() ?? '',
        'CREDIT.ACCT.NO': atmRow['CREDIT.ACCT.NO'] ?? atmRow['DEBIT.ACCT.NO'] ?? '',
        'COMPANY.CODE': atmRow['COMPANY.CODE'] ?? disputeRow['Branch'] ?? '',
        'RETRIEVAL.REF.NO': atmRow['RETRIEVAL.REF.NO'] ?? id,
        'Acquirer Bank': disputeRow['Acquirer Bank'] ?? atmRow['Acquirer Bank'] ?? 'CBE ETS SETTL',
        'VALUE.DATE': atmRow['VALUE.DATE'] ?? '',
        'BOOKING.DATE': atmRow['BOOKING.DATE'] ?? '',
        'PROC.CODE': atmRow['PROC.CODE'] ?? '',
        'MTI.CODE': atmRow['MTI.CODE'] ?? '',
        'BIN.REFERENCE': atmRow['BIN.REFERENCE'] ?? '',
        'DR.CUSTOMER.ID': atmRow['DR.CUSTOMER.ID'] ?? '',
        'MERCHANT.ID': atmRow['MERCHANT.ID'] ?? '',
        'TIMESTAMP': atmRow['TIMESTAMP'] ?? '',
        'CARD.ACC.ID': atmRow['CARD.ACC.ID'] ?? '',
      });
    }
    return matched;
  }

  static RemoteDisputeMemoSummary generateMemoData({
    required List<Map<String, dynamic>> matchedData,
    double commissionRate = 0.006,
    double disasterRate = 0.05,
    double vatRate = 0.15,
    double otherCommissionRate = 0.0,
  }) {
    List<RemoteDisputeMemoItem> items = [];

    for (var row in matchedData) {
      final amount = double.tryParse(row['Amount']?.toString() ?? '0') ?? 0.0;
      final branchRaw = row['Branch']?.toString() ?? row['COMPANY.CODE']?.toString() ?? '';

      final item = RemoteDisputeMemoItem(
        id: row['@ID']?.toString(),
        transRef: row['Id']?.toString() ?? row['id']?.toString() ?? row['TRANSREFERANCE'] ?? '',
        branch: branchRaw,
        customerAccount: row['Account']?.toString() ?? row['CustomerAccount'] ?? '',
        amount: amount,
        customerName: row['Customer']?.toString() ?? row['CustomerName'] ?? '',
        pan: row['PAN']?.toString() ?? '',
        transactionDate: row['Transaction Date']?.toString() ?? '',
        retrievalRefNo: row['RETRIEVAL.REF.NO']?.toString() ?? '',
        drAccount: row['CREDIT.ACCT.NO']?.toString() ?? row['DEBIT.ACCT.NO']?.toString() ?? '',
        acquirerBank: row['Acquirer Bank']?.toString() ?? 'CBE ETS SETTL',
        fuDisputeId: row['FU Dispute Id']?.toString() ?? '',
        valueDate: row['VALUE.DATE']?.toString() ?? '',
        bookingDate: row['BOOKING.DATE']?.toString() ?? '',
        procCode: row['PROC.CODE']?.toString() ?? '',
        mtiCode: row['MTI.CODE']?.toString() ?? '',
        binReference: row['BIN.REFERENCE']?.toString() ?? '',
        drCustomerId: row['DR.CUSTOMER.ID']?.toString() ?? '',
        merchantId: row['MERCHANT.ID']?.toString() ?? '',
        timestamp: row['TIMESTAMP']?.toString() ?? '',
        cardAccId: row['CARD.ACC.ID']?.toString() ?? '',
        investigationStatus: row['Investigation Status']?.toString() ?? '',
        requestedDate: row['Requested Date']?.toString() ?? '',
        assignedDate: row['Assigned Date']?.toString() ?? '',
        commissionRate: commissionRate,
        disasterRate: disasterRate,
        vatRate: vatRate,
        otherCommissionRate: otherCommissionRate,
      );

      items.add(item);
    }

    return RemoteDisputeMemoSummary.fromItems(items);
  }

  static bool _isValidRow(Map<String, dynamic> row, List<String> requiredKeys) {
    final isEntirelyEmpty = row.values.every((val) => val == null || val.toString().trim().isEmpty);
    if (isEntirelyEmpty) return false;

    for (final key in requiredKeys) {
      if (!row.containsKey(key) || row[key] == null || row[key].toString().trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  static Future<List<Map<String, dynamic>>> _readReport(
      String path, {
        List<String> requiredKeys = const [],
      }) async {
    final file = File(path);
    final List<Map<String, dynamic>> validRows = [];

    if (path.endsWith('.csv')) {
      final input = await file.readAsString();
      final rows = const CsvToListConverter().convert(input);
      if (rows.isEmpty) return [];

      final headers = rows.first.map((e) => e.toString().trim()).toList();

      for (final row in rows.skip(1)) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i];
        }
        if (_isValidRow(map, requiredKeys)) {
          validRows.add(map);
        }
      }
    } else {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables[excel.tables.keys.first]!;
      if (table.maxRows == 0) return [];

      final headers = table.rows.first.map((e) => e?.value?.toString().trim() ?? '').toList();

      for (final row in table.rows.skip(1)) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i]?.value;
        }
        if (_isValidRow(map, requiredKeys)) {
          validRows.add(map);
        }
      }
    }

    return validRows;
  }
}
