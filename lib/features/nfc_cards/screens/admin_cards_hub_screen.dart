import 'package:flutter/material.dart';
import '../../../core/services/admin_session.dart';
import '../widgets/franchise_cards_hub.dart';

/// Admin "Cards" — franchise tabs (scoped to the admin's branches). Each tab
/// shows actions + blank cards + card owners. Write actions require Super Admin
/// approval.
class AdminCardsHubScreen extends StatelessWidget {
  const AdminCardsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FranchiseCardsHub(
        requireApproval: true,
        scopeBranchIds: AdminSession.branchIds,
      ),
    );
  }
}
