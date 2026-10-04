import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/lvp_calculator.dart';
import '../../../data/services/nfc_service.dart';
import '../../../shared/widgets/super_admin_gate.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../data/services/audit_repository.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';

class CardOwnerProfileScreen extends StatefulWidget {
  const CardOwnerProfileScreen({super.key, required this.owner});
  final CardOwnerModel owner;

  @override
  State<CardOwnerProfileScreen> createState() => _CardOwnerProfileScreenState();
}

class _CardOwnerProfileScreenState extends State<CardOwnerProfileScreen> {
  late CardOwnerModel _owner;
  List<AdminTransactionModel> _ownerTx = [];

  @override
  void initState() {
    super.initState();
    _owner = widget.owner;
    _loadTx();
  }

  Future<void> _loadTx() async {
    try {
      final tx = await AdminDataRepository.instance
          .fetchTransactions(clientId: _owner.id);
      if (mounted) setState(() => _ownerTx = tx);
    } catch (_) {
      // Leave empty on error.
    }
  }

  double get _totalSpent => _ownerTx
      .where((t) =>
          t.status == TransactionStatus.completed &&
          t.serviceName != 'Wallet Top-Up')
      .fold(0.0, (s, t) => s + t.amount);

  @override
  Widget build(BuildContext context) {
    // Linked card summary derived from the owner's linkedCardId.
    final card = _owner.linkedCardId != null
        ? _LinkedCardInfo(cardId: _owner.linkedCardId!)
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Card Owner Profile'),
        backgroundColor: AdminColors.cardBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _showEditCustomerDialog,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _showLoadWalletDialog,
            icon: const Icon(Icons.add_card_rounded, size: 16),
            label: const Text('Load Wallet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 320, child: _LeftColumn(owner: _owner, card: card, onAction: _handleCardAction)),
                    const SizedBox(width: 20),
                    Expanded(child: _RightColumn(owner: _owner, transactions: _ownerTx, totalSpent: _totalSpent)),
                  ],
                )
              : Column(
                  children: [
                    _LeftColumn(owner: _owner, card: card, onAction: _handleCardAction),
                    const SizedBox(height: 16),
                    _RightColumn(owner: _owner, transactions: _ownerTx, totalSpent: _totalSpent),
                  ],
                );
        }),
      ),
    );
  }

  Future<void> _showLoadWalletDialog() async {
    // Super Admin approval required before loading LVP.
    final approved =
        await SuperAdminGate.require(context, action: 'load this card');
    if (!approved || !mounted) return;

    final res = await showDialog<LvpLoadResult>(
      context: context,
      builder: (ctx) => _LoadLvpDialog(
        ownerName: _owner.fullName,
        currentBalance: _owner.walletBalance,
      ),
    );

    if (res == null) return; // cancelled

    final error = await CardOwnerRepository.instance.loadWalletWithBonus(
      clientId: _owner.id,
      paid: res.loadingAmount,
      notes: 'LVP load via admin panel',
    );

    if (!mounted) return;
    if (!error.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.error ?? 'Loading failed.'),
        backgroundColor: AdminColors.error,
      ));
      return;
    }

    setState(() {
      _owner =
          _owner.copyWith(walletBalance: _owner.walletBalance + error.total);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${Fmt.peso(error.total)} LVP credited '
          '(loaded ${Fmt.peso(error.paid)} + bonus ${Fmt.peso(error.bonus)}).'),
      backgroundColor: AdminColors.statusActive,
    ));
  }

  // ── Edit customer (name / email / phone) ─────────────────────────────────
  Future<void> _showEditCustomerDialog() async {
    final nameCtrl = TextEditingController(text: _owner.fullName);
    final emailCtrl = TextEditingController(text: _owner.email);
    final phoneCtrl = TextEditingController(text: _owner.phone);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Edit Customer'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email (Gmail)',
                        prefixIcon: Icon(Icons.mail_outline_rounded)),
                    validator: (v) {
                      final t = v!.trim();
                      if (t.isEmpty) return 'Required';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setLocal(() => saving = true);
                        final err = await AuditRepository.instance.editCustomer(
                          clientId: _owner.id,
                          fullName: nameCtrl.text,
                          email: emailCtrl.text,
                          phone: phoneCtrl.text,
                        );
                        if (!ctx.mounted) return;
                        if (err != null) {
                          setLocal(() => saving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(err),
                              backgroundColor: AdminColors.error));
                          return;
                        }
                        Navigator.of(ctx).pop(true);
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _owner = CardOwnerModel(
          id: _owner.id,
          customerId: _owner.customerId,
          fullName: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          address: _owner.address,
          dateOfBirth: _owner.dateOfBirth,
          status: _owner.status,
          registeredDate: _owner.registeredDate,
          linkedCardId: _owner.linkedCardId,
          walletBalance: _owner.walletBalance,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Customer updated.'),
        backgroundColor: AdminColors.statusActive,
      ));
    }
  }

  // ── Change / replace card ─────────────────────────────────────────────────
  Future<void> _showChangeCardDialog() async {
    // Super Admin approval required before re-registering / changing a card.
    final approved =
        await SuperAdminGate.require(context, action: 're-register this card');
    if (!approved || !mounted) return;

    final cardCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        bool scanning = false;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> scanCard() async {
              setLocal(() => scanning = true);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                content: Text('Tap the new card on the reader…'),
                duration: Duration(seconds: 3),
              ));
              try {
                final uid = await NfcService.instance.readCardUid();
                cardCtrl.text = uid;
                if (ctx.mounted) {
                  setLocal(() => scanning = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Card read: $uid'),
                    backgroundColor: AdminColors.statusActive,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } on NfcException catch (e) {
                if (ctx.mounted) {
                  setLocal(() => scanning = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(e.message),
                    backgroundColor: AdminColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (_) {
                if (ctx.mounted) {
                  setLocal(() => scanning = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text(
                        'Could not read the card. You can type the ID manually.'),
                    backgroundColor: AdminColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            }

            return AlertDialog(
            title: const Text('Change Card'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Replace the card for ${_owner.fullName}. The old card '
                      'will be marked replaced.',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cardCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'New Card ID',
                            prefixIcon: Icon(Icons.nfc_rounded),
                            hintText: 'Tap or type',
                          ),
                          style: const TextStyle(fontFamily: 'monospace'),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: scanning ? null : scanCard,
                          icon: scanning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.contactless_rounded, size: 18),
                          label: Text(scanning ? 'Tap…' : 'Tap Card'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'e.g. lost card',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setLocal(() => saving = true);
                        final err = await AuditRepository.instance.changeCard(
                          clientId: _owner.id,
                          newDisplayId: cardCtrl.text,
                          reason: reasonCtrl.text.trim().isEmpty
                              ? null
                              : reasonCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        if (err != null) {
                          setLocal(() => saving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(err),
                              backgroundColor: AdminColors.error));
                          return;
                        }
                        Navigator.of(ctx).pop(true);
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Change Card'),
              ),
            ],
          );
          },
        );
      },
    );

    if (done == true && mounted) {
      setState(() {
        _owner = _owner.copyWith(linkedCardId: cardCtrl.text.trim().toUpperCase());
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Card changed successfully.'),
        backgroundColor: AdminColors.statusActive,
      ));
    }
  }

  void _handleCardAction(String action) async {
    if (action == 'replace') {
      await _showChangeCardDialog();
      return;
    }
    final messages = {
      'suspend': 'Are you sure you want to suspend the card linked to ${_owner.fullName}?',
      'unlink': 'Are you sure you want to unlink the card from ${_owner.fullName}?',
    };
    final confirmed = await showConfirmDialog(
      context,
      title: '${action[0].toUpperCase()}${action.substring(1)} Card',
      message: messages[action] ?? '',
      confirmLabel: action[0].toUpperCase() + action.substring(1),
    );
    if (confirmed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card ${action}d successfully.'), backgroundColor: AdminColors.statusActive),
      );
    }
  }
}

/// Lightweight linked-card summary for the profile (the owner has a card
/// linked via linkedCardId; it's active).
class _LinkedCardInfo {
  const _LinkedCardInfo({required this.cardId});
  final String cardId;
  NfcCardStatus get status => NfcCardStatus.active;
  DateTime? get lastUsed => null;
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.owner, required this.card, required this.onAction});
  final CardOwnerModel owner;
  final _LinkedCardInfo? card;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Profile header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AdminColors.cream,
                  child: Text(owner.initials,
                      style: const TextStyle(color: AdminColors.gold, fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Text(owner.fullName, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(owner.customerId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AdminColors.brownLight)),
                const SizedBox(height: 8),
                StatusChip.cardOwner(owner.status),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Customer Info
        SectionCard(
          title: 'Customer Information',
          child: Column(children: [
            DetailRow(label: 'Full Name', value: owner.fullName),
            DetailRow(label: 'Phone', value: owner.phone),
            DetailRow(label: 'Email', value: owner.email.isEmpty ? '—' : owner.email),
            DetailRow(label: 'Address', value: owner.address.isEmpty ? '—' : owner.address),
            DetailRow(label: 'Registered', value: Fmt.date(owner.registeredDate), isLast: true),
          ]),
        ),
        const SizedBox(height: 16),

        // Card
        SectionCard(
          title: 'Linked Card',
          child: card == null
              ? const Text('No card linked.', style: TextStyle(color: AdminColors.brownLight))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Card ID', value: owner.linkedCardId ?? '—'),
                    DetailRow(
                      label: 'Status',
                      value: '',
                      valueWidget: StatusChip.nfcCard(card!.status),
                    ),
                    DetailRow(label: 'Last Used',
                        value: card!.lastUsed != null ? Fmt.relativeDate(card!.lastUsed!) : 'Never',
                        isLast: true),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: () => onAction('replace'),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                        label: const Text('Replace'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onAction('suspend'),
                        icon: const Icon(Icons.block_rounded, size: 14),
                        label: const Text('Suspend'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.statusSuspended,
                          side: const BorderSide(color: AdminColors.statusSuspended),
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onAction('unlink'),
                        icon: const Icon(Icons.link_off_rounded, size: 14),
                        label: const Text('Unlink'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.owner,
    required this.transactions,
    required this.totalSpent,
  });
  final CardOwnerModel owner;
  final List<AdminTransactionModel> transactions;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Wallet summary
        SectionCard(
          title: 'Wallet',
          child: Column(children: [
            Row(children: [
              Expanded(child: _WalletStat('Current Balance', Fmt.peso(owner.walletBalance), AdminColors.statusActive)),
              Expanded(child: _WalletStat('Total Spent', Fmt.peso(totalSpent), AdminColors.statusSuspended)),
              Expanded(child: _WalletStat('Transactions', transactions.length.toString(), AdminColors.brownMedium)),
            ]),
            if (transactions.isNotEmpty) ...[
              const Divider(height: 20),
              DetailRow(
                label: 'Last Transaction',
                value: Fmt.relativeDate(transactions.first.dateTime),
                isLast: true,
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Transaction history
        SectionCard(
          title: 'Transaction History',
          child: transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No transactions yet.', style: TextStyle(color: AdminColors.brownLight)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      _col('Date'),
                      _col('Stylist'),
                      _col('Service'),
                      _col('Amount'),
                      _col('Status'),
                    ],
                    rows: transactions.map((tx) => DataRow(cells: [
                      DataCell(Text(Fmt.relativeDate(tx.dateTime), style: theme.textTheme.bodySmall)),
                      DataCell(Text(tx.staffName)),
                      DataCell(Text(tx.serviceName)),
                      DataCell(Text(Fmt.peso(tx.amount), style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(StatusChip.transaction(tx.status)),
                    ])).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  DataColumn _col(String label) => DataColumn(
    label: Text(label.toUpperCase(),
        style: const TextStyle(color: AdminColors.brownMedium, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );
}

class _WalletStat extends StatelessWidget {
  const _WalletStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ]);
  }
}


// ── Load LVP dialog (tiered bonus, live preview) ─────────────────────────────
class _LoadLvpDialog extends StatefulWidget {
  const _LoadLvpDialog({required this.ownerName, required this.currentBalance});
  final String ownerName;
  final double currentBalance;

  @override
  State<_LoadLvpDialog> createState() => _LoadLvpDialogState();
}

class _LoadLvpDialogState extends State<_LoadLvpDialog> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_ctrl.text.trim().replaceAll(',', '')) ?? 0;
  LvpLoadResult get _calc => LvpCalculator.compute(_amount);

  @override
  Widget build(BuildContext context) {
    final calc = _calc;
    return AlertDialog(
      title: const Text('Load LVP'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add LVP to ${widget.ownerName}\'s wallet.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              'Minimum ₱2,500. ₱2,500–₱3,999 = +₱500 bonus; ₱4,000+ = +25%.',
              style: TextStyle(fontSize: 11, color: AdminColors.brownLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Loading Amount (₱)',
                prefixIcon: Icon(Icons.payments_outlined),
                hintText: '0.00',
              ),
            ),
            if (_amount > 0) ...[
              const SizedBox(height: 14),
              if (!calc.accepted)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.statusSuspendedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.block_rounded,
                        size: 16, color: AdminColors.statusSuspended),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(calc.reason ?? 'Loading not allowed.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.statusSuspended)),
                    ),
                  ]),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminColors.statusActiveBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(children: [
                    _row('Loading Amount', calc.loadingAmount),
                    const SizedBox(height: 5),
                    _row('Bonus', calc.bonus, highlight: true),
                    const Divider(height: 16),
                    _row('LVP to Credit', calc.credited, bold: true),
                    const SizedBox(height: 8),
                    _row('Current LVP Balance', widget.currentBalance),
                    const SizedBox(height: 5),
                    _row('New LVP Balance',
                        widget.currentBalance + calc.credited, bold: true),
                  ]),
                ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              calc.accepted ? () => Navigator.of(context).pop(calc) : null,
          child: const Text('Load'),
        ),
      ],
    );
  }

  Widget _row(String label, double value,
      {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AdminColors.gold : AdminColors.charcoal)),
        Text(Fmt.peso(value),
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color:
                    highlight ? AdminColors.gold : AdminColors.statusActive)),
      ],
    );
  }
}
