import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/category_model.dart';

/// CRUD repository for primary categories and promo categories.
/// All mutations go through Supabase RPCs so they are audit-logged server-side.
class CategoryRepository {
  CategoryRepository._();
  static final CategoryRepository instance = CategoryRepository._();

  SupabaseClient get _db => SupabaseService.client;

  // ── Primary Categories ────────────────────────────────────────────────────

  /// Fetches all primary categories ordered by sort_order.
  /// Pass [activeOnly] = true to exclude inactive ones (e.g. for service dropdowns).
  Future<List<PrimaryCategory>> listPrimaryCategories({
    bool activeOnly = false,
  }) async {
    try {
      final res = await _db.rpc('list_primary_categories', params: {
        'p_active_only': activeOnly,
      });
      if (res is List) {
        return res
            .map((e) => PrimaryCategory.fromRow(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Creates a primary category. Returns null on success or an error string.
  Future<String?> createPrimaryCategory({
    required String name,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _db.rpc('create_primary_category', params: {
        'p_name': name.trim(),
        'p_sort_order': sortOrder,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not create category.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Updates a primary category's name/sort order. Returns null on success.
  Future<String?> updatePrimaryCategory({
    required String id,
    required String name,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _db.rpc('update_primary_category', params: {
        'p_id': id,
        'p_name': name.trim(),
        'p_sort_order': sortOrder,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update category.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Activates or deactivates a primary category. Returns null on success.
  Future<String?> setPrimaryCategoryActive({
    required String id,
    required bool active,
  }) async {
    try {
      final res = await _db.rpc('set_primary_category_active', params: {
        'p_id': id,
        'p_active': active,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update category status.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Permanently deletes a primary category. Returns null on success.
  /// Prefer deactivating if services already use this category.
  Future<String?> deletePrimaryCategory(String id) async {
    try {
      final res = await _db
          .rpc('delete_primary_category', params: {'p_id': id});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not delete category.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  // ── Promo Categories ──────────────────────────────────────────────────────

  /// Fetches all promo/secondary categories ordered by sort_order.
  Future<List<PromoCategory>> listPromoCategories({
    bool activeOnly = false,
  }) async {
    try {
      final res = await _db.rpc('list_promo_categories', params: {
        'p_active_only': activeOnly,
      });
      if (res is List) {
        return res
            .map((e) => PromoCategory.fromRow(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Creates a promo category. Returns null on success or an error string.
  Future<String?> createPromoCategory({
    required String name,
    String description = '',
    int sortOrder = 0,
  }) async {
    try {
      final res = await _db.rpc('create_promo_category', params: {
        'p_name': name.trim(),
        'p_description': description.trim(),
        'p_sort_order': sortOrder,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not create promo category.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Updates a promo category. Returns null on success.
  Future<String?> updatePromoCategory({
    required String id,
    required String name,
    String description = '',
    int sortOrder = 0,
  }) async {
    try {
      final res = await _db.rpc('update_promo_category', params: {
        'p_id': id,
        'p_name': name.trim(),
        'p_description': description.trim(),
        'p_sort_order': sortOrder,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update promo category.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Activates or deactivates a promo category. Returns null on success.
  Future<String?> setPromoCategoryActive({
    required String id,
    required bool active,
  }) async {
    try {
      final res = await _db.rpc('set_promo_category_active', params: {
        'p_id': id,
        'p_active': active,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update promo category status.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Permanently deletes a promo category. Returns null on success.
  Future<String?> deletePromoCategory(String id) async {
    try {
      final res = await _db
          .rpc('delete_promo_category', params: {'p_id': id});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not delete promo category.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }
}
