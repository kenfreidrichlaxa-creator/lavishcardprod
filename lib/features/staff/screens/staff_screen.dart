import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/cache_service.dart';
import '../../../data/models/staff_model.dart';
import '../../../data/services/staff_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filter_bar.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_chip.dart';
import 'staff_profile_screen.dart';

enum _StaffFilter { all, active, inactive }

extension _StaffFilterLabel on _StaffFilter {
  String get label => switch (this) {
        _StaffFilter.all      => 'All',
        _StaffFilter.active   => 'Active',
        _StaffFilter.inactive => 'Inactive',
      };
}

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  _StaffFilter _filter = _StaffFilter.all;
  String _query = '';
  List<StaffModel> _staff = [];
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
      final s = await StaffRepository.instance.listStaff();
      if (!mounted) return;
      await CacheService.writeList(
        CacheKeys.staff,
        s.map((e) => e.toJson()).toList(),
      );
      setState(() {
        _staff    = s;
        _loading  = false;
        _offline  = false;
        _cachedAt = null;
      });
    } catch (_) {
      if (!mounted) return;
      final cached = await CacheService.readList(CacheKeys.staff);
      final ts     = await CacheService.lastUpdated(CacheKeys.staff);
      if (!mounted) return;
      setState(() {
        if (cached != null) {
          _staff = cached.map(StaffModelJson.fromJson).toList();
        }
        _loading  = false;
        _offline  = true;
        _cachedAt = ts;
      });
    }
  }

  List<StaffModel> get _filtered => _staff.where((s) {
        final q = _query.toLowerCase();
        if (q.isNotEmpty &&
            !s.fullName.toLowerCase().contains(q) &&
            !s.staffId.toLowerCase().contains(q) &&
            !s.phone.contains(q)) { return false; }
        return switch (_filter) {
          _StaffFilter.all      => true,
          _StaffFilter.active   => s.status == StaffStatus.active,
          _StaffFilter.inactive => s.status == StaffStatus.inactive,
        };
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
              title: 'Staff / Stylists',
              subtitle: 'Staff is managed by Super Admin.',
            ),

            if (_offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OfflineBanner(cachedAt: _cachedAt, onRetry: _load),
              ),

            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name, staff ID, or phone…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            FilterBar<_StaffFilter>(
              options: _StaffFilter.values,
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
              labelBuilder: (f) => f.label,
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold))
                  : items.isEmpty
                  ? EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'No staff found',
                      subtitle: 'Staff appear here once they process POS payments.',
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
                                _col('Contact'),
                                _col('Services'),
                                _col('Status'),
                                _col('Joined'),
                                _col('Actions'),
                              ],
                              rows: items.map((s) => _buildRow(context, s, theme)).toList(),
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
            style: const TextStyle(color: AdminColors.brownMedium, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  DataRow _buildRow(BuildContext context, StaffModel s, ThemeData theme) {
    return DataRow(cells: [
      DataCell(Text(s.staffId, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AdminColors.brownMedium))),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AdminColors.cream,
          child: Text(s.initials, style: const TextStyle(color: AdminColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(s.fullName, style: theme.textTheme.titleSmall),
      ])),
      DataCell(Text(s.positionLabel.isEmpty ? '—' : s.positionLabel)),
      DataCell(Text(s.phone, style: theme.textTheme.bodyMedium)),
      DataCell(Text('${s.serviceCount} Services', style: theme.textTheme.bodyMedium)),
      DataCell(StatusChip.staff(s.status)),
      DataCell(Text(Fmt.date(s.joinedDate), style: theme.textTheme.bodySmall)),
      DataCell(Row(children: [
        _actionBtn(Icons.visibility_outlined, 'View', () => _openProfile(context, s)),
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

  void _openProfile(BuildContext context, StaffModel s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StaffProfileScreen(staff: s),
    ));
  }
}
