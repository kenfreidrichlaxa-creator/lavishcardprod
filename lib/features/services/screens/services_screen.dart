import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/cache_service.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../data/services/category_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_chip.dart';
import '../widgets/service_dialog.dart';

// ── Static filter options (status) ───────────────────────────────────────────
enum _StatusFilter { all, active, inactive }

extension _StatusFilterLabel on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.all      => 'All',
        _StatusFilter.active   => 'Active',
        _StatusFilter.inactive => 'Inactive',
      };
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  _StatusFilter _statusFilter = _StatusFilter.all;

  /// null = show all categories, non-null = filter by primaryCategoryId
  String? _categoryFilter;

  String _query = '';
  List<ServiceModel> _services = [];
  List<PrimaryCategory> _categories = [];
  bool _loading = true;
  bool _offline = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final results = await Future.wait([
        AdminDataRepository.instance.fetchServices(),
        CategoryRepository.instance.listPrimaryCategories(),
      ]);

      if (!mounted) return;

      final services   = results[0] as List<ServiceModel>;
      final categories = results[1] as List<PrimaryCategory>;

      await CacheService.writeList(
        CacheKeys.services,
        services.map((e) => e.toJson()).toList(),
      );

      setState(() {
        _services   = services;
        _categories = categories;
        _loading    = false;
        _offline    = false;
        _cachedAt   = null;
      });
    } catch (_) {
      if (!mounted) return;
      final cached = await CacheService.readList(CacheKeys.services);
      final ts     = await CacheService.lastUpdated(CacheKeys.services);
      if (!mounted) return;
      setState(() {
        if (cached != null) {
          _services = ServiceCodeGenerator.assign(
              cached.map(ServiceModelJson.fromJson).toList());
        }
        _loading  = false;
        _offline  = true;
        _cachedAt = ts;
      });
    }
  }

  List<ServiceModel> get _filtered => _services.where((s) {
        // Search
        final q = _query.toLowerCase();
        if (q.isNotEmpty &&
            !s.name.toLowerCase().contains(q) &&
            !s.serviceId.toLowerCase().contains(q)) return false;

        // Status filter
        if (_statusFilter == _StatusFilter.active &&
            s.status != ServiceStatus.active) return false;
        if (_statusFilter == _StatusFilter.inactive &&
            s.status != ServiceStatus.inactive) return false;

        // Category filter — match by primaryCategoryId or legacy category name
        if (_categoryFilter != null) {
          if (s.primaryCategoryId != null) {
            if (s.primaryCategoryId != _categoryFilter) return false;
          } else {
            // Fall back: match category name to the selected category's name
            final cat = _categories
                .where((c) => c.id == _categoryFilter)
                .firstOrNull;
            if (cat == null) return false;
            if (!s.category.label
                .toLowerCase()
                .contains(cat.name.toLowerCase())) return false;
          }
        }

        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Services',
              subtitle: 'Manage salon services and pricing.',
              actionLabel: '+ Add Service',
              actionIcon: Icons.add_rounded,
              onAction: () => _showServiceDialog(context, null),
            ),

            if (_offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OfflineBanner(cachedAt: _cachedAt, onRetry: _load),
              ),

            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search service name or ID…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            // ── Status filter chips ────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status chips
                  ..._StatusFilter.values.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: f.label,
                          selected: _statusFilter == f && _categoryFilter == null
                              ? true
                              : _statusFilter == f && f != _StatusFilter.all
                                  ? true
                                  : f == _StatusFilter.all &&
                                      _statusFilter == _StatusFilter.all &&
                                      _categoryFilter == null,
                          onTap: () => setState(() {
                            _statusFilter   = f;
                            _categoryFilter = null;
                          }),
                        ),
                      )),

                  // Dynamic primary category chips
                  if (_categories.isNotEmpty)
                    Container(
                      width: 1,
                      height: 20,
                      color: AdminColors.divider,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                  ..._categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: c.name,
                          selected: _categoryFilter == c.id,
                          onTap: () => setState(() {
                            _categoryFilter = _categoryFilter == c.id
                                ? null
                                : c.id;
                            _statusFilter = _StatusFilter.all;
                          }),
                          isCategory: true,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Table ──────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold))
                  : items.isEmpty
                      ? const EmptyState(
                          icon: Icons.content_cut_outlined,
                          title: 'No services found',
                        )
                      : Card(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    _col('Service ID'),
                                    _col('Service Name'),
                                    _col('Category'),
                                    _col('Price'),
                                    _col('Duration'),
                                    _col('Status'),
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
        ),
      ),
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

  DataRow _buildRow(BuildContext context, ServiceModel s, ThemeData theme) {
    return DataRow(cells: [
      DataCell(Text(s.serviceId,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AdminColors.brownMedium))),
      DataCell(Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: AdminColors.cream,
              borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.content_cut_rounded,
              size: 13, color: AdminColors.brownMedium),
        ),
        const SizedBox(width: 10),
        Text(s.name, style: theme.textTheme.titleSmall),
      ])),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AdminColors.cream,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(s.categoryLabel,
            style: const TextStyle(
                fontSize: 11,
                color: AdminColors.brownMedium,
                fontWeight: FontWeight.w500)),
      )),
      DataCell(Text(Fmt.peso(s.price), style: theme.textTheme.titleSmall)),
      DataCell(Text(s.durationLabel)),
      DataCell(StatusChip.service(s.status)),
      DataCell(Row(children: [
        _actionBtn(Icons.edit_outlined, 'Edit',
            () => _showServiceDialog(context, s)),
        _actionBtn(
          s.status == ServiceStatus.active
              ? Icons.toggle_off_outlined
              : Icons.toggle_on_outlined,
          s.status == ServiceStatus.active ? 'Disable' : 'Enable',
          () => _toggleStatus(context, s),
          color: s.status == ServiceStatus.active
              ? AdminColors.statusSuspended
              : AdminColors.statusActive,
        ),
        _actionBtn(Icons.delete_outline_rounded, 'Delete',
            () => _deleteService(context, s),
            color: AdminColors.error),
      ])),
    ]);
  }

  Widget _actionBtn(IconData icon, String tip, VoidCallback onTap,
      {Color color = AdminColors.brownMedium}) {
    return Tooltip(
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
  }

  void _showServiceDialog(BuildContext context, ServiceModel? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => ServiceDialog(
        existing: existing,
        onSaved: (s) {
          setState(() {
            if (existing == null) {
              _services.insert(0, s);
            } else {
              final idx = _services.indexWhere((x) => x.id == existing.id);
              if (idx != -1) _services[idx] = s;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${s.name} ${existing == null ? 'added' : 'updated'}.'),
            backgroundColor: AdminColors.statusActive,
          ));
        },
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context, ServiceModel s) async {
    final isActive = s.status == ServiceStatus.active;
    final confirmed = await showConfirmDialog(
      context,
      title: '${isActive ? 'Disable' : 'Enable'} Service',
      message:
          'Are you sure you want to ${isActive ? 'disable' : 'enable'} ${s.name}?',
      confirmLabel: isActive ? 'Disable' : 'Enable',
      isDestructive: isActive,
    );
    if (!confirmed) return;
    final err = await AdminDataRepository.instance
        .setServiceStatus(s.id, !isActive);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    setState(() {
      final idx = _services.indexWhere((x) => x.id == s.id);
      if (idx != -1) {
        _services[idx] = ServiceModel(
          id: s.id,
          serviceId: s.serviceId,
          name: s.name,
          category: s.category,
          price: s.price,
          durationMinutes: s.durationMinutes,
          status: isActive ? ServiceStatus.inactive : ServiceStatus.active,
          description: s.description,
          primaryCategoryId: s.primaryCategoryId,
          primaryCategoryName: s.primaryCategoryName,
          promoCategoryId: s.promoCategoryId,
          promoCategoryName: s.promoCategoryName,
        );
      }
    });
  }

  Future<void> _deleteService(BuildContext context, ServiceModel s) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Service',
      message: 'Delete "${s.name}"? This removes it from every branch. '
          'If it has transaction history, disable it instead.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final err = await AdminDataRepository.instance.deleteService(s.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AdminColors.error));
      return;
    }
    setState(() => _services.removeWhere((x) => x.id == s.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${s.name} deleted.'),
        backgroundColor: AdminColors.statusActive));
  }
}

// ── Custom filter chip ────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCategory = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isCategory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AdminColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AdminColors.gold
                : isCategory
                    ? AdminColors.gold.withValues(alpha: 0.4)
                    : AdminColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCategory && !selected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.content_cut_rounded,
                    size: 11,
                    color: selected
                        ? Colors.white
                        : AdminColors.gold),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AdminColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
