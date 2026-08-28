import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cborecon/features/report_merger/domain/entities/settlement_row_entity.dart';
import 'package:cborecon/features/report_merger/domain/services/settlement_merger_engine.dart';

void main() {
  group('SettlementMergerEngine tests', () {
    const csvFile1 = '''Issuer,Acquirer,MTI,Card_Number,Amount,Currency,Transaction_Date,Transaction_Description,Terminal_ID,Transaction_Place,STAN_F11,Refnum_F37,Authidresp_F38,Fe_utrnno,Bo_utrnno
CBO,CBO,0200,6051800012345678,5000.00,ETB,2026-08-30,ATM CW Transaction Amount,ATM1001,Addis Ababa,110245,423012345678,000123,FE9911223344,BO5566778899
CBO,CBE,0200,6051800087654321,1200.50,ETB,2026-08-28,POS PUR THEM-ON-THEM,POS2002,Adama,110246,423012345679,000124,FE9911223345,BO5566778890

''';

    const csvFile2 = '''Issuer,Acquirer,MTI,Card_Number,Amount,Currency,Transaction_Date,Transaction_Description,Terminal_ID,Transaction_Place,STAN_F11,Refnum_F37,Authidresp_F38,Fe_utrnno,Bo_utrnno
CBO,AWASH,0200,6051800099998888,3400.00,ETB,2026-08-31,Dispute Chargeback Amount,ATM1003,Hawassa,110247,423012345680,000125,FE9911223346,BO5566778891

CBO,CBO,0100,6051800011112222,0.00,ETB,2026-08-29,Balance enquiry,ATM1004,Jimma,110248,423012345681,000126,FE9911223347,BO5566778892
Issuer,Acquirer,MTI,Card_Number,Amount,Currency,Transaction_Date,Transaction_Description,Terminal_ID,Transaction_Place,STAN_F11,Refnum_F37,Authidresp_F38,Fe_utrnno,Bo_utrnno
CBO,CBO,0200,6051800033334444,800.00,ETB,2026-08-28,ATM CW Transaction Amount,ATM1005,Dire Dawa,110249,423012345682,000127,FE9911223348,BO5566778893
''';

    test('should merge multiple files, strip duplicate headers, purge empty rows, sort by date, and categorize by description', () async {
      final file1Bytes = Uint8List.fromList(utf8.encode(csvFile1));
      final file2Bytes = Uint8List.fromList(utf8.encode(csvFile2));

      final files = [
        PlatformFile(name: 'Settlement_Part1.csv', size: file1Bytes.length, bytes: file1Bytes),
        PlatformFile(name: 'Settlement_Part2.csv', size: file2Bytes.length, bytes: file2Bytes),
      ];

      final result = await SettlementMergerEngine.mergeFiles(files: files);

      // Total valid transactions should be 5 (2 from file1, 3 from file2)
      expect(result.allMergedRows.length, 5);
      expect(result.totalFilesProcessed, 2);

      // Duplicate header from file2 and empty rows should be purged
      expect(result.duplicateHeadersRemoved >= 1, true);
      expect(result.emptyRowsPurged >= 2, true);

      // Chronological Sorting verification: 28th should be first, followed by 29th, 30th, 31st
      final dates = result.allMergedRows.map((r) => r.transactionDate).toList();
      expect(dates[0], '2026-08-28');
      expect(dates[1], '2026-08-28');
      expect(dates[2], '2026-08-29');
      expect(dates[3], '2026-08-30');
      expect(dates[4], '2026-08-31');

      // Card Numbers should be preserved exactly
      expect(result.allMergedRows[0].cardNumber, '6051800087654321');
      expect(result.allMergedRows[1].cardNumber, '6051800033334444');

      // Categorized Sheets verification
      expect(result.categorizedSheets.containsKey('ATM_CW'), true);
      expect(result.categorizedSheets['ATM_CW']!.length, 2);

      expect(result.categorizedSheets.containsKey('POS_PUR'), true);
      expect(result.categorizedSheets['POS_PUR']!.length, 1);

      expect(result.categorizedSheets.containsKey('Dispute_Chargeback'), true);
      expect(result.categorizedSheets['Dispute_Chargeback']!.length, 1);

      expect(result.categorizedSheets.containsKey('Balance_Enquiry'), true);
      expect(result.categorizedSheets['Balance_Enquiry']!.length, 1);

      // Total Volume sum = 5000 + 1200.50 + 3400 + 0 + 800 = 10400.50
      expect(result.totalVolumeAmount, 10400.50);
    });
  });
}
