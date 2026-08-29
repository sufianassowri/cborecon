import 'package:flutter_test/flutter_test.dart';
import 'package:cborecon/features/remote_disputeutility/domain/entities/remote_dispute_models.dart';
import 'package:cborecon/features/remote_disputeutility/domain/usecases/bank_name_matcher.dart';
import 'package:cborecon/features/remote_disputeutility/domain/usecases/identify_remote_disputes_usecase.dart';

void main() {
  group('BankNameMatcher Tests', () {
    test('Correctly matches bank aliases to canonical names', () {
      expect(BankNameMatcher.isBankMatch('CBE ETS SETTL', 'Commercial Bank of Ethiopia'), isTrue);
      expect(BankNameMatcher.isBankMatch('ABYSSINIA', 'Bank of Abyssinia S.C'), isTrue);
      expect(BankNameMatcher.isBankMatch('DASHEN', 'Dashen Bank'), isTrue);
      expect(BankNameMatcher.isBankMatch('COOP', 'Cooperative Bank of Oromia'), isTrue);
      expect(BankNameMatcher.isBankMatch('AWASH', 'Awash International Bank'), isTrue);
      expect(BankNameMatcher.isBankMatch('HIBRET', 'United Bank'), isTrue);
      expect(BankNameMatcher.isBankMatch('SIINQEE', 'Sinqee Bank'), isTrue);
      expect(BankNameMatcher.isBankMatch('ZAMZAM', 'ZamZam Bank'), isTrue);
    });

    test('Automatically aligns bank names when RRN matches', () {
      expect(BankNameMatcher.isBankMatch('Unknown Branch Code', 'Commercial Bank of Ethiopia', rrnMatched: true), isTrue);
    });

    test('Distinguishes different banks', () {
      expect(BankNameMatcher.isBankMatch('DASHEN', 'Awash Bank'), isFalse);
      expect(BankNameMatcher.isBankMatch('CBE', 'Bank of Abyssinia'), isFalse);
    });
  });

  group('IdentifyRemoteDisputesUseCase Reconciliation Tests', () {
    final useCase = IdentifyRemoteDisputesUseCase();

    test('First Priority Matching (Full Match: PAN last 4 + RRN + Amount + Bank)', () {
      final cbsData = [
        {
          'TRANS.REF': 'FT2621101WRK',
          'PAN.NUMBER': '923141******7444',
          'VALUE.DATE': '20260730',
          'DEBIT.ACCT.NO': '1000028608172',
          'Customer': 'Adugna Balcha Mengesha',
          'Acquirer Bank': 'CBE ETS SETTL',
          'Branch': 'Branch',
          'TXN.AMOUNT': '2000',
          'RETRIEVAL.REF.NO': '394123456789',
        },
      ];

      final settlementData = [
        {
          'Issuer': 'Commercial Bank of Ethiopia',
          'Acquirer': 'Commercial Bank of Ethiopia',
          'MTI': '1442',
          'Card_Number': '923141******7444',
          'Amount': '2000.00',
          'Currency': 'ETB',
          'Transaction_Date': '30.07.2026 12:10:44',
          'Transaction_Description': 'Dispute Chargeback Amount',
          'Terminal_ID': 'AYK00087',
          'Transaction_Place': 'AYK000871ETH ADDIS AB',
          'STAN_F11': '2351',
          'Refnum_F37': '394123456789',
          'Authidresp_F38': '75301',
          'Fe_utrnno': '2719458224',
          'Bo_utrnno': '103538806401',
        },
      ];

      final result = useCase(cbsRawData: cbsData, settlementRawData: settlementData);

      expect(result.matchedRows.length, 1);
      expect(result.mismatchRows.length, 0);
      expect(result.missedRows.length, 0);
      expect(result.candidateRows.length, 0);

      final row = result.matchedRows.first;
      expect(row.status, RemoteDisputeStatus.matched);
      expect(row.isPrioritized, isTrue);
      expect(row.cbs?.transRef, 'FT2621101WRK');
      expect(row.settlement?.feUtrnno, '2719458224');
      expect(row.cbs?.txnAmount, 2000.0);
      expect(row.settlement?.amount, 2000.0);
    });

    test('Amount Mismatch Detection (PAN/RRN match but Amount differs)', () {
      final cbsData = [
        {
          'TRANS.REF': 'FT262110B4TR',
          'PAN.NUMBER': '424312******1010',
          'VALUE.DATE': '20260730',
          'DEBIT.ACCT.NO': '1063500156107',
          'Customer': 'Chala Tesfaye Gurmesa',
          'Acquirer Bank': 'CBE ETS SETTL',
          'Branch': 'ET0010635',
          'TXN.AMOUNT': '500',
          'RETRIEVAL.REF.NO': '46830001',
        },
      ];

      final settlementData = [
        {
          'Issuer': 'Commercial Bank of Ethiopia',
          'Acquirer': 'Commercial Bank of Ethiopia',
          'Card_Number': '424312******1010',
          'Amount': '200.00', // Amount differs
          'Refnum_F37': '46830001',
          'Fe_utrnno': '2719458225',
        },
      ];

      final result = useCase(cbsRawData: cbsData, settlementRawData: settlementData);

      expect(result.matchedRows.length, 0);
      expect(result.mismatchRows.length, 1);
      expect(result.mismatchRows.first.status, RemoteDisputeStatus.mismatch);
      expect(result.mismatchRows.first.cbs?.txnAmount, 500.0);
      expect(result.mismatchRows.first.settlement?.amount, 200.0);
    });

    test('Candidate Unreported Duplicate Error Detection (Empty CBS Side)', () {
      // Customer reported 1 transaction of 2000 ETB for card ending 7444
      final cbsData = [
        {
          'TRANS.REF': 'FT2621101WRK',
          'PAN.NUMBER': '923141******7444',
          'Acquirer Bank': 'CBE ETS SETTL',
          'TXN.AMOUNT': '2000',
          'RETRIEVAL.REF.NO': '394123456789',
        },
      ];

      // Settlement contains the matched transaction + another duplicate transaction of 2000 ETB for same card!
      final settlementData = [
        {
          'Acquirer': 'Commercial Bank of Ethiopia',
          'Card_Number': '923141******7444',
          'Amount': '2000.00',
          'Refnum_F37': '394123456789',
          'Fe_utrnno': '2719458224',
        },
        {
          'Acquirer': 'Commercial Bank of Ethiopia',
          'Card_Number': '923141******7444',
          'Amount': '2000.00',
          'Refnum_F37': '394123999999', // Different RRN (duplicate failed attempt)
          'Fe_utrnno': '2719458229',
        },
      ];

      final result = useCase(cbsRawData: cbsData, settlementRawData: settlementData);

      expect(result.matchedRows.length, 1);
      expect(result.candidateRows.length, 1);

      final candidate = result.candidateRows.first;
      expect(candidate.status, RemoteDisputeStatus.candidate);
      expect(candidate.cbs, isNotNull);
      expect(candidate.cbs?.transRef, '');
      expect(candidate.cbs?.panNumber, '923141******7444');
      expect(candidate.cbs?.txnAmount, 0.0);
      expect(candidate.cbs?.retrievalRefNo, '');
      expect(candidate.settlement?.feUtrnno, '2719458229');
      expect(candidate.settlement?.amount, 2000.0);
      expect(candidate.isPrioritized, isTrue);
    });

    test('Missed CBS Disputes (No match in settlement)', () {
      final cbsData = [
        {
          'TRANS.REF': 'FT262110HM63',
          'PAN.NUMBER': '424312******4211',
          'Acquirer Bank': 'CBE ETS SETTL',
          'TXN.AMOUNT': '4000',
          'RETRIEVAL.REF.NO': '60599999',
        },
      ];

      final settlementData = <Map<String, dynamic>>[];

      final result = useCase(cbsRawData: cbsData, settlementRawData: settlementData);

      expect(result.missedRows.length, 1);
      final missed = result.missedRows.first;
      expect(missed.status, RemoteDisputeStatus.missed);
      expect(missed.cbs?.transRef, 'FT262110HM63');
      expect(missed.settlement, isNull);
    });

    test('Clusters and sorts all transactions by PAN together', () {
      final cbsData = [
        {
          'TRANS.REF': 'FT001',
          'PAN.NUMBER': '923141******9506',
          'Acquirer Bank': 'CBE ETS SETTL',
          'TXN.AMOUNT': '3000',
          'RETRIEVAL.REF.NO': '1111',
        },
        {
          'TRANS.REF': 'FT002',
          'PAN.NUMBER': '923141******7444',
          'Acquirer Bank': 'CBE ETS SETTL',
          'TXN.AMOUNT': '2000',
          'RETRIEVAL.REF.NO': '2222',
        },
      ];

      final settlementData = [
        {
          'Acquirer': 'Commercial Bank of Ethiopia',
          'Card_Number': '923141******9506',
          'Amount': '3000.00',
          'Refnum_F37': '1111',
          'Fe_utrnno': 'FE001',
        },
        {
          'Acquirer': 'Commercial Bank of Ethiopia',
          'Card_Number': '923141******7444',
          'Amount': '2000.00',
          'Refnum_F37': '2222',
          'Fe_utrnno': 'FE002',
        },
      ];

      final result = useCase(cbsRawData: cbsData, settlementRawData: settlementData);

      expect(result.allRows.length, 2);
      expect(result.allRows[0].panKey, '7444');
      expect(result.allRows[1].panKey, '9506');
    });
  });
}
