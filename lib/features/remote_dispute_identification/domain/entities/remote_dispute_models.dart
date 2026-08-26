import 'package:pluto_grid/pluto_grid.dart';

enum RemoteDisputeStatus {
  matched, // Fully matched (PAN last 4 + RRN + Amount + Acquirer Bank)
  mismatch, // Amount mismatch (PAN/Bank/RRN match but Amount differs)
  missed, // CBS dispute with no match in settlement
  candidate, // Prioritized settlement candidate for same PAN/Bank (empty CBS side)
  settlementOnly, // Unmatched settlement record
}

class CbsDisputeRecord {
  final String transRef;
  final String panNumber;
  final String valueDate;
  final String debitAcctNo;
  final String customer;
  final String acquirerBank;
  final String branch;
  final double txnAmount;
  final String retrievalRefNo;
  final Map<String, dynamic> rawRow;

  const CbsDisputeRecord({
    this.transRef = '',
    required this.panNumber,
    this.valueDate = '',
    this.debitAcctNo = '',
    this.customer = '',
    required this.acquirerBank,
    this.branch = '',
    required this.txnAmount,
    required this.retrievalRefNo,
    this.rawRow = const {},
  });

  String get panLast4 {
    final clean = panNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 4) return clean;
    return clean.substring(clean.length - 4);
  }

  static const empty = CbsDisputeRecord(
    panNumber: '',
    acquirerBank: '',
    txnAmount: 0.0,
    retrievalRefNo: '',
  );
}

class SettlementDisputeRecord {
  final String issuer;
  final String acquirer;
  final String mti;
  final String cardNumber;
  final double amount;
  final String currency;
  final String transactionDate;
  final String transactionDescription;
  final String terminalId;
  final String transactionPlace;
  final String stanF11;
  final String refnumF37;
  final String authidrespF38;
  final String feUtrnno;
  final String boUtrnno;
  final Map<String, dynamic> rawRow;

  const SettlementDisputeRecord({
    this.issuer = '',
    required this.acquirer,
    this.mti = '',
    required this.cardNumber,
    required this.amount,
    this.currency = '',
    this.transactionDate = '',
    this.transactionDescription = '',
    this.terminalId = '',
    this.transactionPlace = '',
    this.stanF11 = '',
    required this.refnumF37,
    this.authidrespF38 = '',
    required this.feUtrnno,
    this.boUtrnno = '',
    this.rawRow = const {},
  });

  String get panLast4 {
    final clean = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 4) return clean;
    return clean.substring(clean.length - 4);
  }

  static const empty = SettlementDisputeRecord(
    acquirer: '',
    cardNumber: '',
    amount: 0.0,
    refnumF37: '',
    feUtrnno: '',
  );
}

class RemoteDisputeReconRow {
  final RemoteDisputeStatus status;
  final CbsDisputeRecord? cbs;
  final SettlementDisputeRecord? settlement;
  final String panKey;
  final bool isPrioritized;
  final String notes;
  final Map<String, dynamic> dynamicSettlementFields;
  final List<String> settlementHeaders;

  const RemoteDisputeReconRow({
    required this.status,
    this.cbs,
    this.settlement,
    required this.panKey,
    this.isPrioritized = false,
    this.notes = '',
    this.dynamicSettlementFields = const {},
    this.settlementHeaders = const [],
  });

  String get statusText {
    switch (status) {
      case RemoteDisputeStatus.matched:
        return 'MATCHED';
      case RemoteDisputeStatus.mismatch:
        return 'MISMATCH';
      case RemoteDisputeStatus.missed:
        return 'MISSED';
      case RemoteDisputeStatus.candidate:
        return 'CANDIDATE';
      case RemoteDisputeStatus.settlementOnly:
        return 'SETTLEMENT_ONLY';
    }
  }

  PlutoRow toPlutoRow() {
    final Map<String, PlutoCell> cells = {
      'recon_status': PlutoCell(value: statusText),
      // CBS Fields
      'cbs_trans_ref': PlutoCell(value: cbs?.transRef ?? ''),
      'cbs_pan_number': PlutoCell(value: cbs?.panNumber ?? ''),
      'cbs_value_date': PlutoCell(value: cbs?.valueDate ?? ''),
      'cbs_debit_acct_no': PlutoCell(value: cbs?.debitAcctNo ?? ''),
      'cbs_customer': PlutoCell(value: cbs?.customer ?? ''),
      'cbs_acquirer_bank': PlutoCell(value: cbs?.acquirerBank ?? ''),
      'cbs_branch': PlutoCell(value: cbs?.branch ?? ''),
      'cbs_txn_amount': PlutoCell(
          value: cbs != null && cbs!.txnAmount > 0 ? cbs!.txnAmount : ''),
      'cbs_retrieval_ref_no': PlutoCell(value: cbs?.retrievalRefNo ?? ''),
      // Settlement Fields
      'set_issuer': PlutoCell(value: settlement?.issuer ?? ''),
      'set_acquirer': PlutoCell(value: settlement?.acquirer ?? ''),
      'set_mti': PlutoCell(value: settlement?.mti ?? ''),
      'set_card_number': PlutoCell(value: settlement?.cardNumber ?? ''),
      'set_amount': PlutoCell(
          value: settlement != null && settlement!.amount > 0
              ? settlement!.amount
              : ''),
      'set_currency': PlutoCell(value: settlement?.currency ?? ''),
      'set_transaction_date':
          PlutoCell(value: settlement?.transactionDate ?? ''),
      'set_transaction_description':
          PlutoCell(value: settlement?.transactionDescription ?? ''),
      'set_terminal_id': PlutoCell(value: settlement?.terminalId ?? ''),
      'set_transaction_place':
          PlutoCell(value: settlement?.transactionPlace ?? ''),
      'set_stan_f11': PlutoCell(value: settlement?.stanF11 ?? ''),
      'set_refnum_f37': PlutoCell(value: settlement?.refnumF37 ?? ''),
      'set_authidresp_f38': PlutoCell(value: settlement?.authidrespF38 ?? ''),
      'set_fe_utrnno': PlutoCell(value: settlement?.feUtrnno ?? ''),
      'set_bo_utrnno': PlutoCell(value: settlement?.boUtrnno ?? ''),
      'notes': PlutoCell(value: notes),
    };

    for (final h in settlementHeaders) {
      if (!cells.containsKey('dyn_$h')) {
        cells['dyn_$h'] = PlutoCell(value: dynamicSettlementFields[h] ?? '');
      }
    }

    return PlutoRow(cells: cells);
  }
}

class RemoteDisputeResult {
  final List<RemoteDisputeReconRow> allRows;
  final List<String> cbsHeaders;
  final List<String> settlementHeaders;

  const RemoteDisputeResult({
    required this.allRows,
    this.cbsHeaders = const [],
    this.settlementHeaders = const [],
  });

  List<RemoteDisputeReconRow> get matchedRows =>
      allRows.where((r) => r.status == RemoteDisputeStatus.matched).toList();

  List<RemoteDisputeReconRow> get mismatchRows =>
      allRows.where((r) => r.status == RemoteDisputeStatus.mismatch).toList();

  List<RemoteDisputeReconRow> get missedRows =>
      allRows.where((r) => r.status == RemoteDisputeStatus.missed).toList();

  List<RemoteDisputeReconRow> get candidateRows =>
      allRows.where((r) => r.status == RemoteDisputeStatus.candidate).toList();

  List<RemoteDisputeReconRow> get settlementOnlyRows => allRows
      .where((r) => r.status == RemoteDisputeStatus.settlementOnly)
      .toList();

  int get totalMatchedCount => matchedRows.length;
  int get totalMismatchCount => mismatchRows.length;
  int get totalMissedCount => missedRows.length;
  int get totalCandidateCount => candidateRows.length;
  int get totalSettlementOnlyCount => settlementOnlyRows.length;
  int get totalRowCount => allRows.length;

  double get totalMatchedCbsAmount =>
      matchedRows.fold(0.0, (sum, r) => sum + (r.cbs?.txnAmount ?? 0.0));

  double get totalMismatchCbsAmount =>
      mismatchRows.fold(0.0, (sum, r) => sum + (r.cbs?.txnAmount ?? 0.0));

  double get totalMissedCbsAmount =>
      missedRows.fold(0.0, (sum, r) => sum + (r.cbs?.txnAmount ?? 0.0));

  double get totalCandidateSettlementAmount =>
      candidateRows.fold(0.0, (sum, r) => sum + (r.settlement?.amount ?? 0.0));
}
