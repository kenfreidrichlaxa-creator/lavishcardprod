enum TransactionStatus { completed, pending, cancelled }

enum PaymentMethod { lavishWallet, cash, card }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.lavishWallet => 'Lavish Wallet',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
      };
}

class AdminTransactionModel {
  const AdminTransactionModel({
    required this.id,
    required this.transactionId,
    required this.ownerId,
    required this.ownerName,
    required this.nfcCardId,
    required this.staffId,
    required this.staffName,
    required this.serviceId,
    required this.serviceName,
    required this.amount,
    required this.paymentMethod,
    required this.dateTime,
    required this.status,
    this.notes,
  });

  final String id;
  final String transactionId;
  final String ownerId;
  final String ownerName;
  final String nfcCardId;
  final String staffId;
  final String staffName;
  final String serviceId;
  final String serviceName;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime dateTime;
  final TransactionStatus status;
  final String? notes;
}

extension AdminTransactionModelJson on AdminTransactionModel {
  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'nfcCardId': nfcCardId,
        'staffId': staffId,
        'staffName': staffName,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'amount': amount,
        'paymentMethod': paymentMethod.name,
        'dateTime': dateTime.toIso8601String(),
        'status': status.name,
        'notes': notes,
      };

  static AdminTransactionModel fromJson(Map<String, dynamic> j) =>
      AdminTransactionModel(
        id: j['id'] as String,
        transactionId: j['transactionId'] as String,
        ownerId: j['ownerId'] as String,
        ownerName: j['ownerName'] as String,
        nfcCardId: j['nfcCardId'] as String,
        staffId: j['staffId'] as String,
        staffName: j['staffName'] as String,
        serviceId: j['serviceId'] as String,
        serviceName: j['serviceName'] as String,
        amount: (j['amount'] as num).toDouble(),
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == j['paymentMethod'],
          orElse: () => PaymentMethod.lavishWallet,
        ),
        dateTime: DateTime.parse(j['dateTime'] as String),
        status: TransactionStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => TransactionStatus.completed,
        ),
        notes: j['notes'] as String?,
      );
}
