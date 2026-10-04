import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/services/category_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';

/// Super Admin screen for managing Primary Categories (e.g. "Nails", "Hair")
/// and Promo/Secondary Categories (e.g. "Summer Promo", "Buy 1 Get 1").
class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen>
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
              title: 'Category Manager',
              subtitle:
                  'Define primary service categories and promo/secondary categories.',
            ),
            const SizedBox(height: 4),
            TabBar(
              controller: _tab,
              labelColor: AdminColors.gold,
              unselectedLabelColor: AdminColors.brownMedium,
              indicatorColor: AdminColors.gold,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(
                  icon: Icon(Icons.content_cut_rounded, size: 18),
                  text: 'Primary Categories',
                ),
                Tab(
                  icon: Icon(Icons.local_offer_rounded, size: 18),
                  text: 'Promo Categories',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  _PrimaryCategoriesTab(),
                  _PromoCategoriesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary Categories tab ────────────────────────────────────────────────────

class _PrimaryCategoriesTab extends StatefulWidget {
  const _PrimaryCategoriesTab();

  @override
  State<_PrimaryCategoriesTab> createState() => _PrimaryCategoriesTabState();
}

class _PrimaryCategoriesTabState extends State<_PrimaryCategoriesTab> {
  List<PrimaryCategory> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await CategoryRepository.instance.listPrimaryCategories();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
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
            label: const Text('Add Primary Category'),
            style: FilledButton.styleFrom(backgroundColor: AdminColors.gold),
          ),
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.category_outlined,
              title: 'No primary categories yet',
              subtitle: 'Add your first one, e.g. "Nails" or "Hair".',
            ),
          )
        else
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) =>
                      _PrimaryCategoryTile(
                    item: _items[i],
                    onEdit: () => _showDialog(ctx, _items[i]),
                    onToggle: () => _toggle(_items[i]),
                    onDelete: () => _delete(_items[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showDialog(BuildContext ctx, PrimaryCategory? existing) {
    showDialog<void>(
      context: ctx,
      builder: (_) => _PrimaryCategoryDialog(
        existing: existing,
        onSaved: (_) => _load(),
      ),
    );
  }

  Future<void> _toggle(PrimaryCategory item) async {
    final err = await CategoryRepository.instance.setPrimaryCategoryActive(
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

  Future<void> _delete(PrimaryCategory item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Category',
      message:
          'Delete "${item.name}"? Services using this category will lose their primary category assignment. '
          'Consider deactivating it instead.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final err =
        await CategoryRepository.instance.deletePrimaryCategory(item.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
    } else {
      _load();
    }
  }
}

class _PrimaryCategoryTile extends StatelessWidget {
  const _PrimaryCategoryTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final PrimaryCategory item;
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
            color: item.isActive
                ? AdminColors.cream
                : AdminColors.divider,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.content_cut_rounded,
            size: 16,
            color: item.isActive
                ? AdminColors.gold
                : AdminColors.brownMedium,
          ),
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
          'Sort order: ${item.sortOrder}  •  ${item.isActive ? 'Active' : 'Inactive'}',
          style: const TextStyle(fontSize: 11, color: AdminColors.brownMedium),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(Icons.edit_outlined, 'Edit', onEdit),
            _iconBtn(
              item.isActive
                  ? Icons.toggle_off_outlined
                  : Icons.toggle_on_outlined,
              item.isActive ? 'Deactivate' : 'Activate',
              onToggle,
              color: item.isActive
                  ? AdminColors.statusSuspended
                  : AdminColors.statusActive,
            ),
            _iconBtn(Icons.delete_outline_rounded, 'Delete', onDelete,
                color: AdminColors.error),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap,
      {Color color = AdminColors.brownMedium}) {
    return Tooltip(
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
}

// ── Promo Categories tab ──────────────────────────────────────────────────────

class _PromoCategoriesTab extends StatefulWidget {
  const _PromoCategoriesTab();

  @override
  State<_PromoCategoriesTab> createState() => _PromoCategoriesTabState();
}

class _PromoCategoriesTabState extends State<_PromoCategoriesTab> {
  List<PromoCategory> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await CategoryRepository.instance.listPromoCategories();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
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
            label: const Text('Add Promo Category'),
            style: FilledButton.styleFrom(backgroundColor: AdminColors.gold),
          ),
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No promo categories yet',
              subtitle: 'Add secondary categories like "Summer Promo" or "Buy 1 Get 1".',
            ),
          )
        else
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _PromoCategoryTile(
                    item: _items[i],
                    onEdit: () => _showDialog(ctx, _items[i]),
                    onToggle: () => _toggle(_items[i]),
                    onDelete: () => _delete(_items[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showDialog(BuildContext ctx, PromoCategory? existing) {
    showDialog<void>(
      context: ctx,
      builder: (_) => _PromoCategoryDialog(
        existing: existing,
        onSaved: (_) => _load(),
      ),
    );
  }

  Future<void> _toggle(PromoCategory item) async {
    final err = await CategoryRepository.instance.setPromoCategoryActive(
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

  Future<void> _delete(PromoCategory item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Promo Category',
      message:
          'Delete "${item.name}"? Services linked to this promo will lose the assignment.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final err =
        await CategoryRepository.instance.deletePromoCategory(item.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
    } else {
      _load();
    }
  }
}

class _PromoCategoryTile extends StatelessWidget {
  const _PromoCategoryTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final PromoCategory item;
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
            color: item.isActive
                ? AdminColors.cream
                : AdminColors.divider,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.local_offer_rounded,
            size: 16,
            color: item.isActive
                ? AdminColors.gold
                : AdminColors.brownMedium,
          ),
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
          item.description.isNotEmpty
              ? item.description
              : 'Sort order: ${item.sortOrder}  •  ${item.isActive ? 'Active' : 'Inactive'}',
          style: const TextStyle(fontSize: 11, color: AdminColors.brownMedium),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(Icons.edit_outlined, 'Edit', onEdit),
            _iconBtn(
              item.isActive
                  ? Icons.toggle_off_outlined
                  : Icons.toggle_on_outlined,
              item.isActive ? 'Deactivate' : 'Activate',
              onToggle,
              color: item.isActive
                  ? AdminColors.statusSuspended
                  : AdminColors.statusActive,
            ),
            _iconBtn(Icons.delete_outline_rounded, 'Delete', onDelete,
                color: AdminColors.error),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap,
      {Color color = AdminColors.brownMedium}) {
    return Tooltip(
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
}

// ── Primary Category dialog ───────────────────────────────────────────────────

class _PrimaryCategoryDialog extends StatefulWidget {
  const _PrimaryCategoryDialog({this.existing, required this.onSaved});
  final PrimaryCategory? existing;
  final ValueChanged<PrimaryCategory> onSaved;

  @override
  State<_PrimaryCategoryDialog> createState() =>
      _PrimaryCategoryDialogState();
}

class _PrimaryCategoryDialogState extends State<_PrimaryCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sortCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
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
    final repo = CategoryRepository.instance;
    final String? err;

    if (_isEditing) {
      err = await repo.updatePrimaryCategory(
        id: widget.existing!.id,
        name: name,
        sortOrder: sort,
      );
    } else {
      err = await repo.createPrimaryCategory(name: name, sortOrder: sort);
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved(PrimaryCategory(
        id: widget.existing?.id ?? '', name: name, sortOrder: sort, isActive: true));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                    child: const Icon(Icons.content_cut_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing
                        ? 'Edit Primary Category'
                        : 'Add Primary Category',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ]),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Nails, Hair, Skin…',
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
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? 'Save Changes' : 'Add Category'),
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

// ── Promo Category dialog ─────────────────────────────────────────────────────

class _PromoCategoryDialog extends StatefulWidget {
  const _PromoCategoryDialog({this.existing, required this.onSaved});
  final PromoCategory? existing;
  final ValueChanged<PromoCategory> onSaved;

  @override
  State<_PromoCategoryDialog> createState() => _PromoCategoryDialogState();
}

class _PromoCategoryDialogState extends State<_PromoCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _sortCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _sortCtrl = TextEditingController(
        text: (widget.existing?.sortOrder ?? 0).toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    final repo = CategoryRepository.instance;
    final String? err;

    if (_isEditing) {
      err = await repo.updatePromoCategory(
        id: widget.existing!.id,
        name: name,
        description: desc,
        sortOrder: sort,
      );
    } else {
      err = await repo.createPromoCategory(
          name: name, description: desc, sortOrder: sort);
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved(PromoCategory(
        id: widget.existing?.id ?? '',
        name: name,
        description: desc,
        sortOrder: sort,
        isActive: true));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                    child: const Icon(Icons.local_offer_rounded,
                        color: AdminColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing
                        ? 'Edit Promo Category'
                        : 'Add Promo Category',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ]),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Promo Name',
                    hintText: 'e.g. Summer Promo, Buy 1 Get 1…',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  style: const TextStyle(fontSize: 13),
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
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? 'Save Changes' : 'Add Promo'),
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
