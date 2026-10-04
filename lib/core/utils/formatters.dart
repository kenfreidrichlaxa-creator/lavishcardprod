/// Utility formatters used across the admin panel.
abstract final class Fmt {
  /// Format a double as Lavish Points: LVP 1,500.00
  static String peso(double v) {
    final abs = v.abs();
    final formatted = abs.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return v < 0 ? '− LVP $formatted' : 'LVP $formatted';
  }

  /// Format DateTime as "Sept 9, 2026"
  static String date(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Format DateTime as "Sept 9, 2026 • 2:15 PM"
  static String dateTime(DateTime dt) {
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${date(dt)} • $hour:$min $period';
  }

  /// Format DateTime as "Today, 2:15 PM" or "Sept 9, 2026"
  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(dt.year, dt.month, dt.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$min $period';

    if (txDate == today) return 'Today, $time';
    if (txDate == yesterday) return 'Yesterday, $time';
    return '${date(dt)}, $time';
  }

  /// Comma-separated number: 1248 → "1,248"
  static String number(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
