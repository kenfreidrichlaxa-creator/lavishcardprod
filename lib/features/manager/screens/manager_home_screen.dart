import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/services/auth_service.dart';

/// Manager home —Equick summary cards + shortcuts.
class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final availableCards = AdminMockData.nfcCards
        .where((c) => c.status == NfcCardStatus.available)
        .length;
    final totalOwners = AdminMockData.cardOwners.length;
    final totalStaff = AdminMockData.staff.length;
    final totalWalletValue = AdminMockData.cardOwners
        .fold(0.0, (s, o) => s + o.walletBalance);

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text('$greeting, ${user?.fullName.split(' ').first ?? 'Manager'}',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${user?.branch ?? 'Lavish Prima'}  ·  ${user?.role ?? 'Manager'}',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),

            // Summary cards
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth >= 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.8,
                children: [
                  _SummaryTile(
                    icon: Icons.people_alt_rounded,
                    label: 'Card Owners',
                    value: Fmt.number(totalOwners),
                    iconColor: AdminColors.gold,
                    iconBg: AdminColors.cream,
                  ),
                  _SummaryTile(
                    icon: Icons.badge_rounded,
                    label: 'Active Staff',
                    value: Fmt.number(totalStaff),
                    iconColor: AdminColors.brownMedium,
                    iconBg: AdminColors.beige,
                  ),
                  _SummaryTile(
                    icon: Icons.nfc_rounded,
                    label: 'Available Cards',
                    value: Fmt.number(availableCards),
                    iconColor: AdminColors.statusAvailable,
                    iconBg: AdminColors.statusAvailableBg,
                  ),
                  _SummaryTile(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Total Wallet Value',
                    value: Fmt.peso(totalWalletValue),
                    iconColor: AdminColors.statusActive,
                    iconBg: AdminColors.statusActiveBg,
                  ),
                ],
              );
            }),

            const SizedBox(height: 28),

            // Quick action buttons
            Text('Quick Actions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(
                  icon: Icons.add_card_rounded,
                  label: 'Sell Card',
                  subtitle: 'Register & assign a card',
                  color: AdminColors.gold,
                  onTap: () => _navigateTo(context, 2), // Card Sale tab
                ),
                _QuickAction(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Top Up Wallet',
                  subtitle: 'Add funds to account',
                  color: AdminColors.statusActive,
                  onTap: () => _navigateTo(context, 3),
                ),
                _QuickAction(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfer Balance',
                  subtitle: 'Move funds between accounts',
                  color: AdminColors.statusAvailable,
                  onTap: () => _navigateTo(context, 4),
                ),
                _QuickAction(
                  icon: Icons.credit_card_rounded,
                  label: 'Available Cards',
                  subtitle: 'View unsold cards',
                  color: AdminColors.brownMedium,
                  onTap: () => _navigateTo(context, 5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, int index) {
    // Trigger navigation in the manager shell
    final state = context
        .findAncestorStateOfType<_ManagerShellNavigatorState>();
    state?.navigateTo(index);
  }
}

// Exported for shell access
mixin _ManagerShellNavigatorState on State {
  void navigateTo(int index);
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBg,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
