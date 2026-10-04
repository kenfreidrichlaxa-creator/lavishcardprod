class WalletModel {
  const WalletModel({
    required this.id,
    required this.ownerId,
    required this.balance,
    required this.totalSpent,
    required this.totalTransactions,
    required this.lastTransactionDate,
  });

  final String id;
  final String ownerId;
  final double balance;
  final double totalSpent;
  final int totalTransactions;
  final DateTime? lastTransactionDate;
}
