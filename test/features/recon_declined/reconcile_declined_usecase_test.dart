import 'package:flutter_test/flutter_test.dart';
import 'package:cborecon/features/recon_declined/domain/entities/recon_declined_models.dart';
import 'package:cborecon/features/recon_declined/domain/usecases/generate_declined_accounts_usecase.dart';
import 'package:cborecon/features/recon_declined/domain/usecases/reconcile_declined_usecase.dart';

void main() {
  group('Hardware Classification & Account Generation Tests', () {
    final classifier = ClassifyDeclinedHardwareUseCase();
    final accountGen = GenerateDeclinedAccountsUseCase();

    test('Classifies CRM terminals correctly', () {
      expect(classifier('WFDC3732'), DeclinedAtmHardwareType.crm);
      expect(classifier.getTypeName(DeclinedAtmHardwareType.crm), 'CRM');
    });

    test('Classifies NCR terminals correctly', () {
      expect(classifier('SFDN4056'), DeclinedAtmHardwareType.ncr);
      expect(classifier('EFDN0073'), DeclinedAtmHardwareType.ncr);
      expect(classifier.getTypeName(DeclinedAtmHardwareType.ncr), 'NCR');
    });

    test('Generates correct CRM accounts for WFDC3732', () {
      final derived = accountGen('WFDC3732');
      expect(derived.isValid, isTrue);
      expect(derived.hardwareType, DeclinedAtmHardwareType.crm);
      expect(derived.excessAccount, 'ETB1764400040732');
      expect(derived.atmAccount, 'ETB1000500040732');
    });

    test('Generates correct NCR accounts for SFDN4056', () {
      final derived = accountGen('SFDN4056');
      expect(derived.isValid, isTrue);
      expect(derived.hardwareType, DeclinedAtmHardwareType.ncr);
      expect(derived.excessAccount, 'ETB1764300050056');
      expect(derived.atmAccount, 'ETB1000200050056');
    });

    test('Generates correct NCR accounts for EFDN0073', () {
      final derived = accountGen('EFDN0073');
      expect(derived.isValid, isTrue);
      expect(derived.hardwareType, DeclinedAtmHardwareType.ncr);
      expect(derived.excessAccount, 'ETB1764300010073');
      expect(derived.atmAccount, 'ETB1000200010073');
    });
  });

  group('ReconcileDeclinedUseCase Business Rules & Calculation Tests', () {
    final useCase = ReconcileDeclinedUseCase();

    test('Reconciles prompt examples 1, 2, 3 with exact debit calculations', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '51,150.00',
          'Customer': 'CUST001',
          'Name': 'Branch A Excess',
          'Product': 'Excess A/C',
          'Ccy': 'ETB',
          'Account Officer': 'Officer 1',
        },
        {
          'Account No': 'ETB1764300050056',
          'Account Balance': '9,000.00',
          'Customer': 'CUST002',
          'Name': 'Branch B Excess',
          'Product': 'Excess A/C',
          'Ccy': 'ETB',
          'Account Officer': 'Officer 2',
        },
        {
          'Account No': 'ETB1764300010073',
          'Account Balance': '3,200.00',
          'Customer': 'CUST003',
          'Name': 'Branch C Excess',
          'Product': 'Excess A/C',
          'Ccy': 'ETB',
          'Account Officer': 'Officer 3',
        },
      ];

      final declinedData = [
        {
          'CARD.ACC.ID': 'WFDC3732',
          'TXN.AMOUNT': '51150.00',
        },
        {
          'CARD.ACC.ID': 'SFDN4056',
          'TXN.AMOUNT': '10000.00',
        },
        {
          'CARD.ACC.ID': 'EFDN0073',
          'TXN.AMOUNT': '1200.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 3);
      expect(result.excessOnly.length, 0);
      expect(result.declinedOnly.length, 0);

      // Example 1: WFDC3732
      final m1 = result.matched.firstWhere((m) => m.cardAccId == 'WFDC3732');
      expect(m1.excessAccount, 'ETB1764400040732');
      expect(m1.excessDebitAmount, 51100.00);
      expect(m1.atmAccount, 'ETB1000500040732');
      expect(m1.atmDebitAmount, 50.00);
      expect(m1.difference, 0.00);

      // Example 2: SFDN4056
      final m2 = result.matched.firstWhere((m) => m.cardAccId == 'SFDN4056');
      expect(m2.excessAccount, 'ETB1764300050056');
      expect(m2.excessDebitAmount, 9000.00);
      expect(m2.atmAccount, 'ETB1000200050056');
      expect(m2.atmDebitAmount, 1000.00);
      expect(m2.difference, -1000.00);

      // Example 3: EFDN0073
      final m3 = result.matched.firstWhere((m) => m.cardAccId == 'EFDN0073');
      expect(m3.excessAccount, 'ETB1764300010073');
      expect(m3.excessDebitAmount, 1200.00);
      expect(m3.atmAccount, 'ETB1000200010073');
      expect(m3.atmDebitAmount, 0.00);
      expect(m3.difference, 2000.00);
    });

    test('Correctly routes 100% debit to ATM account when Excess balance <= 0', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '-500.00',
        },
        {
          'Account No': 'ETB1764300050056',
          'Account Balance': '0.00',
        },
      ];

      final declinedData = [
        {
          'CARD.ACC.ID': 'WFDC3732',
          'TXN.AMOUNT': '2000.00',
        },
        {
          'CARD.ACC.ID': 'SFDN4056',
          'TXN.AMOUNT': '1500.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 2);

      final m1 = result.matched.firstWhere((m) => m.cardAccId == 'WFDC3732');
      expect(m1.excessDebitAmount, 0.00);
      expect(m1.atmDebitAmount, 2000.00);
      expect(m1.difference, -2500.00);

      final m2 = result.matched.firstWhere((m) => m.cardAccId == 'SFDN4056');
      expect(m2.excessDebitAmount, 0.00);
      expect(m2.atmDebitAmount, 1500.00);
      expect(m2.difference, -1500.00);
    });

    test('Aggregates multiple detail rows for the same CARD.ACC.ID correctly', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '5000.00',
        },
      ];

      final declinedData = [
        {
          'TRANS.REF': 'FT21001',
          'VALUE.DATE': '2026-08-01',
          'DEBIT.ACCT.NO': '10001',
          'CREDIT.ACCT.NO': '20001',
          'TXN.AMOUNT': '1000.00',
          'CARD.ACC.ID': 'WFDC3732',
          'RETRIEVAL.REF.NO': '123456',
        },
        {
          'TRANS.REF': 'FT21002',
          'VALUE.DATE': '2026-08-01',
          'DEBIT.ACCT.NO': '10001',
          'CREDIT.ACCT.NO': '20001',
          'TXN.AMOUNT': '2000.00',
          'CARD.ACC.ID': 'WFDC3732',
          'RETRIEVAL.REF.NO': '123457',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 1);
      final m = result.matched.first;
      expect(m.totalDeclinedAmount, 3000.00);
      expect(m.excessDebitAmount, 3000.00);
      expect(m.atmDebitAmount, 0.00);
      expect(m.difference, 2000.00);
      expect(m.transactionCount, 2);
    });

    test('Separates unmatched records into excessOnly and declinedOnly', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '5000.00',
          'Customer': 'EXCESS_UNMATCHED',
        },
      ];

      final declinedData = [
        {
          'CARD.ACC.ID': 'SFDN4056', // Derived: ETB1764300050056 (not in excessData)
          'TXN.AMOUNT': '4000.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 0);
      expect(result.excessOnly.length, 1);
      expect(result.excessOnly.first.accountNo, 'ETB1764400040732');
      expect(result.declinedOnly.length, 1);
      expect(result.declinedOnly.first.cardAccId, 'SFDN4056');
      expect(result.declinedOnly.first.totalDeclinedAmount, 4000.00);
    });

    test('Handles pivot report uploaded with CREDIT.ACCT.NO (ATM Account number)', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '51150.00',
        },
        {
          'Account No': 'ETB1764300050056',
          'Account Balance': '9000.00',
        },
      ];

      final declinedData = [
        {
          'CREDIT.ACCT.NO': 'ETB1000500040732',
          'TXN.AMOUNT': '51150.00',
        },
        {
          'CREDIT.ACCT.NO': 'ETB1000200050056',
          'TXN.AMOUNT': '10000.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 2);
      final m1 = result.matched.firstWhere((m) => m.excessAccount == 'ETB1764400040732');
      expect(m1.excessDebitAmount, 51100.00);
      expect(m1.atmDebitAmount, 50.00);

      final m2 = result.matched.firstWhere((m) => m.excessAccount == 'ETB1764300050056');
      expect(m2.excessDebitAmount, 9000.00);
      expect(m2.atmDebitAmount, 1000.00);
    });

    test('Filters out Grand Total summary rows automatically', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '50000.00',
        },
        {
          'Account No': 'Grand Total',
          'Account Balance': '50000.00',
        },
      ];

      final declinedData = [
        {
          'CARD.ACC.ID': 'WFDC3732',
          'TXN.AMOUNT': '5000.00',
        },
        {
          'CARD.ACC.ID': 'Grand Total',
          'TXN.AMOUNT': '5000.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 1);
      expect(result.excessOnly.length, 0);
      expect(result.declinedOnly.length, 0);
    });

    test('Handles headerless pivot table with synthetic columns (COL_0, COL_1)', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '50000.00',
        },
      ];

      final declinedData = [
        {
          'COL_0': 'WFDC3732',
          'COL_1': '5000.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 1);
      expect(result.matched.first.excessDebitAmount, 5000.00);
    });

    test('Generates 2-column Debitable Accounts list (DebitAccount, debitAmount) for Excess and ATM accounts', () {
      final excessData = [
        {
          'Account No': 'ETB1764400040732',
          'Account Balance': '51150.00', // covers full 51150
        },
        {
          'Account No': 'ETB1764300050056',
          'Account Balance': '9000.00', // partial: 9000 excess, 1000 ATM
        },
        {
          'Account No': 'ETB1764300010073',
          'Account Balance': '0.00', // zero balance: 0 excess, 1200 ATM
        },
      ];

      final declinedData = [
        {
          'CARD.ACC.ID': 'WFDC3732',
          'TXN.AMOUNT': '51150.00',
        },
        {
          'CARD.ACC.ID': 'SFDN4056',
          'TXN.AMOUNT': '10000.00',
        },
        {
          'CARD.ACC.ID': 'EFDN0073',
          'TXN.AMOUNT': '1200.00',
        },
      ];

      final result = useCase(excessData, declinedData);

      expect(result.matched.length, 3);
      final debitables = result.debitableAccounts;

      // Expecting 5 debit entries sorted by terminal last 5 digits (10073 < 40732 < 50056):
      // 1. EFDN0073 -> ATM ETB1000200010073 : 1200.00 (last 5: 10073)
      // 2. WFDC3732 -> Excess ETB1764400040732 : 51100.00 (last 5: 40732)
      // 3. WFDC3732 -> ATM ETB1000500040732 : 50.00 (last 5: 40732)
      // 4. SFDN4056 -> Excess ETB1764300050056 : 9000.00 (last 5: 50056, Excess first)
      // 5. SFDN4056 -> ATM ETB1000200050056 : 1000.00 (last 5: 50056, ATM second)
      expect(debitables.length, 5);

      expect(debitables[0].debitAccount, 'ETB1000200010073');
      expect(debitables[0].debitAmount, 1200.00);

      expect(debitables[1].debitAccount, 'ETB1764400040732');
      expect(debitables[1].debitAmount, 51100.00);

      expect(debitables[2].debitAccount, 'ETB1000500040732');
      expect(debitables[2].debitAmount, 50.00);

      expect(debitables[3].debitAccount, 'ETB1764300050056');
      expect(debitables[3].debitAmount, 9000.00);

      expect(debitables[4].debitAccount, 'ETB1000200050056');
      expect(debitables[4].debitAmount, 1000.00);

      expect(result.totalDebitableAccountsCount, 5);
      expect(result.totalDebitableAmount, 51100.00 + 50.00 + 10000.00 + 1200.00);
    });

    test('Debitable accounts on same terminal (Excess and ATM) are placed one after another sorted by terminal', () {
      final excessData = [
        {
          'Account No': 'ETB1764300080123',
          'Account Balance': '3000.00',
        },
        {
          'Account No': 'ETB1764400020456',
          'Account Balance': '4000.00',
        },
      ];

      final declinedData = [
        {
          'CARD.ACC.ID': 'SFDN7123', // suffix 80123 -> partial excess 3000, atm 2000
          'TXN.AMOUNT': '5000.00',
        },
        {
          'CARD.ACC.ID': 'WFDC1456', // suffix 20456 -> partial excess 4000, atm 1000
          'TXN.AMOUNT': '5000.00',
        },
      ];

      final result = useCase(excessData, declinedData);
      final debitables = result.debitableAccounts;

      expect(debitables.length, 4);

      // Suffix 20456 comes first (terminal WFDC1456)
      expect(debitables[0].debitAccount, 'ETB1764400020456'); // Excess
      expect(debitables[0].debitAmount, 4000.00);
      expect(debitables[1].debitAccount, 'ETB1000500020456'); // ATM
      expect(debitables[1].debitAmount, 1000.00);

      // Suffix 80123 comes second (terminal SFDN7123)
      expect(debitables[2].debitAccount, 'ETB1764300080123'); // Excess
      expect(debitables[2].debitAmount, 3000.00);
      expect(debitables[3].debitAccount, 'ETB1000200080123'); // ATM
      expect(debitables[3].debitAmount, 2000.00);
    });
  });
}
