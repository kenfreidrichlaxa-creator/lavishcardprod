import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/wallet_transaction_model.dart';

/// Success receipt shown after a manager completes an operation.
class OperationReceiptCard extends StatelessWidget {
  const OperationReceiptCard({
    super.key,
    required this.record,
    required this.onNewTransaction,
  });

  final WalletTransactionModel record;
  final VoidCallback onNewTransaction;

  Color get _accentColor => switch (record.type) {
        WalletTxType.cardSale => AdminColors.gold,
        WalletTxType.topUp => AdminColors.statusActive,
        WalletTxType.transfer => AdminColors.statusAvailable,
      };

  IconData get _icon => switch (record.type) {
        WalletTxType.cardSale => Icons.add_card_rounded,
        WalletTxType.topUp => Icons.account_balance_wallet_rounded,
        WalletTxType.transfer => Icons.swap_horiz_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Success header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentColor.withValues(alpha: 0.15),
                      border: Border.all(color: _accentColor, width: 2),
                    ),
                    child: Icon(Icons.check_rounded, size: 32, color: _accentColor),
                  ),
                  const SizedBox(height: 14),
                  Text(record.type.label,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: _accentColor)),
                  const SizedBox(height: 8),
                  Text(Fmt.peso(record.amount),
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AdminColors.charcoal)),
                  const SizedBox(height: 4),
                  Text(Fmt.dateTime(record.dateTime),
                      style: theme.textTheme.bodySmall),
                ]),
              ),

              // Detail rows
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.symmetric(
                    vertical: BorderSide(
                        color: _accentColor.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(children: [
                  _detailRow(context, 'Transaction ID', record.id,
                      mono: true),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _detailRow(context, 'Type', record.type.label),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _detailRow(context, 'Performed By', record.performedBy),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  if (record.type == WalletTxType.transfer) ...[
                    _detailRow(context, 'From', record.fromOwnerName ?? '—'),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _detailRow(context, 'To', record.toOwnerName ?? '—'),
                  ] else ...[
                    _detailRow(context, 'Customer', record.targetOwnerName ?? '—'),
                    if (record.targetCardId != null) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _detailRow(context, 'Card ID', record.targetCardId!, mono: true),
                    ],
                  ],

                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _detailRow(context, 'Amount', Fmt.peso(record.amount),
                      valueColor: _accentColor, bold: true),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _detailRow(context, 'Notes',
                      record.notes.isEmpty ? '—' : record.notes),
                ]),
              ),

              // Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AdminColors.cream,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                  border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('Lavish Prima  ·  Recorded successfully',
                      style: TextStyle(
                          fontSize: 11,
                          color: AdminColors.brownLight)),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewTransaction,
                  icon: Icon(_icon, size: 16),
                  label: const Text('New Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {bool mono = false, bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AdminColors.brownLight)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ?? AdminColors.charcoal,
                  fontFamily: mono ? 'monospace' : null)),
        ),
      ]),
    );
  }
}
