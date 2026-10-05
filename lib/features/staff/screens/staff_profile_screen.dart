import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/staff_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';

class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key, required this.staff});
  final StaffModel staff;

  List<AdminTransactionModel> get _txHistory =>
      AdminMockData.transactions.where((t) => t.staffId == staff.id).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txHistory = _txHistory;
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      appBar: AppBar(
        title: const Text('Staff Profile'),
        backgroundColor: AdminColors.cardBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final left = _buildLeft(context, theme);
          final right = _buildRight(context, theme, txHistory);
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 320, child: left),
                  const SizedBox(width: 20),
                  Expanded(child: right),
                ])
              : Column(children: [left, const SizedBox(height: 16), right]);
        }),
      ),
    );
  }

  Widget _buildLeft(BuildContext context, ThemeData theme) {
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AdminColors.cream,
              child: Text(staff.initials,
                  style: const TextStyle(
                      color: AdminColors.gold, fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Text(staff.fullName, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(staff.staffId,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: AdminColors.brownLight)),
            const SizedBox(height: 4),
            Text(staff.positionLabel.isEmpty ? '—' : staff.positionLabel,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            StatusChip.staff(staff.status),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Personal Information',
        child: Column(children: [
          DetailRow(label: 'Full Name', value: staff.fullName),
          DetailRow(label: 'Phone', value: staff.phone),
          DetailRow(label: 'Email', value: staff.email.isEmpty ? '—' : staff.email),
          DetailRow(label: 'Position', value: staff.positionLabel.isEmpty ? '—' : staff.positionLabel),
          DetailRow(label: 'Joined', value: Fmt.date(staff.joinedDate), isLast: true),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Services',
        child: staff.services.isEmpty
            ? const Text('No services assigned.',
                style: TextStyle(color: AdminColors.brownLight))
            : Wrap(
                spacing: 8, runSpacing: 8,
                children: staff.services
                    .map((s) => Chip(
                          label: Text(s),
                          avatar: const Icon(Icons.content_cut_rounded, size: 12),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
      ),
    ]);
  }

  Widget _buildRight(BuildContext context, ThemeData theme,
      List<AdminTransactionModel> txHistory) {
    return SectionCard(
      title: 'Service History',
      child: txHistory.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No service history.',
                  style: TextStyle(color: AdminColors.brownLight)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  _col('Customer'), _col('Card'), _col('Service'),
                  _col('Amount'), _col('Date / Time'), _col('Status'),
                ],
                rows: txHistory.map((tx) => DataRow(cells: [
                  DataCell(Text(tx.ownerName)),
                  DataCell(Text(tx.nfcCardId,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                  DataCell(Text(tx.serviceName)),
                  DataCell(Text(Fmt.peso(tx.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(Fmt.relativeDate(tx.dateTime),
                      style: theme.textTheme.bodySmall)),
                  DataCell(StatusChip.transaction(tx.status)),
                ])).toList(),
              ),
            ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label.toUpperCase(),
            style: const TextStyle(
                color: AdminColors.brownMedium,
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}
