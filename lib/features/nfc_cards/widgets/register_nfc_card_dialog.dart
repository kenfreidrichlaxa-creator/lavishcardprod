import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/nfc_service.dart';

/// Register a card AND create the owner's account in one step.
///
/// Registering a card here creates (atomically, in Supabase):
///   • the client (card owner)
///   • their wallet (with the initial balance loaded onto the card)
///   • the NFC card, linked to the client + activated
///   • login credentials (username + password) for the E-Wallet app
class RegisterNfcCardDialog extends StatefulWidget {
  const RegisterNfcCardDialog({
    super.key,
    required this.existingCardIds,
    required this.onRegistered,
  });
  final Set<String> existingCardIds;
  final ValueChanged<NfcCardModel> onRegistered;

  @override
  State<RegisterNfcCardDialog> createState() => _RegisterNfcCardDialogState();
}

class _RegisterNfcCardDialogState extends State<RegisterNfcCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  final DateTime _dob = DateTime(1995, 1, 1);
  bool _saving = false;
  bool _obscurePassword = true;
  bool _scanning = false;

  @override
  void dispose() {
    _cardIdCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
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
                    child: const Icon(Icons.add_card_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Register Card & Account',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('NFC Card & Wallet'),
                        // Card ID + Tap button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cardIdCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Card ID (tap or type)',
                                  prefixIcon: Icon(Icons.nfc_rounded),
                                  hintText: 'e.g. 04A2B3C4',
                                ),
                                style: const TextStyle(
                                    fontSize: 13, fontFamily: 'monospace'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Card ID is required';
                                  }
                                  if (widget.existingCardIds
                                      .contains(v.trim().toUpperCase())) {
                                    return 'This Card ID already exists';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _scanning ? null : _tapCard,
                                icon: _scanning
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.contactless_rounded,
                                        size: 18),
                                label: Text(_scanning ? 'Tap…' : 'Tap Card'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Initial balance loaded onto the card
                        _field(_balanceCtrl, 'Initial Balance (₱)',
                            Icons.account_balance_wallet_outlined,
                            keyboardType: TextInputType.number, hint: '0.00'),
                        const SizedBox(height: 20),

                        _sectionLabel('Card Owner'),
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
                            hint: 'For password reset', validator: (v) {
                          final t = v!.trim();
                          if (t.isEmpty) return 'Required for password reset';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(t)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        }),
                        const SizedBox(height: 20),

                        _sectionLabel('E-Wallet Login Credentials'),
                        _field(_usernameCtrl, 'Username',
                            Icons.alternate_email_rounded, validator: (v) {
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
                          : const Text('Register Card'),
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
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon), hintText: hint),
      style: const TextStyle(fontSize: 13),
      validator: validator,
    );
  }

  Future<void> _tapCard() async {
    setState(() => _scanning = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tap the card on the reader…'),
        duration: Duration(seconds: 3),
      ));
      final uid = await NfcService.instance.readCardUid();
      if (!mounted) return;
      setState(() {
        _cardIdCtrl.text = uid;
        _scanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Card read: $uid'),
        backgroundColor: AdminColors.statusActive,
        behavior: SnackBarBehavior.floating,
      ));
    } on NfcException catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not read the card. You can type the ID manually.'),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
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
      address: '',
      dateOfBirth: _dob,
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      cardDisplayId: _cardIdCtrl.text.trim().toUpperCase(),
      initialBalance: balance,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Registration failed.'),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final card = NfcCardModel(
      id: result.clientId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      cardId: result.cardDisplayId ?? _cardIdCtrl.text.trim().toUpperCase(),
      status: NfcCardStatus.active,
      registeredDate: DateTime.now(),
      ownerId: result.clientId,
      ownerName: _nameCtrl.text.trim(),
    );

    Navigator.of(context).pop();
    widget.onRegistered(card);
  }
}
