import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/staff_model.dart';
import '../../../data/services/staff_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_chip.dart';

/// Super Admin screen — tabbed: Staff list + Positions management.
class StaffManagerScreen extends StatefulWidget {
  const StaffManagerScreen({super.key});

  @override
  State<StaffManagerScreen> createState() => _StaffManagerScreenState();
}

class _StaffManagerScreenState extends State<StaffManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Staff Manager',
              subtitle:
                  'Manage staff members and their positions across all branches.',
            ),
            const SizedBox(height: 4),
            TabBar(
              controller: _tab,
              labelColor: AdminColors.gold,
              unselectedLabelColor: AdminColors.brownMedium,
              indicatorColor: AdminColors.gold,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.badge_rounded, size: 18), text: 'Staff'),
                Tab(
                    icon: Icon(Icons.work_outline_rounded, size: 18),
                    text: 'Positions'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  _StaffTab(),
                  _PositionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAFF TAB
// ══════════════════════════════════════════════════════════════════════════════

class _StaffTab extends StatefulWidget {
  const _StaffTab();

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  List<StaffModel> _staff = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await StaffRepository.instance.listStaff();
    if (!mounted) return;
    setState(() {
      _staff   = s;
      _loading = false;
    });
  }

  List<StaffModel> get _filtered => _staff.where((s) {
        final q = _query.toLowerCase();
        if (q.isEmpty) return true;
        return s.fullName.toLowerCase().contains(q) ||
            s.staffId.toLowerCase().contains(q) ||
            s.phone.contains(q);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name, ID, or phone…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _showDialog(context, null),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add Staff'),
            style:
                FilledButton.styleFrom(backgroundColor: AdminColors.gold),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminColors.gold))
              : items.isEmpty
                  ? const EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'No staff yet',
                      subtitle:
                          'Add staff here — they appear in the POS stylist picker.',
                    )
                  : Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                _col('Staff ID'),
                                _col('Name'),
                                _col('Position'),
                                _col('Phone'),
                                _col('Email'),
                                _col('Status'),
                                _col('Joined'),
                                _col('Actions'),
                              ],
                              rows: items
                                  .map((s) => _buildRow(context, s, theme))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label.toUpperCase(),
            style: const TextStyle(
                color: AdminColors.brownMedium,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  DataRow _buildRow(BuildContext context, StaffModel s, ThemeData theme) {
    final isActive = s.status == StaffStatus.active;
    return DataRow(cells: [
      DataCell(Text(s.staffId,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AdminColors.brownMedium))),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AdminColors.cream,
          child: Text(s.initials,
              style: const TextStyle(
                  color: AdminColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(s.fullName, style: theme.textTheme.titleSmall),
      ])),
      DataCell(Text(
          s.positionLabel.isEmpty ? '—' : s.positionLabel,
          style: theme.textTheme.bodyMedium)),
      DataCell(Text(s.phone.isEmpty ? '—' : s.phone,
          style: theme.textTheme.bodyMedium)),
      DataCell(Text(s.email.isEmpty ? '—' : s.email,
          style: theme.textTheme.bodyMedium)),
      DataCell(StatusChip.staff(s.status)),
      DataCell(Text(Fmt.date(s.joinedDate),
          style: theme.textTheme.bodySmall)),
      DataCell(Row(children: [
        _btn(Icons.edit_outlined, 'Edit', () => _showDialog(context, s)),
        _btn(
          isActive
              ? Icons.toggle_off_outlined
              : Icons.toggle_on_outlined,
          isActive ? 'Deactivate' : 'Activate',
          () => _toggleStatus(context, s),
          color: isActive
              ? AdminColors.statusSuspended
              : AdminColors.statusActive,
        ),
        _btn(Icons.delete_outline_rounded, 'Delete',
            () => _deleteStaff(context, s),
            color: AdminColors.error),
      ])),
    ]);
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap,
      {Color color = AdminColors.brownMedium}) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );

  void _showDialog(BuildContext context, StaffModel? existing) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _StaffDialog(existing: existing, onSaved: (_) => _load()),
    );
  }

  Future<void> _toggleStatus(BuildContext context, StaffModel s) async {
    final isActive = s.status == StaffStatus.active;
    final confirmed = await showConfirmDialog(
      context,
      title: '${isActive ? 'Deactivate' : 'Activate'} ${s.fullName}',
      message: isActive
          ? 'Hides ${s.fullName} from the POS stylist picker.'
          : 'Makes ${s.fullName} available in the POS stylist picker.',
      confirmLabel: isActive ? 'Deactivate' : 'Activate',
      isDestructive: isActive,
    );
    if (!confirmed) return;
    final err = await StaffRepository.instance
        .setStaffStatus(id: s.id, active: !isActive);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
    } else {
      _load();
    }
  }

  Future<void> _deleteStaff(BuildContext context, StaffModel s) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Staff',
      message:
          'Delete "${s.fullName}" permanently? Transaction history is preserved.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final err = await StaffRepository.instance.deleteStaff(s.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
    } else {
      setState(() => _staff.removeWhere((x) => x.id == s.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s.fullName} deleted.'),
          backgroundColor: AdminColors.statusActive));
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// POSITIONS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _PositionsTab extends StatefulWidget {
  const _PositionsTab();

  @override
  State<_PositionsTab> createState() => _PositionsTabState();
}

class _PositionsTabState extends State<_PositionsTab> {
  List<StaffPositionModel> _positions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await StaffRepository.instance.listPositions();
    if (!mounted) return;
    setState(() {
      _positions = p;
      _loading   = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminColors.gold));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _showDialog(context, null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Position'),
            style:
                FilledButton.styleFrom(backgroundColor: AdminColors.gold),
          ),
        ),
        const SizedBox(height: 12),
        if (_positions.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.work_outline_rounded,
              title: 'No positions yet',
              subtitle: 'Add positions like "Stylist", "Cashier", etc.',
            ),
          )
        else
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _positions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (ctx, i) => _PositionTile(
                    item: _positions[i],
                    onEdit: () => _showDialog(ctx, _positions[i]),
                    onToggle: () => _toggle(_positions[i]),
                    onDelete: () => _delete(_positions[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showDialog(BuildContext context, StaffPositionModel? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _PositionDialog(
        existing: existing,
        onSaved: (_) => _load(),
      ),
    );
  }

  Future<void> _toggle(StaffPositionModel item) async {
    final err = await StaffRepository.instance.setPositionActive(
      id: item.id,
      active: !item.isActive,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
    } else {
      _load();
    }
  }

  Future<void> _delete(StaffPositionModel item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Position',
      message:
          'Delete "${item.name}"? Staff assigned to this position will have their position cleared.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final err = await StaffRepository.instance.deletePosition(item.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
    } else {
      _load();
    }
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final StaffPositionModel item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.isActive ? AdminColors.cream : AdminColors.divider,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.work_outline_rounded,
              size: 16,
              color: item.isActive
                  ? AdminColors.gold
                  : AdminColors.brownMedium),
        ),
        title: Text(
          item.name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: item.isActive ? null : AdminColors.brownMedium,
            decoration:
                item.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          'Sort order: ${item.sortOrder}  ·  ${item.isActive ? 'Active' : 'Inactive'}',
          style: const TextStyle(
              fontSize: 11, color: AdminColors.brownMedium),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.edit_outlined, 'Edit', onEdit),
            _btn(
              item.isActive
                  ? Icons.toggle_off_outlined
                  : Icons.toggle_on_outlined,
              item.isActive ? 'Deactivate' : 'Activate',
              onToggle,
              color: item.isActive
                  ? AdminColors.statusSuspended
                  : AdminColors.statusActive,
            ),
            _btn(Icons.delete_outline_rounded, 'Delete', onDelete,
                color: AdminColors.error),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap,
      {Color color = AdminColors.brownMedium}) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// DIALOGS
// ══════════════════════════════════════════════════════════════════════════════

/// Add / Edit staff member dialog — loads positions dynamically from DB.
class _StaffDialog extends StatefulWidget {
  const _StaffDialog({this.existing, required this.onSaved});
  final StaffModel? existing;
  final ValueChanged<StaffModel> onSaved;

  @override
  State<_StaffDialog> createState() => _StaffDialogState();
}

class _StaffDialogState extends State<_StaffDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late DateTime _joinedDate;

  List<StaffPositionModel> _positions = [];
  String? _selectedPositionId;
  bool _loadingPositions = true;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl  = TextEditingController(text: e?.fullName ?? '');
    _phoneCtrl = TextEditingController(
        text: e?.phone == '—' ? '' : (e?.phone ?? ''));
    _emailCtrl = TextEditingController(
        text: e?.email == '—' ? '' : (e?.email ?? ''));
    _joinedDate         = e?.joinedDate ?? DateTime.now();
    _selectedPositionId = e?.positionId;
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    final p =
        await StaffRepository.instance.listPositions(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _positions         = p;
      _loadingPositions  = false;
      // If existing positionId not in active list, keep as null
      if (_selectedPositionId != null &&
          !p.any((x) => x.id == _selectedPositionId)) {
        _selectedPositionId = null;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final posLabel = _positions
        .where((p) => p.id == _selectedPositionId)
        .map((p) => p.name)
        .firstOrNull ?? '';

    final e = widget.existing;
    final String? err;

    if (_isEditing) {
      err = await StaffRepository.instance.updateStaff(
        id: e!.id,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        positionId: _selectedPositionId ?? '',
        positionLabel: posLabel,
        joinedDate: _joinedDate,
      );
    } else {
      err = await StaffRepository.instance.createStaff(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        positionId: _selectedPositionId ?? '',
        positionLabel: posLabel,
        joinedDate: _joinedDate,
      );
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved(StaffModel(
      id: e?.id ?? '',
      staffId: '',
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      positionLabel: posLabel,
      positionId: _selectedPositionId,
      status: StaffStatus.active,
      joinedDate: _joinedDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AdminColors.cream,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.badge_rounded,
                          color: AdminColors.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing ? 'Edit Staff' : 'Add Staff',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Name
                  TextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    style: const TextStyle(fontSize: 13),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Position — dynamic dropdown
                  if (_loadingPositions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AdminColors.gold),
                        ),
                        SizedBox(width: 10),
                        Text('Loading positions…',
                            style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.brownMedium)),
                      ]),
                    )
                  else
                    DropdownButtonFormField<String?>(
                      value: _selectedPositionId,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        prefixIcon: Icon(Icons.work_outline_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— None —',
                              style: TextStyle(
                                  color: AdminColors.brownMedium,
                                  fontSize: 13)),
                        ),
                        ..._positions.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(p.name,
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedPositionId = v),
                    ),
                  const SizedBox(height: 12),

                  // Phone + Email
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Joined Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _joinedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _joinedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date Joined',
                        prefixIcon:
                            Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(Fmt.date(_joinedDate),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                            backgroundColor: AdminColors.gold),
                        child: _saving
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_isEditing
                                ? 'Save Changes'
                                : 'Add Staff'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Add / Edit position dialog.
class _PositionDialog extends StatefulWidget {
  const _PositionDialog({this.existing, required this.onSaved});
  final StaffPositionModel? existing;
  final ValueChanged<StaffPositionModel> onSaved;

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sortCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _sortCtrl = TextEditingController(
        text: (widget.existing?.sortOrder ?? 0).toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    final String? err;

    if (_isEditing) {
      err = await StaffRepository.instance.updatePosition(
        id: widget.existing!.id,
        name: name,
        sortOrder: sort,
      );
    } else {
      err = await StaffRepository.instance.createPosition(
          name: name, sortOrder: sort);
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved(StaffPositionModel(
      id: widget.existing?.id ?? '',
      name: name,
      sortOrder: sort,
      isActive: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                    child: const Icon(Icons.work_outline_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Position' : 'Add Position',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ]),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Position Name',
                    hintText: 'e.g. Stylist, Cashier, Manager…',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _sortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order',
                    hintText: '0 = first',
                    prefixIcon: Icon(Icons.sort_rounded),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v.trim()) == null) return 'Must be a number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.gold),
                      child: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isEditing ? 'Save Changes' : 'Add Position'),
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
}
