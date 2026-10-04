import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/services/auth_service.dart';

/// Shows a dialog for changing the admin's password.
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
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
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AdminColors.cream,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Change Password',
                      style: Theme.of(context).textTheme.headlineSmall),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Your new password must be at least 8 characters.',
                  style: TextStyle(fontSize: 12, color: AdminColors.brownLight),
                ),
                const SizedBox(height: 20),

                // Server error
                if (_serverError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AdminColors.statusSuspendedBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AdminColors.statusSuspended.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 14, color: AdminColors.statusSuspended),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_serverError!,
                            style: const TextStyle(
                                color: AdminColors.statusSuspended, fontSize: 12)),
                      ),
                    ]),
                  ),

                // Current password
                _passwordField(
                  controller: _oldCtrl,
                  label: 'Current Password',
                  obscure: _obscureOld,
                  onToggle: () => setState(() => _obscureOld = !_obscureOld),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // New password
                _passwordField(
                  controller: _newCtrl,
                  label: 'New Password',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'At least 8 characters';
                    if (v == _oldCtrl.text) {
                      return 'New password must differ from current';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Confirm password
                _passwordField(
                  controller: _confirmCtrl,
                  label: 'Confirm New Password',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _newCtrl.text) return 'Passwords do not match';
                    return null;
                  },
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
                          : const Text('Update Password'),
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: onToggle,
          tooltip: obscure ? 'Show' : 'Hide',
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final error = await AuthService.instance.changePassword(
      oldPassword: _oldCtrl.text,
      newPassword: _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _serverError = error);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated successfully.'),
        backgroundColor: AdminColors.statusActive,
      ),
    );
  }
}
