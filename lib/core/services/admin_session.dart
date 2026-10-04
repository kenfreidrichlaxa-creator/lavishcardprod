import '../../data/models/admin_user_model.dart';
import '../../data/models/branch_model.dart';
import 'cache_service.dart';

/// Holds the currently logged-in admin/super-admin for the session.
abstract final class AdminSession {
  static AdminUserModel? _user;
  static BranchModel? _activeBranch;

  static AdminUserModel? get user => _user;
  static bool get isLoggedIn => _user != null;

  static bool get isSuperAdmin => _user?.isSuperAdmin ?? false;
  static bool get isManager => _user?.isManager ?? false;

  /// Branch ids the current admin may manage (empty = all, for super admin).
  static List<String> get branchIds => _user?.branchIds ?? const [];

  /// The single branch the admin chose to work in this session.
  /// Set after the branch-picker screen. Null for super admins or single-branch
  /// admins (they skip the picker).
  static BranchModel? get activeBranch => _activeBranch;

  /// The active branch id — preferred over the full branchIds list for
  /// scoping queries when a multi-branch admin has picked a branch.
  static String? get activeBranchId => _activeBranch?.id;

  /// The effective branch id list to pass to repository calls.
  /// - Super admin    → empty (means "all branches" in the RPCs).
  /// - Multi-branch admin who picked one → [activeBranchId].
  /// - Single-branch admin               → branchIds (unchanged).
  static List<String> get effectiveBranchIds {
    if (isSuperAdmin) return const [];
    if (_activeBranch != null) return [_activeBranch!.id];
    return branchIds;
  }

  static void setUser(AdminUserModel user) => _user = user;

  static void setActiveBranch(BranchModel branch) =>
      _activeBranch = branch;

  static void clear() {
    _user = null;
    _activeBranch = null;
    // Clear cached data so the next login starts fresh.
    CacheService.clearAll();
  }
}
