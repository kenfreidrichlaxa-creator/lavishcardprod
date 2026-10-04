import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/admin_user_model.dart';
import '../../../data/services/auth_service.dart';

/// Shows a dialog for updating the admin's profile information.
Future<void> showUpdateProfileDialog(
    BuildContext context, AdminUserModel user, VoidCallback onUpdated) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _UpdateProfileDialog(user: user, onUpdated: onUpdated),
  );
}

class _UpdateProfileDialog extends StatefulWidget {
  const _UpdateProfileDialog({required this.user, required this.onUpdated});
  final AdminUserModel user;
  final VoidCallback onUpdated;

  @override
  State<_UpdateProfileDialog> createState() => _UpdateProfileDialogState();
}

class _UpdateProfileDialogState extends State<_UpdateProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _branchCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.fullName);
    _phoneCtrl = TextEditingController(text: widget.user.phone);
    _branchCtrl = TextEditingController(text: widget.user.branch);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AdminColors.cream,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.manage_accounts_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Update Profile',
                      style: Theme.of(context).textTheme.headlineSmall),
                ]),
                const SizedBox(height: 20),

                // Avatar preview
                Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AdminColors.cream,
                    child: Text(
                      widget.user.avatarInitials,
                      style: const TextStyle(
                          color: AdminColors.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Email (read-only)
                TextFormField(
                  initialValue: widget.user.email,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                    filled: true,
                    fillColor: AdminColors.cream,
                    suffixIcon: Tooltip(
                      message: 'Email cannot be changed',
                      child: Icon(Icons.lock_outline_rounded,
                          size: 16, color: AdminColors.brownLight),
                    ),
                  ),
                  style: const TextStyle(
                      fontSize: 13, color: AdminColors.brownLight),
                ),
                const SizedBox(height: 12),

                // Role (read-only)
                TextFormField(
                  initialValue: widget.user.role,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    fillColor: AdminColors.cream,
                    suffixIcon: Tooltip(
                      message: 'Role is assigned by the system',
                      child: Icon(Icons.lock_outline_rounded,
                          size: 16, color: AdminColors.brownLight),
                    ),
                  ),
                  style: const TextStyle(
                      fontSize: 13, color: AdminColors.brownLight),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _branchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await AuthService.instance.updateProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      branch: _branchCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    widget.onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully.'),
        backgroundColor: AdminColors.statusActive,
      ),
    );
  }
}
