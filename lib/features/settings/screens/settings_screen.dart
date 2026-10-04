import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/services/auth_service.dart';
import '../../../features/auth/screens/change_password_dialog.dart';
import '../../../features/auth/screens/login_screen.dart';
import '../../../features/auth/screens/update_profile_dialog.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailAlerts = true;
  bool _autoDeactivateCards = false;

  // Business info controllers
  final _bizNameCtrl = TextEditingController(text: 'Lavish Prima');
  final _bizBranchCtrl = TextEditingController(text: 'Lavish Prima Taytay');
  final _bizPhoneCtrl = TextEditingController(text: '+63 917 123 4567');
  final _bizEmailCtrl = TextEditingController(text: 'admin@lavishprima.com');

  @override
  void dispose() {
    _bizNameCtrl.dispose();
    _bizBranchCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _bizEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Settings',
                subtitle: 'Manage your admin panel preferences and configuration.',
              ),

              // ── Admin Account ────────────────────────────────────────────
              SectionCard(
                title: 'Admin Account',
                trailing: TextButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 14,
                      color: AdminColors.statusSuspended),
                  label: const Text('Log Out',
                      style: TextStyle(color: AdminColors.statusSuspended)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar + name row
                    Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AdminColors.cream,
                        child: Text(
                          user?.avatarInitials ?? 'AU',
                          style: const TextStyle(
                              color: AdminColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?.fullName ?? 'Admin User',
                                  style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(user?.role ?? 'Administrator',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.brownLight)),
                              Text(user?.email ?? '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.brownLight)),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Info rows
                    _infoRow(Icons.store_outlined, 'Branch',
                        user?.branch ?? '—'),
                    const SizedBox(height: 10),
                    _infoRow(Icons.phone_outlined, 'Phone',
                        user?.phone ?? '—'),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          if (user == null) return;
                          showUpdateProfileDialog(
                              context, user, () => setState(() {}));
                        },
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            showChangePasswordDialog(context),
                        icon: const Icon(Icons.lock_reset_rounded,
                            size: 14),
                        label: const Text('Change Password'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16)),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Business Info ────────────────────────────────────────────
              SectionCard(
                title: 'Business Information',
                child: Column(children: [
                  _settingField(_bizNameCtrl, 'Business Name',
                      Icons.store_outlined),
                  const SizedBox(height: 12),
                  _settingField(_bizBranchCtrl, 'Branch',
                      Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  _settingField(_bizPhoneCtrl, 'Contact Number',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _settingField(_bizEmailCtrl, 'Email',
                      Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Business information saved.'),
                            backgroundColor:
                                AdminColors.statusActive,
                          ),
                        );
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Appearance ───────────────────────────────────────────────
              SectionCard(
                title: 'Appearance',
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.mode,
                  builder: (context, mode, _) {
                    return _toggleTile(
                      'Dark Mode',
                      'Use a dark color theme across the admin panel.',
                      mode == ThemeMode.dark,
                      (v) => ThemeController.setDark(v),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Notifications ────────────────────────────────────────────
              SectionCard(
                title: 'Notifications',
                child: Column(children: [
                  _toggleTile(
                    'Push Notifications',
                    'Receive real-time alerts for transactions and system events.',
                    _notificationsEnabled,
                    (v) => setState(() => _notificationsEnabled = v),
                  ),
                  const Divider(height: 1),
                  _toggleTile(
                    'Email Alerts',
                    'Send email summaries for daily transactions.',
                    _emailAlerts,
                    (v) => setState(() => _emailAlerts = v),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Card Settings ────────────────────────────────────────
              SectionCard(
                title: 'Card Settings',
                child: Column(children: [
                  _toggleTile(
                    'Auto-Deactivate Lost Cards',
                    'Automatically disable cards reported as lost.',
                    _autoDeactivateCards,
                    (v) => setState(
                        () => _autoDeactivateCards = v),
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Card ID Prefix',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AdminColors.charcoal)),
                              SizedBox(height: 2),
                              Text(
                                  'Prefix used when registering new cards.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.brownLight)),
                            ]),
                      ),
                      SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          decoration:
                              InputDecoration(hintText: 'LP-'),
                          style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace'),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── About ────────────────────────────────────────────────────
              SectionCard(
                title: 'About',
                child: Column(children: [
                  DetailRow(
                      label: 'Application',
                      value: 'Lavish Prima Admin Panel'),
                  DetailRow(label: 'Version', value: '1.0.0'),
                  DetailRow(
                      label: 'Platform',
                      value: 'Flutter + Material 3'),
                  DetailRow(
                      label: 'Build', value: 'Debug', isLast: true),
                ]),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: AdminColors.brownLight),
      const SizedBox(width: 10),
      Text('$label: ',
          style: const TextStyle(
              fontSize: 13, color: AdminColors.brownLight)),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              color: AdminColors.charcoal,
              fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _settingField(
      TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon)),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _toggleTile(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AdminColors.charcoal)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.brownLight)),
              ]),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AdminColors.gold,
        ),
      ]),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log Out',
      message:
          'Are you sure you want to log out of the admin panel?',
      confirmLabel: 'Log Out',
    );
    if (confirmed && context.mounted) {
      AuthService.instance.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const AdminLoginScreen()),
        (_) => false,
      );
    }
  }
}
