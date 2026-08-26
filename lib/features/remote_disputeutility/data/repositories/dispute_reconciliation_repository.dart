import 'package:cborecon/features/remote_disputeutility/domain/entities/dispute_reconciliation_row.dart';

class DisputeReconciliationRepository {
  String _normalize(dynamic val) {
    if (val == null) return "";
    String s = val.toString().trim();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s;
  }

  bool _isPanMatch(dynamic pan1, dynamic pan2) {
    String p1 = _normalize(pan1).replaceAll(RegExp(r'\s+'), '');
    String p2 = _normalize(pan2).replaceAll(RegExp(r'\s+'), '');

    if (p1.length < 8 || p2.length < 8) return false;

    String p1First4 = p1.substring(0, 4);
    String p1Last4 = p1.substring(p1.length - 4);

    String p2First4 = p2.substring(0, 4);
    String p2Last4 = p2.substring(p2.length - 4);

    return (p1First4 == p2First4) && (p1Last4 == p2Last4);
  }

  String _getValue(List<dynamic> row, List<String> headers, List<String> keywords) {
    for (var kw in keywords) {
      int idx = headers.indexWhere((h) =>
      h.toLowerCase().trim() == kw.toLowerCase().trim() ||
          h.toLowerCase().trim().contains(kw.toLowerCase().trim()));
      if (idx != -1 && idx < row.length) {
        return _normalize(row[idx]);
      }
    }
    return '';
  }

  List<DisputeReconciliationRow> reconcile({
    required List<List<dynamic>> cbsData,
    required List<List<dynamic>> settlementData,
  }) {
    if (cbsData.isEmpty || settlementData.isEmpty) return [];

    List<String> cbsHeaders = cbsData[0].map((e) => e.toString().trim()).toList();
    List<String> setHeaders = settlementData[0].map((e) => e.toString().trim()).toList();

    int cbsRrnIdx = cbsHeaders.indexWhere((h) => h.toUpperCase().contains('RETRIEVAL.REF.NO') || h.toUpperCase().contains('RRN'));
    int cbsAmtIdx = cbsHeaders.indexWhere((h) => h.toUpperCase().contains('TXN.AMOUNT') || h.toUpperCase().contains('AMOUNT'));
    int cbsPanIdx = cbsHeaders.indexWhere((h) => h.toUpperCase().contains('PAN.NUMBER') || h.toUpperCase().contains('PAN'));

    int setRrnIdx = setHeaders.indexWhere((h) => h.toUpperCase().contains('REFNUM_F37') || h.toUpperCase().contains('RRN'));
    int setAmtIdx = setHeaders.indexWhere((h) => h.toUpperCase().contains('AMOUNT'));
    int setPanIdx = setHeaders.indexWhere((h) => h.toUpperCase().contains('CARD_NUMBER') || h.toUpperCase().contains('PAN'));

    // Group records by RRN
    final Map<String, List<List<dynamic>>> cbsGroups = {};
    for (var row in cbsData.skip(1)) {
      if (cbsRrnIdx == -1 || row.length <= cbsRrnIdx) continue;
      String rrn = _normalize(row[cbsRrnIdx]);
      if (rrn.isNotEmpty) cbsGroups.putIfAbsent(rrn, () => []).add(row);
    }

    final Map<String, List<List<dynamic>>> setGroups = {};
    for (var row in settlementData.skip(1)) {
      if (setRrnIdx == -1 || row.length <= setRrnIdx) continue;
      String rrn = _normalize(row[setRrnIdx]);
      if (rrn.isNotEmpty) setGroups.putIfAbsent(rrn, () => []).add(row);
    }

    final Set<String> allRrns = {...cbsGroups.keys, ...setGroups.keys};
    final List<DisputeReconciliationRow> result = [];

    for (String rrn in allRrns) {
      List<List<dynamic>> cbsRows = List.from(cbsGroups[rrn] ?? []);
      List<List<dynamic>> setRows = List.from(setGroups[rrn] ?? []);
      List<Map<String, dynamic>> paired = [];

      // Primary Match: RRN + PAN + Amount
      for (var i = cbsRows.length - 1; i >= 0; i--) {
        var cRow = cbsRows[i];
        String cAmt = (cbsAmtIdx != -1 && cRow.length > cbsAmtIdx) ? _normalize(cRow[cbsAmtIdx]) : '';
        dynamic cPan = (cbsPanIdx != -1 && cRow.length > cbsPanIdx) ? cRow[cbsPanIdx] : null;

        int matchIdx = setRows.indexWhere((sRow) {
          bool amtMatch = true;
          if (cbsAmtIdx != -1 && setAmtIdx != -1 && sRow.length > setAmtIdx) {
            amtMatch = _normalize(sRow[setAmtIdx]) == cAmt;
          }
          if (!amtMatch) return false;

          if (cbsPanIdx != -1 && setPanIdx != -1 && sRow.length > setPanIdx) {
            return _isPanMatch(cPan, sRow[setPanIdx]);
          }
          return true;
        });

        if (matchIdx != -1) {
          paired.add({'cbs': cRow, 'set': setRows.removeAt(matchIdx), 'status': ReconStatus.ok});
          cbsRows.removeAt(i);
        }
      }

      // Secondary Match: RRN match with mismatch status
      for (var i = cbsRows.length - 1; i >= 0; i--) {
        var cRow = cbsRows[i];
        dynamic cPan = (cbsPanIdx != -1 && cRow.length > cbsPanIdx) ? cRow[cbsPanIdx] : null;

        int matchIdx = setRows.indexWhere((sRow) {
          if (cbsPanIdx != -1 && setPanIdx != -1 && sRow.length > setPanIdx) {
            return _isPanMatch(cPan, sRow[setPanIdx]);
          }
          return setRows.isNotEmpty;
        });

        if (matchIdx != -1) {
          paired.add({'cbs': cRow, 'set': setRows.removeAt(matchIdx), 'status': ReconStatus.amtMismatch});
          cbsRows.removeAt(i);
        }
      }

      for (var r in cbsRows) {
        paired.add({'cbs': r, 'set': null, 'status': ReconStatus.missing});
      }
      for (var r in setRows) {
        paired.add({'cbs': null, 'set': r, 'status': ReconStatus.missing});
      }

      // Map rows to DisputeReconciliationRow
      for (var pair in paired) {
        final cRow = pair['cbs'] as List<dynamic>?;
        final sRow = pair['set'] as List<dynamic>?;

        String id = cRow != null
            ? _getValue(cRow, cbsHeaders, ['trans.ref', 'trans_ref', 'transref', 'transaction.ref', 'transaction_ref', 'id'])
            : '';

        String branch = cRow != null ? _getValue(cRow, cbsHeaders, ['branch', 'co_code', 'co.code']) : '';
        String fuDisputeId = cRow != null ? _getValue(cRow, cbsHeaders, ['fu dispute id', 'fu_dispute_id', 'dispute_id', 'dispute', 'fu dispute']) : '';
        String account = cRow != null ? _getValue(cRow, cbsHeaders, ['account', 'acct', 'debit.acct.no']) : '';
        String amount = cRow != null ? _getValue(cRow, cbsHeaders, ['txn.amount', 'amount']) : '';

        String customer = cRow != null ? _getValue(cRow, cbsHeaders, ['customer', 'name']) : '';
        String acquirerBank = cRow != null ? _getValue(cRow, cbsHeaders, ['acquirer bank', 'acquirer', 'bank', 'acquirer_bank']) : '';
        String pan = cRow != null ? _getValue(cRow, cbsHeaders, ['pan.number', 'pan']) : '';

        String transactionDate = cRow != null ? _getValue(cRow, cbsHeaders, ['transaction date', 'date', 'txn.date', 'value.date']) : '';
        if (transactionDate.isEmpty && sRow != null) {
          transactionDate = _getValue(sRow, setHeaders, ['transaction_date', 'date']);
        }

        String cardNumber = sRow != null ? _getValue(sRow, setHeaders, ['card_number', 'pan']) : '';
        String refnumF37Rrn = sRow != null
            ? _getValue(sRow, setHeaders, ['refnum_f37', 'rrn'])
            : (cRow != null ? _getValue(cRow, cbsHeaders, ['retrieval.ref.no', 'rrn']) : '');
        String feUtrnno = sRow != null ? _getValue(sRow, setHeaders, ['fe_utrnno', 'utrnno']) : '';
        String settlementAmount = sRow != null ? _getValue(sRow, setHeaders, ['amount', 'txn_amount']) : '';

        // Safely map dynamic settlement file fields
        Map<String, String> settlementExtraFields = {};
        if (sRow != null) {
          for (int k = 0; k < setHeaders.length; k++) {
            if (k < sRow.length) {
              settlementExtraFields[setHeaders[k]] = _normalize(sRow[k]);
            }
          }
        }

        result.add(
          DisputeReconciliationRow(
            status: pair['status'],
            id: id,
            branch: branch,
            fuDisputeId: fuDisputeId,
            account: account,
            amount: amount,
            customer: customer,
            acquirerBank: acquirerBank,
            pan: pan,
            transactionDate: transactionDate,
            cardNumber: cardNumber,
            refnumF37Rrn: refnumF37Rrn,
            feUtrnno: feUtrnno,
            settlementAmount: settlementAmount,
            settlementExtraFields: settlementExtraFields,
            settlementHeaders: setHeaders,
          ),
        );
      }
    }

    return result;
  }
}