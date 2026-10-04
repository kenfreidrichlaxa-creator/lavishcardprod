import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/page_header.dart';
import '../../card_owners/screens/card_owner_profile_screen.dart';

/// Super Admin — read-only view of ALL card owners across every branch, so the
/// Super Admin doesn't have to switch into individual admin accounts.
class AllCardOwnersScreen extends StatefulWidget {
  const AllCardOwnersScreen({super.key});

  @override
  State<AllCardOwnersScreen> createState() => _AllCardOwnersScreenState();
}

class _AllCardOwnersScreenState extends State<AllCardOwnersScreen> {
  String _query = '';
  bool _loading = true;
  List<CardOwnerModel> _owners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Empty branchIds = all branches (super admin sees everyone).
      final owners = await CardOwnerRepository.instance.fetchCardOwners();
      if (!mounted) return;
      setState(() {
        _owners = owners;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CardOwnerModel> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _owners;
    return _owners.where((o) {
      return o.fullName.toLowerCase().contains(q) ||
          o.customerId.toLowerCase().contains(q) ||
          o.phone.contains(q) ||
          (o.linkedCardId?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: PageHeader(
                    title: 'All Card Owners',
                    subtitle:
                        'Every customer across all branches and franchises.',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name, customer ID, phone, or card ID…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold))
                  : items.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No card owners found',
                          subtitle: 'Customers will appear here once registered.',
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
                                    _col('Contact'),
                                    _col('Card'),
                                    _col('Balance'),
                                    _col('Status'),
                                    _col('Registered'),
                                    _col('Actions'),
                                  ],
                                  rows: items
                                      .map((o) => _row(context, o, theme))
                                      .toList(),
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

  DataRow _row(BuildContext context, CardOwnerModel o, ThemeData theme) {
    return DataRow(cells: [
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
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(o.fullName, style: theme.textTheme.titleSmall),
      ])),
      DataCell(Text(o.phone, style: theme.textTheme.bodyMedium)),
      DataCell(o.linkedCardId != null
          ? Text(o.linkedCardId!,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AdminColors.charcoal))
          : const Text('—', style: TextStyle(color: AdminColors.brownLight))),
      DataCell(Text(Fmt.peso(o.walletBalance), style: theme.textTheme.titleSmall)),
      DataCell(StatusChip.cardOwner(o.status)),
      DataCell(Text(Fmt.date(o.registeredDate), style: theme.textTheme.bodySmall)),
      DataCell(Tooltip(
        message: 'View profile',
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CardOwnerProfileScreen(owner: o),
          )),
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.visibility_outlined,
                size: 16, color: AdminColors.brownMedium),
          ),
        ),
      )),
    ]);
  }
}
