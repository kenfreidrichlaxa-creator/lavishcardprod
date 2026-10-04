import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/admin_user_model.dart';
import '../models/branch_model.dart';

/// Supabase-backed admin/super-admin auth + branch & admin management.
class AdminAuthRepository {
  AdminAuthRepository._();
  static final AdminAuthRepository instance = AdminAuthRepository._();

  SupabaseClient get _db => SupabaseService.client;

  /// Logs in an admin/manager/super-admin by email OR username.
  /// Returns the user, or throws with a message.
  Future<AdminUserModel> login(String identifier, String password) async {
    try {
      final res = await _db.rpc('admin_login', params: {
        'p_identifier': identifier.trim(),
        'p_password': password,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) {
        return AdminUserModel.fromLoginRow(map);
      }
      throw AdminAuthException((map['error'] as String?) ?? 'Login failed.');
    } on AdminAuthException {
      rethrow;
    } catch (e) {
      throw AdminAuthException('Could not connect. Please try again.');
    }
  }

  // ── Branches ────────────────────────────────────────────────────────────
  Future<List<BranchModel>> listBranches() async {
    final res = await _db.rpc('list_branches');
    if (res is List) {
      return res
          .map((e) => BranchModel.fromRow(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Creates a branch. Returns null on success or an error string.
  Future<String?> createBranch({
    required String name,
    required String code,
    required String address,
    required String contact,
  }) async {
    try {
      final res = await _db.rpc('create_branch', params: {
        'p_name': name.trim(),
        'p_code': code.trim(),
        'p_address': address.trim(),
        'p_contact': contact.trim(),
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not create branch.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Updates an existing branch (fix typos in name/code/address/contact).
  /// Returns null on success or an error string.
  Future<String?> updateBranch({
    required String id,
    required String name,
    required String code,
    required String address,
    required String contact,
  }) async {
    try {
      final res = await _db.rpc('update_branch', params: {
        'p_branch_id': id,
        'p_name': name.trim(),
        'p_code': code.trim(),
        'p_address': address.trim(),
        'p_contact': contact.trim(),
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update branch.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Archives (deactivates) or restores a branch. Returns null on success.
  Future<String?> setBranchActive({
    required String id,
    required bool active,
  }) async {
    try {
      final res = await _db.rpc('set_branch_active', params: {
        'p_branch_id': id,
        'p_active': active,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update branch status.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// The hosted reset-password page (shared with the wallet app).
  static const String _resetRedirect =
      'https://shimmering-melomakarona-309da3.netlify.app';

  /// Sends a password-reset email for an admin/super-admin account.
  /// Ensures a Supabase Auth user exists for the email first (super admins may
  /// not have one yet), then triggers the reset email. Returns null on success
  /// or an error message.
  Future<String?> sendPasswordReset(String email) async {
    final e = email.trim();
    if (e.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return 'Please enter a valid email address.';
    }
    // The email must belong to an admin account.
    final match = await _db
        .from('app_users')
        .select('id, auth_user_id')
        .ilike('email', e)
        .maybeSingle();
    if (match == null) {
      return 'No admin account found for that email.';
    }

    // If no linked auth user yet, create one on a standalone client so the
    // current session is untouched, then link it. Use the current password
    // hash as the initial auth password (the reset will overwrite it anyway).
    if (match['auth_user_id'] == null) {
      final row = await _db
          .from('app_users')
          .select('password_hash')
          .eq('id', match['id'])
          .maybeSingle();
      final tempPw = (row?['password_hash'] as String?) ?? 'Temp1234!';
      final auth = SupabaseService.standaloneClient();
      try {
        final signUp = await auth.auth.signUp(email: e, password: tempPw);
        final uid = signUp.user?.id;
        if (uid != null) {
          await _db.rpc('link_admin_auth',
              params: {'p_admin_id': match['id'], 'p_auth_user_id': uid});
        }
      } catch (_) {
        // Auth user may already exist for this email — that's fine.
      } finally {
        try {
          await auth.auth.signOut();
          await auth.dispose();
        } catch (_) {}
      }
    }

    try {
      await _db.auth
          .resetPasswordForEmail(e, redirectTo: _resetRedirect);
      return null;
    } catch (_) {
      return 'Could not send reset email. Please try again.';
    }
  }

  /// Authorization check: verifies the given credentials belong to an active
  /// Super Admin. Returns null on success, or an error message. Does NOT change
  /// the current session.
  Future<String?> verifySuperAdmin(String identifier, String password) async {
    try {
      final res = await _db.rpc('verify_super_admin', params: {
        'p_identifier': identifier.trim(),
        'p_password': password,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Authorization failed.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  // ── Franchise branch groups ─────────────────────────────────────────────
  /// Lists groups + the branches in each (for the drag-and-drop screen).
  Future<List<BranchGroup>> listBranchGroups() async {
    final res = await _db.rpc('list_branch_groups');
    if (res is List) {
      return res
          .map((e) => BranchGroup.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Creates a franchise group with an optional short CODE (e.g. 'LPA').
  /// Returns null on success or an error string.
  Future<String?> createBranchGroup(String name, {String? code}) async {
    try {
      final res = await _db.rpc('create_branch_group', params: {
        'p_name': name.trim(),
        'p_code': (code == null || code.trim().isEmpty) ? null : code.trim(),
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not create group.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Sets/changes a franchise group's short CODE (e.g. 'LPA'). Null on success.
  Future<String?> setBranchGroupCode(String groupId, String code) async {
    try {
      final res = await _db.rpc('set_branch_group_code',
          params: {'p_group_id': groupId, 'p_code': code.trim()});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not set franchise code.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Assigns a branch to a group (or null to ungroup). Null on success.
  Future<String?> assignBranchToGroup({
    required String branchId,
    String? groupId,
  }) async {
    try {
      final res = await _db.rpc('assign_branch_to_group', params: {
        'p_branch_id': branchId,
        'p_group_id': groupId,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not assign branch.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Renames a group. Null on success.
  Future<String?> renameBranchGroup(String groupId, String name) async {
    try {
      final res = await _db.rpc('rename_branch_group',
          params: {'p_group_id': groupId, 'p_name': name.trim()});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not rename group.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  // ── Admin accounts ────────────────────────────────────────────────────────
  Future<List<AdminAccountModel>> listAdmins() async {
    final res = await _db.rpc('list_admins');
    if (res is List) {
      return res
          .map((e) => AdminAccountModel.fromRow(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Creates an admin account (app_users role=admin) + a Supabase auth user
  /// (for the admin's Gmail / password reset). Returns null on success or an
  /// error string.
  Future<String?> createAdmin({
    required String name,
    required String username,
    required String email,
    required String password,
    required List<String> branchIds,
    String role = 'admin',
  }) async {
    try {
      final res = await _db.rpc('create_admin_account', params: {
        'p_name': name.trim(),
        'p_username': username.trim(),
        'p_email': email.trim(),
        'p_password': password,
        'p_branch_ids': branchIds,
        'p_role': role,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) {
        return (map['error'] as String?) ?? 'Could not create admin.';
      }

      // Create the Supabase auth account (email/gmail) on a standalone client
      // so the super-admin's session is not disturbed. Non-fatal on failure.
      final adminId = map['id'] as String?;
      if (adminId != null) {
        final authClient = SupabaseService.standaloneClient();
        try {
          final signUp =
              await authClient.auth.signUp(email: email.trim(), password: password);
          final uid = signUp.user?.id;
          if (uid != null) {
            await _db.rpc('link_admin_auth', params: {
              'p_admin_id': adminId,
              'p_auth_user_id': uid,
            });
          }
        } catch (_) {
          // ignore — admin still works via username login; auth reset optional
        } finally {
          try {
            await authClient.auth.signOut();
            await authClient.dispose();
          } catch (_) {}
        }
      }
      return null;
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }
}

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A franchise group and the branches assigned to it.
class BranchGroup {
  const BranchGroup({
    required this.id,
    required this.name,
    required this.branches,
    this.code = '',
  });

  final String id;
  final String name;
  final String code;
  final List<GroupBranch> branches;

  factory BranchGroup.fromMap(Map<String, dynamic> m) {
    final raw = (m['branches'] as List?) ?? const [];
    return BranchGroup(
      id: (m['id'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      code: (m['code'] as String?) ?? '',
      branches: raw
          .map((b) => GroupBranch.fromMap(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }
}

/// A branch reference inside a group (id + name only).
class GroupBranch {
  const GroupBranch({required this.id, required this.name});
  final String id;
  final String name;

  factory GroupBranch.fromMap(Map<String, dynamic> m) => GroupBranch(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
      );
}
