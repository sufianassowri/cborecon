import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/constants/user_role.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  void _showCreateUserDialog() {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    UserRole selectedRole = UserRole.maker;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CboColors.primaryCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add_rounded, color: CboColors.primaryCyan),
              ),
              const SizedBox(width: 12),
              const Text('Create New User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Container(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create user account and assign Role-Based Access Control permissions.',
                      style: TextStyle(fontSize: 12.5, color: CboColors.slateMuted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 14),
                    const Text('Assigned Role', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CboColors.slateDark)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Row(
                            children: [
                              _buildRoleBadge(role),
                              const SizedBox(width: 8),
                              Text(role.displayName, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CboColors.primaryCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(authNotifierProvider.notifier).createUserByAdmin(
                          username: usernameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          role: selectedRole,
                        );
                        if (mounted) {
                          Navigator.of(ctx).pop();
                          ref.invalidate(adminUsersListProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ User ${usernameCtrl.text} created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRoleBadge(UserRole role) {
    Color bg;
    Color fg;
    switch (role) {
      case UserRole.admin:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case UserRole.maker:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        break;
      case UserRole.checker:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case UserRole.auditor:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case UserRole.manager:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        role.tag,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersListProvider);

    return ResponsiveShell(
      currentRoute: '/admin/users',
      title: 'User Access Control (RBAC)',
      subtitle: 'Manage administrative roles, reconciliation makers, checkers, and auditors',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: CboColors.slateDark),
          tooltip: 'Refresh Users',
          onPressed: () => ref.invalidate(adminUsersListProvider),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System User Directory',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CboColors.slateDark),
                    ),
                    Text(
                      'Assign and enforce permissions based on banking responsibilities.',
                      style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CboColors.primaryCyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Users Table / List
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: usersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: CboColors.primaryCyan)),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Failed to load users: $err', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_outlined, size: 48, color: CboColors.slateLight),
                            const SizedBox(height: 12),
                            const Text('No Users Registered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('Click "Add User" to create accounts.', style: TextStyle(color: CboColors.slateMuted)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: CboColors.cardBorder),
                      itemBuilder: (context, index) {
                        final u = users[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: CboColors.primaryCyan.withValues(alpha: 0.1),
                            child: Text(
                              u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryCyan),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              _buildRoleBadge(u.role),
                            ],
                          ),
                          subtitle: Text(u.email.isNotEmpty ? u.email : 'No email registered', style: const TextStyle(fontSize: 12, color: CboColors.slateMuted)),
                          trailing: DropdownButton<UserRole>(
                            value: u.role,
                            underline: const SizedBox(),
                            items: UserRole.values.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.displayName, style: const TextStyle(fontSize: 12.5)),
                              );
                            }).toList(),
                            onChanged: (newRole) async {
                              if (newRole != null && newRole != u.role) {
                                await ref.read(authNotifierProvider.notifier).changeUserRole(u.username, newRole);
                                ref.invalidate(adminUsersListProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Updated ${u.username} to ${newRole.displayName}')),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
