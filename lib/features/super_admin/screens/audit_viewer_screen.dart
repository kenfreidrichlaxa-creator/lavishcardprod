import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/branch_model.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../data/services/audit_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';

/// Super Admin audit log across ALL branches, filterable by branch + action,
/// plus a Backblaze Backups browser (via the list-backups Edge Function).
class AuditViewerScreen extends StatefulWidget {
  const AuditViewerScreen({super.key});

  @override
  State<AuditViewerScreen> createState() => _AuditViewerScreenState();
}

class _AuditViewerScreenState extends State<AuditViewerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<AuditEvent> _events = [];
  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _branchFilter; // null = all
  String? _actionFilter; // null = all

  static const _actions = [
    'CUSTOMER_EDIT',
    'CARD_CHANGE',
    'ADMIN_ARCHIVE',
    'ADMIN_EDIT',
    'WALLET_LOAD',
    'WALLET_PAYMENT',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _branches = await AdminAuthRepository.instance.listBranches();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final events = await AuditRepository.instance
          .listAudit(branchId: _branchFilter, action: _actionFilter);
      if (!mounted) return;
      setState(() {
        _events = events;
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
            const PageHeader(
              title: 'Audit Trail',
              subtitle:
                  'Every change across all branches. Backed up to Backblaze.',
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              indicatorColor: AdminColors.gold,
              labelColor: AdminColors.gold,
              unselectedLabelColor: AdminColors.brownLight,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Live Audit'),
                Tab(icon: Icon(Icons.cloud_done_rounded, size: 18), text: 'Backblaze Backups'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildLiveAudit(),
                  const _BackupsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAudit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _dropdown(
              label: 'Branch',
              value: _branchFilter,
              items: {for (final b in _branches) b.id: b.name},
              onChanged: (v) {
                setState(() => _branchFilter = v);
                _load();
              },
            ),
            _dropdown(
              label: 'Action',
              value: _actionFilter,
              items: {for (final a in _actions) a: _pretty(a)},
              onChanged: (v) {
                setState(() => _actionFilter = v);
                _load();
              },
            ),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminColors.gold))
              : _events.isEmpty
                  ? EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No audit events',
                      subtitle: 'Actions will appear here as they happen.',
                    )
                  : Card(
                      child: ListView.separated(
                        itemCount: _events.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _AuditTile(event: _events[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.beigeDeep),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text('All ${label}s', style: const TextStyle(fontSize: 13)),
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          items: [
            DropdownMenuItem<String?>(
                value: null, child: Text('All ${label}s')),
            ...items.entries.map((e) => DropdownMenuItem<String?>(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  static String _pretty(String action) => action
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.event});
  final AuditEvent event;

  Color get _color {
    if (event.action.contains('ARCHIVE')) return AdminColors.statusSuspended;
    if (event.action.contains('EDIT')) return AdminColors.statusAvailable;
    if (event.action.contains('CARD')) return AdminColors.gold;
    if (event.action.contains('LOAD') || event.action.contains('PAYMENT')) {
      return AdminColors.statusActive;
    }
    return AdminColors.brownMedium;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = DateFormat('MMM d, y • h:mm a').format(event.createdAt.toLocal());
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _color.withValues(alpha: 0.12),
        child: Icon(_iconFor(event.action), size: 16, color: _color),
      ),
      title: Text(event.summary, style: theme.textTheme.titleSmall),
      subtitle: Text(
        '${_AuditViewerScreenState._pretty(event.action)}  ·  '
        '${event.branchName.isEmpty ? event.branchId : event.branchName}  ·  '
        'by ${event.actor} (${event.actorRole})',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(dt, style: theme.textTheme.bodySmall),
      isThreeLine: false,
    );
  }

  IconData _iconFor(String action) {
    if (action.contains('ARCHIVE')) return Icons.archive_rounded;
    if (action.contains('CARD')) return Icons.credit_card_rounded;
    if (action.contains('EDIT')) return Icons.edit_rounded;
    if (action.contains('LOAD')) return Icons.add_card_rounded;
    if (action.contains('PAYMENT')) return Icons.payments_rounded;
    return Icons.history_rounded;
  }
}

// ── Backblaze Backups tab ─────────────────────────────────────────────────────

class _BackupsTab extends StatefulWidget {
  const _BackupsTab();

  @override
  State<_BackupsTab> createState() => _BackupsTabState();
}

class _BackupsTabState extends State<_BackupsTab> {
  bool _loading = true;
  String? _error;
  List<BackupSnapshot> _snapshots = [];

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
      final snaps = await AuditRepository.instance.listBackups();
      if (!mounted) return;
      setState(() {
        _snapshots = snaps;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_done_rounded,
                size: 16, color: AdminColors.statusActive),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Daily snapshots stored in Backblaze B2 (bucket lavishcard23). '
                'Includes archived data older than 90 days.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminColors.gold))
              : _error != null
                  ? _BackupError(error: _error!, onRetry: _load)
                  : _snapshots.isEmpty
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'No backups found',
                          subtitle:
                              'Daily backups will appear here once they run.',
                        )
                      : Card(
                          child: ListView.separated(
                            itemCount: _snapshots.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = _snapshots[i];
                              final ts = s.timestamp;
                              final label = ts != null
                                  ? DateFormat('MMM d, y • h:mm a')
                                      .format(ts.toLocal())
                                  : s.name;
                              return ListTile(
                                leading: const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AdminColors.statusActiveBg,
                                  child: Icon(Icons.folder_zip_rounded,
                                      size: 16,
                                      color: AdminColors.statusActive),
                                ),
                                title: Text(label,
                                    style: theme.textTheme.titleSmall),
                                subtitle: const Text(
                                    'Full backup of all records',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AdminColors.brownLight)),
                                trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AdminColors.brownLight),
                                onTap: () => _openSnapshot(s),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  void _openSnapshot(BackupSnapshot s) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: _SnapshotViewer(snapshot: s),
      ),
    );
  }
}

class _BackupError extends StatelessWidget {
  const _BackupError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: AdminColors.brownLight),
            const SizedBox(height: 12),
            Text('Could not load backups',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SizedBox(
              width: 380,
              child: Text(error,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page viewer for one snapshot. Opens DIRECTLY into a clean audit-style
/// table (Activity Log first), with a table selector + download buttons.
class _SnapshotViewer extends StatefulWidget {
  const _SnapshotViewer({required this.snapshot});
  final BackupSnapshot snapshot;

  @override
  State<_SnapshotViewer> createState() => _SnapshotViewerState();
}

class _SnapshotViewerState extends State<_SnapshotViewer> {
  static const _friendly = {
    'audit_events': 'Activity Log',
    'wallet_transactions': 'Wallet Transactions',
    'service_transactions': 'Service Transactions',
    'clients': 'Customers',
    'client_cards': 'Cards',
    'client_wallets': 'Wallets',
  };
  // Preferred display order — Activity Log first, like a normal audit view.
  static const _order = [
    'audit_events', 'wallet_transactions', 'service_transactions',
    'clients', 'client_cards', 'client_wallets',
  ];

  bool _loadingList = true;
  bool _loadingRows = false;
  bool _exporting = false;
  bool _exportingAll = false;
  String? _error;
  List<BackupObject> _objects = [];
  BackupObject? _selected;
  int _count = 0;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  String _friendlyName(String table) =>
      _friendly[table] ??
      table
          .split('_')
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');

  String get _snapshotLabel {
    final ts = widget.snapshot.timestamp;
    return ts != null
        ? DateFormat('MMM d, y • h:mm a').format(ts.toLocal())
        : widget.snapshot.name;
  }

  Future<void> _loadList() async {
    try {
      final objs = await AuditRepository.instance
          .listBackupObjects(widget.snapshot.prefix);
      objs.sort((a, b) {
        final ia = _order.indexOf(a.table);
        final ib = _order.indexOf(b.table);
        return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
      });
      if (!mounted) return;
      setState(() {
        _objects = objs;
        _loadingList = false;
      });
      if (objs.isNotEmpty) _select(objs.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingList = false;
      });
    }
  }

  Future<void> _select(BackupObject o) async {
    setState(() {
      _selected = o;
      _loadingRows = true;
    });
    try {
      final data = await AuditRepository.instance.fetchBackupObject(o.key);
      final rawRows = (data['rows'] as List?) ?? const [];
      final rows = rawRows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      if (!mounted) return;
      setState(() {
        _count = (data['count'] as num?)?.toInt() ?? rows.length;
        _rows = rows;
        _loadingRows = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingRows = false;
      });
    }
  }

  Future<void> _downloadCurrent() async {
    final o = _selected;
    if (o == null) return;
    setState(() => _exporting = true);
    try {
      final cols = _displayColsFor(o.table);
      final headers = cols.map((c) => c.header).toList();
      final rows = _rows
          .map((r) => {for (final c in cols) c.header: c.value(r)})
          .toList();
      final path = await AuditRepository.instance.exportBackupCsv(
        table: _friendlyName(o.table),
        columns: headers,
        rows: rows,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      _snack('Saved CSV to: $path');
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      _snack('Could not save CSV: $e', error: true);
    }
  }

  Future<void> _downloadAll() async {
    setState(() => _exportingAll = true);
    try {
      final folder = await AuditRepository.instance.exportSnapshotCsvs(
        snapshotName: widget.snapshot.name,
        objects: _objects.map((o) => o.key).toList(),
        friendlyNames: {for (final o in _objects) o.key: _friendlyName(o.table)},
      );
      if (!mounted) return;
      setState(() => _exportingAll = false);
      _snack('Saved ${_objects.length} CSV files to: $folder');
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportingAll = false);
      _snack('Could not export: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AdminColors.error : AdminColors.statusActive,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      appBar: AppBar(
        backgroundColor: AdminColors.cardBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Backup', style: TextStyle(fontSize: 15)),
            Text(_snapshotLabel,
                style: const TextStyle(
                    fontSize: 12, color: AdminColors.brownLight)),
          ],
        ),
        actions: [
          if (!_loadingList && _objects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: _exportingAll ? null : _downloadAll,
                icon: _exportingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download All'),
              ),
            ),
        ],
      ),
      body: _loadingList
          ? const Center(
              child: CircularProgressIndicator(color: AdminColors.gold))
          : _error != null
              ? _BackupError(error: _error!, onRetry: _loadList)
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _objects.map((o) {
                                final sel = o.key == _selected?.key;
                                return ChoiceChip(
                                  label: Text(_friendlyName(o.table)),
                                  selected: sel,
                                  onSelected: (_) => _select(o),
                                  selectedColor: AdminColors.gold
                                      .withValues(alpha: 0.18),
                                  labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: sel
                                          ? AdminColors.goldDark
                                          : AdminColors.brownMedium),
                                );
                              }).toList(),
                            ),
                          ),
                          if (_selected != null && _rows.isNotEmpty)
                            FilledButton.icon(
                              onPressed: _exporting ? null : _downloadCurrent,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Download CSV'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selected != null)
                        Text(
                          '${_friendlyName(_selected!.table)} · '
                          '$_count record${_count == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _loadingRows
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AdminColors.gold))
                            : _rows.isEmpty
                                ? EmptyState(
                                    icon: Icons.inbox_rounded,
                                    title: 'No records',
                                    subtitle:
                                        'This table had no rows at backup time.',
                                  )
                                : Card(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildTable(),
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTable() {
    final cols = _displayColsFor(_selected!.table);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AdminColors.cream),
          columnSpacing: 28,
          headingTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminColors.brownMedium,
              letterSpacing: 0.4),
          columns: cols.map((c) => DataColumn(label: Text(c.header))).toList(),
          rows: _rows.map((row) {
            return DataRow(
              cells: cols.map((c) {
                final text = c.value(row);
                if (c.chip == _ChipKind.role) return DataCell(_roleChip(text));
                if (c.chip == _ChipKind.action) {
                  return DataCell(_actionChip(text));
                }
                return DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Friendly display columns per table (audit-log style) ────────────────────
  List<_DisplayCol> _displayColsFor(String table) {
    switch (table) {
      case 'audit_events':
        return [
          _DisplayCol('Timestamp', (r) => _dt(r['created_at'])),
          _DisplayCol('User', (r) => _s(r['actor'])),
          _DisplayCol('Role', (r) => _s(r['actor_role']), chip: _ChipKind.role),
          _DisplayCol('Action', (r) => _s(r['action']), chip: _ChipKind.action),
          _DisplayCol('Details', (r) => _s(r['summary'])),
        ];
      case 'wallet_transactions':
        return [
          _DisplayCol('Timestamp', (r) => _dt(r['created_at'])),
          _DisplayCol('Processed By', (r) => _s(r['pos_user_name'])),
          _DisplayCol('Type', (r) => _s(r['transaction_type']),
              chip: _ChipKind.action),
          _DisplayCol('Amount', (r) => _money(r['amount'])),
          _DisplayCol('Paid', (r) => _money(r['paid_amount'])),
          _DisplayCol('Bonus', (r) => _money(r['bonus_amount'])),
          _DisplayCol('Balance After', (r) => _money(r['balance_after'])),
          _DisplayCol('Notes', (r) => _s(r['notes'])),
        ];
      case 'service_transactions':
        return [
          _DisplayCol('Timestamp', (r) => _dt(r['created_at'])),
          _DisplayCol('Service', (r) => _s(r['service_name'])),
          _DisplayCol('Staff', (r) => _s(r['staff_name'])),
          _DisplayCol('Amount', (r) => _money(r['total_charged'] ?? r['amount'])),
          _DisplayCol('Status', (r) => _s(r['status']), chip: _ChipKind.action),
        ];
      case 'clients':
        return [
          _DisplayCol('Customer Code', (r) => _s(r['client_code'])),
          _DisplayCol('Name', (r) => _s(r['full_name'])),
          _DisplayCol('Email', (r) => _s(r['email'])),
          _DisplayCol('Phone', (r) => _s(r['phone'])),
          _DisplayCol('Status', (r) => _s(r['status']), chip: _ChipKind.action),
          _DisplayCol('Registered', (r) => _dt(r['created_at'])),
        ];
      case 'client_cards':
        return [
          _DisplayCol('Card ID', (r) => _s(r['card_display_id'])),
          _DisplayCol('Status', (r) => _s(r['status']), chip: _ChipKind.action),
          _DisplayCol('Activated', (r) => _dt(r['activated_at'])),
          _DisplayCol('Registered', (r) => _dt(r['created_at'])),
        ];
      case 'client_wallets':
        return [
          _DisplayCol('Balance', (r) => _money(r['balance'])),
          _DisplayCol('Currency', (r) => _s(r['currency'])),
          _DisplayCol('Status', (r) => _s(r['status']), chip: _ChipKind.action),
          _DisplayCol('Updated', (r) => _dt(r['updated_at'])),
        ];
      default:
        return const [];
    }
  }

  String _s(dynamic v) => v == null ? '—' : v.toString();

  String _dt(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '—';
    return DateFormat('MMM d, y  h:mm a').format(d.toLocal());
  }

  String _money(dynamic v) {
    if (v == null) return '—';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '—';
    return 'LVP ${n.toStringAsFixed(2)}';
  }

  Widget _roleChip(String role) {
    if (role.isEmpty || role == '—') return const Text('—');
    final low = role.toLowerCase();
    final color = low.contains('super')
        ? AdminColors.gold
        : low.contains('admin')
            ? AdminColors.statusSuspended
            : low.contains('manager')
                ? AdminColors.statusAvailable
                : AdminColors.brownMedium;
    return _chip(role, color);
  }

  Widget _actionChip(String action) {
    if (action.isEmpty || action == '—') return const Text('—');
    final a = action.toLowerCase();
    Color color;
    if (a.contains('archive') || a.contains('fail') || a.contains('void') ||
        a.contains('block')) {
      color = AdminColors.statusSuspended;
    } else if (a.contains('load') || a.contains('complete') ||
        a.contains('active') || a.contains('payment')) {
      color = AdminColors.statusActive;
    } else if (a.contains('edit') || a.contains('change') ||
        a.contains('logout')) {
      color = AdminColors.statusAvailable;
    } else {
      color = AdminColors.brownMedium;
    }
    final label = action
        .split(RegExp(r'[_\s]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
    return _chip(label, color);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

enum _ChipKind { none, role, action }

class _DisplayCol {
  const _DisplayCol(this.header, this.value, {this.chip = _ChipKind.none});
  final String header;
  final String Function(Map<String, dynamic>) value;
  final _ChipKind chip;
}
