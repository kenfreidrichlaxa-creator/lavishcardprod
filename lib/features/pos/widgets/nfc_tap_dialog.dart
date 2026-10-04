import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/nfc_service.dart';

/// Result returned from the NFC tap dialog.
class NfcTapResult {
  const NfcTapResult({required this.owner, required this.card, required this.cardUid});
  final CardOwnerModel owner;
  final NfcCardModel card;

  /// The physical UID read from the card — used to charge the wallet.
  final String cardUid;
}

/// Shows the NFC tap dialog that reads a real card and resolves the owner from
/// Supabase. Returns [NfcTapResult] when a card is identified, or null.
Future<NfcTapResult?> showNfcTapDialog(BuildContext context) {
  return showDialog<NfcTapResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _NfcTapDialog(),
  );
}

enum _NfcState { waiting, scanning, found, notFound, blocked, error }

class _NfcTapDialog extends StatefulWidget {
  const _NfcTapDialog();

  @override
  State<_NfcTapDialog> createState() => _NfcTapDialogState();
}

class _NfcTapDialogState extends State<_NfcTapDialog>
    with SingleTickerProviderStateMixin {
  _NfcState _state = _NfcState.waiting;
  CardOwnerModel? _foundOwner;
  NfcCardModel? _foundCard;
  String? _foundUid;
  String _errorMsg = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _state = _NfcState.scanning);
    try {
      // 1. Read the physical card UID from the reader.
      final uid = await NfcService.instance.readCardUid();

      // 2. Resolve the owner from Supabase by UID.
      final res = await CardOwnerRepository.instance.lookupCardByUid(uid);
      if (!mounted) return;

      if (res['success'] != true) {
        final code = res['error_code'] as String?;
        setState(() {
          _state = _NfcState.notFound;
          _errorMsg = (res['error'] as String?) ??
              'This card is not registered.';
        });
        if (code != null && code.startsWith('CARD_') &&
            code != 'CARD_NOT_FOUND') {
          setState(() => _state = _NfcState.blocked);
        }
        return;
      }

      // lookup_card_by_uid returns a 'status' of:
      //   claimed   → has an owner + wallet (usable for checkout, incl. cards
      //               pre-loaded while still "unclaimed" by the customer)
      //   available → a blank card with no balance yet (cannot pay)
      //   blocked   → lost / blocked / replaced
      //   unknown   → not recognized
      final status = res['status'] as String?;
      if (status == 'blocked') {
        setState(() {
          _state = _NfcState.blocked;
          _errorMsg = (res['error'] as String?) ??
              'This card is blocked and cannot be used.';
        });
        return;
      }
      if (status != 'claimed') {
        // available (blank, no balance) or unknown.
        setState(() {
          _state = _NfcState.notFound;
          _errorMsg = status == 'available'
              ? 'This card has no balance yet. Load it before checkout.'
              : ((res['error'] as String?) ?? 'This card is not registered.');
        });
        return;
      }

      final owner = CardOwnerModel(
        id: res['client_id'] as String,
        customerId: (res['client_code'] as String?) ?? '',
        fullName: (res['client_name'] as String?) ??
            (res['full_name'] as String?) ??
            'Customer',
        phone: '',
        email: '',
        address: '',
        dateOfBirth: DateTime(1990, 1, 1),
        status: CardOwnerStatus.active,
        registeredDate: DateTime.now(),
        linkedCardId: res['card_display_id'] as String?,
        walletBalance: (res['balance'] as num?)?.toDouble() ?? 0,
      );
      final card = NfcCardModel(
        id: (res['card_uid'] as String?) ?? uid,
        cardId: (res['card_display_id'] as String?) ?? uid,
        status: NfcCardStatus.active,
        registeredDate: DateTime.now(),
        ownerId: owner.id,
        ownerName: owner.fullName,
      );

      setState(() {
        _foundUid = uid;
        _foundOwner = owner;
        _foundCard = card;
        _state = _NfcState.found;
      });
    } on NfcException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _NfcState.error;
        _errorMsg = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _NfcState.error;
        _errorMsg = 'Could not read the card. Please try again.';
      });
    }
  }

  void _reset() => setState(() {
        _state = _NfcState.waiting;
        _foundCard = null;
        _foundOwner = null;
        _foundUid = null;
        _errorMsg = '';
      });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: AdminColors.sidebarBg,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Tap Card',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AdminColors.sidebarTextMuted),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cancel',
                ),
              ]),
              const SizedBox(height: 8),
              Text(_subtitle,
                  style: const TextStyle(
                      color: AdminColors.sidebarTextMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              _buildStateContent(),
              const SizedBox(height: 32),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent() {
    return switch (_state) {
      _NfcState.waiting =>
        _WaitingView(pulseAnim: _pulseAnim, onTap: _scan),
      _NfcState.scanning => const _ScanningView(),
      _NfcState.found =>
        _FoundView(owner: _foundOwner!, card: _foundCard!),
      _NfcState.notFound => _ErrorView(
          icon: Icons.credit_card_off_outlined,
          title: 'Card Not Recognised',
          subtitle: _errorMsg,
          color: AdminColors.statusSuspended,
        ),
      _NfcState.blocked => _ErrorView(
          icon: Icons.block_rounded,
          title: 'Card Unavailable',
          subtitle: _errorMsg,
          color: AdminColors.warningAmber,
        ),
      _NfcState.error => _ErrorView(
          icon: Icons.error_outline_rounded,
          title: 'Reader Error',
          subtitle: _errorMsg,
          color: AdminColors.statusSuspended,
        ),
    };
  }

  Widget _buildActions() {
    return switch (_state) {
      _NfcState.waiting => TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AdminColors.sidebarTextMuted)),
        ),
      _NfcState.scanning => const SizedBox.shrink(),
      _NfcState.found => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _reset,
              child: const Text('Different Card',
                  style: TextStyle(color: AdminColors.sidebarTextMuted)),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                NfcTapResult(
                    owner: _foundOwner!,
                    card: _foundCard!,
                    cardUid: _foundUid!),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Confirm Customer'),
              style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.statusActive),
            ),
          ],
        ),
      _ => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AdminColors.sidebarTextMuted)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded,
                  size: 14, color: AdminColors.goldLight),
              label: const Text('Try Again',
                  style: TextStyle(color: AdminColors.goldLight)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AdminColors.gold),
              ),
            ),
          ],
        ),
    };
  }

  String get _subtitle => switch (_state) {
        _NfcState.waiting =>
          'Ask the customer to tap their Lavish card on the reader.',
        _NfcState.scanning => 'Reading card…',
        _NfcState.found => 'Customer identified successfully.',
        _NfcState.notFound => 'Could not find a customer for this card.',
        _NfcState.blocked => 'This card cannot be used for payment.',
        _NfcState.error => 'There was a problem reading the card.',
      };
}

// ── State sub-widgets ─────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.pulseAnim, required this.onTap});
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) =>
                Transform.scale(scale: pulseAnim.value, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminColors.sidebarSelected,
                border: Border.all(color: AdminColors.gold, width: 2),
              ),
              child: const Icon(Icons.nfc_rounded,
                  size: 56, color: AdminColors.gold),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AdminColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AdminColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 16, color: AdminColors.goldLight),
                SizedBox(width: 8),
                Text('Tap here, then tap the card',
                    style: TextStyle(
                        color: AdminColors.goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AdminColors.sidebarSelected,
          border: Border.all(color: AdminColors.gold, width: 2),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              color: AdminColors.gold, strokeWidth: 2.5),
        ),
      ),
      const SizedBox(height: 20),
      const Text('Waiting for card…',
          style: TextStyle(color: AdminColors.sidebarText, fontSize: 15)),
    ]);
  }
}

class _FoundView extends StatelessWidget {
  const _FoundView({required this.owner, required this.card});
  final CardOwnerModel owner;
  final NfcCardModel card;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AdminColors.statusActiveBg,
          border: Border.all(color: AdminColors.statusActive, width: 2),
        ),
        child: const Icon(Icons.check_rounded,
            size: 40, color: AdminColors.statusActive),
      ),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminColors.sidebarSelected,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AdminColors.statusActive.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AdminColors.charcoal,
            child: Text(owner.initials,
                style: const TextStyle(
                    color: AdminColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(owner.customerId,
                    style: const TextStyle(
                        color: AdminColors.sidebarTextMuted,
                        fontSize: 12,
                        fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.nfc_rounded,
                      size: 12, color: AdminColors.goldLight),
                  const SizedBox(width: 4),
                  Text(card.cardId,
                      style: const TextStyle(
                          color: AdminColors.goldLight,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Balance',
                  style: TextStyle(
                      color: AdminColors.sidebarTextMuted, fontSize: 10)),
              Text(Fmt.peso(owner.walletBalance),
                  style: const TextStyle(
                      color: AdminColors.statusActive,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ]),
      ),
    ]);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, size: 36, color: color),
      ),
      const SizedBox(height: 16),
      Text(title,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(subtitle,
          style: const TextStyle(
              color: AdminColors.sidebarTextMuted, fontSize: 13),
          textAlign: TextAlign.center),
    ]);
  }
}
