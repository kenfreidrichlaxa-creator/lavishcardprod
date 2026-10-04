/// Primary service category (e.g. "Nails", "Hair", "Skin").
/// Stored in the `service_primary_categories` Supabase table.
class PrimaryCategory {
  const PrimaryCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory PrimaryCategory.fromRow(Map<String, dynamic> r) => PrimaryCategory(
        id: (r['id'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        sortOrder: (r['sort_order'] as int?) ?? 0,
        isActive: (r['is_active'] as bool?) ?? true,
      );

  PrimaryCategory copyWith({String? name, int? sortOrder, bool? isActive}) =>
      PrimaryCategory(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
      );
}

/// Promo / secondary category (e.g. "Summer Promo", "Buy 1 Get 1").
/// Stored in the `service_promo_categories` Supabase table.
class PromoCategory {
  const PromoCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final String description;
  final int sortOrder;
  final bool isActive;

  factory PromoCategory.fromRow(Map<String, dynamic> r) => PromoCategory(
        id: (r['id'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        description: (r['description'] as String?) ?? '',
        sortOrder: (r['sort_order'] as int?) ?? 0,
        isActive: (r['is_active'] as bool?) ?? true,
      );

  PromoCategory copyWith({
    String? name,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) =>
      PromoCategory(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
      );
}
