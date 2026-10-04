/// Types of manager-initiated wallet operations.
enum WalletTxType { topUp, cardSale, transfer }

extension WalletTxTypeLabel on WalletTxType {
  String get label => switch (this) {
        WalletTxType.topUp => 'Wallet Top Up',
        WalletTxType.cardSale => 'Card Sale',
        WalletTxType.transfer => 'Wallet Transfer',
      };
}

/// A manager-initiated wallet operation record.
class WalletTransactionModel {
  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.performedBy,
    required this.dateTime,
    required this.notes,
    // Top Up / Card Sale
    this.targetOwnerId,
    this.targetOwnerName,
    this.targetCardId,
    // Transfer
    this.fromOwnerId,
    this.fromOwnerName,
    this.toOwnerId,
    this.toOwnerName,
  });

  final String id;
  final WalletTxType type;
  final double amount;
  final String performedBy;
  final DateTime dateTime;
  final String notes;

  // Top Up / Card Sale target
  final String? targetOwnerId;
  final String? targetOwnerName;
  final String? targetCardId;

  // Transfer fields
  final String? fromOwnerId;
  final String? fromOwnerName;
  final String? toOwnerId;
  final String? toOwnerName;
}
