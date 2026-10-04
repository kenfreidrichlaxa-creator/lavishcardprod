import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/admin_session.dart';
import '../../core/services/supabase_service.dart';

/// A single audit event row.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.entityType,
    required this.branchId,
    required this.branchName,
    required this.actor,
    required this.actorRole,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String entityType;
  final String branchId;
  final String branchName;
  final String actor;
  final String actorRole;
  final String summary;
  final DateTime createdAt;

  factory AuditEvent.fromRow(Map<String, dynamic> r) => AuditEvent(
        id: r['id'].toString(),
        action: (r['action'] as String?) ?? '',
        entityType: (r['entity_type'] as String?) ?? '',
        branchId: (r['branch_id'] as String?) ?? '',
        branchName: (r['branch_name'] as String?) ?? '',
        actor: (r['actor'] as String?) ?? '',
        actorRole: (r['actor_role'] as String?) ?? '',
        summary: (r['summary'] as String?) ?? '',
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// A Backblaze backup snapshot (one timestamped folder in the bucket).
class BackupSnapshot {
  const BackupSnapshot({required this.prefix, required this.name});
  final String prefix; // e.g. backups/2026-09-18T01-05-41-913Z/
  final String name; // e.g. 2026-09-18T01-05-41-913Z

  /// Parses the snapshot timestamp from its name (folder = ISO with - for :.).
  DateTime? get timestamp {
    // name like 2026-09-18T01-05-41-913Z -> restore : and .
    final m = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})-(\d{3})Z$')
        .firstMatch(name);
    if (m == null) return DateTime.tryParse(name);
    return DateTime.tryParse(
        '${m[1]}T${m[2]}:${m[3]}:${m[4]}.${m[5]}Z');
  }

  factory BackupSnapshot.fromMap(Map<String, dynamic> m) => BackupSnapshot(
        prefix: (m['prefix'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
      );
}

/// A single backup object (one table's JSON) inside a snapshot.
class BackupObject {
  const BackupObject(
      {required this.key, required this.table, required this.size});
  final String key;
  final String table;
  final int size;

  factory BackupObject.fromMap(Map<String, dynamic> m) => BackupObject(
        key: (m['key'] as String?) ?? '',
        table: (m['table'] as String?) ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
      );
}

/// Audit + customer/admin management calls.
class AuditRepository {
  AuditRepository._();
  static final AuditRepository instance = AuditRepository._();

  SupabaseClient get _db => SupabaseService.client;

  String get _actor => AdminSession.user?.username.isNotEmpty == true
      ? AdminSession.user!.username
      : (AdminSession.user?.fullName ?? 'admin');
  String get _role => AdminSession.user?.role ?? 'admin';

  /// Lists the Backblaze backup snapshots via the list-backups Edge Function.
  /// The B2 keys stay server-side; the admin app only sees snapshot metadata.
  Future<List<BackupSnapshot>> listBackups() async {
    final res = await _db.functions.invoke('list-backups', body: {'action': 'list'});
    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['success'] != true) {
      throw Exception((data['error'] as String?) ?? 'Could not list backups.');
    }
    final list = (data['snapshots'] as List?) ?? [];
    return list
        .map((e) => BackupSnapshot.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Lists the JSON objects (per-table backups) inside one snapshot.
  Future<List<BackupObject>> listBackupObjects(String prefix) async {
    final res = await _db.functions
        .invoke('list-backups', body: {'action': 'get', 'prefix': prefix});
    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['success'] != true) {
      throw Exception((data['error'] as String?) ?? 'Could not open snapshot.');
    }
    final list = (data['objects'] as List?) ?? [];
    return list
        .map((e) => BackupObject.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Fetches one backup object's contents (the stored JSON: table, count, rows).
  Future<Map<String, dynamic>> fetchBackupObject(String key) async {
    final res = await _db.functions
        .invoke('list-backups', body: {'action': 'object', 'key': key});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Writes an organized CSV (given a fixed [columns] order) to the user's
  /// Downloads\lavish_backups folder. Returns the saved file path.
  Future<String> exportBackupCsv({
    required String table,
    required List<String> columns,
    required List<Map<String, dynamic>> rows,
  }) async {
    final buf = StringBuffer();
    // Header row.
    buf.writeln(columns.map(_csvCell).join(','));
    // Data rows in the same column order.
    for (final row in rows) {
      buf.writeln(columns.map((c) => _csvCell(row[c])).join(','));
    }

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory('$home${Platform.pathSeparator}Downloads'
        '${Platform.pathSeparator}lavish_backups');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${dir.path}${Platform.pathSeparator}${table}_$ts.csv');
    // Prepend a UTF-8 BOM so Excel opens accented text correctly.
    await file.writeAsString('\uFEFF${buf.toString()}');
    return file.path;
  }

  /// Downloads EVERY table in a snapshot as organized CSVs into one folder
  /// named after the snapshot (under Downloads\lavish_backups). Returns the
  /// folder path. [objects] are the B2 keys; [friendlyNames] maps key -> label.
  Future<String> exportSnapshotCsvs({
    required String snapshotName,
    required List<String> objects,
    required Map<String, String> friendlyNames,
  }) async {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    // Folder name = readable date if the snapshot name is an ISO-ish stamp.
    final safeName = snapshotName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final dir = Directory('$home${Platform.pathSeparator}Downloads'
        '${Platform.pathSeparator}lavish_backups'
        '${Platform.pathSeparator}$safeName');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (final key in objects) {
      final data = await fetchBackupObject(key);
      final table = (data['table'] as String?) ?? '';
      final rawRows = (data['rows'] as List?) ?? const [];
      final rows = rawRows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      // Prefer the friendly, audit-style columns; fall back to raw.
      final disp = displayColumns(table);
      String csv;
      if (disp.isNotEmpty) {
        final headers = disp.map((d) => d[0]).toList();
        final mapped = rows
            .map((r) => {for (final d in disp) d[0]: formatField(d[1], r[d[1]])})
            .toList();
        csv = buildCsv(headers, mapped);
      } else {
        final columns = orderedColumns(rows);
        csv = buildCsv(columns, rows);
      }

      final label = (friendlyNames[key] ?? (table.isEmpty ? 'table' : table))
          .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
          .trim()
          .replaceAll(' ', '_');
      final file = File('${dir.path}${Platform.pathSeparator}$label.csv');
      await file.writeAsString('\uFEFF$csv');
    }
    return dir.path;
  }

  // ── Friendly, audit-log-style display columns per table ─────────────────────
  /// Returns [ [header, fieldKey], ... ] for a readable, normal-person view.
  /// Used by both the on-screen table and the CSV exports so they match.
  static List<List<String>> displayColumns(String table) {
    switch (table) {
      case 'audit_events':
        return [
          ['Timestamp', 'created_at'],
          ['User', 'actor'],
          ['Role', 'actor_role'],
          ['Action', 'action'],
          ['Details', 'summary'],
        ];
      case 'wallet_transactions':
        return [
          ['Timestamp', 'created_at'],
          ['Processed By', 'pos_user_name'],
          ['Type', 'transaction_type'],
          ['Amount', 'amount'],
          ['Paid', 'paid_amount'],
          ['Bonus', 'bonus_amount'],
          ['Balance After', 'balance_after'],
          ['Notes', 'notes'],
        ];
      case 'service_transactions':
        return [
          ['Timestamp', 'created_at'],
          ['Service', 'service_name'],
          ['Staff', 'staff_name'],
          ['Amount', 'total_charged'],
          ['Status', 'status'],
        ];
      case 'clients':
        return [
          ['Customer Code', 'client_code'],
          ['Name', 'full_name'],
          ['Email', 'email'],
          ['Phone', 'phone'],
          ['Status', 'status'],
          ['Registered', 'created_at'],
        ];
      case 'client_cards':
        return [
          ['Card ID', 'card_display_id'],
          ['Status', 'status'],
          ['Activated', 'activated_at'],
          ['Registered', 'created_at'],
        ];
      case 'client_wallets':
        return [
          ['Balance', 'balance'],
          ['Currency', 'currency'],
          ['Status', 'status'],
          ['Updated', 'updated_at'],
        ];
      default:
        return const [];
    }
  }

  /// Formats a raw field value for CSV/display (dates -> readable, else string).
  static String formatField(String key, dynamic v) {
    if (v == null) return '';
    if (key.contains('_at') || key == 'created_at' || key == 'updated_at' ||
        key == 'activated_at') {
      final d = DateTime.tryParse(v.toString());
      if (d != null) return d.toLocal().toString().split('.').first;
    }
    if (v is Map || v is List) return v.toString();
    return v.toString();
  }

  /// Stable, human-friendly column order (shared by single + batch export).
  static List<String> orderedColumns(List<Map<String, dynamic>> rows) {
    final keys = <String>{};
    for (final r in rows) {
      keys.addAll(r.keys);
    }
    const preferred = [
      'created_at', 'client_code', 'full_name', 'name', 'card_display_id',
      'transaction_type', 'amount', 'paid_amount', 'bonus_amount',
      'balance_after', 'action', 'summary', 'email', 'phone', 'status',
    ];
    final ordered = <String>[];
    for (final p in preferred) {
      if (keys.remove(p)) ordered.add(p);
    }
    final rest = keys.toList()..sort();
    ordered.addAll(rest);
    return ordered;
  }

  /// Builds a full CSV string (header + rows) in the given column order.
  static String buildCsv(
      List<String> columns, List<Map<String, dynamic>> rows) {
    final buf = StringBuffer();
    buf.writeln(columns.map(_csvCell).join(','));
    for (final row in rows) {
      buf.writeln(columns.map((c) => _csvCell(row[c])).join(','));
    }
    return buf.toString();
  }

  /// Escapes a single CSV field per RFC 4180 (quotes, commas, newlines).
  static String _csvCell(dynamic v) {
    if (v == null) return '';
    var s = (v is Map || v is List) ? v.toString() : v.toString();
    if (s.contains('"') || s.contains(',') || s.contains('\n') ||
        s.contains('\r')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Lists audit events (super admin: all branches). Optional filters.
  Future<List<AuditEvent>> listAudit({String? branchId, String? action}) async {
    final res = await _db.rpc('list_audit', params: {
      'p_branch_id': branchId,
      'p_action': action,
      'p_limit': 300,
    });
    if (res is List) {
      return res
          .map((e) => AuditEvent.fromRow(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Edits a customer (name/email/phone). Returns null on success or an error.
  Future<String?> editCustomer({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      final res = await _db.rpc('edit_customer', params: {
        'p_client_id': clientId,
        'p_full_name': fullName.trim(),
        'p_email': email.trim(),
        'p_phone': phone.trim(),
        'p_actor': _actor,
        'p_actor_role': _role,
      });
      final map = Map<String, dynamic>.from(res as Map);
      return map['success'] == true ? null : (map['error'] as String?) ?? 'Failed.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Changes/replaces a customer's card. Returns null on success or an error.
  Future<String?> changeCard({
    required String clientId,
    required String newDisplayId,
    String? newCardUid,
    String? reason,
  }) async {
    try {
      final res = await _db.rpc('change_customer_card', params: {
        'p_client_id': clientId,
        'p_new_card_uid': (newCardUid == null || newCardUid.trim().isEmpty)
            ? newDisplayId.trim()
            : newCardUid.trim(),
        'p_new_display_id': newDisplayId.trim(),
        'p_actor': _actor,
        'p_actor_role': _role,
        'p_reason': reason,
      });
      final map = Map<String, dynamic>.from(res as Map);
      return map['success'] == true ? null : (map['error'] as String?) ?? 'Failed.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Archives an admin (status=inactive). Returns null on success or an error.
  Future<String?> archiveAdmin(String adminId) async {
    try {
      final res = await _db.rpc('archive_admin', params: {
        'p_admin_id': adminId,
        'p_actor': _actor,
        'p_actor_role': _role,
      });
      final map = Map<String, dynamic>.from(res as Map);
      return map['success'] == true ? null : (map['error'] as String?) ?? 'Failed.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Edits an admin (name/branches/status). Returns null on success or an error.
  Future<String?> editAdmin({
    required String adminId,
    required String name,
    required List<String> branchIds,
    required String status,
  }) async {
    try {
      final res = await _db.rpc('edit_admin', params: {
        'p_admin_id': adminId,
        'p_name': name.trim(),
        'p_branch_ids': branchIds,
        'p_status': status,
        'p_actor': _actor,
        'p_actor_role': _role,
      });
      final map = Map<String, dynamic>.from(res as Map);
      return map['success'] == true ? null : (map['error'] as String?) ?? 'Failed.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }
}
