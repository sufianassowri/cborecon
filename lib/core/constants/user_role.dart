enum UserRole {
  admin,
  maker,
  checker,
  auditor,
  manager;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'System Administrator';
      case UserRole.maker:
        return 'Reconciliation Officer (Maker)';
      case UserRole.checker:
        return 'Reviewer / Supervisor (Checker)';
      case UserRole.auditor:
        return 'Internal Auditor';
      case UserRole.manager:
        return 'Operations Manager';
    }
  }

  String get tag {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.maker:
        return 'MAKER';
      case UserRole.checker:
        return 'CHECKER';
      case UserRole.auditor:
        return 'AUDITOR';
      case UserRole.manager:
        return 'MANAGER';
    }
  }

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.maker;
    final r = role.toLowerCase().trim();
    switch (r) {
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'maker':
      case 'officer':
        return UserRole.maker;
      case 'checker':
      case 'supervisor':
        return UserRole.checker;
      case 'auditor':
      case 'audit':
        return UserRole.auditor;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.maker;
    }
  }

  // Permission helpers
  bool get canManageUsers => this == UserRole.admin;
  bool get canRunRecon => this == UserRole.admin || this == UserRole.maker;
  bool get canCreateDispute => this == UserRole.admin || this == UserRole.maker;
  bool get canApproveDispute => this == UserRole.admin || this == UserRole.checker || this == UserRole.manager;
  bool get canViewAuditLogs => this == UserRole.admin || this == UserRole.auditor || this == UserRole.manager || this == UserRole.checker;
  bool get canViewExecutiveDashboard => this == UserRole.admin || this == UserRole.checker || this == UserRole.auditor || this == UserRole.manager;
}
