import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/admin_session.dart';
import '../../core/services/supabase_service.dart';
import '../models/card_owner_model.dart';
import '../models/nfc_card_model.dart';

/// Result of a register-card-owner attempt.
class RegisterResult {
  const RegisterResult({
    required this.success,
    this.error,
    this.clientId,
    this.clientCode,
    this.cardDisplayId,
    this.balance,
    this.paid,
    this.bonus,
    this.username,
  });

  final bool success;
  final String? error;
  final String? clientId;
  final String? clientCode;
  final String? cardDisplayId;
  final double? balance; // grossed-up total credited to the wallet
  final double? paid; // amount the customer paid
  final double? bonus; // 20% bonus added
  final String? username;
}

/// Result of a grossed-up 20%-bonus wallet load.
class LoadBonusResult {
  const LoadBonusResult({
    required this.success,
    this.error,
    this.paid = 0,
    this.bonus = 0,
    this.total = 0,
    this.balanceAfter = 0,
  });

  final bool success;
  final String? error;
  final double paid;
  final double bonus;
  final double total;
  final double balanceAfter;
}

/// Data access for the admin card-owner flows, backed by the shared Supabase
/// project. Registration creates client + wallet + card + credentials in one
/// atomic RPC (register_card_owner).
class CardOwnerRepository {
  CardOwnerRepository._();
  static final CardOwnerRepository instance = CardOwnerRepository._();

  SupabaseClient get _db => SupabaseService.client;

  /// Branch to tag new data with: the admin's active branch (if they picked one),
  /// otherwise the first assigned branch, falling back to the seeded primary.
  /// Super admins (no branch) use br_main.
  static String get defaultBranchId {
    final active = AdminSession.activeBranchId;
    if (active != null) return active;
    final ids = AdminSession.branchIds;
    return ids.isNotEmpty ? ids.first : 'br_main';
  }

  /// Registers a card owner (client + wallet + NFC card + login credentials).
  Future<RegisterResult> registerCardOwner({
    required String fullName,
    required String phone,
    required String email,
    required String address,
    required DateTime dateOfBirth,
    required String username,
    required String password,
    required String cardDisplayId,
    String? cardUid,
    double initialBalance = 0,
    String performedBy = 'admin',
  }) async {
    try {
      final res = await _db.rpc('register_card_owner', params: {
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_email': email.trim(),
        'p_address': address.trim(),
        'p_date_of_birth':
            dateOfBirth.toIso8601String().split('T').first, // YYYY-MM-DD
        'p_username': username.trim(),
        'p_password': password,
        'p_card_uid': (cardUid == null || cardUid.trim().isEmpty)
            ? cardDisplayId.trim()
            : cardUid.trim(),
        'p_card_display_id': cardDisplayId.trim(),
        'p_initial_balance': initialBalance,
        'p_branch_id': defaultBranchId,
        'p_performed_by': performedBy,
      });

      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) {
        final clientId = map['client_id'] as String?;
        // Create a real Supabase Auth account for the customer so they can log
        // in by email and use "forgot password". Done on a standalone client
        // so the admin's own session is not affected. Non-fatal on failure.
        if (clientId != null) {
          await _createAuthAccount(
            clientId: clientId,
            email: email.trim(),
            password: password,
          );
        }
        return RegisterResult(
          success: true,
          clientId: clientId,
          clientCode: map['client_code'] as String?,
          cardDisplayId: map['card_display_id'] as String?,
          balance: (map['balance'] as num?)?.toDouble(),
          paid: (map['paid'] as num?)?.toDouble(),
          bonus: (map['bonus'] as num?)?.toDouble(),
          username: map['username'] as String?,
        );
      }
      return RegisterResult(
        success: false,
        error: (map['error'] as String?) ?? 'Registration failed.',
      );
    } catch (e) {
      return RegisterResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Creates a Supabase Auth user (email+password) on a standalone client and
  /// links its id to the client row. Failure is non-fatal (the client account
  /// still works via username login); password reset needs this to succeed.
  Future<void> _createAuthAccount({
    required String clientId,
    required String email,
    required String password,
  }) async {
    final authClient = SupabaseService.standaloneClient();
    try {
      final res = await authClient.auth.signUp(email: email, password: password);
      final userId = res.user?.id;
      if (userId != null) {
        await _db.rpc('link_client_auth', params: {
          'p_client_id': clientId,
          'p_auth_user_id': userId,
        });
      }
    } catch (_) {
      // Ignore — e.g. email already has an auth user, or email confirmations
      // are enforced. The client account is still usable.
    } finally {
      try {
        await authClient.auth.signOut();
        await authClient.dispose();
      } catch (_) {}
    }
  }

  /// Looks up a card + owner + balance by NFC UID (or display id).
  /// Returns the parsed map (with success flag) from lookup_card_by_uid.
  Future<Map<String, dynamic>> lookupCardByUid(String cardUid) async {
    try {
      final res = await _db.rpc('lookup_card_by_uid', params: {
        'p_card_uid': cardUid.trim(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Atomically charges (debits) a wallet by card UID via pos_charge_wallet.
  /// Returns the parsed result map (success + balance_after, or error).
  Future<Map<String, dynamic>> chargeWallet({
    required String cardUid,
    required double amount,
    required String serviceSummary,
    required String staffName,
    String performedBy = 'admin',
  }) async {
    try {
      final res = await _db.rpc('pos_charge_wallet', params: {
        'p_card_uid': cardUid.trim(),
        'p_amount': amount,
        'p_service_summary': serviceSummary,
        'p_staff_name': staffName,
        'p_branch_id': defaultBranchId,
        'p_performed_by': performedBy,
        'p_idempotency_key':
            DateTime.now().microsecondsSinceEpoch.toString(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Loads (tops up) a client's wallet via the load_client_wallet RPC.
  Future<String?> loadWallet({
    required String clientId,
    required double amount,
    String performedBy = 'admin',
    String performedById = 'usr_admin',
    String? notes,
  }) async {
    try {
      final res = await _db.rpc('load_client_wallet', params: {
        'p_client_id': clientId,
        'p_amount': amount,
        'p_performed_by_id': performedById,
        'p_performed_by': performedBy,
        'p_branch_id': defaultBranchId,
        'p_notes': notes,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Load failed.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  /// Grossed-up top-up with a 20% bonus. [paid] is what the customer pays; the
  /// wallet is credited `paid / 0.8` (paid = 80% of total, 20% is a free bonus).
  /// e.g. paid 4000 -> wallet gets 5000, bonus 1000.
  /// Returns a [LoadBonusResult] with the computed paid/bonus/total + new
  /// balance on success, or an error message.
  Future<LoadBonusResult> loadWalletWithBonus({
    required String clientId,
    required double paid,
    String performedBy = 'admin',
    String performedById = 'usr_admin',
    String? notes,
  }) async {
    try {
      final res = await _db.rpc('load_client_wallet_bonus', params: {
        'p_client_id': clientId,
        'p_paid': paid,
        'p_performed_by_id': performedById,
        'p_performed_by': performedBy,
        'p_branch_id': defaultBranchId,
        'p_notes': notes,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) {
        return LoadBonusResult(
          success: true,
          paid: (map['paid'] as num?)?.toDouble() ?? paid,
          bonus: (map['bonus'] as num?)?.toDouble() ?? 0,
          total: (map['total'] as num?)?.toDouble() ?? 0,
          balanceAfter: (map['balance_after'] as num?)?.toDouble() ?? 0,
        );
      }
      return LoadBonusResult(
        success: false,
        error: (map['error'] as String?) ?? 'Load failed.',
      );
    } catch (e) {
      return LoadBonusResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Loads a BLANK (unclaimed) card with the tiered LVP bonus so it already
  /// carries a balance when shipped. Creates a placeholder client + wallet and
  /// activates the card; the customer inherits this wallet when they claim it.
  /// [cardRef] can be the card's id, display id, or UID.
  Future<LoadBonusResult> loadBlankCard({
    required String cardRef,
    required double paid,
    String performedBy = 'admin',
    String performedById = 'usr_admin',
    String? notes,
  }) async {
    try {
      final res = await _db.rpc('load_blank_card', params: {
        'p_card_id': cardRef,
        'p_paid': paid,
        'p_performed_by_id': performedById,
        'p_performed_by': performedBy,
        'p_branch_id': defaultBranchId,
        'p_notes': notes,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) {
        return LoadBonusResult(
          success: true,
          paid: (map['paid'] as num?)?.toDouble() ?? paid,
          bonus: (map['bonus'] as num?)?.toDouble() ?? 0,
          total: (map['total'] as num?)?.toDouble() ?? 0,
          balanceAfter: (map['balance_after'] as num?)?.toDouble() ?? 0,
        );
      }
      return LoadBonusResult(
        success: false,
        error: (map['error'] as String?) ?? 'Load failed.',
      );
    } catch (e) {
      return LoadBonusResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Pre-registers a BLANK (unassigned) NFC card via add_blank_card.
  /// The card has no owner yet; a customer claims it later via the wallet app.
  /// Returns null on success, or an error message.
  Future<String?> addBlankCard({
    required String cardUid,
    String? displayId,
    String performedBy = 'admin',
  }) async {
    return addBlankCardInBranch(
        cardUid: cardUid,
        branchId: defaultBranchId,
        displayId: displayId,
        performedBy: performedBy);
  }

  /// Adds a blank card assigned to an EXPLICIT branch (used by Super Admin's
  /// per-franchise card management). Returns null on success or an error.
  Future<String?> addBlankCardInBranch({
    required String cardUid,
    required String branchId,
    String? displayId,
    String performedBy = 'superAdmin',
  }) async {
    try {
      final res = await _db.rpc('add_blank_card', params: {
        'p_card_uid': cardUid.trim(),
        'p_branch_id': branchId,
        'p_display_id': (displayId == null || displayId.trim().isEmpty)
            ? null
            : displayId.trim(),
        'p_performed_by': performedBy,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not add card.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  /// Registers a card owner assigned to an EXPLICIT branch (Super Admin's
  /// per-franchise register). Mirrors registerCardOwner but with a branch param.
  Future<RegisterResult> registerCardOwnerInBranch({
    required String fullName,
    required String phone,
    required String email,
    required String username,
    required String password,
    required String cardDisplayId,
    required String branchId,
    String? cardUid,
    double initialBalance = 0,
    String performedBy = 'superAdmin',
  }) async {
    try {
      final res = await _db.rpc('register_card_owner', params: {
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_email': email.trim(),
        'p_address': '',
        'p_date_of_birth': '1990-01-01',
        'p_username': username.trim(),
        'p_password': password,
        'p_card_uid': (cardUid == null || cardUid.trim().isEmpty)
            ? cardDisplayId.trim()
            : cardUid.trim(),
        'p_card_display_id': cardDisplayId.trim(),
        'p_initial_balance': initialBalance,
        'p_branch_id': branchId,
        'p_performed_by': performedBy,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) {
        final clientId = map['client_id'] as String?;
        if (clientId != null) {
          await _createAuthAccount(
            clientId: clientId, email: email.trim(), password: password);
        }
        return RegisterResult(
          success: true,
          clientId: clientId,
          clientCode: map['client_code'] as String?,
          cardDisplayId: map['card_display_id'] as String?,
          balance: (map['balance'] as num?)?.toDouble(),
        );
      }
      return RegisterResult(
        success: false,
        error: (map['error'] as String?) ?? 'Registration failed.',
      );
    } catch (e) {
      return RegisterResult(success: false, error: 'Connection error: $e');
    }
  }

  /// Lists unclaimed blank cards (branch-scoped) via list_blank_cards.
  Future<List<Map<String, dynamic>>> fetchBlankCards(
      {List<String>? branchIds}) async {
    final res = await _db.rpc('list_blank_cards', params: {
      'p_branch_ids':
          (branchIds != null && branchIds.isNotEmpty) ? branchIds : null,
    });
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Deletes a BLANK (unclaimed) card. A [note] (reason) is required and is
  /// recorded in the audit trail. Returns null on success or an error.
  Future<String?> deleteBlankCard(String cardRef,
      {required String note, String performedBy = 'admin'}) async {
    try {
      final res = await _db.rpc('delete_blank_card', params: {
        'p_card_ref': cardRef,
        'p_performed_by': performedBy,
        'p_note': note.trim(),
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] == true) return null;
      return (map['error'] as String?) ?? 'Could not delete card.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }

  /// Fetches blank cards WITH registration date + franchise code, oldest-first
  /// (so row #1 is the oldest). Used for the counter, date filter, numbering,
  /// and the ranged CSV export.
  Future<List<Map<String, dynamic>>> fetchBlankCardsDetailed(
      {List<String>? branchIds}) async {
    final res = await _db.rpc('list_blank_cards_detailed', params: {
      'p_branch_ids':
          (branchIds != null && branchIds.isNotEmpty) ? branchIds : null,
    });
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Exports the given blank cards to an Excel-ready CSV (Downloads\lavish_exports).
  /// Each row: No., Card Code (<FRANCHISE_CODE>-<UID>), UID, Registered.
  /// [startIndex] is the 1-based number of the first card in the slice so the
  /// exported "No." column matches the on-screen numbering.
  Future<String> exportBlankCardsCsv(
    List<Map<String, dynamic>> cards, {
    required String franchiseName,
    int startIndex = 1,
  }) async {
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
    buf.writeln(['No.', 'Card Code', 'Card UID', 'Registered'].map(cell).join(','));
    var n = startIndex;
    for (final c in cards) {
      final uid =
          (c['card_uid'] as String?) ?? (c['card_display_id'] as String?) ?? '';
      final code = (c['franchise_code'] as String?)?.trim();
      final cardCode =
          (code == null || code.isEmpty) ? uid : '$code-$uid';
      final created = DateTime.tryParse((c['created_at'] as String?) ?? '');
      buf.writeln([
        cell(n),
        cell(cardCode),
        cell(uid),
        cell(created?.toLocal().toString().split('.').first ?? ''),
      ].join(','));
      n++;
    }

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory('$home${Platform.pathSeparator}Downloads'
        '${Platform.pathSeparator}lavish_exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final safeName =
        franchiseName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
        '${dir.path}${Platform.pathSeparator}blank_cards_${safeName}_$ts.csv');
    await file.writeAsString('\uFEFF${buf.toString()}');
    return file.path;
  }

  /// Fetches card owners (clients) with wallet balance and linked card.
  /// If [branchIds] is non-empty, only clients of those branches are returned
  /// (branch-scoped admins); empty = all (super admin).
  Future<List<CardOwnerModel>> fetchCardOwners({List<String>? branchIds}) async {
    var q = _db.from('clients').select(
        'id, client_code, full_name, phone, email, address, date_of_birth, '
        'status, created_at, branch_id, client_wallets(balance), '
        'client_cards(id, card_display_id, status)');
    if (branchIds != null && branchIds.isNotEmpty) {
      q = q.inFilter('branch_id', branchIds);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _ownerFromRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Fetches NFC cards with owner info. Branch-scoped when [branchIds] given.
  Future<List<NfcCardModel>> fetchCards({List<String>? branchIds}) async {
    var q = _db.from('client_cards').select(
        'id, card_display_id, status, created_at, updated_at, '
        'client_id, branch_id, clients(full_name)');
    if (branchIds != null && branchIds.isNotEmpty) {
      q = q.inFilter('branch_id', branchIds);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _cardFromRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ── Mappers ────────────────────────────────────────────────────────────────

  CardOwnerModel _ownerFromRow(Map<String, dynamic> r) {
    double balance = 0;
    final w = r['client_wallets'];
    if (w is List && w.isNotEmpty) {
      balance = (w.first['balance'] as num?)?.toDouble() ?? 0;
    } else if (w is Map) {
      balance = (w['balance'] as num?)?.toDouble() ?? 0;
    }

    String? linkedCardDisplay;
    final c = r['client_cards'];
    if (c is List && c.isNotEmpty) {
      linkedCardDisplay = c.first['card_display_id'] as String?;
    } else if (c is Map) {
      linkedCardDisplay = c['card_display_id'] as String?;
    }

    return CardOwnerModel(
      id: r['id'] as String,
      customerId: (r['client_code'] as String?) ?? '',
      fullName: (r['full_name'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      email: (r['email'] as String?) ?? '',
      address: (r['address'] as String?) ?? '',
      dateOfBirth: _parseDate(r['date_of_birth']) ?? DateTime(1990, 1, 1),
      status: _mapOwnerStatus(r['status'] as String?),
      registeredDate: _parseDate(r['created_at']) ?? DateTime.now(),
      linkedCardId: linkedCardDisplay,
      walletBalance: balance,
    );
  }

  NfcCardModel _cardFromRow(Map<String, dynamic> r) {
    String? ownerName;
    final cl = r['clients'];
    if (cl is Map) ownerName = cl['full_name'] as String?;

    return NfcCardModel(
      id: r['id'] as String,
      cardId: (r['card_display_id'] as String?) ?? '',
      status: _mapCardStatus(r['status'] as String?),
      registeredDate: _parseDate(r['created_at']) ?? DateTime.now(),
      ownerId: r['client_id'] as String?,
      ownerName: ownerName,
      lastUsed: _parseDate(r['updated_at']),
    );
  }

  static CardOwnerStatus _mapOwnerStatus(String? s) {
    switch (s) {
      case 'inactive':
        return CardOwnerStatus.inactive;
      case 'suspended':
        return CardOwnerStatus.suspended;
      default:
        return CardOwnerStatus.active;
    }
  }

  static NfcCardStatus _mapCardStatus(String? s) {
    switch (s) {
      case 'active':
        return NfcCardStatus.active;
      case 'inactive':
        return NfcCardStatus.available;
      case 'blocked':
      case 'lost':
        return NfcCardStatus.suspended;
      case 'replaced':
        return NfcCardStatus.replaced;
      default:
        return NfcCardStatus.assigned;
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
