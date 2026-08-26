import 'package:intl/intl.dart';
import '../../../../core/utils/normalization_util.dart';
import '../entities/recon_declined_models.dart';
import 'generate_declined_accounts_usecase.dart';

class ReconcileDeclinedUseCase {
  final GenerateDeclinedAccountsUseCase _accountGen = GenerateDeclinedAccountsUseCase();

  static dynamic _getVal(Map<String, dynamic> row, List<String> possibleKeys) {
    for (final k in possibleKeys) {
      if (row.containsKey(k) && row[k] != null && row[k].toString().trim().isNotEmpty) {
        return row[k];
      }
    }
    // Case-insensitive & format-tolerant lookup
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

  static String _normalizeAccountKey(dynamic acc) {
    if (acc == null) return '';
    String s = acc.toString().trim().toUpperCase();
    if (s.startsWith('ETB')) {
      s = s.substring(3);
    }
    s = s.replaceAll(RegExp(r'[^0-9A-Z]'), '');
    return s;
  }

  static bool _isSummaryOrInvalidRow(String id) {
    final upper = id.trim().toUpperCase();
    if (upper.isEmpty) return true;
    if (upper == 'GRAND TOTAL' ||
        upper == 'TOTAL' ||
        upper == 'SUM' ||
        upper.startsWith('TOTAL ') ||
        upper.startsWith('GRAND TOTAL')) {
      return true;
    }
    return false;
  }

  ReconDeclinedResult call(
    List<Map<String, dynamic>> excessData,
    List<Map<String, dynamic>> declinedData,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    // 1. Process Excess Account Detail records
    final Map<String, ExcessAccountDetail> excessMap = {};
    final List<ExcessAccountDetail> allExcessList = [];

    for (final row in excessData) {
      final accNo = _getVal(row, [
        'Account No',
        'AccountNo',
        'ACCOUNT.NO',
        'ACCOUNT_NO',
        'Account Number',
        'Acct No',
        'Account',
        'Account Id',
      ]).toString().trim();

      if (accNo.isEmpty || _isSummaryOrInvalidRow(accNo)) continue;

      final rawBal = _getVal(row, [
        'Account Balance',
        'AccountBalance',
        'ACCOUNT.BALANCE',
        'ACCOUNT_BALANCE',
        'Balance',
        'BAL',
        'Current Balance',
        'Amount',
      ]);

      final double balance = NormalizationUtil.parseAmount(rawBal);
      final customer = _getVal(row, ['Customer', 'CUSTOMER', 'Cust ID', 'CustomerId']).toString().trim();
      final name = _getVal(row, ['Name', 'NAME', 'Customer Name', 'Account Name']).toString().trim();
      final product = _getVal(row, ['Product', 'PRODUCT', 'Product Name']).toString().trim();
      final ccy = _getVal(row, ['Ccy', 'CCY', 'Currency']).toString().trim();
      final officer = _getVal(row, ['Account Officer', 'AccountOfficer', 'Officer']).toString().trim();

      final detail = ExcessAccountDetail(
        accountNo: accNo,
        accountBalance: balance,
        customer: customer,
        name: name,
        product: product,
        ccy: ccy.isEmpty ? 'ETB' : ccy,
        accountOfficer: officer,
        rawRow: row,
      );

      final normKey = _normalizeAccountKey(accNo);
      excessMap[normKey] = detail;
      allExcessList.add(detail);
    }

    // 2. Ingest and Group Declined Transactions by CARD.ACC.ID or CREDIT.ACCT.NO
    final Map<String, List<DeclinedRawRecord>> declinedGroups = {};

    for (final row in declinedData) {
      // Prioritize CARD.ACC.ID, CREDIT.ACCT.NO, or Row Labels as required
      dynamic rawCardAccId = _getVal(row, [
        'CARD.ACC.ID',
        'CARD_ACC_ID',
        'CARD.ACC',
        'CARDACCID',
        'Terminal_ID',
        'TERMINAL_ID',
        'Terminal ID',
        'Terminal',
        'TERMINAL',
        'Row Labels',
        'ROW LABELS',
        'RowLabels',
        'CREDIT.ACCT.NO',
        'CREDIT_ACCT_NO',
        'CREDIT.ACCT',
        'DEBIT.ACCT.NO',
        'COL_0',
      ]);

      // If still empty (e.g. pivot without header or unusual column name), scan values for terminal or account pattern
      if (rawCardAccId == null || rawCardAccId.toString().trim().isEmpty) {
        for (final entry in row.entries) {
          final val = entry.value?.toString().trim().toUpperCase() ?? '';
          if (val.isEmpty || _isSummaryOrInvalidRow(val)) continue;
          if ((val.length >= 6 &&
                  val.length <= 12 &&
                  (val.contains('N') || val.contains('C')) &&
                  RegExp(r'\d{3,}$').hasMatch(val)) ||
              val.startsWith('ETB1000') ||
              val.startsWith('10002') ||
              val.startsWith('10005') ||
              val.startsWith('ETB1764')) {
            rawCardAccId = val;
            break;
          }
        }
      }

      final String cardAccId = rawCardAccId?.toString().trim().toUpperCase() ?? '';
      if (cardAccId.isEmpty || _isSummaryOrInvalidRow(cardAccId)) continue;

      final rawAmt = _getVal(row, [
        'TXN.AMOUNT',
        'TXN_AMOUNT',
        'TXN.AMT',
        'Amount',
        'AMOUNT',
        'Sum of TXN.AMOUNT',
        'Sum of Amount',
        'Sum of TXN_AMOUNT',
        'Total',
        'COL_1',
      ]);

      // If amount not found by key, search numeric value in row
      double amount = NormalizationUtil.parseAmount(rawAmt);
      if (amount == 0.0 && rawAmt.toString().trim().isEmpty) {
        for (final entry in row.entries) {
          final s = entry.value?.toString().trim() ?? '';
          if (s.isNotEmpty && s != cardAccId) {
            final parsed = NormalizationUtil.parseAmount(s);
            if (parsed > 0) {
              amount = parsed;
              break;
            }
          }
        }
      }

      final transRef = _getVal(row, ['TRANS.REF', 'TRANS_REF', 'TRANS.NO', 'Ref', 'Reference']).toString().trim();
      final valueDate = _getVal(row, ['VALUE.DATE', 'VALUE_DATE', 'Date', 'Transaction Date']).toString().trim();
      final debitAcct = _getVal(row, ['DEBIT.ACCT.NO', 'DEBIT_ACCT_NO', 'DEBIT.ACCT']).toString().trim();
      final creditAcct = _getVal(row, ['CREDIT.ACCT.NO', 'CREDIT_ACCT_NO', 'CREDIT.ACCT']).toString().trim();
      final rrn = _getVal(row, ['RETRIEVAL.REF.NO', 'RETRIEVAL_REF_NO', 'RRN', 'Refnum_F37']).toString().trim();

      final record = DeclinedRawRecord(
        cardAccId: cardAccId,
        amount: amount,
        transRef: transRef,
        valueDate: valueDate,
        debitAcctNo: debitAcct,
        creditAcctNo: creditAcct,
        retrievalRefNo: rrn,
        rawRow: row,
      );

      declinedGroups.putIfAbsent(cardAccId, () => []).add(record);
    }

    // 3. Match generated excess accounts against uploaded excess accounts
    final List<MatchedDeclinedSettlement> matched = [];
    final List<UnmatchedDeclinedRecord> declinedOnly = [];
    final Set<String> matchedExcessKeys = {};

    declinedGroups.forEach((cardAccId, records) {
      final double totalDeclined = records.fold(0.0, (sum, r) => sum + r.amount);
      final derived = _accountGen(cardAccId);

      if (!derived.isValid) {
        declinedOnly.add(UnmatchedDeclinedRecord(
          cardAccId: cardAccId,
          totalDeclinedAmount: totalDeclined,
          derivedExcessAccount: 'INVALID_IDENTIFIER',
          derivedAtmAccount: 'INVALID_IDENTIFIER',
          hardwareType: DeclinedAtmHardwareType.unknown,
          transactionCount: records.length,
          status: 'INVALID_IDENTIFIER',
          rawRows: records.map((r) => r.rawRow).toList(),
        ));
        return;
      }

      final normDerivedExcessKey = _normalizeAccountKey(derived.excessAccount);

      // Search for match in excessMap
      ExcessAccountDetail? excessDetail = excessMap[normDerivedExcessKey];

      // Also try fuzzy match if length differences, leading zeros, or format variations exist
      if (excessDetail == null) {
        for (final entry in excessMap.entries) {
          final k = entry.key;
          if (k == normDerivedExcessKey ||
              k.endsWith(normDerivedExcessKey) ||
              normDerivedExcessKey.endsWith(k)) {
            excessDetail = entry.value;
            break;
          }
          // Check if same prefix (17643 or 17644) and matching terminal suffix digits
          if (normDerivedExcessKey.length >= 5 && k.length >= 5) {
            final derivedPrefix = normDerivedExcessKey.substring(0, 5);
            final mapPrefix = k.substring(0, 5);
            if (derivedPrefix == mapPrefix) {
              final derivedSuffix = normDerivedExcessKey.length >= 4
                  ? normDerivedExcessKey.substring(normDerivedExcessKey.length - 4)
                  : normDerivedExcessKey;
              final mapSuffix = k.length >= 4 ? k.substring(k.length - 4) : k;
              if (derivedSuffix == mapSuffix) {
                excessDetail = entry.value;
                break;
              }
            }
          }
        }
      }

      if (excessDetail != null) {
        // Matched!
        final matchedKey = _normalizeAccountKey(excessDetail.accountNo);
        matchedExcessKeys.add(matchedKey);

        final double balance = excessDetail.accountBalance;
        final double remaining = balance - totalDeclined;

        double excessDebit = 0.0;
        double atmDebit = 0.0;

        if (remaining >= 0) {
          // If remaining >= 0, debit full amount from excess account
          excessDebit = totalDeclined;
          atmDebit = 0.0;
        } else {
          // If remaining < 0
          if (balance > 0) {
            excessDebit = balance;
            atmDebit = totalDeclined - balance;
          } else {
            // Negative or 0 balance in excess -> debit full amount from ATM account
            excessDebit = 0.0;
            atmDebit = totalDeclined;
          }
        }

        final diffFormula =
            '${currencyFormat.format(balance)} - ${currencyFormat.format(totalDeclined)} = ${currencyFormat.format(remaining)}';

        matched.add(MatchedDeclinedSettlement(
          cardAccId: cardAccId,
          excessAccount: derived.excessAccount,
          excessDebitAmount: excessDebit,
          atmAccount: derived.atmAccount,
          atmDebitAmount: atmDebit,
          excessBalance: balance,
          totalDeclinedAmount: totalDeclined,
          difference: remaining,
          differenceFormula: diffFormula,
          hardwareType: derived.hardwareType,
          status: 'MATCHED',
          customer: excessDetail.customer,
          name: excessDetail.name,
          product: excessDetail.product,
          ccy: excessDetail.ccy,
          accountOfficer: excessDetail.accountOfficer,
          transactionCount: records.length,
          rawExcessRow: excessDetail.rawRow,
          rawDeclinedRows: records.map((r) => r.rawRow).toList(),
        ));
      } else {
        // Declined terminal with generated excess account not found in excess file
        declinedOnly.add(UnmatchedDeclinedRecord(
          cardAccId: cardAccId,
          totalDeclinedAmount: totalDeclined,
          derivedExcessAccount: derived.excessAccount,
          derivedAtmAccount: derived.atmAccount,
          hardwareType: derived.hardwareType,
          transactionCount: records.length,
          status: 'DECLINED_ONLY',
          rawRows: records.map((r) => r.rawRow).toList(),
        ));
      }
    });

    // 4. Identify Unmatched Excess Records
    final List<UnmatchedExcessRecord> excessOnly = [];
    for (final excess in allExcessList) {
      final key = _normalizeAccountKey(excess.accountNo);
      if (!matchedExcessKeys.contains(key)) {
        excessOnly.add(UnmatchedExcessRecord(
          accountNo: excess.accountNo,
          accountBalance: excess.accountBalance,
          customer: excess.customer,
          name: excess.name,
          product: excess.product,
          ccy: excess.ccy,
          accountOfficer: excess.accountOfficer,
          status: 'EXCESS_ONLY',
          rawRow: excess.rawRow,
        ));
      }
    }

    final excessHeaders = excessData.isNotEmpty ? excessData.first.keys.toList() : <String>[];
    final declinedHeaders = declinedData.isNotEmpty ? declinedData.first.keys.toList() : <String>[];

    return ReconDeclinedResult(
      matched: matched,
      excessOnly: excessOnly,
      declinedOnly: declinedOnly,
      excessHeaders: excessHeaders,
      declinedHeaders: declinedHeaders,
    );
  }
}
