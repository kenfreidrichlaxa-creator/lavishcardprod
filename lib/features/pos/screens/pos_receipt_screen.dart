import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/models/staff_model.dart';
import '../widgets/pos_cart.dart';

/// Data passed to the receipt screen after a successful checkout.
class ReceiptData {
  const ReceiptData({
    required this.transactionId,
    required this.owner,
    required this.card,
    required this.stylists,
    required this.items,
    required this.total,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.dateTime,
  });

  final String transactionId;
  final CardOwnerModel owner;
  final NfcCardModel card;
  final List<StaffModel> stylists;
  final List<CartItem> items;
  final double total;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime dateTime;

  /// Joined names for display.
  String get stylistNames {
    if (stylists.isEmpty) return '—';
    return stylists.map((s) => s.fullName).join(', ');
  }
}

class PosReceiptScreen extends StatelessWidget {
  const PosReceiptScreen({super.key, required this.data});
  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      appBar: AppBar(
        backgroundColor: AdminColors.cardBg,
        automaticallyImplyLeading: false,
        title: const Text('Payment Receipt'),
        actions: [
          TextButton.icon(
            onPressed: () {
              // Pop back to POS, clearing stack up to it
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.point_of_sale_rounded, size: 16),
            label: const Text('New Transaction'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // ── Success banner ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 28, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AdminColors.statusActiveBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    border: Border.all(
                        color: AdminColors.statusActive
                            .withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AdminColors.statusActive
                            .withValues(alpha: 0.15),
                        border: Border.all(
                            color: AdminColors.statusActive, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 34, color: AdminColors.statusActive),
                    ),
                    const SizedBox(height: 14),
                    Text('Payment Successful',
                        style: theme.textTheme.headlineMedium?.copyWith(
                            color: AdminColors.statusActive)),
                    const SizedBox(height: 6),
                    Text(Fmt.peso(data.total),
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.charcoal)),
                    const SizedBox(height: 4),
                    Text(Fmt.dateTime(data.dateTime),
                        style: theme.textTheme.bodySmall),
                  ]),
                ),

                // ── Receipt body ─────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.symmetric(
                      vertical: BorderSide(
                          color: AdminColors.statusActive
                              .withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Column(children: [
                    // Transaction ID
                    _receiptRow(
                      context,
                      label: 'Transaction ID',
                      value: data.transactionId,
                      mono: true,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Customer
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AdminColors.cream,
                          child: Text(data.owner.initials,
                              style: const TextStyle(
                                  color: AdminColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(data.owner.fullName,
                                  style:
                                      theme.textTheme.titleSmall),
                              Text(data.card.cardId,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color:
                                          AdminColors.brownLight)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            const Text('Card',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AdminColors.brownLight)),
                            const Icon(Icons.nfc_rounded,
                                size: 18,
                                color: AdminColors.gold),
                          ],
                        ),
                      ]),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Stylist(s)
                    _receiptRow(context,
                        label: data.stylists.length > 1
                            ? 'Stylists'
                            : 'Stylist',
                        value: data.stylistNames),
                    if (data.stylists.length == 1)
                      _receiptRow(context,
                          label: 'Position',
                          value: data.stylists.first.positionLabel.isEmpty
                              ? '—'
                              : data.stylists.first.positionLabel),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Services
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 14, 20, 4),
                      child: Row(children: [
                        Text('Services',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(
                                    color: AdminColors.brownLight,
                                    letterSpacing: 0.5)),
                      ]),
                    ),
                    ...data.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: AdminColors.cream,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                  Icons.content_cut_rounded,
                                  size: 13,
                                  color: AdminColors.brownMedium),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(item.service.name,
                                  style:
                                      theme.textTheme.bodyLarge),
                            ),
                            if (item.quantity > 1)
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 8),
                                child: Text('ÁE{item.quantity}',
                                    style: theme
                                        .textTheme.bodySmall),
                              ),
                            Text(Fmt.peso(item.lineTotalCharged),
                                style: theme.textTheme.titleSmall),
                          ]),
                        )),
                    const SizedBox(height: 8),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Total
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Text('TOTAL',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(letterSpacing: 1)),
                        const Spacer(),
                        Text(Fmt.peso(data.total),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(
                                    color: AdminColors.gold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20)),
                      ]),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Balance change
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Column(children: [
                        _balanceRow(context, 'Balance Before',
                            data.balanceBefore,
                            AdminColors.brownMedium),
                        const SizedBox(height: 6),
                        _balanceRow(context, 'Deducted',
                            -data.total, AdminColors.statusSuspended),
                        const Divider(height: 14),
                        _balanceRow(context, 'Balance After',
                            data.balanceAfter,
                            AdminColors.statusActive,
                            bold: true),
                      ]),
                    ),
                  ]),
                ),

                // ── Receipt footer ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AdminColors.cream,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    border: Border.all(
                        color: AdminColors.statusActive
                            .withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    const Icon(Icons.storefront_rounded,
                        size: 20, color: AdminColors.brownLight),
                    const SizedBox(height: 6),
                    const Text('Lavish Prima',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminColors.charcoal,
                            letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text('Thank you for choosing Lavish Prima!',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── New transaction button ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.point_of_sale_rounded,
                        size: 18),
                    label: const Text('New Transaction'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(BuildContext context,
      {required String label,
      required String value,
      bool mono = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AdminColors.brownLight)),
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
    );
  }

  Widget _balanceRow(
      BuildContext context, String label, double amount, Color color,
      {bool bold = false}) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                    fontWeight:
                        bold ? FontWeight.w600 : FontWeight.w400)),
      ),
      Text(
        amount < 0
            ? '∁E{Fmt.peso(amount.abs())}'
            : Fmt.peso(amount),
        style: TextStyle(
            fontSize: bold ? 16 : 13,
            fontWeight:
                bold ? FontWeight.w700 : FontWeight.w500,
            color: color),
      ),
    ]);
  }
}
