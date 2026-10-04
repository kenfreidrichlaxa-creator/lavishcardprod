import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/section_card.dart';
import '../widgets/sales_overview.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = AdminDataRepository.instance;

  bool _loading = true;
  bool _offline = false;
  DateTime? _cachedAt;
  DashboardStats? _stats;
  List<AdminTransactionModel> _transactions = [];
  List<StaffLeader> _leaders = [];
  List<CardLoad> _cardLoads = [];
  CardLoadTotals _loadTotals = CardLoadTotals.empty;

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
      final branchIds = AdminSession.effectiveBranchIds;
      final results = await Future.wait([
        _repo.fetchDashboardStats(branchIds: branchIds),
        _repo.fetchTransactions(limit: 50, branchIds: branchIds),
        _repo.fetchStaffLeaderboard(),
        _repo.fetchCardLoads(branchIds: branchIds, limit: 100),
        _repo.fetchCardLoadTotals(branchIds: branchIds),
      ]);
      if (!mounted) return;

      final stats     = results[0] as DashboardStats;
      final tx        = results[1] as List<AdminTransactionModel>;
      final leaders   = results[2] as List<StaffLeader>;
      final cardLoads = results[3] as List<CardLoad>;
      final totals    = results[4] as CardLoadTotals;

      // ── Persist to cache ──────────────────────────────────────────────────
      await Future.wait([
        CacheService.writeMap(CacheKeys.dashboardStats, stats.toJson()),
        CacheService.writeList(CacheKeys.dashboardTx,
            tx.map((e) => e.toJson()).toList()),
        CacheService.writeList(CacheKeys.dashboardLeaders,
            leaders.map((e) => e.toJson()).toList()),
        CacheService.writeList(CacheKeys.dashboardCardLoads,
            cardLoads.map((e) => e.toJson()).toList()),
        CacheService.writeMap(
            CacheKeys.dashboardLoadTotals, totals.toJson()),
      ]);

      if (!mounted) return;
      setState(() {
        _stats        = stats;
        _transactions = tx;
        _leaders      = leaders;
        _cardLoads    = cardLoads;
        _loadTotals   = totals;
        _loading      = false;
        _offline      = false;
        _cachedAt     = null;
      });
    } catch (_) {
      if (!mounted) return;
      await _restoreFromCache();
    }
  }

  Future<void> _restoreFromCache() async {
    final statsMap  = await CacheService.readMap(CacheKeys.dashboardStats);
    final txList    = await CacheService.readList(CacheKeys.dashboardTx);
    final leadList  = await CacheService.readList(CacheKeys.dashboardLeaders);
    final loadList  = await CacheService.readList(CacheKeys.dashboardCardLoads);
    final totalsMap = await CacheService.readMap(CacheKeys.dashboardLoadTotals);
    final ts        = await CacheService.lastUpdated(CacheKeys.dashboardStats);

    if (!mounted) return;

    if (statsMap != null) {
      setState(() {
        _stats        = DashboardStats.fromJson(statsMap);
        _transactions = txList?.map(AdminTransactionModelJson.fromJson).toList() ?? [];
        _leaders      = leadList?.map((j) => StaffLeader.fromJson(j)).toList() ?? [];
        _cardLoads    = loadList?.map((j) => CardLoad.fromJson(j)).toList() ?? [];
        _loadTotals   = totalsMap != null
            ? CardLoadTotals.fromJson(totalsMap)
            : CardLoadTotals.empty;
        _loading      = false;
        _offline      = true;
        _cachedAt     = ts;
      });
    } else {
      // No cache at all — show empty error state.
      setState(() {
        _loading = false;
        _offline = true;
        _cachedAt = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final completed = _transactions
        .where((t) => t.status == TransactionStatus.completed)
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AdminColors.gold,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$greeting, Admin',
                            style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          "Here's what's happening with Lavish Prima.",
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    color: AdminColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AdminColors.gold)),
                )
              else if (_offline && _stats == null)
                _ErrorPanel(onRetry: _load)
              else ...[
                if (_offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OfflineBanner(
                        cachedAt: _cachedAt, onRetry: _load),
                  ),
                _StatGrid(stats: _stats!),
                const SizedBox(height: 28),
                Text('Card Loads & Purchases',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Amount paid by customers (real revenue). Bonus is a free 20% add-on.',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                _CardLoadSummary(totals: _loadTotals),
                const SizedBox(height: 14),
                _CardLoadsTable(loads: _cardLoads),
                const SizedBox(height: 28),
                SalesOverview(transactions: completed),
                const SizedBox(height: 28),
                _StaffLeaderboards(leaders: _leaders),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text('Recent Transactions',
                        style: theme.textTheme.titleLarge),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
                _RecentTransactionsTable(transactions: _transactions),
                const SizedBox(height: 28),
                Text('Staff Activity', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _StaffActivitySection(transactions: _transactions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AdminColors.brownLight),
            const SizedBox(height: 12),
            Text('Could not load dashboard data',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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

// ── Stat Grid ────────────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final data = [
      _StatData('Total Card Owners', Fmt.number(stats.totalCardOwners),
          Icons.people_alt_rounded, AdminColors.gold, AdminColors.cream),
      _StatData('Active Cards', Fmt.number(stats.activeCards),
          Icons.credit_card_rounded, AdminColors.statusActive, AdminColors.statusActiveBg),
      _StatData('Available Cards', Fmt.number(stats.availableCards),
          Icons.nfc_rounded, AdminColors.statusAvailable, AdminColors.statusAvailableBg),
      _StatData('Active Staff', Fmt.number(stats.totalStaff),
          Icons.badge_rounded, AdminColors.brownMedium, AdminColors.beige),
      _StatData("Today's Transactions", Fmt.number(stats.todayTransactionCount),
          Icons.receipt_long_rounded, AdminColors.statusPending, AdminColors.statusPendingBg),
      _StatData("Today's Revenue", Fmt.peso(stats.todayRevenue),
          Icons.payments_rounded, AdminColors.statusActive, AdminColors.statusActiveBg),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 600
              ? 2
              : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          mainAxisExtent: 128,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: data.length,
        itemBuilder: (context, i) {
          final s = data[i];
          return StatCard(
            title: s.title,
            value: s.value,
            icon: s.icon,
            iconColor: s.iconColor,
            iconBg: s.iconBg,
          );
        },
      );
    });
  }
}

class _StatData {
  const _StatData(this.title, this.value, this.icon, this.iconColor, this.iconBg);
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
}

// ── Card Load Summary + Table ─────────────────────────────────────────────────

class _CardLoadSummary extends StatelessWidget {
  const _CardLoadSummary({required this.totals});
  final CardLoadTotals totals;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData('Total Paid by Customers', Fmt.peso(totals.totalPaid),
          Icons.payments_rounded, AdminColors.statusActive, AdminColors.statusActiveBg),
      _StatData('Total Loaded to Wallets', Fmt.peso(totals.totalLoaded),
          Icons.account_balance_wallet_rounded, AdminColors.statusAvailable, AdminColors.statusAvailableBg),
      _StatData('Total Bonus Given', Fmt.peso(totals.totalBonus),
          Icons.card_giftcard_rounded, AdminColors.gold, AdminColors.cream),
      _StatData('Number of Loads', Fmt.number(totals.loadCount),
          Icons.sync_alt_rounded, AdminColors.brownMedium, AdminColors.beige),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 600
              ? 2
              : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          mainAxisExtent: 118,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final s = cards[i];
          return StatCard(
            title: s.title,
            value: s.value,
            icon: s.icon,
            iconColor: s.iconColor,
            iconBg: s.iconBg,
          );
        },
      );
    });
  }
}

class _CardLoadsTable extends StatelessWidget {
  const _CardLoadsTable({required this.loads});
  final List<CardLoad> loads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = loads.take(12).toList();

    if (recent.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text('No card loads yet.',
                style: theme.textTheme.bodyMedium),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            _col('Customer'),
            _col('Paid'),
            _col('Bonus (20%)'),
            _col('Total to Wallet'),
            _col('Processed By'),
            _col('Date / Time'),
          ],
          rows: recent
              .map((l) => DataRow(cells: [
                    DataCell(Text(l.clientName)),
                    DataCell(Text(Fmt.peso(l.paid),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AdminColors.statusActive))),
                    DataCell(Text(Fmt.peso(l.bonus),
                        style: const TextStyle(color: AdminColors.gold))),
                    DataCell(Text(Fmt.peso(l.total),
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(l.performedBy,
                        style: theme.textTheme.bodySmall)),
                    DataCell(Text(Fmt.relativeDate(l.createdAt),
                        style: theme.textTheme.bodySmall)),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(
          label.toUpperCase(),
          style: const TextStyle(
              color: AdminColors.brownMedium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
        ),
      );
}

// ── Recent Transactions Table ─────────────────────────────────────────────────

class _RecentTransactionsTable extends StatelessWidget {
  const _RecentTransactionsTable({required this.transactions});
  final List<AdminTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(8).toList();
    final theme = Theme.of(context);

    if (recent.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text('No transactions yet.',
                style: theme.textTheme.bodyMedium),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            _col('Transaction ID'),
            _col('Customer'),
            _col('Card'),
            _col('Stylist'),
            _col('Service'),
            _col('Amount'),
            _col('Date / Time'),
            _col('Status'),
          ],
          rows: recent
              .map((tx) => DataRow(cells: [
                    DataCell(Text(tx.transactionId,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12))),
                    DataCell(Text(tx.ownerName)),
                    DataCell(Text(tx.nfcCardId,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11))),
                    DataCell(Text(tx.staffName)),
                    DataCell(Text(tx.serviceName)),
                    DataCell(Text(Fmt.peso(tx.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(Fmt.relativeDate(tx.dateTime),
                        style: theme.textTheme.bodySmall)),
                    DataCell(StatusChip.transaction(tx.status)),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(
          label.toUpperCase(),
          style: const TextStyle(
              color: AdminColors.brownMedium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
        ),
      );
}

// ── Staff Activity ────────────────────────────────────────────────────────────

class _StaffActivitySection extends StatelessWidget {
  const _StaffActivitySection({required this.transactions});
  final List<AdminTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffTx = <String, List<AdminTransactionModel>>{};
    for (final tx in transactions.take(20)) {
      if (tx.staffName == '—' || tx.staffName.isEmpty) continue;
      staffTx.putIfAbsent(tx.staffName, () => []);
      staffTx[tx.staffName]!.add(tx);
    }

    if (staffTx.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('No staff activity yet.',
                style: theme.textTheme.bodyMedium),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth >= 800 ? 2 : 1;
      final entries = staffTx.entries.take(4).toList();
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 260,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          return SectionCard(
            title: entry.key,
            child: Column(
              children: entry.value
                  .take(3)
                  .map((row) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  color: AdminColors.cream,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.content_cut_rounded,
                                  size: 14, color: AdminColors.brownMedium),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.ownerName,
                                      style: theme.textTheme.titleSmall),
                                  Text(row.serviceName,
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Fmt.peso(row.amount),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                StatusChip.transaction(row.status),
                              ],
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          );
        },
      );
    });
  }
}

// ── Staff Leaderboards ────────────────────────────────────────────────────────

class _StaffLeaderboards extends StatelessWidget {
  const _StaffLeaderboards({required this.leaders});
  final List<StaffLeader> leaders;

  @override
  Widget build(BuildContext context) {
    final byRevenue = List<StaffLeader>.from(leaders)
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final byServices = List<StaffLeader>.from(leaders)
      ..sort((a, b) => b.totalServices.compareTo(a.totalServices));

    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth >= 800;
      final content = [
        _LeaderboardCard(
          title: 'Top Earning Staff',
          subtitle: 'Ranked by total revenue',
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xFFFFB300),
          items: byRevenue,
          valueBuilder: (s) => Fmt.peso(s.totalRevenue),
        ),
        _LeaderboardCard(
          title: 'Most Services Rendered',
          subtitle: 'Ranked by completed service count',
          icon: Icons.content_cut_rounded,
          iconColor: AdminColors.gold,
          items: byServices,
          valueBuilder: (s) =>
              '${Fmt.number(s.totalServices)} service${s.totalServices != 1 ? 's' : ''}',
        ),
      ];

      return side
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: content[0]),
                const SizedBox(width: 16),
                Expanded(child: content[1]),
              ],
            )
          : Column(
              children: [
                content[0],
                const SizedBox(height: 16),
                content[1],
              ],
            );
    });
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.valueBuilder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<StaffLeader> items;
  final String Function(StaffLeader) valueBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ]),
            ]),
          ),
          const Divider(height: 20),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text('No data yet.', style: theme.textTheme.bodySmall),
            )
          else
            ...List.generate(items.length, (i) {
              final s = items[i];
              final rank = i + 1;
              final isTop3 = rank <= 3;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(children: [
                      SizedBox(width: 36, child: _RankBadge(rank: rank)),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isTop3
                            ? iconColor.withValues(alpha: 0.15)
                            : AdminColors.cream,
                        child: Text(s.initials,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isTop3 ? iconColor : AdminColors.gold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isTop3
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                      Text(valueBuilder(s),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isTop3 ? iconColor : AdminColors.charcoal)),
                    ]),
                  ),
                  if (i < items.length - 1)
                    const Divider(indent: 16, endIndent: 16, height: 1),
                ],
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    if (medal != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8E1),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text(medal, style: const TextStyle(fontSize: 16))),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AdminColors.cream,
        shape: BoxShape.circle,
        border: Border.all(color: AdminColors.beigeDeep),
      ),
      child: Center(
        child: Text('$rank',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminColors.brownLight)),
      ),
    );
  }
}
