import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central accessor for the Supabase client.
/// Points to the SAME project as the POS and customer wallet apps, so a card
/// owner registered here can log into the E-Wallet app and pay at the POS.
///
/// Call [SupabaseService.client] anywhere after [SupabaseService.initialize].
abstract final class SupabaseService {
  /// Environment is chosen AUTOMATICALLY by build mode:
  ///   • `flutter run` / debug  → TESTING database (safe for QA)
  ///   • `flutter build --release` (what clients get) → PRODUCTION database
  /// This makes it impossible to accidentally test against production or ship
  /// a release pointed at testing.
  static const bool _useProduction = kReleaseMode;

  // ── Production project (sqfzewussbubpsvdlmdp) ──────────────────────────────
  static const String _prodUrl = 'https://sqfzewussbubpsvdlmdp.supabase.co';
  static const String _prodAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNxZnpld3Vzc2J1YnBzdmRsbWRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5MzE2OTgsImV4cCI6MjEwNTUwNzY5OH0.6O0Uq7cQZ6m731LqcumgvDtmF_SBLPDAoDLXeitkFtQ';

  // ── Testing project (xyybhfrflfdzlmuqmkfx) — kept for QA ────────────────────
  static const String _testUrl = 'https://xyybhfrflfdzlmuqmkfx.supabase.co';
  static const String _testAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5eWJoZnJmbGZkemxtdXFta2Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzMDEwMDUsImV4cCI6MjEwNDg3NzAwNX0.iyb13eMLhtOvv2Ply8aerJUyEF_JxVberYnszxbMOGM';
  // NOTE: Never put the service_role (secret) key in client-side code.

  static const String _url = _useProduction ? _prodUrl : _testUrl;
  static const String _anonKey = _useProduction ? _prodAnonKey : _testAnonKey;

  static SupabaseClient get client => Supabase.instance.client;

  static String get url => _url;
  static String get anonKey => _anonKey;

  /// A standalone client with its OWN auth session — used to create customer
  /// auth accounts during registration without logging out the admin.
  static SupabaseClient standaloneClient() =>
      SupabaseClient(_url, _anonKey);

  /// Call once in main() before runApp.
  static Future<void> initialize() => Supabase.initialize(
        url: _url,
        // ignore: deprecated_member_use
        anonKey: _anonKey,
      );
}
