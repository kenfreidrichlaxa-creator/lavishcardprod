import 'package:flutter/foundation.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/staff_model.dart';

/// Whether the POS is charging regular or discounted prices.
enum PosMode { regular, discounted }

/// A single line item in the POS cart.
class CartItem {
  CartItem({required this.service, this.quantity = 1});

  final ServiceModel service;
  int quantity;

  /// Price used for this line item given the current POS mode.
  double effectivePrice(PosMode mode) =>
      service.effectivePrice(useDiscount: mode == PosMode.discounted);

  double lineTotal(PosMode mode) => effectivePrice(mode) * quantity;

  /// The actual unit price charged — set when the receipt is generated.
  /// Falls back to regular price so the receipt screen can call lineTotal()
  /// without needing a mode.
  double get chargedUnitPrice => _chargedUnitPrice ?? service.price;
  double? _chargedUnitPrice;

  void setChargedPrice(double price) => _chargedUnitPrice = price;

  /// Convenience for receipt screen — uses the charged price.
  double get lineTotalCharged => chargedUnitPrice * quantity;
}

/// ChangeNotifier that holds the full POS checkout state.
class PosCart extends ChangeNotifier {
  // ── Mode (Regular / Discounted) ───────────────────────────────────────────
  PosMode _mode = PosMode.regular;
  PosMode get mode => _mode;

  void setMode(PosMode m) {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
  }

  // ── Cart items ────────────────────────────────────────────────────────────
  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  void addService(ServiceModel service) {
    final existing =
        _items.where((i) => i.service.id == service.id).firstOrNull;
    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(CartItem(service: service));
    }
    notifyListeners();
  }

  void removeService(ServiceModel service) {
    _items.removeWhere((i) => i.service.id == service.id);
    notifyListeners();
  }

  void incrementQty(String serviceId) {
    final item =
        _items.where((i) => i.service.id == serviceId).firstOrNull;
    if (item != null) {
      item.quantity++;
      notifyListeners();
    }
  }

  void decrementQty(String serviceId) {
    final item =
        _items.where((i) => i.service.id == serviceId).firstOrNull;
    if (item != null) {
      if (item.quantity <= 1) {
        _items.removeWhere((i) => i.service.id == serviceId);
      } else {
        item.quantity--;
      }
      notifyListeners();
    }
  }

  bool containsService(String serviceId) =>
      _items.any((i) => i.service.id == serviceId);

  // ── Totals ────────────────────────────────────────────────────────────────
  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal(_mode));
  int get totalItems =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  // ── Stylists (multi) ─────────────────────────────────────────────────────
  int _stylistCount = 1;
  final List<StaffModel?> _stylists = [null]; // starts with 1 slot

  int get stylistCount => _stylistCount;
  List<StaffModel?> get stylists => List.unmodifiable(_stylists);

  /// The first selected stylist (for backward-compat with hasStylist check).
  StaffModel? get stylist => _stylists.isNotEmpty ? _stylists.first : null;

  /// All selected (non-null) stylists.
  List<StaffModel> get selectedStylists =>
      _stylists.whereType<StaffModel>().toList();

  /// Joined names for display / transaction recording.
  String get stylistNames {
    final names = selectedStylists.map((s) => s.fullName).toList();
    return names.isEmpty ? '—' : names.join(', ');
  }

  /// True when at least one stylist slot is filled.
  bool get hasStylist => selectedStylists.isNotEmpty;

  /// Set the number of stylist slots (1–5).
  void setStylistCount(int count) {
    final c = count.clamp(1, 5);
    if (c == _stylistCount) return;
    _stylistCount = c;
    // Grow or shrink the list
    while (_stylists.length < c) _stylists.add(null);
    while (_stylists.length > c) _stylists.removeLast();
    notifyListeners();
  }

  /// Set the stylist at a specific slot index.
  void setStylistAt(int index, StaffModel? staff) {
    if (index < 0 || index >= _stylists.length) return;
    _stylists[index] = staff;
    notifyListeners();
  }

  // kept for backward compat — sets slot 0
  void setStylist(StaffModel s) => setStylistAt(0, s);

  // ── Customer (identified via NFC tap) ────────────────────────────────────
  CardOwnerModel? _customer;
  NfcCardModel? _nfcCard;
  CardOwnerModel? get customer => _customer;
  NfcCardModel? get nfcCard => _nfcCard;

  void setCustomer(CardOwnerModel owner, NfcCardModel card) {
    _customer = owner;
    _nfcCard = card;
    notifyListeners();
  }

  void clearCustomer() {
    _customer = null;
    _nfcCard = null;
    notifyListeners();
  }

  // ── Validation ────────────────────────────────────────────────────────────
  bool get hasItems => _items.isNotEmpty;
  bool get hasCustomer => _customer != null;
  bool get canCheckout => hasItems && hasStylist && hasCustomer;

  // ── Reset ─────────────────────────────────────────────────────────────────
  void clear() {
    _items.clear();
    _stylistCount = 1;
    _stylists
      ..clear()
      ..add(null);
    _customer = null;
    _nfcCard  = null;
    _mode     = PosMode.regular;
    notifyListeners();
  }
}
