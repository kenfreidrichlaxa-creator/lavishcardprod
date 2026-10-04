enum CardOwnerStatus { active, inactive, suspended }

class CardOwnerModel {
  const CardOwnerModel({
    required this.id,
    required this.customerId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.address,
    required this.dateOfBirth,
    required this.status,
    required this.registeredDate,
    this.linkedCardId,
    this.walletBalance = 0,
  });

  final String id;
  final String customerId;
  final String fullName;
  final String phone;
  final String email;
  final String address;
  final DateTime dateOfBirth;
  final CardOwnerStatus status;
  final DateTime registeredDate;
  final String? linkedCardId;
  final double walletBalance;

  String get firstName => fullName.split(' ').first;

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'address': address,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'status': status.name,
        'registeredDate': registeredDate.toIso8601String(),
        'linkedCardId': linkedCardId,
        'walletBalance': walletBalance,
      };

  factory CardOwnerModel.fromJson(Map<String, dynamic> j) => CardOwnerModel(
        id: j['id'] as String,
        customerId: j['customerId'] as String,
        fullName: j['fullName'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String,
        address: j['address'] as String,
        dateOfBirth: DateTime.parse(j['dateOfBirth'] as String),
        status: CardOwnerStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => CardOwnerStatus.active,
        ),
        registeredDate: DateTime.parse(j['registeredDate'] as String),
        linkedCardId: j['linkedCardId'] as String?,
        walletBalance: (j['walletBalance'] as num).toDouble(),
      );

  CardOwnerModel copyWith({
    String? linkedCardId,
    double? walletBalance,
    CardOwnerStatus? status,
  }) {
    return CardOwnerModel(
      id: id,
      customerId: customerId,
      fullName: fullName,
      phone: phone,
      email: email,
      address: address,
      dateOfBirth: dateOfBirth,
      status: status ?? this.status,
      registeredDate: registeredDate,
      linkedCardId: linkedCardId ?? this.linkedCardId,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}
