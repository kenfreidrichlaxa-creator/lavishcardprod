import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';

/// Manager view of card owners — read-only.
class ManagerCardOwnersScreen extends StatefulWidget {
  const ManagerCardOwnersScreen({super.key});

  @override
  State<ManagerCardOwnersScreen> createState() =>
      _ManagerCardOwnersScreenState();
}

class _ManagerCardOwnersScreenState extends State<ManagerCardOwnersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owners = AdminMockData.cardOwners.where((o) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return o.fullName.toLowerCase().contains(q) ||
          o.customerId.toLowerCase().contains(q) ||
          o.phone.contains(q) ||
          (o.linkedCardId?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card Owners', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('View customers and their linked cards.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),

            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText:
                    'Search by name, customer ID, phone, or card ID…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

           Expanded(
              child: owners.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No card owners found',
                    )
                  : Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                _col('Customer ID'),
                                _col('Name'),
                                _col('Phone'),
                                _col('Card'),
                                _col('Balance'),
                                _col('Status'),
                                _col('Registered'),
                              ],
                              rows: owners.map((o) => DataRow(cells: [
                                DataCell(Text(o.customerId,
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: AdminColors.brownMedium))),
                                DataCell(Row(children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AdminColors.cream,
                                    child: Text(o.initials,
                                        style: const TextStyle(
                                            color: AdminColors.gold,
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(o.fullName,
                                      style: theme.textTheme.titleSmall),
                                ])),
                                DataCell(Text(o.phone,
                                    style: theme.textTheme.bodyMedium)),
                                DataCell(o.linkedCardId != null
                                    ? Text(o.linkedCardId!,
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11))
                                    : const Text('—',
                                        style: TextStyle(
                                            color: AdminColors.brownLight))),
                                DataCell(Text(Fmt.peso(o.walletBalance),
                                    style: theme.textTheme.titleSmall)),
                                DataCell(StatusChip.cardOwner(o.status)),
                                DataCell(Text(Fmt.date(o.registeredDate),
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
