import '../models/admin_user_model.dart';

/// Simulates authentication for the admin panel.
/// Replace with a real API call in production.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── Hardcoded demo credentials ────────────────────────────────────────────
  // In production these come from a secure backend.
  static const _credentials = {
    'admin@lavishprima.com': 'Admin@2026',
    'manager@lavishprima.com': 'Manager@2026',
  };

  static final _users = {
    'admin@lavishprima.com': AdminUserModel(
      id: 'adm-001',
      fullName: 'Admin User',
      email: 'admin@lavishprima.com',
      role: 'Administrator',
      branch: 'Lavish Prima Taytay',
      phone: '+63 917 123 4567',
      avatarInitials: 'AU',
    ),
    'manager@lavishprima.com': AdminUserModel(
      id: 'adm-002',
      fullName: 'Branch Manager',
      email: 'manager@lavishprima.com',
      role: 'Manager',
      branch: 'Lavish Prima Taytay',
      phone: '+63 918 765 4321',
      avatarInitials: 'BM',
    ),
  };

  AdminUserModel? _currentUser;
  AdminUserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Returns the logged-in user or null if credentials are invalid.
  Future<AdminUserModel?> login(String email, String password) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));
    final stored = _credentials[email.trim().toLowerCase()];
    if (stored == null || stored != password) return null;
    _currentUser = _users[email.trim().toLowerCase()];
    return _currentUser;
  }

  /// Updates profile fields on the current user.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String branch,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_currentUser == null) return;
    _currentUser!.fullName = fullName;
    _currentUser!.phone = phone;
    _currentUser!.branch = branch;
  }

  /// Validates old password and sets a new one.
  /// Returns an error message string, or null on success.
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final email = _currentUser?.email;
    if (email == null) return 'Not logged in.';
    final stored = _credentials[email];
    if (stored != oldPassword) return 'Current password is incorrect.';
    if (newPassword.length < 8) return 'Password must be at least 8 characters.';
    // In a real app: send to backend, don't mutate a map
    (_credentials as Map)[email] = newPassword;
    return null;
  }

  void logout() {
    _currentUser = null;
  }
}
