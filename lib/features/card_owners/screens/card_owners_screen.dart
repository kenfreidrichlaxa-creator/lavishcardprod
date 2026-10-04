import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/cache_service.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/nfc_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filter_bar.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_chip.dart';
import 'card_owner_profile_screen.dart';

enum _OwnerFilter { all, active, inactive, suspended, withCard, withoutCard }

extension _OwnerFilterLabel on _OwnerFilter {
  String get label => switch (this) {
        _OwnerFilter.all => 'All',
        _OwnerFilter.active => 'Active',
        _OwnerFilter.inactive => 'Inactive',
        _OwnerFilter.suspended => 'Suspended',
        _OwnerFilter.withCard => 'With Card',
        _OwnerFilter.withoutCard => 'Without Card',
      };
}

class CardOwnersScreen extends StatefulWidget {
  const CardOwnersScreen({super.key});

  @override
  State<CardOwnersScreen> createState() => _CardOwnersScreenState();
}

class _CardOwnersScreenState extends State<CardOwnersScreen> {
  _OwnerFilter _filter = _OwnerFilter.all;
  String _query = '';
  final _searchCtrl = TextEditingController();
  bool _scanning = false;
  List<CardOwnerModel> _owners = [];
  bool _loading = true;
  bool _offline = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Tap an NFC card to find its owner: reads the UID, looks up the card's
  /// display id, and puts it in the search box so the table filters to it.
  Future<void> _tapToSearch() async {
    setState(() => _scanning = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Tap the card on the reader…'),
      duration: Duration(seconds: 3),
    ));
    try {
      final uid = await NfcService.instance.readCardUid();
      // Resolve the card's display id (what the table shows / searches on).
      final res = await CardOwnerRepository.instance.lookupCardByUid(uid);
      final displayId = (res['card_display_id'] as String?) ??
          (res['card_uid'] as String?) ??
          uid;
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _query = displayId;
        _searchCtrl.text = displayId;
      });
      // Feedback: if it resolved to an owner, say so.
      final ownerName = res['client_name'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ownerName != null && ownerName.isNotEmpty
            ? 'Found: $ownerName ($displayId)'
            : 'Card read: $displayId'),
        backgroundColor: AdminColors.statusActive,
        behavior: SnackBarBehavior.floating,
      ));
    } on NfcException catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not read the card. You can type to search.'),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final owners = await CardOwnerRepository.instance
          .fetchCardOwners(branchIds: AdminSession.effectiveBranchIds);
      if (!mounted) return;
      // Cache on success
      await CacheService.writeList(
        CacheKeys.cardOwners,
        owners.map((o) => o.toJson()).toList(),
      );
      setState(() {
        _owners   = owners;
        _loading  = false;
        _offline  = false;
        _cachedAt = null;
      });
    } catch (_) {
      if (!mounted) return;
      // Restore from cache
      final cached = await CacheService.readList(CacheKeys.cardOwners);
      final ts     = await CacheService.lastUpdated(CacheKeys.cardOwners);
      if (!mounted) return;
      setState(() {
        if (cached != null) {
          _owners = cached.map(CardOwnerModel.fromJson).toList();
        }
        _loading  = false;
        _offline  = true;
        _cachedAt = ts;
      });
    }
  }

  List<CardOwnerModel> get _filtered {
    var list = _owners.where((o) {
      final q = _query.toLowerCase();
      if (q.isNotEmpty) {
        if (!o.fullName.toLowerCase().contains(q) &&
            !o.customerId.toLowerCase().contains(q) &&
            !o.phone.contains(q) &&
            !(o.linkedCardId?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return switch (_filter) {
        _OwnerFilter.all => true,
        _OwnerFilter.active => o.status == CardOwnerStatus.active,
        _OwnerFilter.inactive => o.status == CardOwnerStatus.inactive,
        _OwnerFilter.suspended => o.status == CardOwnerStatus.suspended,
        _OwnerFilter.withCard => o.linkedCardId != null,
        _OwnerFilter.withoutCard => o.linkedCardId == null,
      };
    }).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Card Owners',
              subtitle: 'Manage customers and their linked cards.',
            ),

            if (_offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OfflineBanner(cachedAt: _cachedAt, onRetry: _load),
              ),

            // Search + tap-to-find row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, customer ID, phone, or card ID…',
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() {
                                _query = '';
                                _searchCtrl.clear();
                              }),
                            ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _tapToSearch,
                    icon: _scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.contactless_rounded, size: 18),
                    label: Text(_scanning ? 'Tap…' : 'Tap Card'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilterBar<_OwnerFilter>(
              options: _OwnerFilter.values,
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
              labelBuilder: (f) => f.label,
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold),
                    )
                  : items.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No card owners found',
                      subtitle: 'Register a card owner to get started.',
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
                              rows: items.map((o) => _buildRow(context, o, theme)).toList(),
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

  DataRow _buildRow(
      BuildContext context, CardOwnerModel o, ThemeData theme) {
    return DataRow(
      cells: [
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
            : const Text('—',
                style: TextStyle(color: AdminColors.brownLight))),
        DataCell(Text(Fmt.peso(o.walletBalance),
            style: theme.textTheme.titleSmall)),
        DataCell(StatusChip.cardOwner(o.status)),
        DataCell(Text(Fmt.date(o.registeredDate),
            style: theme.textTheme.bodySmall)),
        DataCell(Row(children: [
          _actionBtn(Icons.visibility_outlined, 'View', () => _openProfile(context, o)),
          _actionBtn(Icons.edit_outlined, 'Edit', () {}),
          _actionBtn(Icons.credit_card_rounded, 'Manage Card', () {}),
          _actionBtn(
            Icons.block_rounded,
            'Suspend',
            () => _confirmSuspend(context, o),
            color: AdminColors.statusSuspended,
          ),
        ])),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String tip, VoidCallback onTap,
      {Color color = AdminColors.brownMedium}) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context, CardOwnerModel owner) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardOwnerProfileScreen(owner: owner),
    ));
  }


  Future<void> _confirmSuspend(
      BuildContext context, CardOwnerModel o) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Suspend Card Owner',
      message:
          'Are you sure you want to suspend ${o.fullName}? '
          'Their card will also be disabled.',
      confirmLabel: 'Suspend',
    );
    if (confirmed) {
      setState(() {
        final idx = _owners.indexWhere((x) => x.id == o.id);
        if (idx != -1) {
          _owners[idx] = o.copyWith(status: CardOwnerStatus.suspended);
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Card owner suspended.'),
          backgroundColor: AdminColors.statusSuspended,
        ));
      }
    }
  }
}
