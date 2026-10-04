import '../mock/mock_data.dart';
import '../models/transaction_model.dart';

// Uses AdminMockData.completedTransactions as the data source.

/// Sales reporting periods for the dashboard.
enum SalesPeriod { today, weekly, monthly, yearly }

extension SalesPeriodLabel on SalesPeriod {
  String get label => switch (this) {
        SalesPeriod.today => 'Today',
        SalesPeriod.weekly => 'Weekly',
        SalesPeriod.monthly => 'Monthly',
        SalesPeriod.yearly => 'Yearly',
      };

  String get summaryLabel => switch (this) {
        SalesPeriod.today => "Today's Sales",
        SalesPeriod.weekly => 'This Week',
        SalesPeriod.monthly => 'This Month',
        SalesPeriod.yearly => 'This Year',
      };
}

/// A single point in the sales chart series.
class SalesPoint {
  const SalesPoint({required this.label, required this.value});

  /// Short axis label (e.g. "9AM", "Mon", "W1", "Jan").
  final String label;

  /// Total revenue for this bucket.
  final double value;
}

/// Aggregated result for a period.
class SalesReport {
  const SalesReport({
    required this.period,
    required this.totalRevenue,
    required this.transactionCount,
    required this.averageSale,
    required this.series,
  });

  final SalesPeriod period;
  final double totalRevenue;
  final int transactionCount;
  final double averageSale;
  final List<SalesPoint> series;
}

/// Computes period-filtered sales analytics from the mock transaction list.
///
/// Periods are anchored to the latest transaction date (not DateTime.now)
/// so the dashboard always shows meaningful data even though the seed data
/// is dated in the past/future relative to the system clock.
abstract final class SalesAnalytics {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// The reference "now" — latest completed transaction date, or DateTime.now.
  static DateTime _anchorOf(List<AdminTransactionModel> completed) {
    if (completed.isEmpty) return DateTime.now();
    return completed
        .map((t) => t.dateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Report over a supplied list of completed transactions (real Supabase data).
  /// Falls back to AdminMockData.completedTransactions if [source] is null.
  static SalesReport report(SalesPeriod period,
      {List<AdminTransactionModel>? source}) {
    final all = source ?? AdminMockData.completedTransactions;
    final anchor = _anchorOf(all);

    late final List<AdminTransactionModel> inPeriod;
    late final List<SalesPoint> series;

    switch (period) {
      case SalesPeriod.today:
        inPeriod = all
            .where((t) => _sameDay(t.dateTime, anchor))
            .toList();
        series = _hourlySeries(inPeriod);
        break;
      case SalesPeriod.weekly:
        final start = _startOfWeek(anchor);
        final end = start.add(const Duration(days: 7));
        inPeriod = all
            .where((t) =>
                !t.dateTime.isBefore(start) && t.dateTime.isBefore(end))
            .toList();
        series = _weeklySeries(inPeriod, start);
        break;
      case SalesPeriod.monthly:
        inPeriod = all
            .where((t) =>
                t.dateTime.year == anchor.year &&
                t.dateTime.month == anchor.month)
            .toList();
        series = _monthlySeries(inPeriod, anchor);
        break;
      case SalesPeriod.yearly:
        inPeriod =
            all.where((t) => t.dateTime.year == anchor.year).toList();
        series = _yearlySeries(inPeriod, anchor.year);
        break;
    }

    final total = inPeriod.fold(0.0, (s, t) => s + t.amount);
    final count = inPeriod.length;
    final avg = count == 0 ? 0.0 : total / count;

    return SalesReport(
      period: period,
      totalRevenue: total,
      transactionCount: count,
      averageSale: avg,
      series: series,
    );
  }

  // ── Series builders ─────────────────────────────────────────────────────

  /// Today → buckets by 3-hour blocks across business hours.
  static List<SalesPoint> _hourlySeries(List<AdminTransactionModel> tx) {
    const blocks = [8, 11, 14, 17, 20]; // 8AM,11AM,2PM,5PM,8PM starts
    final sums = List<double>.filled(blocks.length, 0);
    for (final t in tx) {
      final h = t.dateTime.hour;
      var idx = 0;
      for (var i = 0; i < blocks.length; i++) {
        if (h >= blocks[i]) idx = i;
      }
      sums[idx] += t.amount;
    }
    return List.generate(blocks.length, (i) {
      final h = blocks[i];
      final label = h == 12
          ? '12PM'
          : h > 12
              ? '${h - 12}PM'
              : '${h}AM';
      return SalesPoint(label: label, value: sums[i]);
    });
  }

  /// Weekly → one bucket per day (Mon..Sun).
  static List<SalesPoint> _weeklySeries(
      List<AdminTransactionModel> tx, DateTime weekStart) {
    final sums = List<double>.filled(7, 0);
    for (final t in tx) {
      final dayIdx = t.dateTime.difference(weekStart).inDays;
      if (dayIdx >= 0 && dayIdx < 7) sums[dayIdx] += t.amount;
    }
    return List.generate(
        7, (i) => SalesPoint(label: _weekdays[i], value: sums[i]));
  }

  /// Monthly → 4 weekly buckets (W1..W4/5).
  static List<SalesPoint> _monthlySeries(
      List<AdminTransactionModel> tx, DateTime anchor) {
    final sums = List<double>.filled(5, 0);
    for (final t in tx) {
      final weekIdx = ((t.dateTime.day - 1) ~/ 7).clamp(0, 4);
      sums[weekIdx] += t.amount;
    }
    // Only show as many weeks as the month has.
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final weekCount = ((daysInMonth - 1) ~/ 7) + 1;
    return List.generate(
        weekCount, (i) => SalesPoint(label: 'W${i + 1}', value: sums[i]));
  }

  /// Yearly → 12 monthly buckets (Jan..Dec).
  static List<SalesPoint> _yearlySeries(
      List<AdminTransactionModel> tx, int year) {
    final sums = List<double>.filled(12, 0);
    for (final t in tx) {
      sums[t.dateTime.month - 1] += t.amount;
    }
    return List.generate(
        12, (i) => SalesPoint(label: _months[i], value: sums[i]));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1)); // Monday
  }
}
