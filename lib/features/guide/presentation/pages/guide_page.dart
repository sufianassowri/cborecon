import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/responsive_shell.dart';

class GuidePage extends ConsumerWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveShell(
      currentRoute: '/guide',
      title: 'User Guide & Documentation',
      subtitle: 'Comprehensive guide for all CBO Recon Modules',
      body: const GuideContent(),
    );
  }
}

class GuideContent extends StatelessWidget {
  const GuideContent({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              isScrollable: true,
              labelColor: CboColors.primaryCyan,
              unselectedLabelColor: CboColors.slateMuted,
              indicatorColor: CboColors.primaryCyan,
              tabs: [
                Tab(text: 'General Overview'),
                Tab(text: 'Cards & Terminals'),
                Tab(text: 'Mobile (Ebirr/Telebirr)'),
                Tab(text: 'Audit & Risk'),
                Tab(text: 'IPS Reconciliation'),
                Tab(text: 'Disputes & Governance'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGuideSection(
                  title: 'General Overview',
                  content: 'Welcome to the CBO Recon Hub. This application is designed to automate and streamline reconciliation processes across various platforms, including ATM/POS terminals, Mobile wallets, IPS, and Dispute Management. Ensure you have the proper Role-Based Access Control (RBAC) permissions to view specific modules.',
                ),
                _buildGuideSection(
                  title: 'Cards & Terminals',
                  content: '''
• CBO ATM/POS Recon: Reconciles CBO's own terminals against core banking data.
• CBE ATM/POS Recon: Reconciles CBE terminals using Batch processing.
• Mastercard Ledger Recon: Converts TSV hub data automatically and performs ledger reconciliation for Mastercard transactions.
''',
                ),
                _buildGuideSection(
                  title: 'Mobile (Ebirr/Telebirr)',
                  content: '''
• Ebirr Reconciliation: Matches wallet transactions against core banking records.
• Telebirr Reconciliation: Performs dual-source reconciliation for Telebirr integrations.
''',
                ),
                _buildGuideSection(
                  title: 'Audit & Risk',
                  content: '''
• Shortage & Excess: Analyzes hardware disparities in cash dispensing.
• Reversal & Tolerance: Mathematically processes auto-reversals and identifies threshold exceptions.
• Remote Dispute Hub: A unified interface to identify and process remote disputes efficiently.
• Declined Transaction Recon: Calculates debit splits between ATMs and excess accounts based on available usable balances.
''',
                ),
                _buildGuideSection(
                  title: 'IPS Reconciliation',
                  content: '''
• IPS 2-File Recon: Standard 2-way reconciliation between IPS and core system.
• IPS Triangular Recon: Complex 3-way reconciliation (e.g. Switch vs Core vs Partner).
''',
                ),
                _buildGuideSection(
                  title: 'Disputes & Governance',
                  content: '''
• Maker: Submits new disputes.
• Manager: Assigns disputes to appropriate teams.
• Checker: Approves or rejects disputes.
• Auditor: Oversees the entire lifecycle.
• Settlement Report Merger: A high-performance utility to cleanly merge massive settlement files.
''',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection({required String title, required String content}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: CboColors.slateDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: CboColors.slateMedium,
            ),
          ),
        ],
      ),
    );
  }
}
