import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/service_model.dart';
import '../models/staff_model.dart';
import '../models/transaction_model.dart';
import 'staff_repository.dart';

/// Dashboard-level aggregate stats pulled from Supabase.
class DashboardStats {
  const DashboardStats({
    required this.totalCardOwners,
    required this.activeCards,
    required this.availableCards,
    required this.totalStaff,
    required this.todayTransactionCount,
    required this.todayRevenue,
  });

  final int totalCardOwners;
  final int activeCards;
  final int availableCards;
  final int totalStaff;
  final int todayTransactionCount;
  final double todayRevenue;

  Map<String, dynamic> toJson() => {
        'totalCardOwners': totalCardOwners,
        'activeCards': activeCards,
        'availableCards': availableCards,
        'totalStaff': totalStaff,
        'todayTransactionCount': todayTransactionCount,
        'todayRevenue': todayRevenue,
      };

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalCardOwners: (j['totalCardOwners'] as num).toInt(),
        activeCards: (j['activeCards'] as num).toInt(),
        availableCards: (j['availableCards'] as num).toInt(),
        totalStaff: (j['totalStaff'] as num).toInt(),
        todayTransactionCount: (j['todayTransactionCount'] as num).toInt(),
        todayRevenue: (j['todayRevenue'] as num).toDouble(),
      );
}

/// A staff leaderboard entry derived from wallet_transactions.staff_name.
class StaffLeader {
  const StaffLeader({
    required this.name,
    required this.totalRevenue,
    required this.totalServices,
  });
  final String name;
  final double totalRevenue;
  final int totalServices;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'totalRevenue': totalRevenue,
        'totalServices': totalServices,
      };

  factory StaffLeader.fromJson(Map<String, dynamic> j) => StaffLeader(
        name: j['name'] as String,
        totalRevenue: (j['totalRevenue'] as num).toDouble(),
        totalServices: (j['totalServices'] as num).toInt(),
      );
}

/// A single card load / top-up (with 20% bonus), for the dashboard.
class CardLoad {
  const CardLoad({
    required this.createdAt,
    required this.clientId,
    required this.clientName,
    required this.paid,
    required this.bonus,
    required this.total,
    required this.balanceAfter,
    required this.performedBy,
  });

  final DateTime createdAt;
  final String clientId;
  final String clientName;
  final double paid; // what the customer paid (real revenue)
  final double bonus; // 20% bonus given
  final double total; // credited to wallet (paid + bonus)
  final double balanceAfter;
  final String performedBy;

  factory CardLoad.fromRow(Map<String, dynamic> r) {
    return CardLoad(
      createdAt:
          DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
      clientId: (r['client_id'] as String?) ?? '',
      clientName: (r['client_name'] as String?) ?? '—',
      paid: (r['paid_amount'] as num?)?.toDouble() ?? 0,
      bonus: (r['bonus_amount'] as num?)?.toDouble() ?? 0,
      total: (r['total_amount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (r['balance_after'] as num?)?.toDouble() ?? 0,
      performedBy: (r['performed_by'] as String?) ?? '—',
    );
  }

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'clientId': clientId,
        'clientName': clientName,
        'paid': paid,
        'bonus': bonus,
        'total': total,
        'balanceAfter': balanceAfter,
        'performedBy': performedBy,
      };

  factory CardLoad.fromJson(Map<String, dynamic> j) => CardLoad(
        createdAt: DateTime.parse(j['createdAt'] as String),
        clientId: j['clientId'] as String,
        clientName: j['clientName'] as String,
        paid: (j['paid'] as num).toDouble(),
        bonus: (j['bonus'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        balanceAfter: (j['balanceAfter'] as num).toDouble(),
        performedBy: j['performedBy'] as String,
      );
}

/// Aggregate totals across card loads.
class CardLoadTotals {
  const CardLoadTotals({
    required this.loadCount,
    required this.totalPaid,
    required this.totalBonus,
    required this.totalLoaded,
  });

  final int loadCount;
  final double totalPaid;
  final double totalBonus;
  final double totalLoaded;

  factory CardLoadTotals.fromMap(Map<String, dynamic> m) {
    return CardLoadTotals(
      loadCount: (m['load_count'] as num?)?.toInt() ?? 0,
      totalPaid: (m['total_paid'] as num?)?.toDouble() ?? 0,
      totalBonus: (m['total_bonus'] as num?)?.toDouble() ?? 0,
      totalLoaded: (m['total_loaded'] as num?)?.toDouble() ?? 0,
    );
  }

  static const empty = CardLoadTotals(
      loadCount: 0, totalPaid: 0, totalBonus: 0, totalLoaded: 0);

  Map<String, dynamic> toJson() => {
        'loadCount': loadCount,
        'totalPaid': totalPaid,
        'totalBonus': totalBonus,
        'totalLoaded': totalLoaded,
      };

  factory CardLoadTotals.fromJson(Map<String, dynamic> j) => CardLoadTotals(
        loadCount: (j['loadCount'] as num).toInt(),
        totalPaid: (j['totalPaid'] as num).toDouble(),
        totalBonus: (j['totalBonus'] as num).toDouble(),
        totalLoaded: (j['totalLoaded'] as num).toDouble(),
      );
}

/// Real Supabase-backed data for the admin dashboard and tabs.
///
/// The DB has NO staff/employees table, so "staff" for the dashboard and the
/// POS stylist picker are derived from the distinct staff_name values recorded
/// on wallet_transactions (POS charges), with counts/revenue aggregated.
class AdminDataRepository {
  AdminDataRepository._();
  static final AdminDataRepository instance = AdminDataRepository._();

  SupabaseClient get _db => SupabaseService.client;

  // ── Transactions ────────────────────────────────────────────────────────
  /// Fetches wallet transactions (newest first), mapped to AdminTransactionModel.
  /// Optionally filter to a single client (owner).
  Future<List<AdminTransactionModel>> fetchTransactions({
    String? clientId,
    int? limit,
    List<String>? branchIds,
  }) async {
    var query = _db.from('wallet_transactions').select(
        'id, client_id, transaction_type, amount, balance_before, balance_after, '
        'service_name, staff_name, pos_user_name, status, created_at, card_id, branch_id, '
        'clients(full_name), client_cards(card_display_id)');

    if (clientId != null) {
      query = query.eq('client_id', clientId);
    }
    if (branchIds != null && branchIds.isNotEmpty) {
      query = query.inFilter('branch_id', branchIds);
    }

    final ordered = query.order('created_at', ascending: false);
    final rows = await (limit != null ? ordered.limit(limit) : ordered);

    return (rows as List)
        .map((r) => _txFromRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Exports the given transactions to an Excel-ready CSV in
  /// Downloads\lavish_exports and returns the saved file path.
  Future<String> exportTransactionsCsv(
      List<AdminTransactionModel> txs, {String label = 'transactions'}) async {
    const cols = [
      'Transaction ID', 'Customer', 'Card', 'Stylist', 'Service',
      'Amount', 'Method', 'Date / Time', 'Status',
    ];
    String cell(dynamic v) {
      if (v == null) return '';
      var s = v.toString();
      if (s.contains('"') || s.contains(',') || s.contains('\n') ||
          s.contains('\r')) {
        s = '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    final buf = StringBuffer();
    buf.writeln(cols.map(cell).join(','));
    for (final t in txs) {
      buf.writeln([
        cell(t.transactionId),
        cell(t.ownerName),
        cell(t.nfcCardId),
        cell(t.staffName),
        cell(t.serviceName),
        cell(t.amount.toStringAsFixed(2)),
        cell(t.paymentMethod.label),
        cell(t.dateTime.toLocal().toString().split('.').first),
        cell(t.status.name),
      ].join(','));
    }

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory('$home${Platform.pathSeparator}Downloads'
        '${Platform.pathSeparator}lavish_exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${dir.path}${Platform.pathSeparator}${label}_$ts.csv');
    await file.writeAsString('\uFEFF${buf.toString()}');
    return file.path;
  }

  AdminTransactionModel _txFromRow(Map<String, dynamic> r) {
    final dbType = (r['transaction_type'] as String?) ?? 'PAYMENT';
    String? ownerName;
    final cl = r['clients'];
    if (cl is Map) ownerName = cl['full_name'] as String?;
    String? cardDisplay;
    final cc = r['client_cards'];
    if (cc is Map) cardDisplay = cc['card_display_id'] as String?;

    return AdminTransactionModel(
      id: r['id'].toString(),
      transactionId: _shortRef(r['id'].toString()),
      ownerId: (r['client_id'] as String?) ?? '',
      ownerName: ownerName ?? '—',
      nfcCardId: cardDisplay ?? '—',
      staffId: '',
      staffName: (r['staff_name'] as String?) ??
          (r['pos_user_name'] as String?) ??
          _defaultStaff(dbType),
      serviceId: '',
      serviceName: (r['service_name'] as String?) ?? _defaultService(dbType),
      amount: (r['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: _mapPayment(dbType),
      dateTime: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
          DateTime.now(),
      status: _mapTxStatus(r['status'] as String?),
      notes: null,
    );
  }

  // ── Card loads (top-ups + card purchases with 20% bonus) ──────────────────
  /// Recent LOAD transactions with paid / bonus / total, branch-scoped.
  /// Empty [branchIds] = all branches (super admin).
  Future<List<CardLoad>> fetchCardLoads({
    List<String>? branchIds,
    int limit = 100,
  }) async {
    final res = await _db.rpc('list_card_loads', params: {
      'p_branch_ids':
          (branchIds != null && branchIds.isNotEmpty) ? branchIds : null,
      'p_limit': limit,
    });
    return (res as List)
        .map((r) => CardLoad.fromRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Aggregate load totals (count, total paid, total bonus, total loaded).
  Future<CardLoadTotals> fetchCardLoadTotals({List<String>? branchIds}) async {
    final res = await _db.rpc('card_load_totals', params: {
      'p_branch_ids':
          (branchIds != null && branchIds.isNotEmpty) ? branchIds : null,
    });
    return CardLoadTotals.fromMap(Map<String, dynamic>.from(res as Map));
  }

  // ── Services ──────────────────────────────────────────────────────────────
  Future<List<ServiceModel>> fetchServices() async {
    final rows = await _db
        .from('services')
        .select(
            'id, name, category_name, price, discounted_price, duration_minutes, status, description, primary_category_id, primary_category_name, promo_category_id, promo_category_name')
        .order('name', ascending: true);
    final services = (rows as List)
        .map((r) => _serviceFromRow(Map<String, dynamic>.from(r)))
        .toList();
    // Assign category-prefixed codes (H001, N002, etc.) after loading.
    return ServiceCodeGenerator.assign(services);
  }
  /// Creates or updates a universal service via upsert_service.
  /// Returns the saved service id on success, or throws with a message.
  Future<String> saveService({
    String? id,
    required String name,
    required ServiceCategory category,
    required double price,
    required int durationMinutes,
    required ServiceStatus status,
    String? description,
    String? primaryCategoryId,
    String? promoCategoryId,
    double? discountedPrice,
    String performedBy = 'admin',
  }) async {
    final res = await _db.rpc('upsert_service', params: {
      'p_id': (id == null || id.isEmpty) ? null : id,
      'p_name': name.trim(),
      'p_category_key': category.name,
      'p_price': price,
      'p_duration': durationMinutes,
      'p_status': status == ServiceStatus.active ? 'active' : 'inactive',
      'p_description': description,
      'p_primary_category_id': primaryCategoryId,
      'p_promo_category_id': promoCategoryId,
      'p_performed_by': performedBy,
      'p_discounted_price': discountedPrice,
    });
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) return (map['id'] as String);
    throw Exception((map['error'] as String?) ?? 'Could not save service.');
  }

  /// Deletes a service. Returns null on success or an error message.
  Future<String?> deleteService(String id, {String performedBy = 'admin'}) async {
    try {
      final res = await _db.rpc('delete_service',
          params: {'p_id': id, 'p_performed_by': performedBy});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not delete service.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Enables/disables a service. Returns null on success or an error message.
  Future<String?> setServiceStatus(String id, bool active) async {
    try {
      final res = await _db.rpc('set_service_status',
          params: {'p_id': id, 'p_active': active});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not update status.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  ServiceModel _serviceFromRow(Map<String, dynamic> r) {
    return ServiceModel(
      id: r['id'].toString(),
      serviceId: r['id'].toString().toUpperCase(),
      name: (r['name'] as String?) ?? '',
      category: _mapCategory(r['category_name'] as String?),
      price: (r['price'] as num?)?.toDouble() ?? 0,
      discountedPrice: (r['discounted_price'] as num?)?.toDouble(),
      durationMinutes: (r['duration_minutes'] as num?)?.toInt() ?? 0,
      status: (r['status'] as String?) == 'active'
          ? ServiceStatus.active
          : ServiceStatus.inactive,
      description: r['description'] as String?,
      primaryCategoryId: r['primary_category_id'] as String?,
      primaryCategoryName: r['primary_category_name'] as String?,
      promoCategoryId: r['promo_category_id'] as String?,
      promoCategoryName: r['promo_category_name'] as String?,
    );
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────
  Future<DashboardStats> fetchDashboardStats({List<String>? branchIds}) async {
    final results = await Future.wait([
      _countClients(branchIds),
      _countCards('active', branchIds),
      _countBlankCards(branchIds),
      _distinctStaffCount(),
      _todayTx(branchIds),
    ]);
    final today = results[4] as _TodayAgg;
    return DashboardStats(
      totalCardOwners: results[0] as int,
      activeCards: results[1] as int,
      availableCards: results[2] as int,
      totalStaff: results[3] as int,
      todayTransactionCount: today.count,
      todayRevenue: today.revenue,
    );
  }

  Future<int> _countClients(List<String>? branchIds) async {
    var q = _db.from('clients').select('id, branch_id');
    if (branchIds != null && branchIds.isNotEmpty) {
      q = q.inFilter('branch_id', branchIds);
    }
    final rows = await q;
    return (rows as List).length;
  }

  Future<int> _countCards(String status, List<String>? branchIds) async {
    var q = _db.from('client_cards').select('id, branch_id').eq('status', status);
    if (branchIds != null && branchIds.isNotEmpty) {
      q = q.inFilter('branch_id', branchIds);
    }
    final rows = await q;
    return (rows as List).length;
  }

  /// "Available" cards = BLANK cards: no owner yet (client_id null) and still
  /// inactive/unclaimed — i.e. cards ready to be given to a customer.
  Future<int> _countBlankCards(List<String>? branchIds) async {
    var q = _db
        .from('client_cards')
        .select('id, branch_id')
        .isFilter('client_id', null)
        .eq('status', 'inactive');
    if (branchIds != null && branchIds.isNotEmpty) {
      q = q.inFilter('branch_id', branchIds);
    }
    final rows = await q;
    return (rows as List).length;
  }

  Future<_TodayAgg> _todayTx(List<String>? branchIds) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    var q = _db
        .from('wallet_transactions')
        .select(
            'amount, paid_amount, transaction_type, status, created_at, branch_id')
        .gte('created_at', start);
    if (branchIds != null && branchIds.isNotEmpty) {
      q = q.inFilter('branch_id', branchIds);
    }
    final rows = await q;
    var count = 0;
    var revenue = 0.0;
    for (final r in (rows as List)) {
      count++;
      final type = (r['transaction_type'] as String?) ?? '';
      final status = (r['status'] as String?) ?? '';
      // Revenue = actual cash paid by customers when LOADING (paid_amount,
      // excluding the free 20% bonus). Fall back to amount for legacy loads.
      if (type == 'LOAD' && status == 'completed') {
        final paid = (r['paid_amount'] as num?)?.toDouble();
        revenue += paid ?? (r['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return _TodayAgg(count, revenue);
  }

  Future<int> _distinctStaffCount() async {
    final names = await _distinctStaffNames();
    return names.length;
  }

  // ── Staff (derived from wallet_transactions.staff_name) ───────────────────
  Future<List<String>> _distinctStaffNames() async {
    final rows = await _db
        .from('wallet_transactions')
        .select('staff_name')
        .not('staff_name', 'is', null);
    final set = <String>{};
    for (final r in (rows as List)) {
      final n = r['staff_name'] as String?;
      if (n != null && n.trim().isNotEmpty) set.add(n.trim());
    }
    return set.toList()..sort();
  }

  /// Staff leaderboard: group PAYMENT transactions by staff_name.
  Future<List<StaffLeader>> fetchStaffLeaderboard() async {
    final rows = await _db
        .from('wallet_transactions')
        .select('staff_name, amount, transaction_type, status')
        .eq('transaction_type', 'PAYMENT')
        .eq('status', 'completed');

    final map = <String, StaffLeader>{};
    for (final r in (rows as List)) {
      final name = (r['staff_name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final amt = (r['amount'] as num?)?.toDouble() ?? 0;
      final existing = map[name];
      if (existing == null) {
        map[name] = StaffLeader(
            name: name, totalRevenue: amt, totalServices: 1);
      } else {
        map[name] = StaffLeader(
          name: name,
          totalRevenue: existing.totalRevenue + amt,
          totalServices: existing.totalServices + 1,
        );
      }
    }
    return map.values.toList();
  }

  /// Fetches staff from the centralized `staff` table managed by Super Admin.
  Future<List<StaffModel>> fetchStaff() async {
    return StaffRepository.instance.listStaff();
  }

  /// Staff names for the POS stylist picker (active only).
  Future<List<StaffModel>> fetchActiveStylists() async {
    return StaffRepository.instance.listStaff(activeOnly: true);
  }

  // ── Enum / helper mappers ─────────────────────────────────────────────────
  static PaymentMethod _mapPayment(String dbType) {
    // All wallet transactions are wallet-based.
    return PaymentMethod.lavishWallet;
  }

  static TransactionStatus _mapTxStatus(String? s) {
    switch (s) {
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.cancelled;
      case 'reversed':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }

  static String _defaultService(String dbType) {
    switch (dbType) {
      case 'LOAD':
      case 'ADJUSTMENT':
        return 'Wallet Top-Up';
      case 'REFUND':
      case 'REVERSAL':
        return 'Refund';
      default:
        return 'Service Payment';
    }
  }

  static String _defaultStaff(String dbType) {
    switch (dbType) {
      case 'LOAD':
      case 'ADJUSTMENT':
        return 'Admin';
      default:
        return '—';
    }
  }

  static ServiceCategory _mapCategory(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('hair')) return ServiceCategory.hair;
    if (n.contains('nail') || n.contains('beauty')) {
      return ServiceCategory.nails;
    }
    if (n.contains('skin') || n.contains('facial')) {
      return ServiceCategory.skin;
    }
    if (n.contains('massage') || n.contains('spa')) {
      return ServiceCategory.beauty;
    }
    return ServiceCategory.other;
  }

  static String _shortRef(String id) {
    final clean = id.replaceAll('-', '');
    final tail = clean.length >= 6 ? clean.substring(0, 6) : clean;
    return 'TXN-${tail.toUpperCase()}';
  }
}

class _TodayAgg {
  const _TodayAgg(this.count, this.revenue);
  final int count;
  final double revenue;
}
