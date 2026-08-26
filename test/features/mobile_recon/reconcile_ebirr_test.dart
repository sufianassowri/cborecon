import 'package:flutter_test/flutter_test.dart';
import 'package:cborecon/features/mobile_recon/domain/entities/mobile_recon_row.dart';
import 'package:cborecon/features/mobile_recon/domain/usecases/reconcile_ebirr_usecase.dart';

void main() {
  group('ReconcileEbirrUseCase', () {
    test('reconciles successfully with exact original matching logic and preserves raw rows', () {
      final useCase = ReconcileEbirrUseCase();

      final cbsData = [
        ['THIRD_PARTY_REFERENCE', 'AMOUNT', 'DATE'],
        ['TXN1001', '500.00', '2026-08-20'],
        ['TXN1002', '300.00', '2026-08-21'],
      ];

      final ebirrData = [
        ['Bank TRANSFERID', 'CREDIT', 'FEE', 'CREDIT'],
        ['TXN1001', '500.00', '5.00', '500.00'],
        ['TXN1003', '700.00', '7.00', '700.00'],
      ];

      final results = useCase(cbsData: cbsData, ebirrData: ebirrData);

      expect(results.length, 3);
      final matched = results.firstWhere((r) => r.key == 'TXN1001');
      expect(matched.status, MobileReconStatus.ok);
      expect(matched.rawCbsRow, ['TXN1001', '500.00', '2026-08-20']);
      expect(matched.rawWalletRow, ['TXN1001', '500.00', '5.00', '500.00']);

      final missingInWallet = results.firstWhere((r) => r.key == 'TXN1002');
      expect(missingInWallet.status, MobileReconStatus.missingInWallet);

      final missingInCbs = results.firstWhere((r) => r.key == 'TXN1003');
      expect(missingInCbs.status, MobileReconStatus.missingInCbs);
    });
  });
}
