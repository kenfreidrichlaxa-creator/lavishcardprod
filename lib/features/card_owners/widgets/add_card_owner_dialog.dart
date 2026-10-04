import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/services/card_owner_repository.dart';

class AddCardOwnerDialog extends StatefulWidget {
  const AddCardOwnerDialog({super.key, required this.onCreated});

  /// Called after a successful registration so the parent list can refresh.
  final ValueChanged<CardOwnerModel> onCreated;

  @override
  State<AddCardOwnerDialog> createState() => _AddCardOwnerDialogState();
}

class _AddCardOwnerDialogState extends State<AddCardOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cardIdCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  CardOwnerStatus _status = CardOwnerStatus.active;
  DateTime _dob = DateTime(1995, 1, 1);
  bool _saving = false;
  bool _obscurePassword = true;

  static const double _bonusRate = 0.20; // 20% bonus; paid is 80% of total

  @override
  void initState() {
    super.initState();
    _balanceCtrl.addListener(() => setState(() {}));
  }

  // Grossed-up math: entered amount is what the customer PAYS (80% of total).
  double get _paid =>
      double.tryParse(_balanceCtrl.text.trim().replaceAll(',', '')) ?? 0;
  double get _total => _paid <= 0 ? 0 : _round2(_paid / (1 - _bonusRate));
  double get _bonus => _paid <= 0 ? 0 : _round2(_total - _paid);
  static double _round2(double v) => (v * 100).round() / 100;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _cardIdCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
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
                    child: const Icon(Icons.person_add_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Register Card Owner',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Personal Details'),
                        _field(_nameCtrl, 'Full Name',
                            Icons.person_outline_rounded,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field(_phoneCtrl, 'Phone Number',
                            Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field(_emailCtrl, 'Email Address',
                            Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                          final t = v!.trim();
                          if (t.isEmpty) return 'Required for password reset';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(t)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        }),
                        const SizedBox(height: 12),
                        _field(_addressCtrl, 'Address',
                            Icons.location_on_outlined),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _pickDob(context),
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            child: Text(
                              '${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 13, color: AdminColors.charcoal),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _sectionLabel('Login Credentials (for E-Wallet app)'),
                        _field(_usernameCtrl, 'Username',
                            Icons.alternate_email_rounded,
                            validator: (v) {
                          final t = v!.trim();
                          if (t.isEmpty) return 'Required';
                          if (t.length < 3) return 'Min 3 characters';
                          if (t.contains(' ')) return 'No spaces allowed';
                          return null;
                        }),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 4) return 'Min 4 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        _sectionLabel('NFC Card & Wallet'),
                        _field(_cardIdCtrl, 'NFC Card ID (tap or type)',
                            Icons.nfc_rounded,
                            hint: 'e.g. LP-839274615',
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field(_balanceCtrl, 'Amount Paid (LVP)',
                            Icons.account_balance_wallet_outlined,
                            keyboardType: TextInputType.number,
                            hint: '0.00'),
                        if (_paid > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AdminColors.statusActiveBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AdminColors.statusActive
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Column(children: [
                              _bonusRow('Amount paid', _paid),
                              const SizedBox(height: 6),
                              _bonusRow('20% bonus', _bonus, highlight: true),
                              const Divider(height: 18),
                              _bonusRow('Wallet starts at', _total, bold: true),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CardOwnerStatus>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.toggle_on_outlined),
                          ),
                          items: CardOwnerStatus.values
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name[0].toUpperCase() +
                                        s.name.substring(1)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Register Owner'),
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

  Widget _bonusRow(String label, double value,
      {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AdminColors.gold : AdminColors.charcoal)),
        Text(
          'LVP ${value.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? AdminColors.gold : AdminColors.statusActive),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AdminColors.gold,
          ),
        ),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType,
      String? Function(String?)? validator,
      String? hint}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration:
          InputDecoration(labelText: label, prefixIcon: Icon(icon), hintText: hint),
      style: const TextStyle(fontSize: 13),
      validator: validator,
    );
  }

  Future<void> _pickDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final balance =
        double.tryParse(_balanceCtrl.text.trim().replaceAll(',', '')) ?? 0;

    final result = await CardOwnerRepository.instance.registerCardOwner(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      dateOfBirth: _dob,
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      cardDisplayId: _cardIdCtrl.text.trim(),
      initialBalance: balance,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Registration failed.'),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Build a model for optimistic UI insertion.
    final newOwner = CardOwnerModel(
      id: result.clientId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: result.clientCode ?? '',
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      dateOfBirth: _dob,
      status: _status,
      registeredDate: DateTime.now(),
      linkedCardId: result.cardDisplayId,
      walletBalance: result.balance ?? balance,
    );

    Navigator.of(context).pop();
    widget.onCreated(newOwner);

    final bonus = result.bonus ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(bonus > 0
            ? 'Registered. Wallet credited ₱${(result.balance ?? 0).toStringAsFixed(2)} '
                '(paid ₱${(result.paid ?? 0).toStringAsFixed(2)} + 20% bonus ₱${bonus.toStringAsFixed(2)}).'
            : 'Card owner registered.'),
        backgroundColor: AdminColors.statusActive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
