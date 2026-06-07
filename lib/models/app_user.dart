class AppUser {
  const AppUser({
    this.id,
    required this.username,
    required this.password,
    required this.isAdmin,
    required this.canManageUsers,
    required this.canManageAssets,
    required this.canReportFailure,
  });

  final int? id;
  final String username;
  final String password;
  final bool isAdmin;
  final bool canManageUsers;
  final bool canManageAssets;
  final bool canReportFailure;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'is_admin': isAdmin ? 1 : 0,
      'can_manage_users': canManageUsers ? 1 : 0,
      'can_manage_assets': canManageAssets ? 1 : 0,
      'can_report_failure': canReportFailure ? 1 : 0,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      isAdmin: (map['is_admin'] as int? ?? 0) == 1,
      canManageUsers: (map['can_manage_users'] as int? ?? 0) == 1,
      canManageAssets: (map['can_manage_assets'] as int? ?? 0) == 1,
      canReportFailure: (map['can_report_failure'] as int? ?? 0) == 1,
    );
  }
}
