import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/staff_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';

/// Manager view of staff — read-only, no add/edit/delete.
class ManagerStaffScreen extends StatefulWidget {
  const ManagerStaffScreen({super.key});

  @override
  State<ManagerStaffScreen> createState() => _ManagerStaffScreenState();
}

class _ManagerStaffScreenState extends State<ManagerStaffScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = AdminMockData.staff.where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.staffId.toLowerCase().contains(q) ||
          s.positionLabel.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Staff / Stylists', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('View all Lavish Prima employees.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),

            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name, ID or position…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: staff.isEmpty
                  ? const EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'No staff found',
                    )
                  : Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                _col('Staff ID'),
                                _col('Name'),
                                _col('Position'),
                                _col('Contact'),
                                _col('Services'),
                                _col('Status'),
                                _col('Joined'),
                              ],
                              rows: staff.map((s) => DataRow(cells: [
                                DataCell(Text(s.staffId,
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: AdminColors.brownMedium))),
                                DataCell(Row(children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AdminColors.cream,
                                    child: Text(s.initials,
                                        style: const TextStyle(
                                            color: AdminColors.gold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(s.fullName,
                                      style: theme.textTheme.titleSmall),
                                ])),
                                DataCell(Text(s.positionLabel)),
                                DataCell(Text(s.phone,
                                    style: theme.textTheme.bodyMedium)),
                                DataCell(Text('${s.serviceCount} services')),
                                DataCell(StatusChip.staff(s.status)),
                                DataCell(Text(Fmt.date(s.joinedDate),
                                    style: theme.textTheme.bodySmall)),
                              ])).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label.toUpperCase(),
            style: const TextStyle(
                color: AdminColors.brownMedium,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}
