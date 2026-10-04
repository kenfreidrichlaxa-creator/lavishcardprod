import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/models/wallet_transaction_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/lvp_calculator.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../widgets/operation_receipt_card.dart';

/// Tabbed screen: Card Sale | Top Up | Transfer
class WalletOperationsScreen extends StatefulWidget {
  const WalletOperationsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<WalletOperationsScreen> createState() =>
      _WalletOperationsScreenState();
}

class _WalletOperationsScreenState extends State<WalletOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet Operations',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Sell cards, top up wallets, and transfer balances.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Container(
            color: AdminColors.cardBg,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AdminColors.gold,
              labelColor: AdminColors.gold,
              unselectedLabelColor: AdminColors.brownLight,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.add_card_rounded, size: 18), text: 'Card Sale'),
                Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Top Up'),
                Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Transfer'),
              ],
            ),
          ),
         Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _CardSaleTab(),
                _TopUpTab(),
                _TransferTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── INFO BANNER ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.statusAvailableBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AdminColors.statusAvailable.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AdminColors.statusAvailable),
        const SizedBox(width: 10),
       Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.statusAvailable,
                  height: 1.5)),
        ),
      ]),
    );
  }
}

// ── CARD SALE ────────────────────────────────────────────────────────────────

class _CardSaleTab extends StatefulWidget {
  const _CardSaleTab();

  @override
  State<_CardSaleTab> createState() => _CardSaleTabState();
}

class _CardSaleTabState extends State<_CardSaleTab> {
  final _formKey = GlobalKey<FormState>();
  NfcCardModel? _selectedCard;
  CardOwnerModel? _selectedOwner;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _initialLoadCtrl = TextEditingController(text: '0.00');
  bool _saving = false;
  WalletTransactionModel? _lastRecord;

  List<NfcCardModel> get _availableCards =>
      AdminMockData.nfcCards.where((c) => c.status == NfcCardStatus.available).toList();

  List<CardOwnerModel> get _unlinkedOwners =>
      AdminMockData.cardOwners.where((o) => o.linkedCardId == null).toList();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _initialLoadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_lastRecord != null) {
      return OperationReceiptCard(
        record: _lastRecord!,
        onNewTransaction: () => setState(() => _lastRecord = null),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InfoBanner(
                icon: Icons.info_outline_rounded,
                message: 'Selling a card links it to a customer and optionally loads an initial wallet balance.',
              ),
              const SizedBox(height: 20),

              Text('Card to Sell',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AdminColors.brownLight, letterSpacing: 0.5)),
              const SizedBox(height: 8),

              DropdownButtonFormField<NfcCardModel>(
                initialValue: _selectedCard,
                decoration: const InputDecoration(
                  labelText: 'Select Available Card',
                  prefixIcon: Icon(Icons.nfc_rounded),
                ),
                items: _availableCards
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.cardId,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (c) => setState(() => _selectedCard = c),
                validator: (v) => v == null ? 'Select a card' : null,
              ),
              const SizedBox(height: 20),

              Text('Assign To',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AdminColors.brownLight, letterSpacing: 0.5)),
              const SizedBox(height: 8),

              if (_unlinkedOwners.isNotEmpty)
                DropdownButtonFormField<CardOwnerModel>(
                  initialValue: _selectedOwner,
                  decoration: const InputDecoration(
                    labelText: 'Existing Customer (optional)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<CardOwnerModel>(
                        value: null, child: Text('— New Customer —')),
                    ..._unlinkedOwners.map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(
                            '${o.fullName}  ·  ${o.customerId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (o) {
                    setState(() {
                      _selectedOwner = o;
                      if (o != null) {
                        _nameCtrl.text = o.fullName;
                        _phoneCtrl.text = o.phone;
                        _emailCtrl.text = o.email;
                      } else {
                        _nameCtrl.clear();
                        _phoneCtrl.clear();
                        _emailCtrl.clear();
                      }
                    });
                  },
                ),
              const SizedBox(height: 12),

              if (_selectedOwner == null) ...[
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person_outline_rounded)),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.mail_outline_rounded)),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _initialLoadCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Initial Wallet Load (LVP)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    hintText: '0.00'),
                style: const TextStyle(fontSize: 13),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter 0 if no initial load';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text('Complete Card Sale',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_initialLoadCtrl.text) ?? 0;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Card Sale',
      message: 'Sell card ${_selectedCard?.cardId} to ${_nameCtrl.text.trim()}?\n\n'
          'Initial load: ${Fmt.peso(amount)}',
      confirmLabel: 'Confirm Sale',
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    final record = WalletTransactionModel(
      id: 'wt_${DateTime.now().millisecondsSinceEpoch}',
      type: WalletTxType.cardSale,
      amount: amount,
      performedBy: AuthService.instance.currentUser?.fullName ?? 'Manager',
      dateTime: DateTime.now(),
      notes: 'Card ${_selectedCard?.cardId} sold to ${_nameCtrl.text.trim()}',
      targetOwnerName: _nameCtrl.text.trim(),
      targetCardId: _selectedCard?.cardId,
    );
    if (mounted) setState(() { _saving = false; _lastRecord = record; });
  }
}

// ── TOP UP ────────────────────────────────────────────────────────────────────

class _TopUpTab extends StatefulWidget {
  const _TopUpTab();

  @override
  State<_TopUpTab> createState() => _TopUpTabState();
}

class _TopUpTabState extends State<_TopUpTab> {
  final _formKey = GlobalKey<FormState>();
  CardOwnerModel? _selectedOwner;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  bool _loadingOwners = true;
  String? _loadError;
  List<CardOwnerModel> _owners = const [];
  WalletTransactionModel? _lastRecord;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    setState(() { _loadingOwners = true; _loadError = null; });
    try {
      final owners = await CardOwnerRepository.instance
          .fetchCardOwners(branchIds: AdminSession.branchIds);
      if (!mounted) return;
      setState(() { _owners = owners; _loadingOwners = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = 'Failed to load customers: $e'; _loadingOwners = false; });
    }
  }

  // Tiered LVP loading calculation (single source of truth).
  double get _amount =>
      double.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0;
  LvpLoadResult get _calc => LvpCalculator.compute(_amount);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_lastRecord != null) {
      return OperationReceiptCard(
        record: _lastRecord!,
        onNewTransaction: () {
          setState(() => _lastRecord = null);
          _loadOwners(); // refresh balances after a successful load
        },
      );
    }

    if (_loadingOwners) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InfoBanner(
                icon: Icons.account_balance_wallet_rounded,
                message: 'Load LVP (Prima Service Value). Minimum ₱2,500. '
                    '₱2,500–₱3,999 earns a fixed ₱500 bonus; ₱4,000+ earns a 25% bonus.',
              ),
              const SizedBox(height: 20),

              if (_loadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.statusSuspendedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AdminColors.statusSuspended),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_loadError!, style: const TextStyle(fontSize: 12, color: AdminColors.statusSuspended))),
                    TextButton(onPressed: _loadOwners, child: const Text('Retry')),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              DropdownButtonFormField<CardOwnerModel>(
                initialValue: _selectedOwner,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Customer',
                    prefixIcon: Icon(Icons.person_outline_rounded)),
                items: _owners.map((o) => DropdownMenuItem(
                  value: o,
                  child: Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AdminColors.cream,
                      child: Text(o.initials,
                          style: const TextStyle(fontSize: 9, color: AdminColors.gold, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                   Expanded(
                      child: Text(
                        '${o.fullName}  ·  ${Fmt.peso(o.walletBalance)}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                )).toList(),
                onChanged: (o) => setState(() => _selectedOwner = o),
                validator: (v) => v == null ? 'Select a customer' : null,
              ),

              if (_selectedOwner != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminColors.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminColors.beigeDeep),
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 16, color: AdminColors.brownLight),
                    const SizedBox(width: 10),
                    Text('Current Balance: ', style: theme.textTheme.bodyMedium),
                    Text(Fmt.peso(_selectedOwner!.walletBalance),
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: AdminColors.statusActive, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Loading Amount (₱)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    hintText: '0.00',
                    helperText: 'Minimum ₱2,500.00'),
                style: const TextStyle(fontSize: 13),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  if (n < LvpCalculator.minimumLoad) {
                    return 'Minimum loading is ${Fmt.peso(LvpCalculator.minimumLoad)}';
                  }
                  return null;
                },
              ),

              // Live LVP breakdown (recalculates on every change).
              if (_amount > 0) ...[
                const SizedBox(height: 14),
                if (!_calc.accepted)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminColors.statusSuspendedBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminColors.statusSuspended.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.block_rounded,
                          size: 18, color: AdminColors.statusSuspended),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_calc.reason ?? 'Loading not allowed.',
                            style: const TextStyle(
                                fontSize: 12, color: AdminColors.statusSuspended)),
                      ),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminColors.statusActiveBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminColors.statusActive.withValues(alpha: 0.35)),
                    ),
                    child: Column(children: [
                      _bonusRow('Loading Amount', _calc.loadingAmount, theme),
                      const SizedBox(height: 6),
                      _bonusRow('Bonus', _calc.bonus, theme, highlight: true),
                      const Divider(height: 18),
                      _bonusRow('LVP to Credit', _calc.credited, theme, bold: true),
                      if (_selectedOwner != null) ...[
                        const SizedBox(height: 10),
                        _bonusRow('Current LVP Balance',
                            _selectedOwner!.walletBalance, theme),
                        const SizedBox(height: 6),
                        _bonusRow('New LVP Balance',
                            _selectedOwner!.walletBalance + _calc.credited, theme,
                            bold: true),
                      ],
                    ]),
                  ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    hintText: 'e.g. Cash payment'),
                style: const TextStyle(fontSize: 13),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: (_saving || !_calc.accepted) ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: const Text('Load LVP',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(backgroundColor: AdminColors.statusActive),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bonusRow(String label, double value, ThemeData theme,
      {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AdminColors.gold : null)),
        Text(Fmt.peso(value),
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AdminColors.gold : AdminColors.statusActive)),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final calc = _calc;
    if (!calc.accepted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(calc.reason ?? 'Loading not allowed.'),
        backgroundColor: AdminColors.statusSuspended,
      ));
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm LVP Loading',
      message: 'Load for ${_selectedOwner!.fullName}:\n\n'
          'Loading Amount: ${Fmt.peso(calc.loadingAmount)}\n'
          'Bonus: ${Fmt.peso(calc.bonus)}\n'
          'LVP to Credit: ${Fmt.peso(calc.credited)}\n'
          'New LVP Balance: ${Fmt.peso(_selectedOwner!.walletBalance + calc.credited)}',
      confirmLabel: 'Load LVP',
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);

    final performer = AuthService.instance.currentUser?.fullName ?? 'Manager';
    final result = await CardOwnerRepository.instance.loadWalletWithBonus(
      clientId: _selectedOwner!.id,
      paid: calc.loadingAmount,
      performedBy: performer,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Loading failed.'),
            backgroundColor: AdminColors.statusSuspended),
      );
      return;
    }

    final record = WalletTransactionModel(
      id: 'wt_${DateTime.now().millisecondsSinceEpoch}',
      type: WalletTxType.topUp,
      amount: result.total,
      performedBy: performer,
      dateTime: DateTime.now(),
      notes: 'Loaded ${Fmt.peso(result.paid)} + bonus ${Fmt.peso(result.bonus)}'
          '${_notesCtrl.text.trim().isEmpty ? '' : ' · ${_notesCtrl.text.trim()}'}',
      targetOwnerId: _selectedOwner!.id,
      targetOwnerName: _selectedOwner!.fullName,
    );
    setState(() { _saving = false; _lastRecord = record; });
  }
}

// ── TRANSFER ─────────────────────────────────────────────────────────────────

class _TransferTab extends StatefulWidget {
  const _TransferTab();

  @override
  State<_TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends State<_TransferTab> {
  final _formKey = GlobalKey<FormState>();
  CardOwnerModel? _fromOwner;
  CardOwnerModel? _toOwner;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  WalletTransactionModel? _lastRecord;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_lastRecord != null) {
      return OperationReceiptCard(
        record: _lastRecord!,
        onNewTransaction: () => setState(() => _lastRecord = null),
      );
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final insufficient = _fromOwner != null && amount > _fromOwner!.walletBalance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InfoBanner(
                icon: Icons.swap_horiz_rounded,
                message: 'Transfer wallet balance from one customer account to another.',
              ),
              const SizedBox(height: 20),

              Text('FROM', style: theme.textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1, color: AdminColors.brownLight)),
              const SizedBox(height: 6),
              _ownerDropdown(
                label: 'From Customer',
                value: _fromOwner,
                exclude: _toOwner?.id,
                onChanged: (o) => setState(() { _fromOwner = o; }),
                validator: (v) => v == null ? 'Select a customer' : null,
              ),
              if (_fromOwner != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                  child: Text('Available: ${Fmt.peso(_fromOwner!.walletBalance)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: insufficient ? AdminColors.statusSuspended : AdminColors.statusActive,
                          fontWeight: FontWeight.w600)),
                ),

              const SizedBox(height: 14),
              const Center(child: Icon(Icons.arrow_downward_rounded,
                  color: AdminColors.brownLight, size: 20)),
              const SizedBox(height: 10),

              Text('TO', style: theme.textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1, color: AdminColors.brownLight)),
              const SizedBox(height: 6),
              _ownerDropdown(
                label: 'To Customer',
                value: _toOwner,
                exclude: _fromOwner?.id,
                onChanged: (o) => setState(() { _toOwner = o; }),
                validator: (v) => v == null ? 'Select a customer' : null,
              ),

              const SizedBox(height: 14),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Transfer Amount (LVP)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  hintText: '0.00',
                  errorText: insufficient ? 'Insufficient balance' : null,
                ),
                style: const TextStyle(fontSize: 13),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Invalid amount';
                  if (_fromOwner != null && n > _fromOwner!.walletBalance) {
                    return 'Insufficient balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    hintText: 'Reason for transfer'),
                style: const TextStyle(fontSize: 13),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving || insufficient ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Transfer Balance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(backgroundColor: AdminColors.statusAvailable),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerDropdown({
    required String label,
    required CardOwnerModel? value,
    required String? exclude,
    required ValueChanged<CardOwnerModel?> onChanged,
    required String? Function(CardOwnerModel?)? validator,
  }) {
    return DropdownButtonFormField<CardOwnerModel>(
      initialValue: value,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.person_outline_rounded)),
      items: AdminMockData.cardOwners
          .where((o) => o.id != exclude)
          .map((o) => DropdownMenuItem(
                value: o,
                child: Row(children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AdminColors.cream,
                    child: Text(o.initials,
                        style: const TextStyle(fontSize: 9, color: AdminColors.gold, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                 Expanded(
                    child: Text(
                      '${o.fullName}  ·  ${Fmt.peso(o.walletBalance)}',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', ''));
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Transfer',
      message: 'Transfer ${Fmt.peso(amount)} from ${_fromOwner!.fullName} to ${_toOwner!.fullName}?',
      confirmLabel: 'Transfer',
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    final record = WalletTransactionModel(
      id: 'wt_${DateTime.now().millisecondsSinceEpoch}',
      type: WalletTxType.transfer,
      amount: amount,
      performedBy: AuthService.instance.currentUser?.fullName ?? 'Manager',
      dateTime: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? 'Wallet transfer' : _notesCtrl.text.trim(),
      fromOwnerId: _fromOwner!.id,
      fromOwnerName: _fromOwner!.fullName,
      toOwnerId: _toOwner!.id,
      toOwnerName: _toOwner!.fullName,
    );
    if (mounted) setState(() { _saving = false; _lastRecord = record; });
  }
}
