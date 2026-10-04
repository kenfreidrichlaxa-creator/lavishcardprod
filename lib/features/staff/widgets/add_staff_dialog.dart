import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/staff_model.dart';

class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key, required this.onCreated});
  final ValueChanged<StaffModel> onCreated;

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  StaffPosition _position = StaffPosition.stylist;
  StaffStatus _status = StaffStatus.active;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                    decoration: BoxDecoration(color: AdminColors.cream, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.badge_rounded, color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Add Staff', style: Theme.of(context).textTheme.headlineSmall),
                ]),
                const SizedBox(height: 20),

                _field(_nameCtrl, 'Full Name', Icons.person_outline_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Email', Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),

                DropdownButtonFormField<StaffPosition>(
                  initialValue: _position,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                  items: StaffPosition.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _position = v); },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<StaffStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Employment Status',
                    prefixIcon: Icon(Icons.toggle_on_outlined),
                  ),
                  items: StaffStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _status = v); },
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
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Staff'),
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

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      style: const TextStyle(fontSize: 13),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final s = StaffModel(
      id: 'st_${DateTime.now().millisecondsSinceEpoch}',
      staffId: 'STF-${(100 + AdminMockData.staff.length + 1).toString().padLeft(3, '0')}',
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      position: _position,
      status: _status,
      joinedDate: DateTime.now(),
    );
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCreated(s);
    }
  }
}
