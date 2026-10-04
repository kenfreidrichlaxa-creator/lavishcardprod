import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/staff_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../data/services/card_owner_repository.dart';
import '../widgets/nfc_tap_dialog.dart';
import '../widgets/pos_cart.dart';
import 'pos_receipt_screen.dart';

/// POS-style service checkout screen.
/// Left panel: service catalogue grid.
/// Right panel: cart, stylist picker, customer, totals.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final PosCart _cart = PosCart();
  ServiceCategory? _selectedCategory;
  String _serviceQuery = '';

  List<ServiceModel> _services = [];
  bool _loadingServices = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final s = await AdminDataRepository.instance.fetchServices();
      if (!mounted) return;
      setState(() {
        _services = s;
        _loadingServices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  List<ServiceModel> get _visibleServices {
    return _services.where((s) {
      if (s.status != ServiceStatus.active) { return false; }
      if (_selectedCategory != null && s.category != _selectedCategory) {
        return false;
      }
      if (_serviceQuery.isNotEmpty &&
          !s.name.toLowerCase().contains(_serviceQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loadingServices
          ? const Center(
              child: CircularProgressIndicator(color: AdminColors.gold))
          : isWide
          ? Row(
              children: [
                Expanded(flex: 6, child: _ServicePanel(
                  cart: _cart,
                  selectedCategory: _selectedCategory,
                  serviceQuery: _serviceQuery,
                  visibleServices: _visibleServices,
                  onCategoryChanged: (c) =>
                      setState(() => _selectedCategory = c),
                  onQueryChanged: (q) =>
                      setState(() => _serviceQuery = q),
                )),
                Container(width: 1, color: AdminColors.divider),
                SizedBox(
                  width: 360,
                  child: _CartPanel(
                    cart: _cart,
                    onCheckout: _handleCheckout,
                    onClear: () => setState(() => _cart.clear()),
                  ),
                ),
              ],
            )
          : _NarrowPosLayout(
              cart: _cart,
              selectedCategory: _selectedCategory,
              serviceQuery: _serviceQuery,
              visibleServices: _visibleServices,
              onCategoryChanged: (c) =>
                  setState(() => _selectedCategory = c),
              onQueryChanged: (q) =>
                  setState(() => _serviceQuery = q),
              onCheckout: _handleCheckout,
              onClear: () => setState(() => _cart.clear()),
            ),
    );
  }

  Future<void> _handleCheckout() async {
    if (!_cart.hasItems) {
      _snack('Add at least one service to continue.', error: true);
      return;
    }
    if (!_cart.hasStylist) {
      _snack('Please select a stylist.', error: true);
      return;
    }

    // NFC tap to identify customer (reads the physical card + resolves owner)
    final result = await showNfcTapDialog(context);
    if (result == null || !mounted) return;

    _cart.setCustomer(result.owner, result.card);

    // Insufficient balance check (server re-checks atomically too)
    if (_cart.customer!.walletBalance < _cart.subtotal) {
      if (!mounted) return;
      _snack(
        'Insufficient wallet balance. '
        'Balance: ${Fmt.peso(_cart.customer!.walletBalance)}, '
        'Required: ${Fmt.peso(_cart.subtotal)}',
        error: true,
      );
      _cart.clearCustomer();
      return;
    }

    // Confirmation dialog
    if (!mounted) return;
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    // Real atomic debit against Supabase.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProcessingDialog(),
    );

    final serviceSummary =
        _cart.items.map((i) => '${i.service.name} x${i.quantity}').join(', ');
    final chargeResult = await CardOwnerRepository.instance.chargeWallet(
      cardUid: result.cardUid,
      amount: _cart.subtotal,
      serviceSummary: serviceSummary,
      staffName: _cart.stylist!.fullName,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // close processing dialog

    if (chargeResult['success'] != true) {
      _snack(
        (chargeResult['error'] as String?) ?? 'Payment failed.',
        error: true,
      );
      _cart.clearCustomer();
      return;
    }

    final balanceBefore =
        (chargeResult['balance_before'] as num?)?.toDouble() ??
            _cart.customer!.walletBalance;
    final balanceAfter =
        (chargeResult['balance_after'] as num?)?.toDouble() ??
            (balanceBefore - _cart.subtotal);

    // Build receipt data from the real result.
    final now = DateTime.now();
    final txId = (chargeResult['wallet_tx_id'] as String?) ??
        'TXN-${now.millisecondsSinceEpoch.toString().substring(6)}';
    final receipt = ReceiptData(
      transactionId: txId,
      owner: _cart.customer!,
      card: _cart.nfcCard!,
      stylist: _cart.stylist!,
      items: List.from(_cart.items),
      total: _cart.subtotal,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      dateTime: now,
    );

    _cart.clear();
    setState(() {});

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PosReceiptScreen(data: receipt),
      ),
    );
  }

  Future<bool> _showConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CheckoutConfirmDialog(cart: _cart),
    );
    return result ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? AdminColors.statusSuspended : AdminColors.statusActive,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ── Service Panel ─────────────────────────────────────────────────────────────

class _ServicePanel extends StatelessWidget {
  const _ServicePanel({
    required this.cart,
    required this.selectedCategory,
    required this.serviceQuery,
    required this.visibleServices,
    required this.onCategoryChanged,
    required this.onQueryChanged,
  });

  final PosCart cart;
  final ServiceCategory? selectedCategory;
  final String serviceQuery;
  final List<ServiceModel> visibleServices;
  final ValueChanged<ServiceCategory?> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [null, ...ServiceCategory.values];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          color: AdminColors.cardBg,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.point_of_sale_rounded,
                    size: 20, color: AdminColors.gold),
                const SizedBox(width: 10),
                Text('Service Checkout',
                    style: theme.textTheme.titleLarge),
              ]),
              const SizedBox(height: 12),

              // Search
              TextField(
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Search services…',
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: categories.map((cat) {
                    final isSelected = selectedCategory == cat;
                    final label = cat == null
                        ? 'All'
                        : cat.label;
                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => onCategoryChanged(cat),
                      showCheckmark: false,
                      selectedColor: AdminColors.gold,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: isSelected
                              ? AdminColors.gold
                              : AdminColors.beigeDeep),
                      labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AdminColors.brownMedium,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Service grid
        Expanded(
          child: visibleServices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_cut_outlined,
                          size: 48, color: AdminColors.beigeDeep),
                      const SizedBox(height: 12),
                      Text('No services found',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                )
              : ListenableBuilder(
                  listenable: cart,
                  builder: (context, _) => GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: visibleServices.length,
                    itemBuilder: (context, i) {
                      final svc = visibleServices[i];
                      final inCart = cart.containsService(svc.id);
                      return _ServiceCard(
                        service: svc,
                        inCart: inCart,
                        onTap: () => inCart
                            ? cart.removeService(svc)
                            : cart.addService(svc),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.inCart,
    required this.onTap,
  });

  final ServiceModel service;
  final bool inCart;
  final VoidCallback onTap;

  Color get _catColor => switch (service.category) {
        ServiceCategory.hair => const Color(0xFF8B6835),
        ServiceCategory.nails => const Color(0xFF7B3F6E),
        ServiceCategory.skin => const Color(0xFF2E6B8A),
        ServiceCategory.beauty => const Color(0xFF4A7C59),
        ServiceCategory.other => AdminColors.brownMedium,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: inCart ? AdminColors.gold : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                inCart ? AdminColors.goldDark : AdminColors.divider,
            width: inCart ? 2 : 1,
          ),
          boxShadow: inCart
              ? [
                  BoxShadow(
                    color: AdminColors.gold.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: inCart
                        ? Colors.white.withValues(alpha: 0.3)
                        : _catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    service.category.label,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: inCart ? Colors.white : _catColor,
                        letterSpacing: 0.3),
                  ),
                ),
                const Spacer(),
                Icon(
                  inCart
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 16,
                  color: inCart
                      ? Colors.white
                      : AdminColors.brownLight,
                ),
              ],
            ),
            const Spacer(),
            Text(
              service.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: inCart ? Colors.white : AdminColors.charcoal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Text(
                Fmt.peso(service.price),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: inCart
                      ? Colors.white
                      : AdminColors.gold,
                ),
              ),
              const Spacer(),
              Text(
                service.durationLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: inCart
                      ? Colors.white.withValues(alpha: 0.8)
                      : AdminColors.brownLight,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Cart Panel ────────────────────────────────────────────────────────────────

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.onCheckout,
    required this.onClear,
  });

  final PosCart cart;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final theme = Theme.of(context);

        return Column(
          children: [
            // Panel header
            Container(
              color: AdminColors.cardBg,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                Text('Order Summary', style: theme.textTheme.titleLarge),
                const Spacer(),
                if (cart.hasItems)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      foregroundColor: AdminColors.statusSuspended,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    child: const Text('Clear All'),
                  ),
              ]),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stylist picker ────────────────────────────────
                    _StylistPicker(cart: cart),
                    const SizedBox(height: 16),

                    // ── Customer from NFC ─────────────────────────────
                    _CustomerSection(cart: cart),
                    const SizedBox(height: 16),

                    // ── Cart items ────────────────────────────────────
                    if (cart.hasItems) ...[
                      Text('Services',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: AdminColors.brownLight,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      ...cart.items.map(
                          (item) => _CartItemTile(item: item, cart: cart)),
                    ] else
                      _EmptyCartPlaceholder(),
                  ],
                ),
              ),
            ),

            // ── Totals + checkout ─────────────────────────────────────
            const Divider(height: 1),
            Container(
              color: AdminColors.cardBg,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Text('${cart.totalItems} item${cart.totalItems != 1 ? 's' : ''}',
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('Total',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(width: 12),
                    Text(Fmt.peso(cart.subtotal),
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: AdminColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 22)),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          cart.hasItems && cart.hasStylist
                              ? onCheckout
                              : null,
                      icon: const Icon(Icons.nfc_rounded, size: 20),
                      label: const Text('Tap Card & Checkout',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminColors.gold,
                        disabledBackgroundColor:
                            AdminColors.beigeDeep,
                        disabledForegroundColor:
                            AdminColors.brownLight,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (!cart.hasItems || !cart.hasStylist) ...[
                    const SizedBox(height: 6),
                    Text(
                      !cart.hasItems
                          ? 'Add services to continue'
                          : 'Select a stylist to continue',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stylist Picker ────────────────────────────────────────────────────────────

class _StylistPicker extends StatelessWidget {
  const _StylistPicker({required this.cart});
  final PosCart cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stylists = AdminMockData.staff
        .where((s) =>
            s.status == StaffStatus.active &&
            (s.position == StaffPosition.stylist ||
                s.position == StaffPosition.seniorStylist))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Stylist *',
          style: theme.textTheme.labelMedium?.copyWith(
              color: AdminColors.brownLight, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      DropdownButtonFormField<StaffModel>(
        initialValue: cart.stylist,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
          hintText: 'Select stylist',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AdminColors.beigeDeep)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AdminColors.beigeDeep)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AdminColors.gold, width: 1.5)),
        ),
        items: stylists
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AdminColors.cream,
                      child: Text(s.initials,
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.gold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.fullName}  ·  ${s.position.label}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AdminColors.charcoal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ))
            .toList(),
        onChanged: (s) {
          if (s != null) cart.setStylist(s);
        },
        style: const TextStyle(
            fontSize: 13, color: AdminColors.charcoal),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
        isExpanded: true,
      ),
    ]);
  }
}

// ── Customer Section ─────────────────────────────────────────────────────────

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.cart});
  final PosCart cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = cart.customer;

    if (customer == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AdminColors.beigeDeep,
              style: BorderStyle.solid),
        ),
        child: Row(children: [
          const Icon(Icons.nfc_rounded,
              size: 20, color: AdminColors.brownLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Customer will be identified\nwhen you tap the card',
              style: theme.textTheme.bodySmall
                  ?.copyWith(height: 1.5),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.statusActiveBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AdminColors.statusActive.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AdminColors.cream,
          child: Text(customer.initials,
              style: const TextStyle(
                  color: AdminColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.fullName,
                    style: theme.textTheme.titleSmall),
                Text('Balance: ${Fmt.peso(customer.walletBalance)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.statusActive,
                        fontWeight: FontWeight.w600)),
              ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 14, color: AdminColors.brownLight),
          onPressed: () => cart.clearCustomer(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Remove customer',
        ),
      ]),
    );
  }
}

// ── Cart Item Tile ────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item, required this.cart});
  final CartItem item;
  final PosCart cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: AdminColors.cream,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.content_cut_rounded,
              size: 14, color: AdminColors.brownMedium),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.service.name, style: theme.textTheme.titleSmall),
              Text(Fmt.peso(item.service.price),
                  style: const TextStyle(
                      fontSize: 11, color: AdminColors.brownLight)),
            ],
          ),
        ),

        // Qty controls
        Row(mainAxisSize: MainAxisSize.min, children: [
          _QtyBtn(
            icon: Icons.remove_rounded,
            onTap: () => cart.decrementQty(item.service.id),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${item.quantity}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          _QtyBtn(
            icon: Icons.add_rounded,
            onTap: () => cart.incrementQty(item.service.id),
          ),
        ]),

        const SizedBox(width: 10),
        Text(Fmt.peso(item.lineTotal),
            style: theme.textTheme.titleSmall
                ?.copyWith(color: AdminColors.gold)),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: AdminColors.cream,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AdminColors.beigeDeep),
        ),
        child: Icon(icon, size: 14, color: AdminColors.brownMedium),
      ),
    );
  }
}

class _EmptyCartPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AdminColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AdminColors.beigeDeep,
            style: BorderStyle.solid),
      ),
      child: Column(children: [
        Icon(Icons.shopping_basket_outlined,
            size: 36, color: AdminColors.beigeDeep),
        const SizedBox(height: 10),
        const Text('No services added',
            style: TextStyle(
                color: AdminColors.brownLight,
                fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Tap a service from the left panel',
            style: TextStyle(
                color: AdminColors.brownLight,
                fontSize: 11)),
      ]),
    );
  }
}

// ── Narrow layout (tablet/phone) ─────────────────────────────────────────────

class _NarrowPosLayout extends StatefulWidget {
  const _NarrowPosLayout({
    required this.cart,
    required this.selectedCategory,
    required this.serviceQuery,
    required this.visibleServices,
    required this.onCategoryChanged,
    required this.onQueryChanged,
    required this.onCheckout,
    required this.onClear,
  });

  final PosCart cart;
  final ServiceCategory? selectedCategory;
  final String serviceQuery;
  final List<ServiceModel> visibleServices;
  final ValueChanged<ServiceCategory?> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  @override
  State<_NarrowPosLayout> createState() => _NarrowPosLayoutState();
}

class _NarrowPosLayoutState extends State<_NarrowPosLayout>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabs,
        indicatorColor: AdminColors.gold,
        labelColor: AdminColors.gold,
        unselectedLabelColor: AdminColors.brownLight,
        tabs: [
          const Tab(text: 'Services'),
          ListenableBuilder(
            listenable: widget.cart,
            builder: (context, child) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cart'),
                  if (widget.cart.totalItems > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminColors.gold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${widget.cart.totalItems}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _ServicePanel(
              cart: widget.cart,
              selectedCategory: widget.selectedCategory,
              serviceQuery: widget.serviceQuery,
              visibleServices: widget.visibleServices,
              onCategoryChanged: widget.onCategoryChanged,
              onQueryChanged: widget.onQueryChanged,
            ),
            _CartPanel(
              cart: widget.cart,
              onCheckout: widget.onCheckout,
              onClear: widget.onClear,
            ),
          ],
        ),
      ),
    ]);
  }
}

// ── Checkout confirm dialog ───────────────────────────────────────────────────

class _CheckoutConfirmDialog extends StatelessWidget {
  const _CheckoutConfirmDialog({required this.cart});
  final PosCart cart;

  @override
  Widget build(BuildContext context) {
    final insufficient =
        (cart.customer?.walletBalance ?? 0) < cart.subtotal;

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary rows
          _ConfirmRow('Customer',
              cart.customer?.fullName ?? '—'),
          _ConfirmRow('Card',
              cart.nfcCard?.cardId ?? '—', mono: true),
          _ConfirmRow('Stylist',
              cart.stylist?.fullName ?? '—'),
          _ConfirmRow(
              'Services', '${cart.totalItems} service(s)'),
          const Divider(height: 20),
          _ConfirmRow('Total', Fmt.peso(cart.subtotal),
              bold: true, valueColor: AdminColors.gold),
          _ConfirmRow('Wallet Balance',
              Fmt.peso(cart.customer?.walletBalance ?? 0),
              valueColor: insufficient
                  ? AdminColors.statusSuspended
                  : AdminColors.statusActive),
          _ConfirmRow(
            'Balance After',
            Fmt.peso((cart.customer?.walletBalance ?? 0) -
                cart.subtotal),
            bold: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm & Charge'),
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow(this.label, this.value,
      {this.mono = false, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool mono;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AdminColors.brownLight)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color:
                      valueColor ?? AdminColors.charcoal,
                  fontFamily: mono ? 'monospace' : null)),
        ),
      ]),
    );
  }
}

// ── Processing dialog ─────────────────────────────────────────────────────────

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AdminColors.sidebarBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AdminColors.gold, strokeWidth: 2.5),
            SizedBox(height: 20),
            Text('Processing Payment…',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Please wait',
                style: TextStyle(
                    color: AdminColors.sidebarTextMuted,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
