import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/cbo_colors.dart';
import '../constants/app_constants.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class NavItemData {
  final String title;
  final IconData icon;
  final String route;
  final String category;
  final String? badge;

  const NavItemData({
    required this.title,
    required this.icon,
    required this.route,
    required this.category,
    this.badge,
  });
}

class ResponsiveShell extends ConsumerStatefulWidget {
  final String currentRoute;
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveShell({
    super.key,
    required this.currentRoute,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  bool _isSidebarCollapsed = false;

  static const List<NavItemData> navItems = [
    NavItemData(
      title: 'Executive Dashboard',
      icon: Icons.dashboard_rounded,
      route: '/',
      category: 'Overview',
      badge: 'HUD',
    ),
    // Terminals
    NavItemData(
      title: 'CBO ATM/POS Recon',
      icon: Icons.atm_rounded,
      route: '/terminal_cbo',
      category: 'Terminals',
      badge: 'RRN',
    ),
    NavItemData(
      title: 'CBE ATM/POS Recon',
      icon: Icons.credit_card_rounded,
      route: '/terminal_cbe',
      category: 'Terminals',
      badge: 'Batch',
    ),
    // Mobile
    NavItemData(
      title: 'Ebirr Reconciliation',
      icon: Icons.phone_android_rounded,
      route: '/mobile_ebirr',
      category: 'Mobile',
      badge: 'Wallet',
    ),
    NavItemData(
      title: 'Telebirr Reconciliation',
      icon: Icons.account_balance_wallet_rounded,
      route: '/mobile_telebirr',
      category: 'Mobile',
      badge: 'Dual',
    ),
    // IPS
    NavItemData(
      title: 'IPS 2-File Recon',
      icon: Icons.rule_folder_rounded,
      route: '/ips_two',
      category: 'IPS',
      badge: '2-Way',
    ),
    NavItemData(
      title: 'IPS Triangular Recon',
      icon: Icons.account_tree_rounded,
      route: '/ips_triangular',
      category: 'IPS',
      badge: '3-Way',
    ),
    // Audit & Governance
    NavItemData(
      title: 'Dispute Management',
      icon: Icons.gavel_rounded,
      route: '/dispute_maker',
      category: 'Audit & Risk',
      badge: 'Gov',
    ),
    NavItemData(
      title: 'Dispute Memo Generator',
      icon: Icons.note_add_rounded,
      route: '/dispute_memo',
      category: 'Audit & Risk',
      badge: 'GL',
    ),
    NavItemData(
      title: 'Shortage & Excess',
      icon: Icons.sync_problem_rounded,
      route: '/shortage_excess',
      category: 'Audit & Risk',
      badge: 'Hardware',
    ),
    NavItemData(
      title: 'Reversal & Tolerance',
      icon: Icons.published_with_changes_rounded,
      route: '/reversal_recon',
      category: 'Audit & Risk',
      badge: 'Math',
    ),
    NavItemData(
      title: 'Remote Dispute Utility',
      icon: Icons.tune_rounded,
      route: '/remote_dispute_utility',
      category: 'Audit & Risk',
      badge: 'Utility',
    ),
    NavItemData(
      title: 'Declined Transaction Recon',
      icon: Icons.assignment_late_rounded,
      route: '/recon_declined',
      category: 'Audit & Risk',
      badge: 'Settlement',
    ),
    NavItemData(
      title: 'Remote Dispute Identification',
      icon: Icons.find_in_page_rounded,
      route: '/remote_dispute_identification',
      category: 'Audit & Risk',
      badge: 'Disputes',
    ),
    // Cards
    NavItemData(
      title: 'Mastercard Hub (TSV)',
      icon: Icons.payment_rounded,
      route: '/mastercard_hub',
      category: 'Cards',
      badge: 'TSV',
    ),
    NavItemData(
      title: 'Mastercard Ledger Recon',
      icon: Icons.pie_chart_rounded,
      route: '/mastercard_reconciliation',
      category: 'Cards',
      badge: 'Ledger',
    ),
  ];

  void _navigateTo(String route) {
    if (widget.currentRoute == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    return Scaffold(
      backgroundColor: CboColors.background,
      appBar: _buildTopAppBar(context, showDrawerButton: !isDesktop),
      drawer: isDesktop ? null : _buildDrawer(context),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context),
          Expanded(
            child: widget.body,
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context, {required bool showDrawerButton}) {
    final width = MediaQuery.of(context).size.width;
    return AppBar(
      leading: showDrawerButton
          ? null
          : IconButton(
              icon: Icon(
                _isSidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: CboColors.slateDark,
              ),
              onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              tooltip: 'Toggle Sidebar',
            ),
      title: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.currentRoute == '/' ? null : () => _navigateTo('/'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: CboColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.currentRoute != '/') ...[
                    const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                  ],
                  const Text(
                    'CBO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: CboColors.slateDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null && width >= 650)
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(
                      color: CboColors.slateMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.actions != null) ...widget.actions!,
        // Live Engine Indicator (visible on medium/large screens)
        if (width >= 550)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CboColors.statusOkBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CboColors.statusOkGlow.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: CboColors.neonGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE SYNC',
                  style: TextStyle(
                    color: CboColors.statusOkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        // Home Button Shortcut
        IconButton(
          icon: const Icon(Icons.home_rounded, color: CboColors.slateMedium),
          tooltip: 'Dashboard Home',
          onPressed: () => _navigateTo('/'),
        ),
        // Logout / Profile Popup
        PopupMenuButton<String>(
          icon: const CircleAvatar(
            radius: 15,
            backgroundColor: CboColors.primaryCyanLight,
            child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
          ),
          tooltip: 'Account Options',
          onSelected: (val) {
            if (val == 'logout') {
              ref.read(authNotifierProvider.notifier).logout();
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'user',
              enabled: false,
              child: Text(
                'CBO Recon Officer',
                style: TextStyle(fontWeight: FontWeight.bold, color: CboColors.slateDark),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: CboColors.alertRed, size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: CboColors.alertRed)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final width = _isSidebarCollapsed ? 76.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: CboColors.cardBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                for (final item in navItems) _buildSidebarItem(item),
              ],
            ),
          ),
          // Sidebar footer with version info
          if (!_isSidebarCollapsed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: CboColors.cardBorder)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: CboColors.slateMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConstants.version,
                      style: TextStyle(fontSize: 11, color: CboColors.slateMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(NavItemData item) {
    final isSelected = widget.currentRoute == item.route;

    if (_isSidebarCollapsed) {
      return Tooltip(
        message: item.title,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? CboColors.primaryCyan.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              item.icon,
              color: isSelected ? CboColors.primaryCyan : CboColors.slateMedium,
              size: 22,
            ),
            onPressed: () => _navigateTo(item.route),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? CboColors.primaryCyan.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: CboColors.primaryCyan.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          item.icon,
          color: isSelected ? CboColors.primaryCyan : CboColors.slateMedium,
          size: 20,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isSelected ? CboColors.primaryCyanDark : CboColors.slateDark,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        trailing: item.badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? CboColors.primaryCyan : CboColors.slateUltraLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.badge!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : CboColors.slateMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
        onTap: () => _navigateTo(item.route),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: CboColors.primaryGradient,
              ),
              child: const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        AppConstants.bankName,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (final item in navItems) _buildSidebarItem(item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
