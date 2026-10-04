import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';
import '../../data/models/card_owner_model.dart';
import '../../data/models/nfc_card_model.dart';
import '../../data/models/service_model.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/transaction_model.dart';

/// Generic pill-shaped status chip.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  // ── Factory constructors ─────────────────────────────────────────────────

  factory StatusChip.cardOwner(CardOwnerStatus status) {
    return switch (status) {
      CardOwnerStatus.active => const StatusChip(
          label: 'Active',
          color: AdminColors.statusActive,
          backgroundColor: AdminColors.statusActiveBg,
        ),
      CardOwnerStatus.inactive => const StatusChip(
          label: 'Inactive',
          color: AdminColors.statusInactive,
          backgroundColor: AdminColors.statusInactiveBg,
        ),
      CardOwnerStatus.suspended => const StatusChip(
          label: 'Suspended',
          color: AdminColors.statusSuspended,
          backgroundColor: AdminColors.statusSuspendedBg,
        ),
    };
  }

  factory StatusChip.nfcCard(NfcCardStatus status) {
    return switch (status) {
      NfcCardStatus.active => const StatusChip(
          label: 'Active',
          color: AdminColors.statusActive,
          backgroundColor: AdminColors.statusActiveBg,
        ),
      NfcCardStatus.available => const StatusChip(
          label: 'Available',
          color: AdminColors.statusAvailable,
          backgroundColor: AdminColors.statusAvailableBg,
        ),
      NfcCardStatus.assigned => const StatusChip(
          label: 'Assigned',
          color: AdminColors.statusPending,
          backgroundColor: AdminColors.statusPendingBg,
        ),
      NfcCardStatus.suspended => const StatusChip(
          label: 'Suspended',
          color: AdminColors.statusSuspended,
          backgroundColor: AdminColors.statusSuspendedBg,
        ),
      NfcCardStatus.replaced => const StatusChip(
          label: 'Replaced',
          color: AdminColors.statusReplaced,
          backgroundColor: AdminColors.statusReplacedBg,
        ),
    };
  }

  factory StatusChip.staff(StaffStatus status) {
    return switch (status) {
      StaffStatus.active => const StatusChip(
          label: 'Active',
          color: AdminColors.statusActive,
          backgroundColor: AdminColors.statusActiveBg,
        ),
      StaffStatus.inactive => const StatusChip(
          label: 'Inactive',
          color: AdminColors.statusInactive,
          backgroundColor: AdminColors.statusInactiveBg,
        ),
    };
  }

  factory StatusChip.service(ServiceStatus status) {
    return switch (status) {
      ServiceStatus.active => const StatusChip(
          label: 'Active',
          color: AdminColors.statusActive,
          backgroundColor: AdminColors.statusActiveBg,
        ),
      ServiceStatus.inactive => const StatusChip(
          label: 'Inactive',
          color: AdminColors.statusInactive,
          backgroundColor: AdminColors.statusInactiveBg,
        ),
    };
  }

  factory StatusChip.transaction(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.completed => const StatusChip(
          label: 'Completed',
          color: AdminColors.statusActive,
          backgroundColor: AdminColors.statusActiveBg,
        ),
      TransactionStatus.pending => const StatusChip(
          label: 'Pending',
          color: AdminColors.statusPending,
          backgroundColor: AdminColors.statusPendingBg,
        ),
      TransactionStatus.cancelled => const StatusChip(
          label: 'Cancelled',
          color: AdminColors.statusSuspended,
          backgroundColor: AdminColors.statusSuspendedBg,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
