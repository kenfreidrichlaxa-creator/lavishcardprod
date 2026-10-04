import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/branch_model.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../data/services/audit_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/page_header.dart';

class AdminMakerScreen extends StatefulWidget {
  const AdminMakerScreen({super.key});

  @override
  State<AdminMakerScreen> createState() => _AdminMakerScreenState();
}

class _AdminMakerScreenState extends State<AdminMakerScreen> {
  final _repo = AdminAuthRepository.instance;
  List<AdminAccountModel> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final a = await _repo.listAdmins();
      if (!mounted) return;
      setState(() {
        _admins = a;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Admin Accounts',
              subtitle:
                  'Create admins and assign the franchise group they manage.',
              actionLabel: '+ New Admin',
              actionIcon: Icons.person_add_alt_1_rounded,
              onAction: _openMaker,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold))
                  : _admins.isEmpty
                      ? Center(
                          child: Text('No admin accounts yet.',
                              style: theme.textTheme.bodyMedium),
                        )
                      : Card(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('NAME')),
                                    DataColumn(label: Text('USERNAME')),
                                    DataColumn(label: Text('EMAIL')),
                                    DataColumn(label: Text('ROLE')),
                                    DataColumn(label: Text('BRANCHES')),
                                    DataColumn(label: Text('STATUS')),
                                    DataColumn(label: Text('ACTIONS')),
                                  ],
                                  rows: _admins
                                      .map((a) => DataRow(cells: [
                                            DataCell(Text(a.name,
                                                style: theme
                                                    .textTheme.titleSmall)),
                                            DataCell(Text(a.username,
                                                style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 12))),
                                            DataCell(Text(a.email)),
                                            DataCell(Text(a.role)),
                                            DataCell(Text(
                                                '${a.branchIds.length} branch${a.branchIds.length == 1 ? '' : 'es'}')),
                                            DataCell(Text(
                                              a.status,
                                              style: TextStyle(
                                                color: a.status == 'active'
                                                    ? AdminColors.statusActive
                                                    : AdminColors.brownLight,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )),
                                            DataCell(Row(children: [
                                              if (a.status == 'active')
                                                Tooltip(
                                                  message: 'Archive',
                                                  child: InkWell(
                                                    onTap: () => _archive(a),
                                                    child: const Padding(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(
                                                          Icons.archive_outlined,
                                                          size: 16,
                                                          color: AdminColors
                                                              .statusSuspended),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Tooltip(
                                                  message: 'Reactivate',
                                                  child: InkWell(
                                                    onTap: () => _reactivate(a),
                                                    child: const Padding(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(
                                                          Icons.unarchive_outlined,
                                                          size: 16,
                                                          color: AdminColors
                                                              .statusActive),
                                                    ),
                                                  ),
                                                ),
                                            ])),
                                          ]))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archive(AdminAccountModel a) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Archive Admin',
      message: 'Archive ${a.name}? They will no longer be able to log in. '
          'This is recorded in the audit trail.',
      confirmLabel: 'Archive',
      isDestructive: true,
    );
    if (!ok) return;
    final err = await AuditRepository.instance.archiveAdmin(a.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    _load();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${a.name} archived.'),
        backgroundColor: AdminColors.statusActive));
  }

  Future<void> _reactivate(AdminAccountModel a) async {
    final err = await AuditRepository.instance.editAdmin(
      adminId: a.id,
      name: a.name,
      branchIds: a.branchIds,
      status: 'active',
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    _load();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${a.name} reactivated.'),
        backgroundColor: AdminColors.statusActive));
  }

  Future<void> _openMaker() async {
    final groups = await _repo.listBranchGroups();
    if (!mounted) return;
    // Only groups that actually contain branches can be assigned.
    final usable = groups.where((g) => g.branches.isNotEmpty).toList();
    if (usable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Create a franchise group with branches first (Franchise Groups).'),
        backgroundColor: AdminColors.warning,
      ));
      return;
    }
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminMakerDialog(groups: usable),
    );
    if (created == true) _load();
  }
}

// ── The maker dialog with drag-and-drop FRANCHISE GROUP assignment ───────────

class _AdminMakerDialog extends StatefulWidget {
  const _AdminMakerDialog({required this.groups});
  final List<BranchGroup> groups;

  @override
  State<_AdminMakerDialog> createState() => _AdminMakerDialogState();
}

class _AdminMakerDialogState extends State<_AdminMakerDialog> {
  final _repo = AdminAuthRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  BranchGroup? _assignedGroup; // the single franchise group this admin manages
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  List<BranchGroup> get _available =>
      widget.groups.where((g) => g.id != _assignedGroup?.id).toList();

  void _assign(BranchGroup g) => setState(() => _assignedGroup = g);
  void _unassign() => setState(() => _assignedGroup = null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
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
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: AdminColors.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Text('New Admin Account', style: theme.textTheme.headlineSmall),
              ]),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(_nameCtrl, 'Full Name', Icons.person_outline_rounded,
                            validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field(_userCtrl, 'Username', Icons.alternate_email_rounded,
                            validator: (v) {
                          final t = v!.trim();
                          if (t.isEmpty) return 'Required';
                          if (t.length < 3) return 'Min 3 characters';
                          if (t.contains(' ')) return 'No spaces';
                          return null;
                        }),
                        const SizedBox(height: 12),
                        _field(_emailCtrl, 'Email (Gmail — for password reset)',
                            Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                          final t = v!.trim();
                          if (t.isEmpty) return 'Required';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        }),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pwCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(fontSize: 13),
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
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 4) return 'Min 4 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Text('FRANCHISE ASSIGNMENT',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: AdminColors.gold)),
                        const SizedBox(height: 4),
                        Text(
                          'Drag a franchise group into "Managed by this admin". '
                          'The admin will manage all branches in that group.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _DragAssignArea(
                          available: _available,
                          assigned: _assignedGroup,
                          onAssign: _assign,
                          onUnassign: _unassign,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
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
                        : const Text('Create Admin'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final group = _assignedGroup;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Assign a franchise group.'),
        backgroundColor: AdminColors.warning,
      ));
      return;
    }
    setState(() => _saving = true);
    // The admin manages every branch in the assigned franchise group.
    final err = await _repo.createAdmin(
      name: _nameCtrl.text,
      username: _userCtrl.text,
      email: _emailCtrl.text,
      password: _pwCtrl.text,
      branchIds: group.branches.map((b) => b.id).toList(),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AdminColors.error,
      ));
      return;
    }
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Admin "${_nameCtrl.text.trim()}" created.'),
      backgroundColor: AdminColors.statusActive,
    ));
  }
}

// ── Drag & drop franchise-group assignment area ──────────────────────────────

class _DragAssignArea extends StatelessWidget {
  const _DragAssignArea({
    required this.available,
    required this.assigned,
    required this.onAssign,
    required this.onUnassign,
  });

  final List<BranchGroup> available;
  final BranchGroup? assigned;
  final ValueChanged<BranchGroup> onAssign;
  final VoidCallback onUnassign;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Available franchise groups (draggable)
          Expanded(
            child: _Column(
              title: 'Franchise Groups',
              child: available.isEmpty
                  ? const _Hint('No other groups')
                  : ListView(
                      padding: const EdgeInsets.all(8),
                      children: available
                          .map((g) => Draggable<BranchGroup>(
                                data: g,
                                feedback: _GroupChip(group: g, dragging: true),
                                childWhenDragging: Opacity(
                                    opacity: 0.4, child: _GroupChip(group: g)),
                                child: GestureDetector(
                                  onTap: () => onAssign(g),
                                  child: _GroupChip(group: g),
                                ),
                              ))
                          .toList(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward_rounded,
              color: AdminColors.brownLight, size: 20),
          const SizedBox(width: 12),
          // Assigned drop target (one group)
          Expanded(
            child: DragTarget<BranchGroup>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (d) => onAssign(d.data),
              builder: (context, candidate, rejected) {
                final highlight = candidate.isNotEmpty;
                return _Column(
                  title: 'Managed by this Admin',
                  highlight: highlight,
                  child: assigned == null
                      ? const _Hint('Drag a franchise group here')
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            _GroupChip(group: assigned!, onRemove: onUnassign),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.title, required this.child, this.highlight = false});
  final String title;
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? AdminColors.cream : AdminColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? AdminColors.gold : AdminColors.beigeDeep,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AdminColors.brownMedium)),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.group, this.onRemove, this.dragging = false});
  final BranchGroup group;
  final VoidCallback? onRemove;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final branchNames = group.branches.map((b) => b.name).join(', ');
    final chip = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.beigeDeep),
        boxShadow: dragging
            ? [BoxShadow(color: AdminColors.gold.withValues(alpha: 0.3), blurRadius: 8)]
            : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_rounded,
              size: 15, color: AdminColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(group.name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.charcoal),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${group.branches.length} branch'
                  '${group.branches.length == 1 ? '' : 'es'}'
                  '${branchNames.isEmpty ? '' : ' · $branchNames'}',
                  style: const TextStyle(
                      fontSize: 10, color: AdminColors.brownLight),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 15, color: AdminColors.statusSuspended),
            ),
        ],
      ),
    );
    if (dragging) {
      return Material(
          color: Colors.transparent,
          child: SizedBox(width: 240, child: chip));
    }
    return chip;
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: AdminColors.brownLight)),
      ),
    );
  }
}
