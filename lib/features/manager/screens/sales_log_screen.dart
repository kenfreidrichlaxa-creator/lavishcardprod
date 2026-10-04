import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/wallet_transaction_model.dart';

/// A shared in-memory log of all manager-initiated wallet operations.
/// In production this would be fetched from the backend.
class SalesLogStore {
  SalesLogStore._();
  static final SalesLogStore instance = SalesLogStore._();

  final List<WalletTransactionModel> _records = [];
  List<WalletTransactionModel> get records =>
      List.unmodifiable(_records.reversed.toList());

  void add(WalletTransactionModel record) {
    _records.add(record);
  }
}

/// Screen showing all manager-initiated wallet operations.
/// Visible to both Manager (own view) and Admin (in Transactions area).
class SalesLogScreen extends StatelessWidget {
  const SalesLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = SalesLogStore.instance.records;

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales & Operations Log', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Card sales, wallet top ups, and transfers.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),

            // Summary chips
            Row(children: [
              _SummaryChip(
                label: 'Card Sales',
                count: records.where((r) => r.type == WalletTxType.cardSale).length,
                color: AdminColors.gold,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Top Ups',
                count: records.where((r) => r.type == WalletTxType.topUp).length,
                color: AdminColors.statusActive,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Transfers',
                count: records.where((r) => r.type == WalletTxType.transfer).length,
                color: AdminColors.statusAvailable,
              ),
            ]),
            const SizedBox(height: 16),

            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 52, color: AdminColors.beigeDeep),
                          const SizedBox(height: 14),
                          Text('No operations recorded yet',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                              'Card sales, top ups, and transfers will appear here.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                _col('ID'),
                                _col('Type'),
                                _col('Customer / Details'),
                                _col('Card ID'),
                                _col('Amount'),
                                _col('Performed By'),
                                _col('Date / Time'),
                              ],
                              rows: records.map((r) {
                                final details = switch (r.type) {
                                  WalletTxType.cardSale =>
                                    r.targetOwnerName ?? '—',
                                  WalletTxType.topUp =>
                                    r.targetOwnerName ?? '—',
                                  WalletTxType.transfer =>
                                    '${r.fromOwnerName} → ${r.toOwnerName}',
                                };
                                return DataRow(cells: [
                                  DataCell(Text(r.id.substring(3, 16),
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: AdminColors.brownMedium))),
                                  DataCell(_TypeChip(type: r.type)),
                                  DataCell(Text(details,
                                      style: theme.textTheme.bodyMedium)),
                                  DataCell(r.targetCardId != null
                                      ? Text(r.targetCardId!,
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11))
                                      : const Text('—',
                                          style: TextStyle(
                                              color: AdminColors.brownLight))),
                                  DataCell(Text(Fmt.peso(r.amount),
                                      style: theme.textTheme.titleSmall)),
                                  DataCell(Text(r.performedBy,
                                      style: theme.textTheme.bodyMedium)),
                                  DataCell(Text(Fmt.relativeDate(r.dateTime),
                                      style: theme.textTheme.bodySmall)),
                                ]);
                              }).toList(),
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
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final WalletTxType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      WalletTxType.cardSale => ('Card Sale', AdminColors.gold),
      WalletTxType.topUp => ('Top Up', AdminColors.statusActive),
      WalletTxType.transfer => ('Transfer', AdminColors.statusAvailable),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
