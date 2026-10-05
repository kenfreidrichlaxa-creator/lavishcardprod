enum ServiceStatus { active, inactive }

enum ServiceCategory { hair, nails, skin, beauty, other }

extension ServiceCategoryLabel on ServiceCategory {
  String get label => switch (this) {
        ServiceCategory.hair => 'Hair',
        ServiceCategory.nails => 'Nails',
        ServiceCategory.skin => 'Skin',
        ServiceCategory.beauty => 'Beauty',
        ServiceCategory.other => 'Other',
      };

  /// Single-letter prefix used in service codes (e.g. H001, N002).
  String get codePrefix => switch (this) {
        ServiceCategory.hair => 'H',
        ServiceCategory.nails => 'N',
        ServiceCategory.skin => 'S',
        ServiceCategory.beauty => 'B',
        ServiceCategory.other => 'O',
      };
}

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.status,
    this.description,
    this.primaryCategoryId,
    this.primaryCategoryName,
    this.promoCategoryId,
    this.promoCategoryName,
    this.discountedPrice,
  });

  final String id;
  final String serviceId;
  final String name;
  final ServiceCategory category;
  final double price;

  /// Optional discounted price. Null means no promo price set.
  final double? discountedPrice;

  final int durationMinutes;
  final ServiceStatus status;
  final String? description;
  final String? primaryCategoryId;
  final String? primaryCategoryName;
  final String? promoCategoryId;
  final String? promoCategoryName;

  String get durationLabel => '$durationMinutes min';
  String get categoryLabel => primaryCategoryName ?? category.label;

  /// True if this service has a discounted price set.
  bool get hasDiscount => discountedPrice != null && discountedPrice! > 0;

  /// Returns discounted price if available, otherwise regular price.
  double effectivePrice({bool useDiscount = false}) =>
      useDiscount && hasDiscount ? discountedPrice! : price;

  String get _codePrefix {
    final dynamic = primaryCategoryName;
    if (dynamic != null && dynamic.isNotEmpty) {
      return dynamic.trim()[0].toUpperCase();
    }
    return category.codePrefix;
  }
}

/// Assigns sequential category-prefixed codes to a list of services in place.
/// Call this once after fetching all services from the DB.
///
/// Algorithm:
///   1. Group services by their effective category prefix letter.
///   2. Within each group, sort alphabetically by name so the numbering is
///      stable across refreshes.
///   3. Assign code = prefix + zero-padded 3-digit index (001, 002, …).
///
/// Example output for a mixed list:
///   Manicure      → N001
///   Nail Art      → N002
///   Pedicure      → N003
///   Haircut       → H001
///   Hair Color    → H002
///   Facial        → S001
abstract final class ServiceCodeGenerator {
  static List<ServiceModel> assign(List<ServiceModel> services) {
    // Group by prefix letter (uses dynamic primary category name first).
    final Map<String, List<ServiceModel>> groups = {};
    for (final s in services) {
      final prefix = s._codePrefix;
      groups.putIfAbsent(prefix, () => []).add(s);
    }

    final result = <ServiceModel>[];
    for (final entry in groups.entries) {
      final prefix = entry.key;
      // Sort alphabetically within group for stable numbering.
      final sorted = [...entry.value]
        ..sort((a, b) => a.name.compareTo(b.name));

      for (var i = 0; i < sorted.length; i++) {
        final s = sorted[i];
        final code = '$prefix${(i + 1).toString().padLeft(3, '0')}';
        result.add(ServiceModel(
          id: s.id,
          serviceId: code,
          name: s.name,
          category: s.category,
          price: s.price,
          discountedPrice: s.discountedPrice,
          durationMinutes: s.durationMinutes,
          status: s.status,
          description: s.description,
          primaryCategoryId: s.primaryCategoryId,
          primaryCategoryName: s.primaryCategoryName,
          promoCategoryId: s.promoCategoryId,
          promoCategoryName: s.promoCategoryName,
        ));
      }
    }

    // Return in original fetch order (stable sort by id keeps table order tidy).
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }
}

extension ServiceModelJson on ServiceModel {
  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'name': name,
        'category': category.name,
        'price': price,
        'discountedPrice': discountedPrice,
        'durationMinutes': durationMinutes,
        'status': status.name,
        'description': description,
        'primaryCategoryId': primaryCategoryId,
        'primaryCategoryName': primaryCategoryName,
        'promoCategoryId': promoCategoryId,
        'promoCategoryName': promoCategoryName,
      };

  static ServiceModel fromJson(Map<String, dynamic> j) => ServiceModel(
        id: j['id'] as String,
        serviceId: j['serviceId'] as String,
        name: j['name'] as String,
        category: ServiceCategory.values.firstWhere(
          (e) => e.name == j['category'],
          orElse: () => ServiceCategory.other,
        ),
        price: (j['price'] as num).toDouble(),
        discountedPrice: j['discountedPrice'] == null
            ? null
            : (j['discountedPrice'] as num).toDouble(),
        durationMinutes: (j['durationMinutes'] as num).toInt(),
        status: ServiceStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => ServiceStatus.active,
        ),
        description: j['description'] as String?,
        primaryCategoryId: j['primaryCategoryId'] as String?,
        primaryCategoryName: j['primaryCategoryName'] as String?,
        promoCategoryId: j['promoCategoryId'] as String?,
        promoCategoryName: j['promoCategoryName'] as String?,
      );
}
