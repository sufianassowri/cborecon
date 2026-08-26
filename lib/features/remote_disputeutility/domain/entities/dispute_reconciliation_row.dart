import 'package:pluto_grid/pluto_grid.dart';

enum ReconStatus { ok, amtMismatch, missing }

class DisputeReconciliationRow {
  final ReconStatus status;
  final String id;
  final String branch;
  final String fuDisputeId;
  final String account;
  final String amount;
  final String customer;
  final String acquirerBank;
  final String pan;
  final String transactionDate;
  final String cardNumber;
  final String refnumF37Rrn;
  final String feUtrnno;
  final String settlementAmount;

  /// Holds all dynamic settlement file columns
  final Map<String, String> settlementExtraFields;
  final List<String> settlementHeaders;

  DisputeReconciliationRow({
    required this.status,
    required this.id,
    required this.branch,
    required this.fuDisputeId,
    required this.account,
    required this.amount,
    required this.customer,
    required this.acquirerBank,
    required this.pan,
    required this.transactionDate,
    required this.cardNumber,
    required this.refnumF37Rrn,
    required this.feUtrnno,
    required this.settlementAmount,
    required this.settlementExtraFields,
    required this.settlementHeaders,
  });

  String get statusText {
    switch (status) {
      case ReconStatus.ok:
        return 'OK';
      case ReconStatus.amtMismatch:
        return 'AMT_MISMATCH';
      case ReconStatus.missing:
        return 'MISSING';
    }
  }

  /// Convert Entity into PlutoRow for UI presentation
  PlutoRow toPlutoRow() {
    final Map<String, PlutoCell> cells = {
      'reconcile_status': PlutoCell(value: statusText),
      'id': PlutoCell(value: id),
      'branch': PlutoCell(value: branch),
      'fu_dispute_id': PlutoCell(value: fuDisputeId),
      'account': PlutoCell(value: account),
      'amount': PlutoCell(value: amount),
      'settlement_amount': PlutoCell(value: settlementAmount),
      'customer': PlutoCell(value: customer),
      'acquirer_bank': PlutoCell(value: acquirerBank),
      'pan': PlutoCell(value: pan),
      'transaction_date': PlutoCell(value: transactionDate),
      'card_number': PlutoCell(value: cardNumber),
      'refnum_f37_rrn': PlutoCell(value: refnumF37Rrn),
      'fe_utrnno': PlutoCell(value: feUtrnno),
    };

    // Dynamically add all settlement file columns
    for (var header in settlementHeaders) {
      cells['settlement_$header'] = PlutoCell(value: settlementExtraFields[header] ?? '');
    }

    return PlutoRow(cells: cells);
  }
}

