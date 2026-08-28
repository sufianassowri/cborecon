import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/cbo_colors.dart';
import '../constants/app_constants.dart';
import '../constants/user_role.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class NavItemData {
  final String title;
  final IconData icon;
  final String route;
  final String category;
  final String? badge;
  final List<UserRole>? allowedRoles;

  const NavItemData({
    required this.title,
    required this.icon,
    required this.route,
    required this.category,
    this.badge,
    this.allowedRoles,
  });

  bool isVisibleFor(UserRole role) {
    if (allowedRoles == null || allowedRoles!.isEmpty) return true;
    return allowedRoles!.contains(role);
  }
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
      allowedRoles: [UserRole.admin, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    // Administration (Admin Only)
    NavItemData(
      title: 'User Access Control',
      icon: Icons.admin_panel_settings_rounded,
      route: '/admin/users',
      category: 'Admin',
      badge: 'RBAC',
      allowedRoles: [UserRole.admin],
    ),
    // Terminals
    NavItemData(
      title: 'CBO ATM/POS Recon',
      icon: Icons.atm_rounded,
      route: '/terminal_cbo',
      category: 'Terminals',
      badge: 'RRN',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'CBE ATM/POS Recon',
      icon: Icons.credit_card_rounded,
      route: '/terminal_cbe',
      category: 'Terminals',
      badge: 'Batch',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    // Mobile
    NavItemData(
      title: 'Ebirr Reconciliation',
      icon: Icons.phone_android_rounded,
      route: '/mobile_ebirr',
      category: 'Mobile',
      badge: 'Wallet',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Telebirr Reconciliation',
      icon: Icons.account_balance_wallet_rounded,
      route: '/mobile_telebirr',
      category: 'Mobile',
      badge: 'Dual',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    // IPS
    NavItemData(
      title: 'IPS 2-File Recon',
      icon: Icons.rule_folder_rounded,
      route: '/ips_two',
      category: 'IPS',
      badge: '2-Way',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'IPS Triangular Recon',
      icon: Icons.account_tree_rounded,
      route: '/ips_triangular',
      category: 'IPS',
      badge: '3-Way',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    // Dispute Governance
    NavItemData(
      title: 'Dispute Maker (Submit)',
      icon: Icons.gavel_rounded,
      route: '/dispute_maker',
      category: 'Disputes & Governance',
      badge: 'Maker',
      allowedRoles: [UserRole.admin, UserRole.maker],
    ),
    NavItemData(
      title: 'Dispute Manager (Assign)',
      icon: Icons.assignment_turned_in_rounded,
      route: '/dispute_manager',
      category: 'Disputes & Governance',
      badge: 'Manager',
      allowedRoles: [UserRole.admin, UserRole.manager],
    ),
    NavItemData(
      title: 'Checker Approval Panel',
      icon: Icons.fact_check_rounded,
      route: '/dispute_checker',
      category: 'Disputes & Governance',
      badge: 'Checker',
      allowedRoles: [UserRole.admin, UserRole.checker, UserRole.manager],
    ),
    NavItemData(
      title: 'Dispute Auditor View',
      icon: Icons.manage_search_rounded,
      route: '/dispute_auditor',
      category: 'Disputes & Governance',
      badge: 'Audit',
      allowedRoles: [UserRole.admin, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Dispute Memo Generator',
      icon: Icons.note_add_rounded,
      route: '/dispute_memo',
      category: 'Disputes & Governance',
      badge: 'GL',
      allowedRoles: [UserRole.admin, UserRole.maker],
    ),
    NavItemData(
      title: 'Settlement Report Merger',
      icon: Icons.merge_type_rounded,
      route: '/report_merger',
      category: 'Disputes & Governance',
      badge: 'Fast Merge',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    // Risk & Utilities
    NavItemData(
      title: 'Shortage & Excess',
      icon: Icons.sync_problem_rounded,
      route: '/shortage_excess',
      category: 'Audit & Risk',
      badge: 'Hardware',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Reversal & Tolerance',
      icon: Icons.published_with_changes_rounded,
      route: '/reversal_recon',
      category: 'Audit & Risk',
      badge: 'Math',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Remote Dispute Utility',
      icon: Icons.tune_rounded,
      route: '/remote_dispute_utility',
      category: 'Audit & Risk',
      badge: 'Utility',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Declined Transaction Recon',
      icon: Icons.assignment_late_rounded,
      route: '/recon_declined',
      category: 'Audit & Risk',
      badge: 'Settlement',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Remote Dispute Identification',
      icon: Icons.find_in_page_rounded,
      route: '/remote_dispute_identification',
      category: 'Audit & Risk',
      badge: 'Disputes',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    // Cards
    NavItemData(
      title: 'Mastercard Hub (TSV)',
      icon: Icons.payment_rounded,
      route: '/mastercard_hub',
      category: 'Cards',
      badge: 'TSV',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
    ),
    NavItemData(
      title: 'Mastercard Ledger Recon',
      icon: Icons.pie_chart_rounded,
      route: '/mastercard_reconciliation',
      category: 'Cards',
      badge: 'Ledger',
      allowedRoles: [UserRole.admin, UserRole.maker, UserRole.checker, UserRole.auditor, UserRole.manager],
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
    final currentRole = ref.watch(currentUserRoleProvider);

    return Scaffold(
      backgroundColor: CboColors.background,
      appBar: _buildTopAppBar(context, showDrawerButton: !isDesktop),
      drawer: isDesktop ? null : _buildDrawer(context, currentRole),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context, currentRole),
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
    final authState = ref.watch(authNotifierProvider);
    final user = authState.value;
    final role = user?.role ?? UserRole.maker;

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
        // Role Tag
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleBgColor(role),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            role.tag,
            style: TextStyle(
              color: _getRoleTextColor(role),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        // Live Engine Indicator
        if (width >= 600)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CboColors.statusOkBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CboColors.statusOkGlow.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: CboColors.neonGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE SYNC',
                  style: TextStyle(
                    color: CboColors.statusOkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
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
        // Profile & Logout Popup
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
            } else if (val == 'users') {
              Navigator.of(context).pushReplacementNamed('/admin/users');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'user',
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.username ?? 'Officer',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.slateDark, fontSize: 14),
                  ),
                  Text(
                    role.displayName,
                    style: const TextStyle(fontSize: 11.5, color: CboColors.slateMuted),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            if (role == UserRole.admin)
              const PopupMenuItem(
                value: 'users',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, color: CboColors.primaryCyan, size: 18),
                    SizedBox(width: 8),
                    Text('User Access Control'),
                  ],
                ),
              ),
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

  static Color _getRoleBgColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Color(0xFFFEE2E2);
      case UserRole.maker:
        return const Color(0xFFE0F2FE);
      case UserRole.checker:
        return const Color(0xFFFEF3C7);
      case UserRole.auditor:
        return const Color(0xFFF3E8FF);
      case UserRole.manager:
        return const Color(0xFFDCFCE7);
    }
  }

  static Color _getRoleTextColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Color(0xFFDC2626);
      case UserRole.maker:
        return const Color(0xFF0284C7);
      case UserRole.checker:
        return const Color(0xFFD97706);
      case UserRole.auditor:
        return const Color(0xFF7E22CE);
      case UserRole.manager:
        return const Color(0xFF16A34A);
    }
  }

  Widget _buildSidebar(BuildContext context, UserRole role) {
    final width = _isSidebarCollapsed ? 76.0 : 260.0;
    final visibleItems = navItems.where((item) => item.isVisibleFor(role)).toList();

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
                for (final item in visibleItems) _buildSidebarItem(item),
              ],
            ),
          ),
          if (!_isSidebarCollapsed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: CboColors.cardBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: CboColors.slateMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${AppConstants.version} • ${role.tag}',
                      style: const TextStyle(fontSize: 11, color: CboColors.slateMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, UserRole role) {
    final visibleItems = navItems.where((item) => item.isVisibleFor(role)).toList();

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: CboColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: CboColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('CBO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recon Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(role.displayName, style: const TextStyle(fontSize: 11.5, color: CboColors.slateMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (final item in visibleItems) _buildSidebarItem(item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(NavItemData item) {
    final isSelected = widget.currentRoute == item.route;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _navigateTo(item.route),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isSidebarCollapsed ? 12 : 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isSelected ? CboColors.primaryCyan.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: CboColors.primaryCyan.withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected ? CboColors.primaryCyan : CboColors.slateMedium,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? CboColors.primaryCyan : CboColors.slateDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? CboColors.primaryCyan : CboColors.cardBorder,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badge!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : CboColors.slateMuted,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
