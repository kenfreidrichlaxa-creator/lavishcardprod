import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/services/lvp_calculator.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/nfc_service.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../shared/widgets/page_header.dart';

/// Super Admin — Cards by Franchise.
///
/// The Super Admin picks a FRANCHISE GROUP (tab). New cards registered/added
/// under that tab are assigned to that franchise's branch, so when the cards
/// are shipped to that franchise's admins they work there. Also allows loading
/// a customer's card. The Super Admin can do this without being at a branch.
class FranchiseCardsScreen extends StatefulWidget {
  const FranchiseCardsScreen({super.key});

  @override
  State<FranchiseCardsScreen> createState() => _FranchiseCardsScreenState();
}

class _FranchiseCardsScreenState extends State<FranchiseCardsScreen> {
  final _repo = AdminAuthRepository.instance;

  bool _loading = true;
  String? _error;
  List<BranchGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _repo.listBranchGroups();
      // Only groups that have at least one branch can hold cards.
      final usable = groups.where((g) => g.branches.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        _groups = usable;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AdminColors.gold)),
      );
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }
    if (_groups.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Cards by Franchise',
                subtitle: 'Register and load cards per franchise group.',
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.account_tree_rounded,
                        size: 44, color: AdminColors.brownLight),
                    const SizedBox(height: 12),
                    Text('No franchise groups with branches yet.',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Create a franchise group and assign branches first.',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: _groups.length,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: PageHeader(
                title: 'Cards by Franchise',
                subtitle:
                    'Pick a franchise, then register or load cards for it. '
                    'New cards are assigned to that franchise.',
              ),
            ),
            Container(
              color: AdminColors.cardBg,
              child: TabBar(
                isScrollable: true,
                indicatorColor: AdminColors.gold,
                labelColor: AdminColors.gold,
                unselectedLabelColor: AdminColors.brownLight,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: _groups
                    .map((g) => Tab(
                          icon: const Icon(Icons.account_tree_rounded, size: 16),
                          text: g.name,
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: _groups
                    .map((g) => _FranchiseCardPanel(group: g))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One franchise tab: register a card / add blank card / load a customer card,
/// all assigned to this franchise's primary branch.
class _FranchiseCardPanel extends StatefulWidget {
  const _FranchiseCardPanel({required this.group});
  final BranchGroup group;

  @override
  State<_FranchiseCardPanel> createState() => _FranchiseCardPanelState();
}

class _FranchiseCardPanelState extends State<_FranchiseCardPanel> {
  // The franchise's primary branch (new cards are tagged with this).
  String get _branchId => widget.group.branches.first.id;
  String get _branchName => widget.group.branches.first.name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchList = widget.group.branches.map((b) => b.name).join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.statusActiveBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AdminColors.statusActive),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cards created here are assigned to "${widget.group.name}" '
                    '(branches: $branchList). They will work at those branches '
                    'once shipped.',
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.statusActive),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            _ActionCard(
              icon: Icons.person_add_rounded,
              title: 'Register Card + Owner',
              subtitle:
                  'Create a customer account with a card in this franchise.',
              onTap: () => _registerWithOwner(),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.style_rounded,
              title: 'Add Blank Cards',
              subtitle:
                  'Pre-register cards (no owner) to ship to this franchise.',
              onTap: () => _addBlank(),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Load a Card (LVP)',
              subtitle: 'Load LVP into a customer\'s wallet in this franchise.',
              onTap: () => _loadCard(),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AdminColors.error : AdminColors.statusActive,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Register card + owner (assigned to this franchise's branch) ────────────
  Future<void> _registerWithOwner() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RegisterInFranchiseDialog(
        branchId: _branchId,
        branchName: _branchName,
        franchiseName: widget.group.name,
        onDone: (msg) => _snack(msg),
      ),
    );
  }

  // ── Add blank cards (no owner), tagged to this franchise's branch ──────────
  Future<void> _addBlank() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddBlankInFranchiseDialog(
        branchId: _branchId,
        franchiseName: widget.group.name,
      ),
    );
  }

  // ── Load a customer's card (LVP) ───────────────────────────────────────────
  Future<void> _loadCard() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LoadInFranchiseDialog(
        branchId: _branchId,
        franchiseName: widget.group.name,
        onDone: (msg) => _snack(msg),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AdminColors.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AdminColors.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AdminColors.brownLight),
          ]),
        ),
      ),
    );
  }
}

// ── Register card + owner in a specific franchise branch ─────────────────────

class _RegisterInFranchiseDialog extends StatefulWidget {
  const _RegisterInFranchiseDialog({
    required this.branchId,
    required this.branchName,
    required this.franchiseName,
    required this.onDone,
  });
  final String branchId;
  final String branchName;
  final String franchiseName;
  final ValueChanged<String> onDone;

  @override
  State<_RegisterInFranchiseDialog> createState() =>
      _RegisterInFranchiseDialogState();
}

class _RegisterInFranchiseDialogState
    extends State<_RegisterInFranchiseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  bool _saving = false;
  bool _scanning = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _pwCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final uid = await NfcService.instance.readCardUid();
      if (mounted) setState(() { _cardCtrl.text = uid; _scanning = false; });
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final res = await CardOwnerRepository.instance.registerCardOwnerInBranch(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _pwCtrl.text,
      cardDisplayId: _cardCtrl.text.trim(),
      branchId: widget.branchId,
    );
    if (!mounted) return;
    if (!res.success) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.error ?? 'Registration failed.'),
          backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onDone('${_nameCtrl.text.trim()} registered in ${widget.franchiseName}.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Register Card — ${widget.franchiseName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _f(_nameCtrl, 'Full Name', Icons.person_outline_rounded,
                  req: true),
              _f(_phoneCtrl, 'Phone', Icons.phone_outlined),
              _f(_emailCtrl, 'Email', Icons.mail_outline_rounded, req: true,
                  email: true),
              _f(_userCtrl, 'Username', Icons.alternate_email_rounded,
                  req: true),
              TextFormField(
                controller: _pwCtrl,
                obscureText: _obscure,
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
                validator: (v) =>
                    (v == null || v.length < 4) ? 'Min 4 chars' : null,
              ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _f(_cardCtrl, 'Card ID (tap or type)',
                      Icons.nfc_rounded,
                      req: true),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.contactless_rounded, size: 16),
                    label: Text(_scanning ? 'Tap…' : 'Tap'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Register'),
        ),
      ],
    );
  }

  Widget _f(TextEditingController c, String label, IconData icon,
      {bool req = false, bool email = false}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (req && t.isEmpty) return 'Required';
        if (email && t.isNotEmpty &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }
}

// ── Add blank cards in a specific franchise branch ───────────────────────────

class _AddBlankInFranchiseDialog extends StatefulWidget {
  const _AddBlankInFranchiseDialog({
    required this.branchId,
    required this.franchiseName,
  });
  final String branchId;
  final String franchiseName;

  @override
  State<_AddBlankInFranchiseDialog> createState() =>
      _AddBlankInFranchiseDialogState();
}

class _AddBlankInFranchiseDialogState
    extends State<_AddBlankInFranchiseDialog> {
  final _uidCtrl = TextEditingController();
  bool _scanning = false;
  bool _saving = false;
  final List<String> _added = [];

  @override
  void dispose() {
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final uid = await NfcService.instance.readCardUid();
      if (!mounted) return;
      setState(() { _uidCtrl.text = uid; _scanning = false; });
      await _add();
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _add() async {
    final uid = _uidCtrl.text.trim().toUpperCase();
    if (uid.isEmpty || _added.contains(uid)) return;
    setState(() => _saving = true);
    final err = await CardOwnerRepository.instance
        .addBlankCardInBranch(cardUid: uid, branchId: widget.branchId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    setState(() {
      _added.insert(0, uid);
      _uidCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Add Blank Cards — ${widget.franchiseName}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _uidCtrl,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  labelText: 'Card UID (tap or type)',
                  prefixIcon: Icon(Icons.nfc_rounded),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.contactless_rounded, size: 16),
                label: Text(_scanning ? 'Tap…' : 'Tap'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Card'),
              style:
                  FilledButton.styleFrom(backgroundColor: AdminColors.statusActive),
            ),
          ),
          if (_added.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Added (${_added.length})',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AdminColors.gold)),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: AdminColors.cream,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _added
                      .map((u) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.check_circle_rounded,
                                size: 16, color: AdminColors.statusActive),
                            title: Text(u,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 13)),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ]),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ── Load a customer's card (LVP) within a franchise ──────────────────────────

class _LoadInFranchiseDialog extends StatefulWidget {
  const _LoadInFranchiseDialog({
    required this.branchId,
    required this.franchiseName,
    required this.onDone,
  });
  final String branchId;
  final String franchiseName;
  final ValueChanged<String> onDone;

  @override
  State<_LoadInFranchiseDialog> createState() => _LoadInFranchiseDialogState();
}

class _LoadInFranchiseDialogState extends State<_LoadInFranchiseDialog> {
  final _amountCtrl = TextEditingController();
  bool _loadingOwners = true;
  bool _saving = false;
  List<CardOwnerModel> _owners = const [];
  CardOwnerModel? _selected;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    try {
      // Super admin: fetch all owners (branchIds empty = all).
      final owners = await CardOwnerRepository.instance.fetchCardOwners();
      if (!mounted) return;
      setState(() { _owners = owners; _loadingOwners = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOwners = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0;
  LvpLoadResult get _calc => LvpCalculator.compute(_amount);

  Future<void> _submit() async {
    final calc = _calc;
    if (_selected == null || !calc.accepted) return;
    setState(() => _saving = true);
    final res = await CardOwnerRepository.instance.loadWalletWithBonus(
      clientId: _selected!.id,
      paid: calc.loadingAmount,
      performedBy: 'Super Admin',
    );
    if (!mounted) return;
    if (!res.success) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.error ?? 'Load failed.'),
          backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onDone(
        '${Fmt.peso(res.total)} loaded to ${_selected!.fullName}.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calc = _calc;
    return AlertDialog(
      title: const Text('Load a Card'),
      content: SizedBox(
        width: 420,
        child: _loadingOwners
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AdminColors.gold)),
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<CardOwnerModel>(
                  initialValue: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: _owners
                      .map((o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                                '${o.fullName}  ·  ${Fmt.peso(o.walletBalance)}',
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (o) => setState(() => _selected = o),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Loading Amount (₱)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    helperText: 'Minimum ₱2,500.00',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                if (_amount > 0) ...[
                  const SizedBox(height: 12),
                  if (!calc.accepted)
                    Text(calc.reason ?? 'Not allowed.',
                        style: const TextStyle(
                            fontSize: 12, color: AdminColors.statusSuspended))
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminColors.statusActiveBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(children: [
                        _row('Loading Amount', calc.loadingAmount, theme),
                        const SizedBox(height: 4),
                        _row('Bonus', calc.bonus, theme, gold: true),
                        const Divider(height: 14),
                        _row('LVP to Credit', calc.credited, theme, bold: true),
                        if (_selected != null) ...[
                          const SizedBox(height: 4),
                          _row('New Balance',
                              _selected!.walletBalance + calc.credited, theme,
                              bold: true),
                        ],
                      ]),
                    ),
                ],
              ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: (_saving || _selected == null || !calc.accepted)
              ? null
              : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Load LVP'),
        ),
      ],
    );
  }

  Widget _row(String label, double value, ThemeData theme,
      {bool bold = false, bool gold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: gold ? AdminColors.gold : AdminColors.charcoal)),
        Text(Fmt.peso(value),
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: gold ? AdminColors.gold : AdminColors.statusActive)),
      ],
    );
  }
}
