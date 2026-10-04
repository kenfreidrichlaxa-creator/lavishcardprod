import 'package:flutter/material.dart';
import '../../nfc_cards/widgets/franchise_cards_hub.dart';

/// Super Admin "Cards" — franchise tabs (all franchises). Each tab shows
/// actions + blank cards + card owners. No approval gate (Super Admin).
class CardsHubScreen extends StatelessWidget {
  const CardsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const FranchiseCardsHub(requireApproval: false),
    );
  }
}
