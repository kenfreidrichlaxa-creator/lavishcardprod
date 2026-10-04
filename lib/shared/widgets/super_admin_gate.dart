import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';
import '../../data/services/admin_auth_repository.dart';

/// Shows a Super Admin authorization prompt. Returns true if a valid Super
/// Admin credential was entered, false/null if cancelled or failed.
///
/// Use before sensitive admin actions (Load LVP, Change/Re-register card):
/// ```dart
/// final ok = await SuperAdminGate.require(context, action: 'load this card');
/// if (!ok) return;
/// ```
class SuperAdminGate {
  static Future<bool> require(BuildContext context, {String? action}) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuperAdminGateDialog(action: action),
    );
    return ok == true;
  }
}

class _SuperAdminGateDialog extends StatefulWidget {
  const _SuperAdminGateDialog({this.action});
  final String? action;

  @override
  State<_SuperAdminGateDialog> createState() => _SuperAdminGateDialogState();
}

class _SuperAdminGateDialogState extends State<_SuperAdminGateDialog> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final err = await AdminAuthRepository.instance
        .verifySuperAdmin(_idCtrl.text, _pwCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _checking = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AdminColors.cream, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.shield_rounded,
              color: AdminColors.gold, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Super Admin Approval')),
      ]),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.action == null
                    ? 'A Super Admin must approve this action.'
                    : 'A Super Admin must approve to ${widget.action}.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Super Admin username or email',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwCtrl,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.statusSuspendedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: AdminColors.statusSuspended),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.statusSuspended)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Authorize'),
        ),
      ],
    );
  }
}
