/// A salon branch (app_branches).
class BranchModel {
  const BranchModel({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.contact,
    required this.isActive,
  });

  final String id;
  final String name;
  final String code;
  final String address;
  final String contact;
  final bool isActive;

  factory BranchModel.fromRow(Map<String, dynamic> r) => BranchModel(
        id: (r['id'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        code: (r['code'] as String?) ?? '',
        address: (r['address'] as String?) ?? '',
        contact: (r['contact'] as String?) ?? '',
        isActive: (r['is_active'] as bool?) ?? true,
      );
}

/// An admin/manager account row (app_users) for the super-admin list.
class AdminAccountModel {
  const AdminAccountModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    required this.status,
    required this.branchIds,
    required this.branchName,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String role;
  final String status;
  final List<String> branchIds;
  final String branchName;

  factory AdminAccountModel.fromRow(Map<String, dynamic> r) {
    final ids = <String>[];
    final raw = r['branch_ids'];
    if (raw is List) {
      for (final e in raw) {
        if (e != null) ids.add(e.toString());
      }
    }
    return AdminAccountModel(
      id: (r['id'] as String?) ?? '',
      name: (r['name'] as String?) ?? '',
      username: (r['username'] as String?) ?? '',
      email: (r['email'] as String?) ?? '',
      role: (r['role'] as String?) ?? 'admin',
      status: (r['status'] as String?) ?? 'active',
      branchIds: ids,
      branchName: (r['branch_name'] as String?) ?? '',
    );
  }
}
