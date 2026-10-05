import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/staff_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../data/services/card_owner_repository.dart';
import '../../../data/services/category_repository.dart';
import '../../../data/services/staff_repository.dart';
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

  // null = show all categories
  String? _selectedCategoryId;
  String _serviceQuery = '';

  List<ServiceModel> _services = [];
  List<StaffModel> _staff = [];
  List<PrimaryCategory> _categories = [];
  bool _loadingServices = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        AdminDataRepository.instance.fetchServices(),
        StaffRepository.instance.listStaff(activeOnly: true),
        CategoryRepository.instance.listPrimaryCategories(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _services   = results[0] as List<ServiceModel>;
        _staff      = results[1] as List<StaffModel>;
        _categories = results[2] as List<PrimaryCategory>;
        _loadingServices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  List<ServiceModel> get _visibleServices {
    return _services.where((s) {
      if (s.status != ServiceStatus.active) return false;
      // Filter by dynamic primary category
      if (_selectedCategoryId != null) {
        if (s.primaryCategoryId != null) {
          if (s.primaryCategoryId != _selectedCategoryId) return false;
        } else {
          // Fall back: match by category name
          final cat = _categories
              .where((c) => c.id == _selectedCategoryId)
              .firstOrNull;
          if (cat == null) return false;
          if (!s.category.label
              .toLowerCase()
              .contains(cat.name.toLowerCase())) return false;
        }
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
                  selectedCategoryId: _selectedCategoryId,
                  categories: _categories,
                  serviceQuery: _serviceQuery,
                  visibleServices: _visibleServices,
                  onCategoryChanged: (id) =>
                      setState(() => _selectedCategoryId = id),
                  onQueryChanged: (q) =>
                      setState(() => _serviceQuery = q),
                )),
                Container(width: 1, color: AdminColors.divider),
                SizedBox(
                  width: 360,
                  child: _CartPanel(
                    cart: _cart,
                    staff: _staff,
                    onCheckout: _handleCheckout,
                    onClear: () => setState(() => _cart.clear()),
                  ),
                ),
              ],
            )
          : _NarrowPosLayout(
              cart: _cart,
              selectedCategoryId: _selectedCategoryId,
              categories: _categories,
              serviceQuery: _serviceQuery,
              visibleServices: _visibleServices,
              onCategoryChanged: (id) =>
                  setState(() => _selectedCategoryId = id),
              onQueryChanged: (q) =>
                  setState(() => _serviceQuery = q),
              staff: _staff,
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
      _snack('Please select at least one stylist.', error: true);
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
      staffName: _cart.stylistNames,
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
    // Stamp the charged unit price on each item before building the receipt
    for (final item in _cart.items) {
      item.setChargedPrice(item.effectivePrice(_cart.mode));
    }

    final receipt = ReceiptData(
      transactionId: txId,
      owner: _cart.customer!,
      card: _cart.nfcCard!,
      stylists: _cart.selectedStylists,
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
    required this.selectedCategoryId,
    required this.categories,
    required this.serviceQuery,
    required this.visibleServices,
    required this.onCategoryChanged,
    required this.onQueryChanged,
  });

  final PosCart cart;
  final String? selectedCategoryId;
  final List<PrimaryCategory> categories;
  final String serviceQuery;
  final List<ServiceModel> visibleServices;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Regular / Discounted mode toggle
              ListenableBuilder(
                listenable: cart,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    color: AdminColors.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminColors.beigeDeep),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ModeTab(
                        label: 'Regular',
                        icon: Icons.price_check_rounded,
                        selected: cart.mode == PosMode.regular,
                        onTap: () => cart.setMode(PosMode.regular),
                      ),
                      _ModeTab(
                        label: 'Discounted',
                        icon: Icons.local_offer_rounded,
                        selected: cart.mode == PosMode.discounted,
                        onTap: () => cart.setMode(PosMode.discounted),
                        selectedColor: const Color(0xFF7B3F6E),
                      ),
                    ],
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    // "All" chip
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedCategoryId == null,
                      onSelected: (_) => onCategoryChanged(null),
                      showCheckmark: false,
                      selectedColor: AdminColors.gold,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: selectedCategoryId == null
                              ? AdminColors.gold
                              : AdminColors.beigeDeep),
                      labelStyle: TextStyle(
                          color: selectedCategoryId == null
                              ? Colors.white
                              : AdminColors.brownMedium,
                          fontSize: 12,
                          fontWeight: selectedCategoryId == null
                              ? FontWeight.w600
                              : FontWeight.w400),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                    ),
                    // Dynamic primary category chips
                    ...categories.map((cat) {
                      final isSelected = selectedCategoryId == cat.id;
                      return FilterChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => onCategoryChanged(
                            isSelected ? null : cat.id),
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
                    }),
                  ],
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
                        mode: cart.mode,
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
    required this.mode,
    required this.onTap,
  });

  final ServiceModel service;
  final bool inCart;
  final PosMode mode;
  final VoidCallback onTap;

  Color get _catColor {
    // Use a consistent color based on the first letter of the category name
    final name = (service.primaryCategoryName ?? service.category.label).toLowerCase();
    if (name.contains('nail')) return const Color(0xFF7B3F6E);
    if (name.contains('hair')) return const Color(0xFF8B6835);
    if (name.contains('skin') || name.contains('facial')) return const Color(0xFF2E6B8A);
    if (name.contains('massage') || name.contains('beauty')) return const Color(0xFF4A7C59);
    if (name.contains('combo') || name.contains('promo')) return const Color(0xFF6B4C9A);
    return AdminColors.brownMedium;
  }

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
                    service.categoryLabel,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fmt.peso(service.effectivePrice(
                          useDiscount: mode == PosMode.discounted)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: inCart ? Colors.white : AdminColors.gold,
                      ),
                    ),
                    // Show original price as strikethrough if in discounted mode
                    if (mode == PosMode.discounted && service.hasDiscount)
                      Text(
                        Fmt.peso(service.price),
                        style: TextStyle(
                          fontSize: 10,
                          color: inCart
                              ? Colors.white.withValues(alpha: 0.7)
                              : AdminColors.brownLight,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ),
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
    required this.staff,
    required this.onCheckout,
    required this.onClear,
  });

  final PosCart cart;
  final List<StaffModel> staff;
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
                    _StylistPicker(cart: cart, staff: staff),
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
                          : 'Select at least one stylist',
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

// ── Multi-Stylist Picker ──────────────────────────────────────────────────────

class _StylistPicker extends StatelessWidget {
  const _StylistPicker({required this.cart, required this.staff});
  final PosCart cart;
  final List<StaffModel> staff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: cart,
      builder: (_, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: label + count stepper ──────────────────────
            Row(children: [
              Text('Stylist(s) *',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: AdminColors.brownLight, letterSpacing: 0.5)),
              const Spacer(),
              // Stepper
              Container(
                decoration: BoxDecoration(
                  color: AdminColors.cream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.beigeDeep),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _StepBtn(
                    icon: Icons.remove_rounded,
                    onTap: cart.stylistCount > 1
                        ? () => cart.setStylistCount(cart.stylistCount - 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${cart.stylistCount}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StepBtn(
                    icon: Icons.add_rounded,
                    onTap: cart.stylistCount < 5
                        ? () => cart.setStylistCount(cart.stylistCount + 1)
                        : null,
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 8),

            // ── One dropdown per slot ───────────────────────────────────
            if (staff.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.cream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.beigeDeep),
                ),
                child: const Row(children: [
                  Icon(Icons.badge_outlined,
                      size: 16, color: AdminColors.brownLight),
                  SizedBox(width: 8),
                  Text('No stylists available',
                      style: TextStyle(
                          fontSize: 12, color: AdminColors.brownLight)),
                ]),
              )
            else
              ...List.generate(cart.stylistCount, (i) {
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: i < cart.stylistCount - 1 ? 8 : 0),
                  child: DropdownButtonFormField<StaffModel?>(
                    value: staff.any((s) => s.id == cart.stylists[i]?.id)
                        ? cart.stylists[i]
                        : null,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.badge_outlined, size: 18),
                      hintText: 'Stylist ${i + 1}',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AdminColors.beigeDeep)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AdminColors.beigeDeep)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AdminColors.gold, width: 1.5)),
                    ),
                    items: [
                      const DropdownMenuItem<StaffModel?>(
                        value: null,
                        child: Text('— None —',
                            style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.brownMedium)),
                      ),
                      ...staff.map((s) => DropdownMenuItem<StaffModel?>(
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
                                  s.positionLabel.isEmpty
                                      ? s.fullName
                                      : '${s.fullName}  ·  ${s.positionLabel}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AdminColors.charcoal),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          )),
                    ],
                    onChanged: (s) => cart.setStylistAt(i, s),
                    style: const TextStyle(
                        fontSize: 13, color: AdminColors.charcoal),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    isExpanded: true,
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null
                ? AdminColors.brownMedium
                : AdminColors.beigeDeep),
      ),
    );
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
    final unitPrice = item.effectivePrice(cart.mode);
    final total = item.lineTotal(cart.mode);
    final isDiscounted =
        cart.mode == PosMode.discounted && item.service.hasDiscount;

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
              Row(children: [
                Text(Fmt.peso(unitPrice),
                    style: const TextStyle(
                        fontSize: 11, color: AdminColors.brownLight)),
                if (isDiscounted) ...[
                  const SizedBox(width: 4),
                  Text(Fmt.peso(item.service.price),
                      style: const TextStyle(
                          fontSize: 10,
                          color: AdminColors.brownLight,
                          decoration: TextDecoration.lineThrough)),
                ],
              ]),
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
        Text(Fmt.peso(total),
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
    required this.selectedCategoryId,
    required this.categories,
    required this.serviceQuery,
    required this.visibleServices,
    required this.onCategoryChanged,
    required this.onQueryChanged,
    required this.staff,
    required this.onCheckout,
    required this.onClear,
  });

  final PosCart cart;
  final String? selectedCategoryId;
  final List<PrimaryCategory> categories;
  final String serviceQuery;
  final List<ServiceModel> visibleServices;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;
  final List<StaffModel> staff;
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
              selectedCategoryId: widget.selectedCategoryId,
              categories: widget.categories,
              serviceQuery: widget.serviceQuery,
              visibleServices: widget.visibleServices,
              onCategoryChanged: widget.onCategoryChanged,
              onQueryChanged: widget.onQueryChanged,
            ),
            _CartPanel(
              cart: widget.cart,
              staff: widget.staff,
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
          // Mode badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cart.mode == PosMode.discounted
                  ? const Color(0xFF7B3F6E).withValues(alpha: 0.12)
                  : AdminColors.cream,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                cart.mode == PosMode.discounted
                    ? Icons.local_offer_rounded
                    : Icons.price_check_rounded,
                size: 12,
                color: cart.mode == PosMode.discounted
                    ? const Color(0xFF7B3F6E)
                    : AdminColors.brownMedium,
              ),
              const SizedBox(width: 4),
              Text(
                cart.mode == PosMode.discounted
                    ? 'Discounted Price'
                    : 'Regular Price',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cart.mode == PosMode.discounted
                      ? const Color(0xFF7B3F6E)
                      : AdminColors.brownMedium,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _ConfirmRow('Customer', cart.customer?.fullName ?? '—'),
          _ConfirmRow('Card', cart.nfcCard?.cardId ?? '—', mono: true),
          _ConfirmRow('Stylist', cart.stylistNames),
          _ConfirmRow('Services', '${cart.totalItems} service(s)'),
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

// ── Mode Tab (Regular / Discounted) ──────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor = AdminColors.gold,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : AdminColors.brownMedium),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color:
                    selected ? Colors.white : AdminColors.brownMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
