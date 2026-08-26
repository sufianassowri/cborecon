import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../../core/widgets/cbo_metric_card.dart';

class OmniReconDashboard extends ConsumerStatefulWidget {
  const OmniReconDashboard({super.key});

  @override
  ConsumerState<OmniReconDashboard> createState() => _OmniReconDashboardState();
}

class _OmniReconDashboardState extends ConsumerState<OmniReconDashboard> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Terminals',
    'Mobile',
    'IPS',
    'Audit & Risk',
    'Cards',
  ];

  final List<_OmniModuleData> _modules = const [
    _OmniModuleData(
      title: 'CBO ATM/POS Recon',
      subtitle: 'CBS vs Switch Settlement reconciliation by RRN',
      icon: Icons.atm_rounded,
      color: CboColors.primaryCyan,
      route: '/terminal_cbo',
      category: 'Terminals',
      badge: 'Core Engine',
      description: 'Pairs core banking entries against Switch transaction logs using RRN with discrepancy isolation.',
    ),
    _OmniModuleData(
      title: 'CBE ATM/POS Recon',
      subtitle: 'Multi-settlement batch pairing with PAN & Amount verification',
      icon: Icons.credit_card_rounded,
      color: Color(0xFF00838F),
      route: '/terminal_cbe',
      category: 'Terminals',
      badge: 'Multi-Batch',
      description: 'Matches cross-bank transactions against CBE settlement batches with masked PAN validation.',
    ),
    _OmniModuleData(
      title: 'Ebirr Reconciliation',
      subtitle: 'CBS ledger vs Ebirr statement automated sync',
      icon: Icons.phone_android_rounded,
      color: CboColors.bankGreen,
      route: '/mobile_ebirr',
      category: 'Mobile',
      badge: 'Wallet Sync',
      description: 'Reconciles mobile wallet deposits, transfers, and merchant disbursements with CBS statements.',
    ),
    _OmniModuleData(
      title: 'Telebirr Reconciliation',
      subtitle: 'CashIn & CashOut dual-mode matching engine',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF6A1B9A),
      route: '/mobile_telebirr',
      category: 'Mobile',
      badge: 'Dual-Mode',
      description: 'Bi-directional financial reconciliation for Ethio Telecom Telebirr super-app transactions.',
    ),
    _OmniModuleData(
      title: 'IPS Two-File Recon',
      subtitle: 'IPS portal transaction reports vs settlement files',
      icon: Icons.rule_folder_rounded,
      color: Color(0xFF283593),
      route: '/ips_two',
      category: 'IPS',
      badge: '2-Way',
      description: 'Direct 2-way comparison between EthSwitch IPS portal exports and internal settlement ledgers.',
    ),
    _OmniModuleData(
      title: 'IPS 3-Way Triangular Recon',
      subtitle: 'Ebirr CBS, partner settlement, & general ledger triangular validation',
      icon: Icons.account_tree_rounded,
      color: Color(0xFF1565C0),
      route: '/ips_triangular',
      category: 'IPS',
      badge: 'Triangular',
      description: '3-Way triangular reconciliation linking CBS ledger, partner statement, and switch clearing file.',
    ),
    _OmniModuleData(
      title: 'Dispute Management',
      subtitle: 'Maker, Checker & Auditor multi-tier governance lifecycle',
      icon: Icons.gavel_rounded,
      color: CboColors.accentGold,
      route: '/dispute_maker',
      category: 'Audit & Risk',
      badge: 'Governance',
      description: 'Enterprise 3-tier lifecycle management for customer transaction claims, reversals, and audit approvals.',
    ),
    _OmniModuleData(
      title: 'Withdrawal Dispute Memo',
      subtitle: 'ATM.ENQ log synthesis & official GL memorandum generator',
      icon: Icons.note_add_rounded,
      color: Color(0xFF00796B),
      route: '/dispute_memo',
      category: 'Audit & Risk',
      badge: 'Accounting',
      description: 'Generates official accounting dispute memos and credit/debit GL slips directly from ENQ logs.',
    ),
    _OmniModuleData(
      title: 'Shortage & Excess Tracker',
      subtitle: 'Hardware classification (NCR/CRM) & GL account derivation',
      icon: Icons.sync_problem_rounded,
      color: Color(0xFFD84315),
      route: '/shortage_excess',
      category: 'Audit & Risk',
      badge: 'Hardware GL',
      description: 'Identifies ATM hardware discrepancies (NCR vs CRM) and auto-derives the respective GL accounts.',
    ),
    _OmniModuleData(
      title: 'Reversal & Interchange Matcher',
      subtitle: 'Tolerance-based matching with 0.46%-0.60% commission detection',
      icon: Icons.published_with_changes_rounded,
      color: Color(0xFFAD1457),
      route: '/reversal_recon',
      category: 'Audit & Risk',
      badge: 'Tolerance',
      description: 'Tolerance matching engine calculating interchange commission rates and detecting reversal lags.',
    ),
    _OmniModuleData(
      title: 'Remote Dispute Utility',
      subtitle: 'Multi-criteria matching with dynamic settlement header mapper',
      icon: Icons.tune_rounded,
      color: Color(0xFF00897B),
      route: '/remote_dispute_utility',
      category: 'Audit & Risk',
      badge: 'Utility',
      description: 'Flexible header mapping and multi-criteria comparison engine for arbitrary settlement formats.',
    ),
    _OmniModuleData(
      title: 'Declined Transaction Recon',
      subtitle: 'Excess & Cash at ATM multi-hardware settlement debit calculation',
      icon: Icons.assignment_late_rounded,
      color: Color(0xFF00695C),
      route: '/recon_declined',
      category: 'Audit & Risk',
      badge: 'Settlement',
      description: 'Calculates debit splits across Excess and ATM GLs for declined transactions based on NCR & CRM hardware.',
    ),
    _OmniModuleData(
      title: 'Remote Dispute Identification',
      subtitle: 'Cross-bank card dispute matcher & unreported error detection',
      icon: Icons.find_in_page_rounded,
      color: Color(0xFF00838F),
      route: '/remote_dispute_identification',
      category: 'Audit & Risk',
      badge: 'Disputes',
      description: 'Matches CBS dispute extracts with settlement journals, normalizes 28+ bank names, and catches unreported duplicate errors.',
    ),
    _OmniModuleData(
      title: 'Mastercard Settlement Hub',
      subtitle: 'TSV parser, balance projection & overdraft risk monitoring',
      icon: Icons.payment_rounded,
      color: Color(0xFF4527A0),
      route: '/mastercard_hub',
      category: 'Cards',
      badge: 'Settlement',
      description: 'Processes bulk TSV/ZIP files, tracks international cardholder balances, and models overdraft risks.',
    ),
    _OmniModuleData(
      title: 'Mastercard Ledger Recon',
      subtitle: 'Cardholder balance projection, variance & overdraft risk monitor',
      icon: Icons.pie_chart_rounded,
      color: Color(0xFF388E3C),
      route: '/mastercard_reconciliation',
      category: 'Cards',
      badge: 'Ledger',
      description: 'Reconciles cardholder top-up allocations against clearing TSV transaction logs, computing balance variances and overdraft risks.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _modules.where((m) {
      final matchesCat = _selectedCategory == 'All' || m.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesQuery = m.title.toLowerCase().contains(q) ||
          m.subtitle.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();

    return ResponsiveShell(
      currentRoute: '/',
      title: 'Executive OmniRecon Command Center',
      subtitle: 'Enterprise Reconciliation & Multi-Channel Clearing Hub',
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 3;
          double childAspectRatio = 1.5;

          if (constraints.maxWidth < 650) {
            crossAxisCount = 1;
            childAspectRatio = 1.8;
          } else if (constraints.maxWidth < 1000) {
            crossAxisCount = 2;
            childAspectRatio = 1.5;
          } else if (constraints.maxWidth < 1400) {
            crossAxisCount = 3;
            childAspectRatio = 1.45;
          } else {
            crossAxisCount = 4;
            childAspectRatio = 1.4;
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Futuristic Top Metric HUD
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HUD Quick Metrics
                      _buildMetricHud(constraints.maxWidth, filteredCount: filtered.length, totalCount: _modules.length),
                      const SizedBox(height: 24),
                      // Search and Filter Bar
                      _buildSearchAndFilters(),
                    ],
                  ),
                ),
              ),

              // Module Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                sliver: filtered.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48.0),
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded, size: 56, color: CboColors.slateLight),
                                const SizedBox(height: 12),
                                Text(
                                  'No reconciliation engines found for "$_searchQuery"',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CboColors.slateMedium),
                                ),
                                const SizedBox(height: 6),
                                const Text('Try clearing your search query or switching category filter.', style: TextStyle(color: CboColors.slateMuted)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final module = filtered[index];
                            return _buildModuleCard(context, module);
                          },
                          childCount: filtered.length,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricHud(double screenWidth, {required int filteredCount, required int totalCount}) {
    final isFiltered = filteredCount != totalCount;
    final engineVal = isFiltered ? '$filteredCount / $totalCount Systems' : '$totalCount ${totalCount == 1 ? 'System' : 'Systems'}';
    final engineSub = isFiltered ? '$filteredCount Filtered' : '100% Operational';

    final metrics = [
      CboMetricCard(
        title: 'Active Recon Engines',
        value: engineVal,
        subtitle: engineSub,
        icon: Icons.hub_rounded,
        color: CboColors.primaryCyan,
      ),
      const CboMetricCard(
        title: 'Settlement Gateways',
        value: '5 Gateways',
        subtitle: 'CBO • CBE • EthSwitch • Ebirr • Telebirr',
        icon: Icons.account_balance_rounded,
        color: Color(0xFF00838F),
      ),
      const CboMetricCard(
        title: 'Governance Lifecycle',
        value: '3-Tier Active',
        subtitle: 'Maker • Checker • Auditor',
        icon: Icons.shield_rounded,
        color: CboColors.accentGold,
      ),
      const CboMetricCard(
        title: 'Card Settlement',
        value: 'Mastercard TSV',
        subtitle: 'Live Multi-Currency Matrix',
        icon: Icons.credit_card_rounded,
        color: Color(0xFF4527A0),
      ),
    ];

    if (screenWidth < 600) {
      return Column(
        children: metrics.map((m) => Padding(padding: const EdgeInsets.only(bottom: 10), child: m)).toList(),
      );
    } else if (screenWidth < 1100) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: metrics[0]),
              const SizedBox(width: 12),
              Expanded(child: metrics[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: metrics[2]),
              const SizedBox(width: 12),
              Expanded(child: metrics[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < metrics.length; i++) ...[
          Expanded(child: metrics[i]),
          if (i < metrics.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search reconciliation engines, formats, or channels...',
                    hintStyle: const TextStyle(fontSize: 13, color: CboColors.slateMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: CboColors.primaryCyan),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: CboColors.primaryCyan,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : CboColors.slateDark,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? CboColors.primaryCyan : CboColors.cardBorder,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(BuildContext context, _OmniModuleData module) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(module.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(module.icon, color: module.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: CboColors.slateDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.category,
                      style: TextStyle(
                        color: module.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (module.badge != null)
                Flexible(
                  flex: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: module.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: module.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      module.badge!,
                      style: TextStyle(
                        color: module.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              module.description,
              style: const TextStyle(
                color: CboColors.slateMuted,
                fontSize: 12,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Open Engine',
                style: TextStyle(
                  color: module.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: module.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _OmniModuleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String category;
  final String? badge;
  final String description;

  const _OmniModuleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    required this.category,
    this.badge,
    required this.description,
  });
}
