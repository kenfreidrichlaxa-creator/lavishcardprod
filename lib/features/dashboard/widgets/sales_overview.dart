import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/sales_analytics.dart';
import '../../../shared/widgets/stat_card.dart';

/// Interactive sales overview: a Today/Weekly/Monthly/Yearly selector that
/// drives summary stat cards and a bar chart of revenue over the period.
class SalesOverview extends StatefulWidget {
  const SalesOverview({super.key, required this.transactions});

  /// Completed transactions (real Supabase data) to compute sales from.
  final List<AdminTransactionModel> transactions;

  @override
  State<SalesOverview> createState() => _SalesOverviewState();
}

class _SalesOverviewState extends State<SalesOverview> {
  SalesPeriod _period = SalesPeriod.weekly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report =
        SalesAnalytics.report(_period, source: widget.transactions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + period selector
        Row(
          children: [
            Text('Sales Overview', style: theme.textTheme.titleLarge),
            const Spacer(),
            _PeriodSelector(
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Summary stat cards
        LayoutBuilder(builder: (context, constraints) {
          final cross = constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 480
                  ? 3
                  : 1;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cross,
            mainAxisExtent: 120,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: [
              StatCard(
                title: '${_period.summaryLabel} Revenue',
                value: Fmt.peso(report.totalRevenue),
                icon: Icons.payments_rounded,
                iconColor: AdminColors.statusActive,
                iconBg: AdminColors.statusActiveBg,
              ),
              StatCard(
                title: 'Transactions',
                value: Fmt.number(report.transactionCount),
                icon: Icons.receipt_long_rounded,
                iconColor: AdminColors.statusAvailable,
                iconBg: AdminColors.statusAvailableBg,
              ),
              StatCard(
                title: 'Average Sale',
                value: Fmt.peso(report.averageSale),
                icon: Icons.trending_up_rounded,
                iconColor: AdminColors.gold,
                iconBg: AdminColors.cream,
              ),
            ],
          );
        }),
        const SizedBox(height: 16),

        // Chart card
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue — ${_period.label}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ${Fmt.peso(report.totalRevenue)} across '
                  '${report.series.length} periods',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: report.totalRevenue == 0
                      ? Center(
                          child: Text('No sales in this period.',
                              style: theme.textTheme.bodyMedium),
                        )
                      : _SalesBarChart(series: report.series),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});
  final SalesPeriod selected;
  final ValueChanged<SalesPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: SalesPeriod.values.map((p) {
        final isSel = p == selected;
        return ChoiceChip(
          label: Text(p.label),
          selected: isSel,
          onSelected: (_) => onChanged(p),
          showCheckmark: false,
          selectedColor: AdminColors.gold,
          labelStyle: TextStyle(
            color: isSel ? Colors.white : AdminColors.brownMedium,
            fontSize: 12,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
              color: isSel ? AdminColors.gold : AdminColors.beigeDeep),
        );
      }).toList(),
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({required this.series});
  final List<SalesPoint> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = series.fold<double>(
        0, (m, p) => p.value > m ? p.value : m);
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AdminColors.charcoal,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              Fmt.peso(rod.toY),
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AdminColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _compact(value),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= series.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(series[i].label,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(series.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: series[i].value,
                width: series.length > 8 ? 12 : 20,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AdminColors.goldDark, AdminColors.goldLight],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}
