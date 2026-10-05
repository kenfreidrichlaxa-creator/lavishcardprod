import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/staff_model.dart';

/// CRUD repository for the centralized `staff` table and `staff_positions`.
class StaffRepository {
  StaffRepository._();
  static final StaffRepository instance = StaffRepository._();

  SupabaseClient get _db => SupabaseService.client;

  // ── Staff ─────────────────────────────────────────────────────────────────

  /// Lists all staff ordered by name.
  Future<List<StaffModel>> listStaff({bool activeOnly = false}) async {
    try {
      final res = await _db.rpc('list_staff');
      if (res is! List) return [];
      final all = res
          .map((r) => _staffFromRow(Map<String, dynamic>.from(r)))
          .toList();
      return activeOnly
          ? all.where((s) => s.status == StaffStatus.active).toList()
          : all;
    } catch (_) {
      return [];
    }
  }

  /// Creates a new staff member. Returns null on success or an error string.
  Future<String?> createStaff({
    required String fullName,
    String phone = '',
    String email = '',
    String positionId = '',
    String positionLabel = '',
    DateTime? joinedDate,
    String performedBy = 'admin',
  }) async {
    try {
      final res = await _db.rpc('create_staff_member', params: {
        'p_full_name':    fullName.trim(),
        'p_phone':        phone.trim(),
        'p_email':        email.trim(),
        'p_position':     positionLabel.trim(),
        'p_position_id':  positionId.isEmpty ? null : positionId,
        'p_joined_date':  (joinedDate ?? DateTime.now())
            .toIso8601String()
            .split('T')
            .first,
        'p_performed_by': performedBy,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not create staff.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Updates a staff member. Returns null on success or an error string.
  Future<String?> updateStaff({
    required String id,
    required String fullName,
    String phone = '',
    String email = '',
    String positionId = '',
    String positionLabel = '',
    DateTime? joinedDate,
    String performedBy = 'admin',
  }) async {
    try {
      final res = await _db.rpc('update_staff_member', params: {
        'p_id':           id,
        'p_full_name':    fullName.trim(),
        'p_phone':        phone.trim(),
        'p_email':        email.trim(),
        'p_position':     positionLabel.trim(),
        'p_position_id':  positionId.isEmpty ? null : positionId,
        'p_joined_date':  (joinedDate ?? DateTime.now())
            .toIso8601String()
            .split('T')
            .first,
        'p_performed_by': performedBy,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update staff.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Activates or deactivates a staff member.
  Future<String?> setStaffStatus({
    required String id,
    required bool active,
  }) async {
    try {
      final res = await _db.rpc('set_staff_status', params: {
        'p_id':     id,
        'p_active': active,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update status.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Permanently deletes a staff member.
  Future<String?> deleteStaff(String id) async {
    try {
      final res =
          await _db.rpc('delete_staff_member', params: {'p_id': id});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not delete staff.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  // ── Staff Positions ───────────────────────────────────────────────────────

  /// Lists all staff positions.
  Future<List<StaffPositionModel>> listPositions({
    bool activeOnly = false,
  }) async {
    try {
      final res = await _db.rpc('list_staff_positions', params: {
        'p_active_only': activeOnly,
      });
      if (res is! List) return [];
      return res
          .map((r) =>
              StaffPositionModel.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Creates a position. Returns null on success or an error string.
  Future<String?> createPosition({
    required String name,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _db.rpc('create_staff_position', params: {
        'p_name':       name.trim(),
        'p_sort_order': sortOrder,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not create position.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Updates a position.
  Future<String?> updatePosition({
    required String id,
    required String name,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _db.rpc('update_staff_position', params: {
        'p_id':         id,
        'p_name':       name.trim(),
        'p_sort_order': sortOrder,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update position.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Activates or deactivates a position.
  Future<String?> setPositionActive({
    required String id,
    required bool active,
  }) async {
    try {
      final res = await _db.rpc('set_staff_position_active', params: {
        'p_id':     id,
        'p_active': active,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update position.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Deletes a position.
  Future<String?> deletePosition(String id) async {
    try {
      final res = await _db
          .rpc('delete_staff_position', params: {'p_id': id});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not delete position.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  // ── Internal mapper ───────────────────────────────────────────────────────

  static StaffModel _staffFromRow(Map<String, dynamic> r) {
    final joinedRaw = r['joined_date']?.toString() ?? '';
    // Prefer position_name (dynamic), fall back to position column (legacy)
    final posLabel = (r['position_name'] as String?)?.trim().isNotEmpty == true
        ? r['position_name'] as String
        : (r['position'] as String?) ?? '';

    return StaffModel(
      id: (r['id'] as String?) ?? '',
      staffId: _toStaffCode((r['id'] as String?) ?? ''),
      fullName: (r['full_name'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      email: (r['email'] as String?) ?? '',
      positionLabel: posLabel,
      positionId: r['position_id'] as String?,
      status: ((r['status'] as String?) ?? 'active') == 'active'
          ? StaffStatus.active
          : StaffStatus.inactive,
      joinedDate: DateTime.tryParse(joinedRaw) ?? DateTime.now(),
    );
  }

  static String _toStaffCode(String id) {
    if (id.startsWith('stf_')) {
      return 'STF-${id.substring(4).toUpperCase()}';
    }
    return id.toUpperCase();
  }
}
