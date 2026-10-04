import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/admin_session.dart';
import '../../core/services/supabase_service.dart';

/// A notification sent to admins (e.g. a client reported a lost card).
class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.branchId,
    required this.clientName,
    required this.cardDisplayId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String branchId;
  final String clientName;
  final String cardDisplayId;
  final bool isRead;
  final DateTime createdAt;

  factory AdminNotification.fromMap(Map<String, dynamic> m) => AdminNotification(
        id: m['id'].toString(),
        type: (m['type'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        branchId: (m['branch_id'] as String?) ?? '',
        clientName: (m['client_name'] as String?) ?? '',
        cardDisplayId: (m['card_display_id'] as String?) ?? '',
        isRead: (m['is_read'] as bool?) ?? false,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Reads admin notifications (branch-scoped) + unread count + mark read.
class AdminNotificationsRepository {
  AdminNotificationsRepository._();
  static final AdminNotificationsRepository instance =
      AdminNotificationsRepository._();

  SupabaseClient get _db => SupabaseService.client;

  List<String>? get _branchIds {
    final ids = AdminSession.branchIds;
    return ids.isEmpty ? null : ids; // null = super admin / all branches
  }

  Future<List<AdminNotification>> list() async {
    final res = await _db.rpc('list_admin_notifications', params: {
      'p_branch_ids': _branchIds,
      'p_limit': 100,
    });
    if (res is List) {
      return res
          .map((e) => AdminNotification.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<int> unreadCount() async {
    final res = await _db.rpc('admin_notif_unread_count', params: {
      'p_branch_ids': _branchIds,
    });
    return (res as num?)?.toInt() ?? 0;
  }

  /// Marks one notification read (or all when [id] is null).
  Future<void> markRead({String? id}) async {
    await _db.rpc('mark_admin_notification_read', params: {
      'p_id': id,
      'p_branch_ids': _branchIds,
    });
  }

  /// Deletes one notification (or all read ones when [id] is null).
  Future<void> delete({String? id}) async {
    await _db.rpc('delete_admin_notification', params: {
      'p_id': id,
      'p_branch_ids': _branchIds,
    });
  }
}
