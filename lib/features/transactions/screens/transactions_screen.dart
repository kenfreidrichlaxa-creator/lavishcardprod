import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/cache_service.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filter_bar.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_chip.dart';
import '../widgets/transaction_detail_sheet.dart';

enum _TxFilter { today, thisWeek, thisMonth, all, completed, pending, cancelled }

extension _TxFilterLabel on _TxFilter {
  String get label => switch (this) {
        _TxFilter.today => 'Today',
        _TxFilter.thisWeek => 'This Week',
        _TxFilter.thisMonth => 'This Month',
        _TxFilter.all => 'All Time',
        _TxFilter.completed => 'Completed',
        _TxFilter.pending => 'Pending',
        _TxFilter.cancelled => 'Cancelled',
      };
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _TxFilter _filter = _TxFilter.all;
  String _query = '';

  List<AdminTransactionModel> _all = [];
  bool _loading = true;
  bool _offline = false;
  DateTime? _cachedAt;
  bool _exporting = false;

  Future<void> _exportExcel() async {
    final items = _filtered;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No transactions to export.'),
        backgroundColor: AdminColors.warning,
      ));
      return;
    }
    setState(() => _exporting = true);
    try {
      final path = await AdminDataRepository.instance.exportTransactionsCsv(
        items,
        label: 'transactions_${_filter.name}',
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved ${items.length} transactions to: $path'),
        backgroundColor: AdminColors.statusActive,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not export: $e'),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

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
      final tx = await AdminDataRepository.instance
          .fetchTransactions(branchIds: AdminSession.effectiveBranchIds);
      if (!mounted) return;
      await CacheService.writeList(
        CacheKeys.transactions,
        tx.map((e) => e.toJson()).toList(),
      );
      setState(() {
        _all      = tx;
        _loading  = false;
        _offline  = false;
        _cachedAt = null;
      });
    } catch (_) {
      if (!mounted) return;
      final cached = await CacheService.readList(CacheKeys.transactions);
      final ts     = await CacheService.lastUpdated(CacheKeys.transactions);
      if (!mounted) return;
      setState(() {
        if (cached != null) {
          _all = cached.map(AdminTransactionModelJson.fromJson).toList();
        }
        _loading  = false;
        _offline  = true;
        _cachedAt = ts;
      });
    }
  }

  List<AdminTransactionModel> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    return _all.where((tx) {
      final q = _query.toLowerCase();
      if (q.isNotEmpty &&
          !tx.transactionId.toLowerCase().contains(q) &&
          !tx.ownerName.toLowerCase().contains(q) &&
          !tx.nfcCardId.toLowerCase().contains(q) &&
          !tx.staffName.toLowerCase().contains(q) &&
          !tx.serviceName.toLowerCase().contains(q)) { return false; }

      return switch (_filter) {
        _TxFilter.today => tx.dateTime.isAfter(today),
        _TxFilter.thisWeek => tx.dateTime.isAfter(weekAgo),
        _TxFilter.thisMonth => tx.dateTime.isAfter(monthStart),
        _TxFilter.all => true,
        _TxFilter.completed => tx.status == TransactionStatus.completed,
        _TxFilter.pending => tx.status == TransactionStatus.pending,
        _TxFilter.cancelled => tx.status == TransactionStatus.cancelled,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;
    final totalRevenue = items
        .where((t) => t.status == TransactionStatus.completed)
        .fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Transactions',
              subtitle: 'View and manage all payment transactions.',
              action: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AdminColors.statusActiveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AdminColors.statusActive.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.payments_rounded,
                        size: 14, color: AdminColors.statusActive),
                    const SizedBox(width: 8),
                    Text('Revenue: ${Fmt.peso(totalRevenue)}',
                        style: const TextStyle(
                            color: AdminColors.statusActive,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportExcel,
                  icon: _exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Excel'),
                ),
              ]),
            ),

            if (_offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OfflineBanner(cachedAt: _cachedAt, onRetry: _load),
              ),

            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search transaction, customer, card, or stylist…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            FilterBar<_TxFilter>(
              options: _TxFilter.values,
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
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions found',
                      subtitle: 'Try adjusting your filters or date range.',
                    )
                  : Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
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
                                _col('Method'),
                                _col('Date / Time'),
                                _col('Status'),
                                _col(''),
                              ],
                              rows: items.map((tx) => _buildRow(context, tx, theme)).toList(),
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
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  DataRow _buildRow(BuildContext context, AdminTransactionModel tx, ThemeData theme) {
    return DataRow(cells: [
      DataCell(Text(tx.transactionId,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AdminColors.brownMedium))),
      DataCell(Text(tx.ownerName, style: theme.textTheme.bodyMedium)),
      DataCell(Text(tx.nfcCardId,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
      DataCell(Text(tx.staffName)),
      DataCell(Text(tx.serviceName)),
      DataCell(Text(Fmt.peso(tx.amount),
          style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(tx.paymentMethod.label, style: theme.textTheme.bodySmall)),
      DataCell(Text(Fmt.relativeDate(tx.dateTime), style: theme.textTheme.bodySmall)),
      DataCell(StatusChip.transaction(tx.status)),
      DataCell(IconButton(
        icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AdminColors.brownMedium),
        onPressed: () => _openDetail(context, tx),
        tooltip: 'View Details',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      )),
    ]);
  }

  void _openDetail(BuildContext context, AdminTransactionModel tx) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(transaction: tx),
    );
  }
}
