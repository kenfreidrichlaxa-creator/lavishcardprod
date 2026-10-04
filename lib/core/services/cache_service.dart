import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistence layer on top of shared_preferences.
/// Stores JSON strings keyed by cache key constants.
///
/// Usage:
///   // Write
///   await CacheService.write(CacheKeys.services, jsonList);
///
///   // Read
///   final raw = await CacheService.readList(CacheKeys.services);
///   if (raw != null) { /* restore from cache */ }
abstract final class CacheService {
  // ── Write helpers ─────────────────────────────────────────────────────────

  /// Persists a List of JSON-serialisable maps.
  static Future<void> writeList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items));
      await prefs.setString('${key}_ts', DateTime.now().toIso8601String());
    } catch (_) {/* disk full or permission — fail silently */}
  }

  /// Persists a single JSON-serialisable map.
  static Future<void> writeMap(
    String key,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      await prefs.setString('${key}_ts', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // ── Read helpers ──────────────────────────────────────────────────────────

  /// Returns a cached list of maps, or null if nothing is stored yet.
  static Future<List<Map<String, dynamic>>?> readList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Returns a cached map, or null if nothing is stored yet.
  static Future<Map<String, dynamic>?> readMap(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Returns when the key was last written, or null if never written.
  static Future<DateTime?> lastUpdated(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getString('${key}_ts');
      return ts == null ? null : DateTime.tryParse(ts);
    } catch (_) {
      return null;
    }
  }

  /// Clears all cached data (e.g. on logout).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((k) => CacheKeys.all.any((ck) => k.startsWith(ck)))
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

/// Cache key constants — one per screen / data set.
abstract final class CacheKeys {
  static const String dashboardStats      = 'cache_dashboard_stats';
  static const String dashboardTx         = 'cache_dashboard_tx';
  static const String dashboardLeaders    = 'cache_dashboard_leaders';
  static const String dashboardCardLoads  = 'cache_dashboard_card_loads';
  static const String dashboardLoadTotals = 'cache_dashboard_load_totals';
  static const String cardOwners          = 'cache_card_owners';
  static const String transactions        = 'cache_transactions';
  static const String staff               = 'cache_staff';
  static const String services            = 'cache_services';

  static const List<String> all = [
    dashboardStats,
    dashboardTx,
    dashboardLeaders,
    dashboardCardLoads,
    dashboardLoadTotals,
    cardOwners,
    transactions,
    staff,
    services,
  ];
}
