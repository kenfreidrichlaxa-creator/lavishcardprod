enum StaffStatus { active, inactive }

enum StaffPosition {
  stylist,
  seniorStylist,
  manager,
  cashier,
  receptionist,
  administrator,
}

extension StaffPositionLabel on StaffPosition {
  String get label => switch (this) {
        StaffPosition.stylist => 'Stylist',
        StaffPosition.seniorStylist => 'Senior Stylist',
        StaffPosition.manager => 'Manager',
        StaffPosition.cashier => 'Cashier',
        StaffPosition.receptionist => 'Receptionist',
        StaffPosition.administrator => 'Administrator',
      };
}

class StaffModel {
  const StaffModel({
    required this.id,
    required this.staffId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.position,
    required this.status,
    required this.joinedDate,
    this.serviceCount = 0,
    this.services = const [],
  });

  final String id;
  final String staffId;
  final String fullName;
  final String phone;
  final String email;
  final StaffPosition position;
  final StaffStatus status;
  final DateTime joinedDate;
  final int serviceCount;
  final List<String> services;

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

extension StaffModelJson on StaffModel {
  Map<String, dynamic> toJson() => {
        'id': id,
        'staffId': staffId,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'position': position.name,
        'status': status.name,
        'joinedDate': joinedDate.toIso8601String(),
        'serviceCount': serviceCount,
        'services': services,
      };

  static StaffModel fromJson(Map<String, dynamic> j) => StaffModel(
        id: j['id'] as String,
        staffId: j['staffId'] as String,
        fullName: j['fullName'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String,
        position: StaffPosition.values.firstWhere(
          (e) => e.name == j['position'],
          orElse: () => StaffPosition.stylist,
        ),
        status: StaffStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => StaffStatus.active,
        ),
        joinedDate: DateTime.parse(j['joinedDate'] as String),
        serviceCount: (j['serviceCount'] as num?)?.toInt() ?? 0,
        services: (j['services'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}
