import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../shared/widgets/empty_state.dart';

/// Shows all unassigned/available cards —Ecards that haven't been sold yet.
class AvailableCardsScreen extends StatelessWidget {
  const AvailableCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = AdminMockData.nfcCards
        .where((c) => c.status == NfcCardStatus.available)
        .toList();

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Cards',
                        style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                        '${cards.length} card${cards.length != 1 ? 's' : ''} available for sale.',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AdminColors.statusAvailableBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AdminColors.statusAvailable
                          .withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.nfc_rounded,
                      size: 16, color: AdminColors.statusAvailable),
                  const SizedBox(width: 8),
                  Text('${cards.length} Available',
                      style: const TextStyle(
                          color: AdminColors.statusAvailable,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            Expanded(
              child: cards.isEmpty
                  ? const EmptyState(
                      icon: Icons.credit_card_off_outlined,
                      title: 'No available cards',
                      subtitle:
                          'All cards have been assigned to customers.',
                    )
                  : LayoutBuilder(builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                      return GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 2.6,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, i) =>
                            _AvailableCardTile(card: cards[i]),
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableCardTile extends StatelessWidget {
  const _AvailableCardTile({required this.card});
  final NfcCardModel card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C2420), Color(0xFF3D2E26)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.nfc_rounded,
                color: AdminColors.goldLight, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(card.cardId,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.charcoal,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Registered: ${Fmt.date(card.registeredDate)}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AdminColors.statusAvailableBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Available',
                style: TextStyle(
                    color: AdminColors.statusAvailable,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
