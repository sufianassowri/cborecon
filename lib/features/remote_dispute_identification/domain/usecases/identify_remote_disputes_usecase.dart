import '../../../../core/utils/normalization_util.dart';
import '../entities/remote_dispute_models.dart';
import 'bank_name_matcher.dart';

class IdentifyRemoteDisputesUseCase {
  static dynamic _getVal(Map<String, dynamic> row, List<String> possibleKeys) {
    for (final k in possibleKeys) {
      if (row.containsKey(k) && row[k] != null && row[k].toString().trim().isNotEmpty) {
        return row[k];
      }
    }
    // Case-insensitive / format-tolerant lookup
    for (final k in possibleKeys) {
      final cleanK = k.replaceAll(RegExp(r'[\s._-]'), '').toUpperCase();
      for (final entry in row.entries) {
        final cleanKey = entry.key.replaceAll(RegExp(r'[\s._-]'), '').toUpperCase();
        if (cleanKey == cleanK && entry.value != null && entry.value.toString().trim().isNotEmpty) {
          return entry.value;
        }
      }
    }
    return '';
  }

  static String _normRrn(dynamic val) {
    if (val == null) return '';
    String s = val.toString().trim();
    if (s.contains('E') || s.contains('e')) {
      final double? d = double.tryParse(s);
      if (d != null) s = d.toStringAsFixed(0);
    }
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    s = s.replaceAll(RegExp(r'[^\w]'), '');
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final stripped = s.replaceFirst(RegExp(r'^0+'), '');
      return stripped.isEmpty ? '0' : stripped;
    }
    return s.toUpperCase();
  }

  static String _normAmt(dynamic val) {
    if (val == null) return '0.00';
    final double amt = NormalizationUtil.parseAmount(val).abs();
    return amt.toStringAsFixed(2);
  }

  RemoteDisputeResult call({
    required List<Map<String, dynamic>> cbsRawData,
    required List<Map<String, dynamic>> settlementRawData,
  }) {
    // 1. Ingest CBS Records
    final List<CbsDisputeRecord> cbsRecords = [];
    for (final row in cbsRawData) {
      final pan = _getVal(row, ['PAN.NUMBER', 'PAN', 'CARD.NUMBER', 'PAN NUMBER', 'CARD_NO', 'CARD NUMBER']).toString().trim();
      final rrn = _getVal(row, ['RETRIEVAL.REF.NO', 'RRN', 'RETRIEVAL_REF_NO', 'REFNUM', 'REFNUM_F37']).toString().trim();
      final amt = _getVal(row, ['TXN.AMOUNT', 'TXN_AMOUNT', 'AMOUNT', 'TXN AMOUNT']);
      final bank = _getVal(row, ['Acquirer Bank', 'ACQUIRER BANK', 'ACQUIRER', 'BANK', 'ACQUIRER_BANK']).toString().trim();

      if (pan.isEmpty && rrn.isEmpty && amt.toString().trim().isEmpty) continue;

      final transRef = _getVal(row, ['TRANS.REF', 'TRANS_REF', 'TRANSREF', 'ID', 'TRANSACTION.REF']).toString().trim();
      final valueDate = _getVal(row, ['VALUE.DATE', 'VALUE_DATE', 'DATE', 'TXN.DATE', 'TRANSACTION DATE']).toString().trim();
      final debitAcct = _getVal(row, ['DEBIT.ACCT.NO', 'DEBIT_ACCT_NO', 'DEBIT.ACCT', 'ACCOUNT', 'ACCT']).toString().trim();
      final customer = _getVal(row, ['Customer', 'CUSTOMER', 'NAME', 'CUSTOMER NAME']).toString().trim();
      final branch = _getVal(row, ['Branch', 'BRANCH', 'CO_CODE', 'CO.CODE']).toString().trim();

      cbsRecords.add(CbsDisputeRecord(
        transRef: transRef,
        panNumber: pan,
        valueDate: valueDate,
        debitAcctNo: debitAcct,
        customer: customer,
        acquirerBank: bank,
        branch: branch,
        txnAmount: NormalizationUtil.parseAmount(amt),
        retrievalRefNo: rrn,
        rawRow: row,
      ));
    }

    // 2. Ingest Settlement Records
    final List<SettlementDisputeRecord> settlementRecords = [];
    for (final row in settlementRawData) {
      final cardNo = _getVal(row, ['Card_Number', 'CARD_NUMBER', 'CARD_NO', 'PAN', 'CARD NUMBER', 'PAN.NUMBER']).toString().trim();
      final rrn = _getVal(row, ['Refnum_F37', 'REFNUM_F37', 'RRN', 'RETRIEVAL.REF.NO', 'REFNUM']).toString().trim();
      final amt = _getVal(row, ['Amount', 'AMOUNT', 'TXN.AMOUNT', 'TXN_AMOUNT']);
      final acquirer = _getVal(row, ['Acquirer', 'ACQUIRER', 'Acquirer Bank', 'BANK', 'ACQUIRER_BANK']).toString().trim();
      final feUtrnno = _getVal(row, ['Fe_utrnno', 'FE_UTRNNO', 'UTRNNO', 'FE_UTRN']).toString().trim();

      if (cardNo.isEmpty && rrn.isEmpty && amt.toString().trim().isEmpty && feUtrnno.isEmpty) continue;

      final issuer = _getVal(row, ['Issuer', 'ISSUER']).toString().trim();
      final mti = _getVal(row, ['MTI', 'mti']).toString().trim();
      final currency = _getVal(row, ['Currency', 'CURRENCY', 'CCY']).toString().trim();
      final txnDate = _getVal(row, ['Transaction_Date', 'TRANSACTION_DATE', 'DATE', 'VALUE.DATE']).toString().trim();
      final txnDesc = _getVal(row, ['Transaction_Description', 'TRANSACTION_DESCRIPTION', 'DESC']).toString().trim();
      final terminalId = _getVal(row, ['Terminal_ID', 'TERMINAL_ID', 'TERMINAL', 'CARD.ACC.ID']).toString().trim();
      final txnPlace = _getVal(row, ['Transaction_Place', 'TRANSACTION_PLACE', 'PLACE']).toString().trim();
      final stanF11 = _getVal(row, ['STAN_F11', 'STAN', 'STAN_F_11']).toString().trim();
      final authidrespF38 = _getVal(row, ['Authidresp_F38', 'AUTHIDRESP_F38', 'AUTH_CODE']).toString().trim();
      final boUtrnno = _getVal(row, ['Bo_utrnno', 'BO_UTRNNO']).toString().trim();

      settlementRecords.add(SettlementDisputeRecord(
        issuer: issuer,
        acquirer: acquirer,
        mti: mti,
        cardNumber: cardNo,
        amount: NormalizationUtil.parseAmount(amt),
        currency: currency.isEmpty ? 'ETB' : currency,
        transactionDate: txnDate,
        transactionDescription: txnDesc,
        terminalId: terminalId,
        transactionPlace: txnPlace,
        stanF11: stanF11,
        refnumF37: rrn,
        authidrespF38: authidrespF38,
        feUtrnno: feUtrnno,
        boUtrnno: boUtrnno,
        rawRow: row,
      ));
    }

    final List<SettlementDisputeRecord> remainingSettlement = List.from(settlementRecords);
    final List<RemoteDisputeReconRow> generatedRows = [];
    final Set<String> disputedPanLast4Set = {};

    for (final c in cbsRecords) {
      if (c.panLast4.isNotEmpty) {
        disputedPanLast4Set.add(c.panLast4);
      }
    }

    // Build hash indices for fast O(1) settlement lookups
    // Index by normalized RRN -> list of indices
    final Map<String, List<int>> _rrnIndex = {};
    // Index by composite key (pan4 + amount) -> list of indices
    final Map<String, List<int>> _panAmtIndex = {};
    final Set<int> _consumedSettlement = {};

    for (int i = 0; i < remainingSettlement.length; i++) {
      final set = remainingSettlement[i];
      final setRrn = _normRrn(set.refnumF37);
      if (setRrn.isNotEmpty) {
        _rrnIndex.putIfAbsent(setRrn, () => []).add(i);
      }
      final setPan4 = set.panLast4;
      final setAmt = _normAmt(set.amount);
      if (setPan4.isNotEmpty) {
        final compositeKey = '${setPan4}_$setAmt';
        _panAmtIndex.putIfAbsent(compositeKey, () => []).add(i);
      }
    }

    int? _findFirstUnconsumed(List<int>? indices) {
      if (indices == null) return null;
      for (final idx in indices) {
        if (!_consumedSettlement.contains(idx)) return idx;
      }
      return null;
    }

    final List<CbsDisputeRecord> remainingCbs = [];

    // Phase 1: First Priority Matching (Full Match: PAN last 4 + RRN + Amount + Acquirer Bank)
    for (final cbs in cbsRecords) {
      final cbsPan4 = cbs.panLast4;
      final cbsRrnNorm = _normRrn(cbs.retrievalRefNo);
      final cbsAmtNorm = _normAmt(cbs.txnAmount);

      int? matchedIdx;

      // Try RRN-based lookup first (most selective)
      if (cbsRrnNorm.isNotEmpty) {
        final rrnCandidates = _rrnIndex[cbsRrnNorm];
        if (rrnCandidates != null) {
          // Look for full match: RRN + PAN + Amount + Bank
          for (final idx in rrnCandidates) {
            if (_consumedSettlement.contains(idx)) continue;
            final set = remainingSettlement[idx];
            final setPan4 = set.panLast4;
            final setAmtNorm = _normAmt(set.amount);
            final bool panMatch = cbsPan4.isNotEmpty && setPan4.isNotEmpty && cbsPan4 == setPan4;
            final bool amtMatch = cbsAmtNorm == setAmtNorm;
            final bool bankMatch = BankNameMatcher.isBankMatch(cbs.acquirerBank, set.acquirer, rrnMatched: true);
            if (panMatch && amtMatch && bankMatch) {
              matchedIdx = idx;
              break;
            }
          }
          // Fallback: RRN + Amount match (even if PAN mask format differs)
          if (matchedIdx == null) {
            for (final idx in rrnCandidates) {
              if (_consumedSettlement.contains(idx)) continue;
              final set = remainingSettlement[idx];
              final setAmtNorm = _normAmt(set.amount);
              if (setAmtNorm == cbsAmtNorm) {
                matchedIdx = idx;
                break;
              }
            }
          }
        }
      }

      // Fallback: PAN + Amount composite key lookup
      if (matchedIdx == null && cbsPan4.isNotEmpty) {
        final compositeKey = '${cbsPan4}_$cbsAmtNorm';
        final panAmtCandidates = _panAmtIndex[compositeKey];
        if (panAmtCandidates != null) {
          for (final idx in panAmtCandidates) {
            if (_consumedSettlement.contains(idx)) continue;
            final set = remainingSettlement[idx];
            final bool rrnMatch = cbsRrnNorm.isNotEmpty && _normRrn(set.refnumF37) == cbsRrnNorm;
            final bool bankMatch = BankNameMatcher.isBankMatch(cbs.acquirerBank, set.acquirer, rrnMatched: rrnMatch);
            if (bankMatch) {
              matchedIdx = idx;
              break;
            }
          }
        }
      }

      if (matchedIdx != null) {
        _consumedSettlement.add(matchedIdx);
        final matchedSet = remainingSettlement[matchedIdx];
        generatedRows.add(RemoteDisputeReconRow(
          status: RemoteDisputeStatus.matched,
          cbs: cbs,
          settlement: matchedSet,
          panKey: cbsPan4.isNotEmpty ? cbsPan4 : matchedSet.panLast4,
          isPrioritized: true,
          notes: 'Full match on PAN ($cbsPan4), RRN ($cbsRrnNorm), Amount ($cbsAmtNorm), and Bank',
          dynamicSettlementFields: matchedSet.rawRow,
        ));
      } else {
        remainingCbs.add(cbs);
      }
    }

    // Build secondary indices for remaining (unconsumed) settlement records
    // Index by PAN last 4 -> list of unconsumed indices
    final Map<String, List<int>> _panIndex = {};
    // Index by RRN -> list of unconsumed indices
    final Map<String, List<int>> _rrnIndex2 = {};
    for (int i = 0; i < remainingSettlement.length; i++) {
      if (_consumedSettlement.contains(i)) continue;
      final set = remainingSettlement[i];
      final setPan4 = set.panLast4;
      if (setPan4.isNotEmpty) {
        _panIndex.putIfAbsent(setPan4, () => []).add(i);
      }
      final setRrn = _normRrn(set.refnumF37);
      if (setRrn.isNotEmpty) {
        _rrnIndex2.putIfAbsent(setRrn, () => []).add(i);
      }
    }

    // Phase 2: Secondary Match - Amount Mismatch (PAN, Bank, and/or RRN matched but Amount differs)
    final List<CbsDisputeRecord> unmatchedCbs = [];
    for (final cbs in remainingCbs) {
      final cbsPan4 = cbs.panLast4;
      final cbsRrnNorm = _normRrn(cbs.retrievalRefNo);

      int? mismatchIdx;

      // Try RRN-based lookup
      if (cbsRrnNorm.isNotEmpty) {
        mismatchIdx = _findFirstUnconsumed(_rrnIndex2[cbsRrnNorm]);
      }

      // Fallback: PAN + Bank match
      if (mismatchIdx == null && cbsPan4.isNotEmpty) {
        final panCandidates = _panIndex[cbsPan4];
        if (panCandidates != null) {
          for (final idx in panCandidates) {
            if (_consumedSettlement.contains(idx)) continue;
            final set = remainingSettlement[idx];
            final setRrnNorm = _normRrn(set.refnumF37);
            final bool rrnMatch = cbsRrnNorm.isNotEmpty && setRrnNorm.isNotEmpty && cbsRrnNorm == setRrnNorm;
            final bool bankMatch = BankNameMatcher.isBankMatch(cbs.acquirerBank, set.acquirer, rrnMatched: rrnMatch);
            if (bankMatch) {
              mismatchIdx = idx;
              break;
            }
          }
        }
      }

      if (mismatchIdx != null) {
        _consumedSettlement.add(mismatchIdx);
        final mismatchedSet = remainingSettlement[mismatchIdx];
        generatedRows.add(RemoteDisputeReconRow(
          status: RemoteDisputeStatus.mismatch,
          cbs: cbs,
          settlement: mismatchedSet,
          panKey: cbsPan4.isNotEmpty ? cbsPan4 : mismatchedSet.panLast4,
          isPrioritized: false,
          notes: 'Amount mismatch: CBS ${_normAmt(cbs.txnAmount)} vs Settlement ${_normAmt(mismatchedSet.amount)}',
          dynamicSettlementFields: mismatchedSet.rawRow,
        ));
      } else {
        unmatchedCbs.add(cbs);
      }
    }

    // Phase 3: Missed CBS Records (No matching settlement record found)
    for (final cbs in unmatchedCbs) {
      generatedRows.add(RemoteDisputeReconRow(
        status: RemoteDisputeStatus.missed,
        cbs: cbs,
        settlement: null,
        panKey: cbs.panLast4,
        isPrioritized: false,
        notes: 'No matching transaction found in settlement report',
      ));
    }

    // Phase 4: Candidate / Unreported Duplicate Settlement Records
    // For every card/PAN that had CBS disputes, identify all remaining settlement transactions
    // and attach reference CBS context (TRANS.REF, DEBIT.ACCT.NO, Branch, Customer, PAN, Acquirer Bank)
    // from the prioritized CBS dispute of that PAN.
    final Map<String, CbsDisputeRecord> prioritizedCbsByPan = {};
    for (final row in generatedRows) {
      if (row.status == RemoteDisputeStatus.matched && row.cbs != null) {
        prioritizedCbsByPan.putIfAbsent(row.panKey, () => row.cbs!);
      }
    }
    for (final cbs in cbsRecords) {
      if (cbs.panLast4.isNotEmpty) {
        prioritizedCbsByPan.putIfAbsent(cbs.panLast4, () => cbs);
      }
    }

    final List<SettlementDisputeRecord> leftoverSettlement = [];
    for (int i = 0; i < remainingSettlement.length; i++) {
      if (_consumedSettlement.contains(i)) continue;
      final set = remainingSettlement[i];
      final setPan4 = set.panLast4;
      if (setPan4.isNotEmpty && disputedPanLast4Set.contains(setPan4)) {
        final referenceCbs = prioritizedCbsByPan[setPan4];
        final duplicateCbsContext = referenceCbs != null
            ? CbsDisputeRecord(
                transRef: '', // Unknown for candidate
                panNumber: referenceCbs.panNumber.isNotEmpty ? referenceCbs.panNumber : set.cardNumber, // Kept for candidate
                valueDate: '', // Unknown for candidate
                debitAcctNo: referenceCbs.debitAcctNo,
                customer: referenceCbs.customer,
                acquirerBank: '', // Unknown for candidate
                branch: '', // Unknown for candidate
                txnAmount: 0.0, // Unknown for candidate
                retrievalRefNo: '', // Unknown for candidate
                rawRow: const {},
              )
            : null;

        generatedRows.add(RemoteDisputeReconRow(
          status: RemoteDisputeStatus.candidate,
          cbs: duplicateCbsContext,
          settlement: set,
          panKey: setPan4,
          isPrioritized: true,
          notes: 'Unreported candidate settlement transaction for disputed card (...$setPan4)',
          dynamicSettlementFields: set.rawRow,
        ));
      } else {
        leftoverSettlement.add(set);
      }
    }

    // Phase 5: Settlement Only Records (Non-disputed cards)
    for (final set in leftoverSettlement) {
      generatedRows.add(RemoteDisputeReconRow(
        status: RemoteDisputeStatus.settlementOnly,
        cbs: null,
        settlement: set,
        panKey: set.panLast4,
        isPrioritized: false,
        notes: 'Non-disputed settlement record',
        dynamicSettlementFields: set.rawRow,
      ));
    }

    // Phase 6: Sorting and Clustering by PAN
    // Sort matching records by PAN together to quickly identify all related disputes and duplicates
    generatedRows.sort((a, b) {
      final panA = a.panKey;
      final panB = b.panKey;

      if (panA != panB) {
        return panA.compareTo(panB);
      }

      // Within same PAN, prioritize: matched -> mismatch -> missed -> candidate -> settlementOnly
      return a.status.index.compareTo(b.status.index);
    });

    final cbsHeaders = cbsRawData.isNotEmpty ? cbsRawData.first.keys.toList() : <String>[];
    final settlementHeaders = settlementRawData.isNotEmpty ? settlementRawData.first.keys.toList() : <String>[];

    return RemoteDisputeResult(
      allRows: generatedRows,
      cbsHeaders: cbsHeaders,
      settlementHeaders: settlementHeaders,
    );
  }
}
