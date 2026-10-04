import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/admin_session.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/super_admin_gate.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filter_bar.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_chip.dart';
import '../widgets/register_nfc_card_dialog.dart';
import '../widgets/add_blank_card_dialog.dart';

enum _CardFilter { all, available, assigned, active, suspended, replaced }

extension _CardFilterLabel on _CardFilter {
  String get label => switch (this) {
        _CardFilter.all => 'All',
        _CardFilter.available => 'Available',
        _CardFilter.assigned => 'Assigned',
        _CardFilter.active => 'Active',
        _CardFilter.suspended => 'Suspended',
        _CardFilter.replaced => 'Replaced',
      };
}

class NfcCardsScreen extends StatefulWidget {
  const NfcCardsScreen({super.key});

  @override
  State<NfcCardsScreen> createState() => _NfcCardsScreenState();
}

class _NfcCardsScreenState extends State<NfcCardsScreen> {
  _CardFilter _filter = _CardFilter.all;
  String _query = '';
  List<NfcCardModel> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cards = await CardOwnerRepository.instance
          .fetchCards(branchIds: AdminSession.branchIds);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NfcCardModel> get _filtered => _cards.where((c) {
        final q = _query.toLowerCase();
        if (q.isNotEmpty &&
            !c.cardId.toLowerCase().contains(q) &&
            !(c.ownerName?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
        return switch (_filter) {
          _CardFilter.all => true,
          _CardFilter.available => c.status == NfcCardStatus.available,
          _CardFilter.assigned => c.status == NfcCardStatus.assigned,
          _CardFilter.active => c.status == NfcCardStatus.active,
          _CardFilter.suspended => c.status == NfcCardStatus.suspended,
          _CardFilter.replaced => c.status == NfcCardStatus.replaced,
        };
      }).toList();

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
            PageHeader(
              title: 'Cards',
              subtitle: 'Register, assign, and manage Lavish Prima cards.',
              actionLabel: '+ Register Card',
              actionIcon: Icons.add_card_rounded,
              onAction: () => _showRegisterDialog(context),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddBlankDialog(context),
                  icon: const Icon(Icons.style_rounded, size: 16),
                  label: const Text('Add Blank Cards (no owner)'),
                ),
              ),
            ),

            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search card ID or owner name…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            FilterBar<_CardFilter>(
              options: _CardFilter.values,
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
              labelBuilder: (f) => f.label,
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AdminColors.gold),
                    )
                  : items.isEmpty
                  ? EmptyState(
                      icon: Icons.credit_card_off_outlined,
                      title: 'No cards found',
                      subtitle: 'Register a card to get started.',
                    )
                  : Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                _col('Card ID'),
                                _col('Owner'),
                                _col('Status'),
                                _col('Registered'),
                                _col('Last Used'),
                                _col('Actions'),
                              ],
                              rows: items.map((c) => _buildRow(context, c, theme)).toList(),
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
            style: const TextStyle(color: AdminColors.brownMedium, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  DataRow _buildRow(BuildContext context, NfcCardModel c, ThemeData theme) {
    return DataRow(cells: [
      DataCell(Row(children: [
        const Icon(Icons.nfc_rounded, size: 14, color: AdminColors.brownLight),
        const SizedBox(width: 8),
        Text(c.cardId, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ])),
      DataCell(c.ownerName != null
          ? Text(c.ownerName!, style: theme.textTheme.bodyMedium)
          : const Text('Unassigned', style: TextStyle(color: AdminColors.brownLight, fontStyle: FontStyle.italic))),
      DataCell(StatusChip.nfcCard(c.status)),
      DataCell(Text(Fmt.date(c.registeredDate), style: theme.textTheme.bodySmall)),
      DataCell(Text(
          c.lastUsed != null ? Fmt.relativeDate(c.lastUsed!) : 'Never',
          style: theme.textTheme.bodySmall)),
      DataCell(Row(children: [
        _actionBtn(Icons.edit_outlined, 'Edit', () {}),
        _actionBtn(Icons.person_add_outlined, 'Assign', () {}),
        _actionBtn(Icons.block_rounded, 'Suspend',
            () => _confirmSuspend(context, c),
            color: AdminColors.statusSuspended),
      ])),
    ]);
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

  Future<void> _showAddBlankDialog(BuildContext context) async {
    // Super Admin approval required before adding blank cards.
    final approved =
        await SuperAdminGate.require(context, action: 'add blank cards');
    if (!approved || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AddBlankCardDialog(
        onAdded: _load, // refresh the card list as blanks are added
      ),
    );
  }

  Future<void> _showRegisterDialog(BuildContext context) async {
    // Super Admin approval required before registering a card.
    final approved =
        await SuperAdminGate.require(context, action: 'register a card');
    if (!approved || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => RegisterNfcCardDialog(
        existingCardIds: _cards.map((c) => c.cardId).toSet(),
        onRegistered: (card) {
          // Account + card already persisted to Supabase — refresh from DB.
          _load();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Card ${card.cardId} registered. Owner can now log into the wallet app.'),
            backgroundColor: AdminColors.statusActive,
          ));
        },
      ),
    );
  }

  Future<void> _confirmSuspend(BuildContext context, NfcCardModel c) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Suspend Card',
      message: 'Are you sure you want to suspend card ${c.cardId}?',
      confirmLabel: 'Suspend',
    );
    if (confirmed) {
      setState(() {
        final idx = _cards.indexWhere((x) => x.id == c.id);
        if (idx != -1) _cards[idx] = c.copyWith(status: NfcCardStatus.suspended);
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('card suspended.'),
          backgroundColor: AdminColors.statusSuspended,
        ));
      }
    }
  }
}
