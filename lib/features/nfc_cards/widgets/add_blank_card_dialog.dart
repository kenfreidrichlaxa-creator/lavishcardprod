import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/nfc_service.dart';

/// Pre-registers BLANK (unassigned) NFC cards into the system.
///
/// These cards have no owner yet. After they're handed to a customer, the
/// customer taps the card in the wallet app and self-registers to claim it.
///
/// Supports adding one card (tap or type the UID) at a time; each successful
/// add is appended to a running list so you can register a batch in one sitting.
class AddBlankCardDialog extends StatefulWidget {
  const AddBlankCardDialog({super.key, required this.onAdded});

  /// Called after any blank cards were added, so the list can refresh.
  final VoidCallback onAdded;

  @override
  State<AddBlankCardDialog> createState() => _AddBlankCardDialogState();
}

class _AddBlankCardDialogState extends State<AddBlankCardDialog> {
  final _uidCtrl = TextEditingController();
  bool _scanning = false;
  bool _saving = false;
  final List<String> _added = []; // UIDs added this session

  @override
  void dispose() {
    _uidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                  child: const Icon(Icons.style_rounded,
                      color: AdminColors.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Add Blank Cards',
                      style: theme.textTheme.headlineSmall),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Register cards with no owner yet. Hand them to customers, who '
                'then self-register by tapping the card in the wallet app.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              // Card UID + tap
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _uidCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(
                        labelText: 'Card UID (tap or type)',
                        prefixIcon: Icon(Icons.nfc_rounded),
                        hintText: 'e.g. 04A2B3C4',
                      ),
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'monospace'),
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
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.contactless_rounded, size: 18),
                      label: Text(_scanning ? 'Tap…' : 'Tap'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _add,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Card'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.statusActive),
                ),
              ),

              const SizedBox(height: 16),
              if (_added.isNotEmpty) ...[
                Text('Added this session (${_added.length})',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AdminColors.gold)),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AdminColors.cream,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _added.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle_rounded,
                            size: 18, color: AdminColors.statusActive),
                        title: Text(_added[i],
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 13)),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        _uidCtrl.text = uid;
        _scanning = false;
      });
      // Auto-add after a successful tap for a fast batch workflow.
      await _add();
    } on NfcException catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _snack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _snack('Could not read the card. You can type the UID manually.',
          error: true);
    }
  }

  Future<void> _add() async {
    final uid = _uidCtrl.text.trim().toUpperCase();
    if (uid.isEmpty) {
      _snack('Enter or tap a card UID first.', error: true);
      return;
    }
    if (_added.contains(uid)) {
      _snack('That card was already added.', error: true);
      return;
    }
    setState(() => _saving = true);
    final err = await CardOwnerRepository.instance.addBlankCard(cardUid: uid);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    setState(() {
      _added.insert(0, uid);
      _uidCtrl.clear();
    });
    widget.onAdded();
    _snack('Card $uid added.');
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? AdminColors.error : AdminColors.statusActive,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
