import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/services/lvp_calculator.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/nfc_service.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/super_admin_gate.dart';
import '../../card_owners/screens/card_owner_profile_screen.dart';

/// Reusable Cards hub organised by FRANCHISE tabs. Each franchise tab shows:
///   • actions (register / add blank / load) for that franchise
///   • its blank (unclaimed) cards
///   • its card owners
///
/// [requireApproval] = true gates the write actions behind a Super Admin login
/// (used by the admin app). Super Admin passes false.
/// [scopeBranchIds] restricts which franchise groups appear (admin's branches);
/// empty/null = all groups (super admin).
class FranchiseCardsHub extends StatefulWidget {
  const FranchiseCardsHub({
    super.key,
    required this.requireApproval,
    this.scopeBranchIds,
  });

  final bool requireApproval;
  final List<String>? scopeBranchIds;

  @override
  State<FranchiseCardsHub> createState() => _FranchiseCardsHubState();
}

class _FranchiseCardsHubState extends State<FranchiseCardsHub> {
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
    setState(() { _loading = true; _error = null; });
    try {
      final all = await _repo.listBranchGroups();
      var groups = all.where((g) => g.branches.isNotEmpty).toList();
      final scope = widget.scopeBranchIds?.toSet() ?? {};
      if (scope.isNotEmpty) {
        final s = groups
            .where((g) => g.branches.any((b) => scope.contains(b.id)))
            .toList();
        if (s.isNotEmpty) groups = s;
      }
      if (!mounted) return;
      setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminColors.gold));
    }
    if (_error != null) return Center(child: Text(_error!));
    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_tree_rounded,
                size: 44, color: AdminColors.brownLight),
            const SizedBox(height: 12),
            Text('No franchise available yet.',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Create a franchise group with branches first.',
                style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: _groups.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  .map((g) => _FranchiseTab(
                        group: g,
                        requireApproval: widget.requireApproval,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── One franchise tab: actions + blank cards + card owners ───────────────────

class _FranchiseTab extends StatefulWidget {
  const _FranchiseTab({required this.group, required this.requireApproval});
  final BranchGroup group;
  final bool requireApproval;

  @override
  State<_FranchiseTab> createState() => _FranchiseTabState();
}

class _FranchiseTabState extends State<_FranchiseTab> {
  final _repo = CardOwnerRepository.instance;
  bool _loading = true;
  List<CardOwnerModel> _owners = [];
  List<Map<String, dynamic>> _blanks = [];
  String _query = '';
  DateTime? _blankFrom; // registration date filter (inclusive)
  DateTime? _blankTo;

  String get _branchId => widget.group.branches.first.id;
  List<String> get _branchIds =>
      widget.group.branches.map((b) => b.id).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final owners = await _repo.fetchCardOwners(branchIds: _branchIds);
      final blanks = await _repo.fetchBlankCardsDetailed(branchIds: _branchIds);
      if (!mounted) return;
      setState(() {
        _owners = owners;
        _blanks = blanks;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Blank cards after applying the date filter, oldest-first (already sorted).
  List<Map<String, dynamic>> get _filteredBlanks {
    return _blanks.where((b) {
      final created = DateTime.tryParse((b['created_at'] as String?) ?? '');
      if (created == null) return true;
      final d = created.toLocal();
      if (_blankFrom != null && d.isBefore(_blankFrom!)) return false;
      if (_blankTo != null &&
          d.isAfter(DateTime(_blankTo!.year, _blankTo!.month, _blankTo!.day,
              23, 59, 59))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<CardOwnerModel> get _filteredOwners {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _owners;
    return _owners.where((o) =>
        o.fullName.toLowerCase().contains(q) ||
        o.customerId.toLowerCase().contains(q) ||
        o.phone.contains(q) ||
        (o.linkedCardId?.toLowerCase().contains(q) ?? false)).toList();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AdminColors.error : AdminColors.statusActive,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _gate(String action) async {
    if (!widget.requireApproval) return true;
    return SuperAdminGate.require(context, action: action);
  }

  Future<void> _register() async {
    if (!await _gate('register a card') || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _RegisterDialog(
        branchId: _branchId,
        franchiseName: widget.group.name,
        onDone: (m) { _snack(m); _load(); },
      ),
    );
  }

  Future<void> _addBlank() async {
    if (!await _gate('add blank cards') || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _AddBlankDialog(
        branchId: _branchId,
        franchiseName: widget.group.name,
      ),
    );
    _load();
  }

  Future<void> _loadCard() async {
    if (!await _gate('load a card') || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _LoadDialog(
        branchIds: _branchIds,
        onDone: (m) { _snack(m); _load(); },
      ),
    );
  }

  Future<void> _loadBlank(String cardRef, String display) async {
    if (!await _gate('load a blank card') || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _LoadBlankDialog(
        cardRef: cardRef,
        cardDisplay: display,
        onDone: (m) { _snack(m); _load(); },
      ),
    );
  }

  // Identify which franchise/branch a card is assigned to (no gate — read-only).
  Future<void> _identify() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _IdentifyCardDialog(),
    );
  }

  Future<void> _deleteBlank(String cardRef, String display) async {
    if (!await _gate('delete a blank card') || !mounted) return;
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Blank Card'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'Delete blank card "$display"? This removes it permanently. '
                'Only unclaimed cards (no owner) can be deleted.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            TextFormField(
              controller: noteCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'e.g. damaged card, wrong entry',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A reason is required.' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.error),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(noteCtrl.text.trim());
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    final err =
        await CardOwnerRepository.instance.deleteBlankCard(cardRef, note: note);
    if (!mounted) return;
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _snack('Blank card "$display" deleted.');
    _load();
  }

  // ── Blank-card date filter + export helpers ────────────────────────────────
  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _dateChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      avatar: const Icon(Icons.calendar_today_rounded,
          size: 14, color: AdminColors.brownMedium),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: AdminColors.cream,
    );
  }

  Future<void> _pickBlankDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _blankFrom : _blankTo) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _blankFrom = picked;
      } else {
        _blankTo = picked;
      }
    });
  }

  /// Export a numbered RANGE of the (filtered) blank cards to a CSV whose rows
  /// are formatted as  <FRANCHISE_CODE>-<UID>.
  Future<void> _exportBlanks(List<Map<String, dynamic>> filtered) async {
    final total = filtered.length;
    final fromCtrl = TextEditingController(text: '1');
    final toCtrl = TextEditingController(text: '$total');
    final formKey = GlobalKey<FormState>();

    final range = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Blank Cards'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'There are $total blank card(s). Choose the range to export '
                '(e.g. 1 to 15, or 4 to 9).',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: fromCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'From #', isDense: true),
                  validator: (v) => _rangeErr(v, total),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: toCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'To #', isDense: true),
                  validator: (v) => _rangeErr(v, total),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final f = int.parse(fromCtrl.text.trim());
              final t = int.parse(toCtrl.text.trim());
              if (f > t) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('"From" must be less than or equal to "To".'),
                    backgroundColor: AdminColors.error));
                return;
              }
              Navigator.of(ctx).pop([f, t]);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (range == null || !mounted) return;
    final from = range[0], to = range[1];
    // 1-based inclusive slice.
    final slice = filtered.sublist(from - 1, to);

    try {
      final path = await CardOwnerRepository.instance.exportBlankCardsCsv(
        slice,
        franchiseName: widget.group.name,
        startIndex: from,
      );
      if (!mounted) return;
      _snack('Saved ${slice.length} card(s) to: $path');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not export: $e', error: true);
    }
  }

  static String? _rangeErr(String? v, int total) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Number';
    if (n < 1 || n > total) return '1–$total';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchList = widget.group.branches.map((b) => b.name).join(', ');
    return RefreshIndicator(
      onRefresh: _load,
      color: AdminColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info banner
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
                  'Cards here are assigned to "${widget.group.name}" '
                  '(branches: $branchList).'
                  '${widget.requireApproval ? ' Super Admin approval required.' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AdminColors.statusActive),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Actions
          Wrap(spacing: 10, runSpacing: 10, children: [
            _actionBtn(Icons.person_add_rounded, 'Register Card + Owner', _register),
            _actionBtn(Icons.style_rounded, 'Add Blank Cards', _addBlank),
            _actionBtn(Icons.account_balance_wallet_rounded, 'Load a Card', _loadCard),
            _actionBtn(Icons.contactless_rounded, 'Identify Card (Tap)', _identify),
          ]),
          const SizedBox(height: 24),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                  child: CircularProgressIndicator(color: AdminColors.gold)),
            )
          else ...[
            // Blank cards — counter + date filter + export + numbered list
            Builder(builder: (context) {
              final filtered = _filteredBlanks;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.style_rounded,
                        size: 18, color: AdminColors.brownMedium),
                    const SizedBox(width: 8),
                    Text('Blank Cards (${filtered.length})',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (filtered.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _exportBlanks(filtered),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export to Excel'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AdminColors.gold,
                            side: const BorderSide(color: AdminColors.gold)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  // Date filter row
                  Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment:
                      WrapCrossAlignment.center, children: [
                    _dateChip(
                      label: _blankFrom == null
                          ? 'From date'
                          : 'From ${_fmtDate(_blankFrom!)}',
                      onTap: () => _pickBlankDate(isFrom: true),
                    ),
                    _dateChip(
                      label: _blankTo == null
                          ? 'To date'
                          : 'To ${_fmtDate(_blankTo!)}',
                      onTap: () => _pickBlankDate(isFrom: false),
                    ),
                    if (_blankFrom != null || _blankTo != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _blankFrom = null;
                          _blankTo = null;
                        }),
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                            foregroundColor: AdminColors.brownMedium),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Text('No blank cards for this franchise.',
                        style: theme.textTheme.bodySmall)
                  else
                    Card(
                      child: Column(
                        children: List.generate(
                          filtered.length > 100 ? 100 : filtered.length,
                          (i) {
                            final b = filtered[i];
                            final display =
                                (b['card_display_id'] as String?) ??
                                    (b['card_uid'] as String?) ??
                                    '';
                            final ref = (b['card_id'] as String?) ??
                                (b['card_display_id'] as String?) ??
                                (b['card_uid'] as String?) ??
                                '';
                            final created = DateTime.tryParse(
                                (b['created_at'] as String?) ?? '');
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 13,
                                backgroundColor: AdminColors.cream,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: AdminColors.gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                              title: Text(display,
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 13)),
                              subtitle: Text(
                                  created != null
                                      ? 'Registered ${_fmtDateTime(created.toLocal())}'
                                      : 'Unclaimed — ready to ship',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _Chip(
                                      'BLANK', AdminColors.brownMedium),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _loadBlank(ref, display),
                                    icon: const Icon(
                                        Icons
                                            .account_balance_wallet_outlined,
                                        size: 15),
                                    label: const Text('Load'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AdminColors.gold,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete blank card',
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AdminColors.error),
                                    onPressed: () =>
                                        _deleteBlank(ref, display),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 24),

            // Card owners
            Row(children: [
              const Icon(Icons.people_alt_rounded,
                  size: 18, color: AdminColors.brownMedium),
              const SizedBox(width: 8),
              Text('Card Owners (${_owners.length})',
                  style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search owner by name, ID, phone, or card…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (_filteredOwners.isEmpty)
              const EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No card owners',
                subtitle: 'Register a customer to get started.',
              )
            else
              Card(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            columnSpacing: 28,
                            // Let the Name column absorb the extra width so the
                            // table fills the whole area (no empty gap).
                            columns: const [
                              DataColumn(label: Text('CUSTOMER ID')),
                              DataColumn(label: Text('NAME')),
                              DataColumn(label: Text('CARD')),
                              DataColumn(label: Text('BALANCE')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('ACTION')),
                            ],
                            rows: _filteredOwners
                                .map((o) => _ownerRow(o, theme))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
            backgroundColor: AdminColors.gold,
            foregroundColor: Colors.white),
      ),
    );
  }

  DataRow _ownerRow(CardOwnerModel o, ThemeData theme) {
    return DataRow(cells: [
      DataCell(Text(o.customerId,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 12,
              color: AdminColors.brownMedium))),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AdminColors.cream,
          child: Text(o.initials,
              style: const TextStyle(
                  color: AdminColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(o.fullName, style: theme.textTheme.titleSmall),
      ])),
      DataCell(o.linkedCardId != null
          ? Text(o.linkedCardId!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11))
          : const Text('—', style: TextStyle(color: AdminColors.brownLight))),
      DataCell(Text(Fmt.peso(o.walletBalance), style: theme.textTheme.titleSmall)),
      DataCell(StatusChip.cardOwner(o.status)),
      DataCell(Tooltip(
        message: 'View profile',
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CardOwnerProfileScreen(owner: o),
            ));
            _load();
          },
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.visibility_outlined,
                size: 16, color: AdminColors.brownMedium),
          ),
        ),
      )),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Register dialog ──────────────────────────────────────────────────────────

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog(
      {required this.branchId,
      required this.franchiseName,
      required this.onDone});
  final String branchId;
  final String franchiseName;
  final ValueChanged<String> onDone;

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _user = TextEditingController();
  final _pw = TextEditingController();
  final _card = TextEditingController();
  bool _saving = false, _scanning = false, _obscure = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _user, _pw, _card]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final uid = await NfcService.instance.readCardUid();
      if (mounted) setState(() { _card.text = uid; _scanning = false; });
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final res = await CardOwnerRepository.instance.registerCardOwnerInBranch(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      username: _user.text.trim(),
      password: _pw.text,
      cardDisplayId: _card.text.trim(),
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
    widget.onDone('${_name.text.trim()} registered in ${widget.franchiseName}.');
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
              _f(_name, 'Full Name', Icons.person_outline_rounded, req: true),
              _f(_phone, 'Phone', Icons.phone_outlined),
              _f(_email, 'Email', Icons.mail_outline_rounded,
                  req: true, email: true),
              _f(_user, 'Username', Icons.alternate_email_rounded, req: true),
              TextFormField(
                controller: _pw,
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
                  child: _f(_card, 'Card ID (tap or type)', Icons.nfc_rounded,
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

// ── Add blank cards dialog ───────────────────────────────────────────────────

class _AddBlankDialog extends StatefulWidget {
  const _AddBlankDialog({required this.branchId, required this.franchiseName});
  final String branchId;
  final String franchiseName;

  @override
  State<_AddBlankDialog> createState() => _AddBlankDialogState();
}

class _AddBlankDialogState extends State<_AddBlankDialog> {
  final _uid = TextEditingController();
  bool _scanning = false, _saving = false, _cancelScan = false;
  final List<String> _added = [];

  @override
  void dispose() {
    _cancelScan = true; // stop any in-flight scan when the dialog closes
    _uid.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _cancelScan = false; });
    try {
      final uid = await NfcService.instance
          .readCardUid(shouldCancel: () => _cancelScan);
      if (!mounted) return;
      setState(() { _uid.text = uid; _scanning = false; });
      await _add();
    } on NfcCancelledException {
      if (mounted) setState(() => _scanning = false);
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _cancel() => setState(() => _cancelScan = true);

  Future<void> _add() async {
    final uid = _uid.text.trim().toUpperCase();
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
    setState(() { _added.insert(0, uid); _uid.clear(); });
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
                controller: _uid,
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
              child: _scanning
                  ? OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.error,
                          side: const BorderSide(color: AdminColors.error)),
                    )
                  : FilledButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.contactless_rounded, size: 16),
                      label: const Text('Tap'),
                    ),
            ),
          ]),
          if (_scanning) ...[
            const SizedBox(height: 8),
            const Row(children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AdminColors.gold)),
              SizedBox(width: 8),
              Text('Waiting for card… tap Cancel to stop.',
                  style: TextStyle(fontSize: 12, color: AdminColors.brownMedium)),
            ]),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_saving || _scanning) ? null : _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Card'),
              style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.statusActive),
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

// ── Load a customer card (LVP) ───────────────────────────────────────────────

class _LoadDialog extends StatefulWidget {
  const _LoadDialog({required this.branchIds, required this.onDone});
  final List<String> branchIds;
  final ValueChanged<String> onDone;

  @override
  State<_LoadDialog> createState() => _LoadDialogState();
}

class _LoadDialogState extends State<_LoadDialog> {
  final _amount = TextEditingController();
  bool _loadingOwners = true, _saving = false;
  List<CardOwnerModel> _owners = const [];
  CardOwnerModel? _selected;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    try {
      final owners = await CardOwnerRepository.instance
          .fetchCardOwners(branchIds: widget.branchIds);
      if (!mounted) return;
      setState(() { _owners = owners; _loadingOwners = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOwners = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _amt =>
      double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
  LvpLoadResult get _calc => LvpCalculator.compute(_amt);

  Future<void> _submit() async {
    final calc = _calc;
    if (_selected == null || !calc.accepted) return;
    setState(() => _saving = true);
    final res = await CardOwnerRepository.instance.loadWalletWithBonus(
      clientId: _selected!.id, paid: calc.loadingAmount);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.error ?? 'Load failed.'),
          backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onDone('${Fmt.peso(res.total)} loaded to ${_selected!.fullName}.');
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
                    child: CircularProgressIndicator(color: AdminColors.gold)),
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
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Loading Amount (₱)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    helperText: 'Minimum ₱2,500.00',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                if (_amt > 0) ...[
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

// ── Load a BLANK card (pre-load LVP before shipping) ─────────────────────────

class _LoadBlankDialog extends StatefulWidget {
  const _LoadBlankDialog({
    required this.cardRef,
    required this.cardDisplay,
    required this.onDone,
  });
  final String cardRef;
  final String cardDisplay;
  final ValueChanged<String> onDone;

  @override
  State<_LoadBlankDialog> createState() => _LoadBlankDialogState();
}

class _LoadBlankDialogState extends State<_LoadBlankDialog> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _amt =>
      double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
  LvpLoadResult get _calc => LvpCalculator.compute(_amt);

  Future<void> _submit() async {
    final calc = _calc;
    if (!calc.accepted) return;
    setState(() => _saving = true);
    final res = await CardOwnerRepository.instance.loadBlankCard(
      cardRef: widget.cardRef,
      paid: calc.loadingAmount,
      notes: 'Blank card pre-load via admin panel',
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
        '${Fmt.peso(res.total)} loaded to blank card ${widget.cardDisplay}.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calc = _calc;
    return AlertDialog(
      title: const Text('Load Blank Card'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.cream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.nfc_rounded, size: 18, color: AdminColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Card ${widget.cardDisplay}\nThis card has no owner yet — it '
                  'will carry this balance until a customer claims it.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Loading Amount (₱)',
              prefixIcon: Icon(Icons.payments_outlined),
              helperText: 'Minimum ₱2,500.00',
            ),
            style: const TextStyle(fontSize: 13),
          ),
          if (_amt > 0) ...[
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
                  _blankRow('Loading Amount', calc.loadingAmount, theme),
                  const SizedBox(height: 4),
                  _blankRow('Bonus', calc.bonus, theme, gold: true),
                  const Divider(height: 14),
                  _blankRow('LVP to Credit', calc.credited, theme, bold: true),
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
          onPressed: (_saving || !calc.accepted) ? null : _submit,
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

  Widget _blankRow(String label, double value, ThemeData theme,
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

// ── Identify Card: tap a card to see its franchise / branch assignment ───────

class _IdentifyCardDialog extends StatefulWidget {
  const _IdentifyCardDialog();

  @override
  State<_IdentifyCardDialog> createState() => _IdentifyCardDialogState();
}

class _IdentifyCardDialogState extends State<_IdentifyCardDialog> {
  bool _scanning = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _scan() async {
    setState(() { _scanning = true; _error = null; _result = null; });
    try {
      final uid = await NfcService.instance.readCardUid();
      final res = await CardOwnerRepository.instance.lookupCardByUid(uid);
      if (!mounted) return;
      if (res['success'] != true || res['status'] == 'unknown') {
        setState(() {
          _scanning = false;
          _error = (res['error'] as String?) ?? 'This card is not recognized.';
        });
        return;
      }
      setState(() { _scanning = false; _result = res; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Could not read the card. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AlertDialog(
      title: const Text('Identify Card'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (r == null) ...[
            Text(
              _error ??
                  'Tap a card on the reader to see which franchise and branch '
                      'it is assigned to.',
              style: TextStyle(
                  fontSize: 13,
                  color: _error != null
                      ? AdminColors.statusSuspended
                      : AdminColors.brownMedium),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.contactless_rounded, size: 18),
                label: Text(_scanning ? 'Reading card…' : 'Tap Card'),
                style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.gold),
              ),
            ),
          ] else ...[
            _idLine('Card',
                (r['card_display_id'] as String?) ??
                    (r['card_uid'] as String?) ??
                    '—',
                mono: true),
            const Divider(height: 18),
            _idLine('Franchise',
                _valueOr(r['franchise_name'] as String?, 'Ungrouped'),
                highlight: true),
            _idLine('Branch',
                _valueOr(r['branch_name'] as String?, 'Unassigned')),
            _idLine('Status', _statusLabel(r['status'] as String?)),
            if ((r['client_name'] as String?)?.isNotEmpty ?? false)
              _idLine('Owner', r['client_name'] as String),
          ],
        ]),
      ),
      actions: [
        if (r != null)
          TextButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tap Another'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  static String _valueOr(String? v, String fallback) =>
      (v == null || v.trim().isEmpty) ? fallback : v;

  static String _statusLabel(String? s) => switch (s) {
        'claimed' => 'Registered / in use',
        'available' => 'Blank (unclaimed)',
        'blocked' => 'Blocked',
        _ => 'Unknown',
      };

  Widget _idLine(String label, String value,
      {bool mono = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.brownMedium,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: highlight ? 15 : 13,
                    fontFamily: mono ? 'monospace' : null,
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w600,
                    color: highlight
                        ? AdminColors.gold
                        : AdminColors.charcoal)),
          ),
        ],
      ),
    );
  }
}
