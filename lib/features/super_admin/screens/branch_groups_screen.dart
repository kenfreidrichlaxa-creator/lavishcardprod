import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/branch_model.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../shared/widgets/page_header.dart';

/// Super Admin: manage FRANCHISE GROUPS. A card registered at a branch can be
/// used at any branch in the SAME group. Drag branches into a group box to
/// assign them. Unassigned branches sit in the "Unassigned" pool.
class BranchGroupsScreen extends StatefulWidget {
  const BranchGroupsScreen({super.key});

  @override
  State<BranchGroupsScreen> createState() => _BranchGroupsScreenState();
}

class _BranchGroupsScreenState extends State<BranchGroupsScreen> {
  final _repo = AdminAuthRepository.instance;

  bool _loading = true;
  String? _error;
  List<BranchGroup> _groups = [];
  List<BranchModel> _allBranches = [];

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
      final branches = await _repo.listBranches();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _allBranches = branches;
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

  /// Branch ids that are assigned to some group.
  Set<String> get _assignedIds =>
      {for (final g in _groups) for (final b in g.branches) b.id};

  /// Branches not in any group.
  List<BranchModel> get _unassigned =>
      _allBranches.where((b) => !_assignedIds.contains(b.id)).toList();

  Future<void> _assign(String branchId, String? groupId) async {
    final err = await _repo.assignBranchToGroup(branchId: branchId, groupId: groupId);
    if (!mounted) return;
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _load();
  }

  Future<void> _createGroup() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _GroupDialog(title: 'New Franchise Group'),
    );
    if (result == null || result[0].trim().isEmpty) return;
    final err = await _repo.createBranchGroup(result[0].trim(),
        code: result[1].trim());
    if (!mounted) return;
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _load();
  }

  /// Set / change a franchise group's code (e.g. 'LPA').
  Future<void> _editCode(BranchGroup g) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _GroupDialog(
        title: 'Franchise Code — ${g.name}',
        codeOnly: true,
        initialCode: g.code,
      ),
    );
    if (result == null) return;
    final err = await _repo.setBranchGroupCode(g.id, result[1].trim());
    if (!mounted) return;
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _load();
    _snack('Franchise code set to ${result[1].trim().toUpperCase()}.');
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AdminColors.error : AdminColors.statusActive,
      behavior: SnackBarBehavior.floating,
    ));
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
              title: 'Franchise Groups',
              subtitle:
                  'Cards work only within their franchise group. Drag a branch '
                  'into a group to let its cards be used across those branches.',
              actionLabel: '+ New Group',
              actionIcon: Icons.create_new_folder_rounded,
              onAction: _createGroup,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold))
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _buildBoard(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unassigned pool (drag FROM here, and a drop target to ungroup).
          _GroupBox(
            title: 'Unassigned',
            subtitle: 'Branches not in any group',
            icon: Icons.inbox_rounded,
            accent: AdminColors.brownLight,
            branchChips: _unassigned
                .map((b) => _draggableChip(b.id, b.name))
                .toList(),
            onAcceptBranch: (branchId) => _assign(branchId, null),
          ),
          const SizedBox(height: 16),
          // Group boxes.
          ..._groups.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GroupBox(
                  title: g.name,
                  subtitle: '${g.branches.length} branch'
                      '${g.branches.length == 1 ? '' : 'es'}'
                      '${g.code.isNotEmpty ? '  ·  Code: ${g.code}' : '  ·  No code set'}',
                  icon: Icons.store_mall_directory_rounded,
                  accent: AdminColors.gold,
                  trailing: IconButton(
                    tooltip: 'Set franchise code',
                    icon: const Icon(Icons.qr_code_rounded,
                        size: 18, color: AdminColors.gold),
                    onPressed: () => _editCode(g),
                  ),
                  branchChips: g.branches
                      .map((b) => _draggableChip(b.id, b.name))
                      .toList(),
                  onAcceptBranch: (branchId) => _assign(branchId, g.id),
                ),
              )),
        ],
      ),
    );
  }

  Widget _draggableChip(String branchId, String branchName) {
    final chip = _BranchChip(name: branchName);
    return Draggable<String>(
      data: branchId,
      feedback: Material(
        color: Colors.transparent,
        child: _BranchChip(name: branchName, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

/// A drop-target box for a group (or the unassigned pool).
class _GroupBox extends StatefulWidget {
  const _GroupBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.branchChips,
    required this.onAcceptBranch,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> branchChips;
  final ValueChanged<String> onAcceptBranch;
  final Widget? trailing;

  @override
  State<_GroupBox> createState() => _GroupBoxState();
}

class _GroupBoxState extends State<_GroupBox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.onAcceptBranch(d.data);
      },
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovering
                ? widget.accent.withValues(alpha: 0.08)
                : AdminColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? widget.accent : AdminColors.beigeDeep,
              width: _hovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(widget.icon, size: 18, color: widget.accent),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(widget.title,
                        style: theme.textTheme.titleMedium)),
                const SizedBox(width: 8),
                Flexible(
                    child: Text('· ${widget.subtitle}',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis)),
                const Spacer(),
                if (widget.trailing != null) widget.trailing!,
              ]),
              const SizedBox(height: 12),
              if (widget.branchChips.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: Text('Drop branches here',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AdminColors.brownLight)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.branchChips,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.name, this.dragging = false});
  final String name;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dragging ? AdminColors.gold : AdminColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.beigeDeep),
        boxShadow: dragging
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.drag_indicator_rounded,
            size: 16,
            color: dragging ? Colors.white : AdminColors.brownLight),
        const SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dragging ? Colors.white : AdminColors.charcoal)),
      ]),
    );
  }
}

/// Simple text-input dialog for creating/renaming a group.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});
  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Group name',
          hintText: 'e.g. North Franchise',
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog to create a franchise group (name + code) or set just the code.
/// Returns a [name, code] pair, or null when cancelled.
class _GroupDialog extends StatefulWidget {
  const _GroupDialog({
    required this.title,
    this.codeOnly = false,
    this.initialName = '',
    this.initialCode = '',
  });

  final String title;
  final bool codeOnly;
  final String initialName;
  final String initialCode;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _code =
      TextEditingController(text: widget.initialCode);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!widget.codeOnly)
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. North Franchise',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          if (!widget.codeOnly) const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            autofocus: widget.codeOnly,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Franchise code',
              hintText: 'e.g. LPA',
              helperText: 'Used to label exported cards as CODE-UID.',
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (widget.codeOnly && t.isEmpty) return 'Required';
              if (t.isNotEmpty && t.length > 8) return 'Max 8 characters';
              return null;
            },
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop([_name.text.trim(), _code.text.trim()]);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
