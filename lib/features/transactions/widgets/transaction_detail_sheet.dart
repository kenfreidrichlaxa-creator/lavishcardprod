import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/status_chip.dart';

class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({super.key, required this.transaction});
  final AdminTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = transaction;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AdminColors.beigeDeep,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(24),
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminColors.cream,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AdminColors.gold, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Transaction Details', style: theme.textTheme.headlineSmall),
                      Text(tx.transactionId,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AdminColors.brownLight)),
                    ]),
                    const Spacer(),
                    StatusChip.transaction(tx.status),
                  ]),

                  const SizedBox(height: 24),

                  // Amount hero
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: AdminColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.beigeDeep),
                    ),
                    child: Column(children: [
                      Text(Fmt.peso(tx.amount),
                          style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AdminColors.charcoal)),
                      const SizedBox(height: 6),
                      Text(tx.serviceName,
                          style: theme.textTheme.bodyMedium),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Details card
                  _DetailCard(children: [
                    _Row('Transaction ID', tx.transactionId, mono: true),
                    _Row('Customer', tx.ownerName),
                    _Row('Card', tx.nfcCardId, mono: true),
                    _Row('Stylist', tx.staffName),
                    _Row('Service', tx.serviceName),
                    _Row('Payment Method', tx.paymentMethod.label),
                    _Row('Date', Fmt.date(tx.dateTime)),
                    _Row('Time', _formatTime(tx.dateTime)),
                    _Row('Status', tx.status.name[0].toUpperCase() + tx.status.name.substring(1), isLast: true),
                  ]),

                  const SizedBox(height: 16),

                  // Relationship summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminColors.cream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.beigeDeep),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TRANSACTION FLOW',
                            style: TextStyle(
                                fontSize: 10,
                                color: AdminColors.brownLight,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _FlowRow(icon: Icons.person_rounded, label: 'Customer', value: tx.ownerName),
                        _FlowArrow(),
                        _FlowRow(icon: Icons.nfc_rounded, label: 'Card', value: tx.nfcCardId),
                        _FlowArrow(),
                        _FlowRow(icon: Icons.content_cut_rounded, label: 'Service', value: tx.serviceName),
                        _FlowArrow(),
                        _FlowRow(icon: Icons.badge_rounded, label: 'Stylist', value: tx.staffName),
                        _FlowArrow(),
                        _FlowRow(icon: Icons.payments_rounded, label: 'Payment', value: Fmt.peso(tx.amount)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AdminColors.beigeDeep),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.mono = false, this.isLast = false});
  final String label;
  final String value;
  final bool mono;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.brownLight)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AdminColors.charcoal,
                      fontFamily: mono ? 'monospace' : null)),
            ),
          ]),
        ),
        if (!isLast)
          const Divider(indent: 16, endIndent: 16, height: 1),
      ],
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AdminColors.beigeDeep)),
        child: Icon(icon, size: 13, color: AdminColors.gold),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AdminColors.brownLight)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.charcoal)),
      ]),
    ]);
  }
}

class _FlowArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14, top: 4, bottom: 4),
      child: Icon(Icons.arrow_downward_rounded, size: 12, color: AdminColors.beigeDeep),
    );
  }
}
