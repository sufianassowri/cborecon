import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/dashboard/presentation/screens/omni_recon_dashboard.dart';
import 'features/terminal_recon/presentation/pages/cbo_terminal_recon_page.dart';
import 'features/terminal_recon/presentation/pages/cbe_terminal_recon_page.dart';
import 'features/mobile_recon/presentation/pages/ebirr_recon_page.dart';
import 'features/mobile_recon/presentation/pages/telebirr_recon_page.dart';
import 'features/ips_recon/presentation/pages/ips_two_recon_page.dart';
import 'features/ips_recon/presentation/pages/ips_triangular_recon_page.dart';
import 'features/admin/presentation/pages/user_management_page.dart';
import 'features/shortage_excess/presentation/screens/shortage_excess_dashboard.dart';
import 'features/reversal_recon/presentation/screens/reversal_recon_screen.dart';
import 'features/disputes/presentation/screens/maker_form_screen.dart';
import 'features/disputes/presentation/screens/checker_review_screen.dart';
import 'features/disputes/presentation/screens/dispute_checker_view.dart';
import 'features/disputes/presentation/screens/dispute_auditor_view.dart';
import 'features/disputes/disputememo/presentation/views/dispute_memo_page.dart';
import 'features/remote_disputeutility/presentation/pages/remote_dispute_utility_page.dart';
import 'features/master_card/tsv_processor_page.dart';
import 'features/recon_declined/presentation/screens/recon_declined_dashboard.dart';
import 'features/remote_dispute_identification/presentation/screens/remote_dispute_identification_dashboard.dart';
import 'features/mastercard_reconciliation/presentation/widgets/reconciliation_data_grid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Parse().initialize(
    AppConstants.parseAppId,
    AppConstants.parseServerUrl,
    clientKey: AppConstants.parseClientKey,
    autoSendSessionId: true,
    debug: false,
  );
  await _ensureMasterCardTableExists();
  runApp(const ProviderScope(child: CboOmniReconApp()));
}
Future<void> _ensureMasterCardTableExists() async {
  try {
    final query = QueryBuilder<ParseObject>(
        ParseObject(AppConstants.tableMasterCardAccount))
      ..setLimit(1);
    final response = await query.query();
    if (response.success &&
        (response.results == null || response.results!.isEmpty)) {
      final initObj = ParseObject(AppConstants.tableMasterCardAccount)
        ..set('clientId', 'SYSTEM_INIT')
        ..set('pan', '000000******0000')
        ..set('totalTopUp', 0.0)
        ..set('totalUsed', 0.0)
        ..set('currentBalance', 0.0);
      final saveResponse = await initObj.save();
      if (saveResponse.success) {
        await initObj.delete();
      }
    }
  } catch (e) {
    debugPrint("Back4App Table Auto-Check Notice: $e");
  }
}

class CboOmniReconApp extends ConsumerWidget {
  const CboOmniReconApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '${AppConstants.appName} - ${AppConstants.bankName}',
      theme: AppTheme.lightTheme,
      initialRoute: '/auth_check',
      routes: {
        '/auth_check': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/admin/users': (context) => const UserManagementPage(),
        '/': (context) => const OmniReconDashboard(),

        // Modern Feature Routes
        '/terminal_cbo': (context) => const CboTerminalReconPage(),
        '/terminal_cbe': (context) => const CbeTerminalReconPage(),
        '/mobile_ebirr': (context) => const EbirrReconPage(),
        '/mobile_telebirr': (context) => const TelebirrReconPage(),
        '/ips_two': (context) => const IpsTwoReconPage(),
        '/ips_triangular': (context) => const IpsTriangularReconPage(),
        '/shortage_excess': (context) => const ShortageExcessDashboard(),
        '/reversal_recon': (context) => const ReversalReconScreen(),
        '/dispute_maker': (context) => MakerFormScreen(),
        '/dispute_checker': (context) => CheckerPanelScreen(),
        '/dispute_auditor': (context) => DisputeAuditorView(),
        '/dispute_memo': (context) => const DisputeMemoPage(),
        '/remote_dispute_utility': (context) =>
            const RemoteDisputeUtilityPage(),
        '/mastercard_hub': (context) => const TsvProcessorPage(),
        '/mastercard_reconciliation': (context) =>
            const ReconciliationDataGrid(),
        '/recon_declined': (context) => const ReconDeclinedDashboard(),
        '/mastercard_recon': (context) => const ReconciliationDataGrid(),
        '/remote_dispute_identification': (context) =>
            const RemoteDisputeIdentificationDashboard(),

        // Backward-Compatibility Aliases
        '/pos': (context) => const CboTerminalReconPage(),
        '/cbepos': (context) => const CbeTerminalReconPage(),
        '/ebirr': (context) => const EbirrReconPage(),
        '/ips': (context) => const IpsTriangularReconPage(),
        '/ipstwo': (context) => const IpsTwoReconPage(),
        '/telebir': (context) => const TelebirrReconPage(),
        '/disputeMaker': (context) => MakerFormScreen(),
        '/disputeChecker': (context) => CheckerPanelScreen(),
        '/checker': (context) => DisputeCheckerView(),
        '/auditor': (context) => DisputeAuditorView(),
        '/sytemessue': (context) => const ShortageExcessDashboard(),
        '/mastercard': (context) => const ReconciliationDataGrid(),
        '/onusdisputememo': (context) => const DisputeMemoPage(),
        '/reversalmatcher': (context) => const ReversalReconScreen(),
        '/remote_disputeutility': (context) => const RemoteDisputeUtilityPage(),
      },
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    return authState.when(
      data: (user) {
        if (user != null) {
          return const OmniReconDashboard();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginScreen(),
    );
  }
}
