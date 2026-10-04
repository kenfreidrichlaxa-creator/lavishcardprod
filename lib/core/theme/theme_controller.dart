import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode controller. A simple global [ValueNotifier] the root
/// [MaterialApp] listens to and the Settings screen writes to. Persisted with
/// shared_preferences so the choice survives app restarts.
abstract final class ThemeController {
  static const _prefsKey = 'admin_theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDark => mode.value == ThemeMode.dark;

  /// Load the saved preference (call once at startup).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      mode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      mode.value = ThemeMode.light;
    }
  }

  /// Toggle / set dark mode and persist.
  static Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, dark ? 'dark' : 'light');
    } catch (_) {
      // Non-fatal — the toggle still applies for this session.
    }
  }
}
