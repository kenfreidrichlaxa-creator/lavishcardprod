import 'package:flutter/foundation.dart';
import '../../../data/models/card_owner_model.dart';
import '../../../data/models/nfc_card_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/staff_model.dart';

/// A single line item in the POS cart.
class CartItem {
  CartItem({required this.service, this.quantity = 1});

  final ServiceModel service;
  int quantity;

  double get lineTotal => service.price * quantity;
}

/// ChangeNotifier that holds the full POS checkout state.
class PosCart extends ChangeNotifier {
  // ── Cart items ────────────────────────────────────────────────────────────
  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  void addService(ServiceModel service) {
    final existing = _items.where((i) => i.service.id == service.id).firstOrNull;
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
    final item = _items.where((i) => i.service.id == serviceId).firstOrNull;
    if (item != null) {
      item.quantity++;
      notifyListeners();
    }
  }

  void decrementQty(String serviceId) {
    final item = _items.where((i) => i.service.id == serviceId).firstOrNull;
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
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  int get totalItems =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  // ── Stylist ───────────────────────────────────────────────────────────────
  StaffModel? _stylist;
  StaffModel? get stylist => _stylist;
  void setStylist(StaffModel s) {
    _stylist = s;
    notifyListeners();
  }

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
  bool get hasStylist => _stylist != null;
  bool get hasCustomer => _customer != null;
  bool get canCheckout => hasItems && hasStylist && hasCustomer;

  // ── Reset ─────────────────────────────────────────────────────────────────
  void clear() {
    _items.clear();
    _stylist = null;
    _customer = null;
    _nfcCard = null;
    notifyListeners();
  }
}
