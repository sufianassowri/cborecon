import 'package:flutter_test/flutter_test.dart';
import 'package:cborecon/features/disputes/data/datasources/dispute_file_parser.dart';

void main() {
  group('DisputeFileParser 6-line format tests', () {
    const raw6LineInput = '''ETB1764400020478
D
38400
1
Deposit Dispute
Deposit Dispute
ETB1000500020478
D
19800
1
Deposit Dispute
Deposit Dispute
ETB1000500010013
D
1000
1
Deposit Dispute
Deposit Dispute
1051800016565
C
38400
51
Deposit Dispute
Deposit Dispute
1051800016565
C
19800
51
Deposit Dispute
Deposit Dispute
1006300315056
C
1000
51
Deposit Dispute
Deposit Dispute''';

    test('should parse 6-line repeating format into single batch with 6 items', () {
      final result = DisputeFileParser.parseRawText(
        rawText: raw6LineInput,
        fileName: 'Deposit_Dispute_Test.txt',
        makerUsername: 'Sufian_Maker',
      );

      expect(result.items.length, 6);
      expect(result.batch.transactionCount, 6);

      // Debit sum = 38400 + 19800 + 1000 = 59200
      expect(result.batch.totalDebitAmount, 59200.0);

      // Credit sum = 38400 + 19800 + 1000 = 59200
      expect(result.batch.totalCreditAmount, 59200.0);

      // Balanced
      expect(result.batch.isBalanced, true);

      // Check first item (Debit)
      final firstItem = result.items[0];
      expect(firstItem.type, 'D');
      expect(firstItem.debitAcc, 'ETB1764400020478');
      expect(firstItem.amount, 38400.0);
      expect(firstItem.txnCode, '1');
      expect(firstItem.narrative1, 'Deposit Dispute');
      expect(firstItem.recordStatus, 'INAU');
      expect(firstItem.transactionId.startsWith('DC'), true);

      // Check fourth item (Credit)
      final fourthItem = result.items[3];
      expect(fourthItem.type, 'C');
      expect(fourthItem.creditAcc, '1051800016565');
      expect(fourthItem.amount, 38400.0);
      expect(fourthItem.txnCode, '51');
      expect(fourthItem.narrative1, 'Deposit Dispute');
    });
  });
}
