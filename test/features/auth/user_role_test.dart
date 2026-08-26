import 'package:flutter_test/flutter_test.dart';
import 'package:cborecon/core/constants/user_role.dart';
import 'package:cborecon/features/auth/domain/entities/user_entity.dart';

void main() {
  group('UserRole & Permissions Matrix Tests', () {
    test('Admin role permissions', () {
      const admin = UserRole.admin;
      expect(admin.canManageUsers, isTrue);
      expect(admin.canRunRecon, isTrue);
      expect(admin.canCreateDispute, isTrue);
      expect(admin.canApproveDispute, isTrue);
      expect(admin.canViewAuditLogs, isTrue);
      expect(admin.canViewExecutiveDashboard, isTrue);
    });

    test('Maker role permissions', () {
      const maker = UserRole.maker;
      expect(maker.canManageUsers, isFalse);
      expect(maker.canRunRecon, isTrue);
      expect(maker.canCreateDispute, isTrue);
      expect(maker.canApproveDispute, isFalse);
      expect(maker.canViewAuditLogs, isFalse);
      expect(maker.canViewExecutiveDashboard, isFalse);
    });

    test('Checker role permissions', () {
      const checker = UserRole.checker;
      expect(checker.canManageUsers, isFalse);
      expect(checker.canRunRecon, isFalse);
      expect(checker.canCreateDispute, isFalse);
      expect(checker.canApproveDispute, isTrue);
      expect(checker.canViewAuditLogs, isTrue);
      expect(checker.canViewExecutiveDashboard, isTrue);
    });

    test('Auditor role permissions', () {
      const auditor = UserRole.auditor;
      expect(auditor.canManageUsers, isFalse);
      expect(auditor.canRunRecon, isFalse);
      expect(auditor.canCreateDispute, isFalse);
      expect(auditor.canApproveDispute, isFalse);
      expect(auditor.canViewAuditLogs, isTrue);
      expect(auditor.canViewExecutiveDashboard, isTrue);
    });

    test('Manager role permissions', () {
      const manager = UserRole.manager;
      expect(manager.canManageUsers, isFalse);
      expect(manager.canRunRecon, isFalse);
      expect(manager.canCreateDispute, isFalse);
      expect(manager.canApproveDispute, isTrue);
      expect(manager.canViewAuditLogs, isTrue);
      expect(manager.canViewExecutiveDashboard, isTrue);
    });

    test('Role string parsing handles various casings', () {
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('administrator'), UserRole.admin);
      expect(UserRole.fromString('maker'), UserRole.maker);
      expect(UserRole.fromString('checker'), UserRole.checker);
      expect(UserRole.fromString('auditor'), UserRole.auditor);
      expect(UserRole.fromString('manager'), UserRole.manager);
      expect(UserRole.fromString(null), UserRole.maker);
      expect(UserRole.fromString('unknown_role'), UserRole.maker);
    });

    test('UserEntity role mapping and copyWith', () {
      const user = UserEntity(
        id: 'u-1',
        username: 'solomon',
        email: 'solomon@cbo.com',
        role: UserRole.checker,
      );

      expect(user.role, UserRole.checker);
      final updated = user.copyWith(role: UserRole.admin);
      expect(updated.role, UserRole.admin);
    });
  });
}
