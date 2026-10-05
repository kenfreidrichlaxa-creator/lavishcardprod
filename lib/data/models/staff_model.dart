enum StaffStatus { active, inactive }

/// Dynamic staff position from `staff_positions` table.
class StaffPositionModel {
  const StaffPositionModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory StaffPositionModel.fromRow(Map<String, dynamic> r) =>
      StaffPositionModel(
        id: (r['id'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        sortOrder: (r['sort_order'] as int?) ?? 0,
        isActive: (r['is_active'] as bool?) ?? true,
      );
}

class StaffModel {
  const StaffModel({
    required this.id,
    required this.staffId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.positionLabel,
    required this.status,
    required this.joinedDate,
    this.positionId,
    this.serviceCount = 0,
    this.services = const [],
  });

  final String id;
  final String staffId;
  final String fullName;
  final String phone;
  final String email;

  /// The display label for this staff's position (e.g. "Stylist", "Senior Stylist").
  /// Comes from position_name column (denormalized) or falls back to position column.
  final String positionLabel;

  /// FK to staff_positions table — null for legacy staff with no dynamic position.
  final String? positionId;

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
        'positionLabel': positionLabel,
        'positionId': positionId,
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
        positionLabel: (j['positionLabel'] as String?) ?? '',
        positionId: j['positionId'] as String?,
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
