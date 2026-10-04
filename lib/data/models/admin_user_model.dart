/// Represents an authorized admin panel user.
class AdminUserModel {
  AdminUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.branch,
    required this.phone,
    required this.avatarInitials,
    this.username = '',
    List<String>? branchIds,
  }) : branchIds = branchIds ?? const [];

  final String id;
  String fullName;
  String email;
  String username;

  /// Raw role string. May be legacy ('Administrator'/'Manager') or the
  /// Supabase app_users role ('superAdmin'/'admin'/'manager'/'posStaff'/...).
  final String role;

  /// Primary branch display name.
  String branch;
  String phone;
  final String avatarInitials;

  /// Branch ids this user can manage (admins may have 1–2).
  final List<String> branchIds;

  bool get isSuperAdmin =>
      role == 'superAdmin' || role == 'Super Admin' || role == 'SuperAdmin';
  bool get isAdmin =>
      role == 'Administrator' || role == 'admin';
  bool get isManager => role == 'Manager' || role == 'manager';

  /// Builds from an admin_login RPC result map.
  factory AdminUserModel.fromLoginRow(Map<String, dynamic> r) {
    final name = (r['name'] as String?) ?? 'User';
    final ids = <String>[];
    final raw = r['branch_ids'];
    if (raw is List) {
      for (final e in raw) {
        if (e != null) ids.add(e.toString());
      }
    }
    return AdminUserModel(
      id: (r['id'] as String?) ?? '',
      fullName: name,
      email: (r['email'] as String?) ?? '',
      username: (r['username'] as String?) ?? '',
      role: (r['role'] as String?) ?? 'admin',
      branch: (r['branch_name'] as String?) ?? '',
      phone: '',
      avatarInitials: _initials(name),
      branchIds: ids,
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
