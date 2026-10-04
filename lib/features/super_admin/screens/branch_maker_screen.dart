import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/branch_model.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';

class BranchMakerScreen extends StatefulWidget {
  const BranchMakerScreen({super.key});

  @override
  State<BranchMakerScreen> createState() => _BranchMakerScreenState();
}

class _BranchMakerScreenState extends State<BranchMakerScreen> {
  final _repo = AdminAuthRepository.instance;
  List<BranchModel> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final b = await _repo.listBranches();
      if (!mounted) return;
      setState(() {
        _branches = b;
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
              title: 'Branches',
              subtitle: 'Create and manage salon branches.',
              actionLabel: '+ Add Branch',
              actionIcon: Icons.add_business_rounded,
              onAction: _showAddDialog,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold))
                  : _branches.isEmpty
                      ? EmptyState(
                          icon: Icons.store_mall_directory_outlined,
                          title: 'No branches yet',
                          subtitle: 'Add your first branch to get started.',
                        )
                      : Card(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('BRANCH ID')),
                                    DataColumn(label: Text('NAME')),
                                    DataColumn(label: Text('CODE')),
                                    DataColumn(label: Text('ADDRESS')),
                                    DataColumn(label: Text('CONTACT')),
                                    DataColumn(label: Text('STATUS')),
                                    DataColumn(label: Text('ACTIONS')),
                                  ],
                                  rows: _branches
                                      .map((b) => DataRow(cells: [
                                            DataCell(Text(b.id,
                                                style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 11))),
                                            DataCell(Text(b.name,
                                                style: theme
                                                    .textTheme.titleSmall)),
                                            DataCell(Text(b.code)),
                                            DataCell(Text(b.address.isEmpty
                                                ? '—'
                                                : b.address)),
                                            DataCell(Text(b.contact.isEmpty
                                                ? '—'
                                                : b.contact)),
                                            DataCell(Text(
                                              b.isActive ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                color: b.isActive
                                                    ? AdminColors.statusActive
                                                    : AdminColors.brownLight,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )),
                                            DataCell(Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Edit',
                                                  icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18,
                                                      color: AdminColors
                                                          .brownMedium),
                                                  onPressed: () =>
                                                      _showEditDialog(b),
                                                ),
                                                IconButton(
                                                  tooltip: b.isActive
                                                      ? 'Archive'
                                                      : 'Restore',
                                                  icon: Icon(
                                                    b.isActive
                                                        ? Icons.archive_outlined
                                                        : Icons
                                                            .unarchive_outlined,
                                                    size: 18,
                                                    color: b.isActive
                                                        ? AdminColors.error
                                                        : AdminColors
                                                            .statusActive,
                                                  ),
                                                  onPressed: () =>
                                                      _toggleArchive(b),
                                                ),
                                              ],
                                            )),
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

  void _showAddDialog() => _showBranchDialog();

  void _showEditDialog(BranchModel branch) => _showBranchDialog(existing: branch);

  /// Archive (deactivate) or restore a branch with a confirmation.
  Future<void> _toggleArchive(BranchModel b) async {
    final archiving = b.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(archiving ? 'Archive Branch' : 'Restore Branch'),
        content: Text(archiving
            ? 'Archive "${b.name}"? It will be marked Inactive. Existing cards '
                'and data are kept — you can restore it anytime.'
            : 'Restore "${b.name}" back to Active?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    archiving ? AdminColors.error : AdminColors.statusActive),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(archiving ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await _repo.setBranchActive(id: b.id, active: !b.isActive);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    _load();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(archiving
          ? 'Branch "${b.name}" archived.'
          : 'Branch "${b.name}" restored.'),
      backgroundColor: AdminColors.statusActive,
    ));
  }

  void _showBranchDialog({BranchModel? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final contactCtrl = TextEditingController(text: existing?.contact ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isEdit ? 'Edit Branch' : 'Add Branch'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Branch Name',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code (optional)',
                    prefixIcon: Icon(Icons.tag_rounded),
                    hintText: 'e.g. LP-TAY',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => saving = true);
                      final String? err;
                      if (isEdit) {
                        err = await _repo.updateBranch(
                          id: existing.id,
                          name: nameCtrl.text,
                          code: codeCtrl.text,
                          address: addrCtrl.text,
                          contact: contactCtrl.text,
                        );
                      } else {
                        err = await _repo.createBranch(
                          name: nameCtrl.text,
                          code: codeCtrl.text,
                          address: addrCtrl.text,
                          contact: contactCtrl.text,
                        );
                      }
                      if (!ctx.mounted) return;
                      if (err != null) {
                        setLocal(() => saving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(err),
                          backgroundColor: AdminColors.error,
                        ));
                        return;
                      }
                      Navigator.of(ctx).pop();
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit
                              ? 'Branch "${nameCtrl.text.trim()}" updated.'
                              : 'Branch "${nameCtrl.text.trim()}" created.'),
                          backgroundColor: AdminColors.statusActive,
                        ));
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
