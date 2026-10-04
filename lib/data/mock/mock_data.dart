import '../models/card_owner_model.dart';
import '../models/nfc_card_model.dart';
import '../models/service_model.dart';
import '../models/staff_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

abstract final class AdminMockData {
  // ── Services ────────────────────────────────────────────────────────────
  static final List<ServiceModel> services = [
    const ServiceModel(
      id: 's1', serviceId: 'SRV-001', name: 'Haircut',
      category: ServiceCategory.hair, price: 500, durationMinutes: 45,
      status: ServiceStatus.active,
      description: 'Classic haircut and styling.',
    ),
    const ServiceModel(
      id: 's2', serviceId: 'SRV-002', name: 'Hair Color',
      category: ServiceCategory.hair, price: 1800, durationMinutes: 120,
      status: ServiceStatus.active,
      description: 'Full hair coloring service.',
    ),
    const ServiceModel(
      id: 's3', serviceId: 'SRV-003', name: 'Hair Treatment',
      category: ServiceCategory.hair, price: 800, durationMinutes: 60,
      status: ServiceStatus.active,
      description: 'Deep conditioning hair treatment.',
    ),
    const ServiceModel(
      id: 's4', serviceId: 'SRV-004', name: 'Manicure',
      category: ServiceCategory.nails, price: 350, durationMinutes: 40,
      status: ServiceStatus.active,
    ),
    const ServiceModel(
      id: 's5', serviceId: 'SRV-005', name: 'Pedicure',
      category: ServiceCategory.nails, price: 400, durationMinutes: 50,
      status: ServiceStatus.active,
    ),
    const ServiceModel(
      id: 's6', serviceId: 'SRV-006', name: 'Facial',
      category: ServiceCategory.skin, price: 1200, durationMinutes: 90,
      status: ServiceStatus.active,
    ),
    const ServiceModel(
      id: 's7', serviceId: 'SRV-007', name: 'Full Body Massage',
      category: ServiceCategory.beauty, price: 1500, durationMinutes: 90,
      status: ServiceStatus.active,
    ),
    const ServiceModel(
      id: 's8', serviceId: 'SRV-008', name: 'Eyebrow Threading',
      category: ServiceCategory.beauty, price: 200, durationMinutes: 20,
      status: ServiceStatus.inactive,
    ),
  ];

  // ── Staff ────────────────────────────────────────────────────────────────
  static final List<StaffModel> staff = [
    StaffModel(
      id: 'st1', staffId: 'STF-001', fullName: 'Maria Santos',
      phone: '09171234567', email: 'maria.santos@lavishprima.com',
      position: StaffPosition.seniorStylist, status: StaffStatus.active,
      joinedDate: DateTime(2024, 3, 10),
      serviceCount: 12,
      services: ['Haircut', 'Hair Color', 'Hair Treatment', 'Hair Styling'],
    ),
    StaffModel(
      id: 'st2', staffId: 'STF-002', fullName: 'Carlo Reyes',
      phone: '09182345678', email: 'carlo.reyes@lavishprima.com',
      position: StaffPosition.stylist, status: StaffStatus.active,
      joinedDate: DateTime(2024, 6, 15),
      serviceCount: 8,
      services: ['Haircut', 'Hair Styling'],
    ),
    StaffModel(
      id: 'st3', staffId: 'STF-003', fullName: 'Angela Cruz',
      phone: '09193456789', email: 'angela.cruz@lavishprima.com',
      position: StaffPosition.stylist, status: StaffStatus.active,
      joinedDate: DateTime(2025, 1, 5),
      serviceCount: 10,
      services: ['Manicure', 'Pedicure', 'Eyebrow Threading'],
    ),
    StaffModel(
      id: 'st4', staffId: 'STF-004', fullName: 'Reyna Lim',
      phone: '09204567890', email: 'reyna.lim@lavishprima.com',
      position: StaffPosition.seniorStylist, status: StaffStatus.active,
      joinedDate: DateTime(2023, 11, 20),
      serviceCount: 15,
      services: ['Facial', 'Full Body Massage', 'Hair Treatment'],
    ),
    StaffModel(
      id: 'st5', staffId: 'STF-005', fullName: 'Dan Flores',
      phone: '09215678901', email: 'dan.flores@lavishprima.com',
      position: StaffPosition.manager, status: StaffStatus.active,
      joinedDate: DateTime(2023, 8, 1),
      serviceCount: 5,
      services: [],
    ),
  ];

  // ── Card Owners ──────────────────────────────────────────────────────────
  static final List<CardOwnerModel> cardOwners = [
    CardOwnerModel(
      id: 'co1', customerId: 'CUS-00124', fullName: 'Juan Dela Cruz',
      phone: '09171112222', email: 'juan.delacruz@email.com',
      address: '123 Rizal St, Taytay, Rizal',
      dateOfBirth: DateTime(1990, 4, 15),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 1, 10),
      linkedCardId: 'LP-839274615', walletBalance: 1500,
    ),
    CardOwnerModel(
      id: 'co2', customerId: 'CUS-00125', fullName: 'Maria Garcia',
      phone: '09182223333', email: 'maria.garcia@email.com',
      address: '45 Mabini Ave, Antipolo, Rizal',
      dateOfBirth: DateTime(1995, 7, 22),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 1, 18),
      linkedCardId: 'LP-918273645', walletBalance: 3200,
    ),
    CardOwnerModel(
      id: 'co3', customerId: 'CUS-00126', fullName: 'Pedro Santos',
      phone: '09193334444', email: 'pedro.santos@email.com',
      address: '78 Bonifacio St, Pasig City',
      dateOfBirth: DateTime(1988, 12, 3),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 2, 5),
      linkedCardId: 'LP-736482910', walletBalance: 800,
    ),
    CardOwnerModel(
      id: 'co4', customerId: 'CUS-00127', fullName: 'Ana Reyes',
      phone: '09204445555', email: 'ana.reyes@email.com',
      address: '22 Luna St, BGC, Taguig',
      dateOfBirth: DateTime(1993, 3, 11),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 2, 20),
      linkedCardId: 'LP-628374591', walletBalance: 5500,
    ),
    CardOwnerModel(
      id: 'co5', customerId: 'CUS-00128', fullName: 'Roberto Cruz',
      phone: '09215556666', email: 'roberto.cruz@email.com',
      address: '90 Aguinaldo St, Marikina City',
      dateOfBirth: DateTime(1985, 9, 28),
      status: CardOwnerStatus.inactive,
      registeredDate: DateTime(2026, 3, 1),
      linkedCardId: 'LP-517263849', walletBalance: 200,
    ),
    CardOwnerModel(
      id: 'co6', customerId: 'CUS-00129', fullName: 'Sofia Mendoza',
      phone: '09226667777', email: 'sofia.mendoza@email.com',
      address: '11 Quezon Ave, Quezon City',
      dateOfBirth: DateTime(1998, 6, 5),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 3, 15),
      linkedCardId: 'LP-406152738', walletBalance: 2800,
    ),
    CardOwnerModel(
      id: 'co7', customerId: 'CUS-00130', fullName: 'Miguel Torres',
      phone: '09237778888', email: 'miguel.torres@email.com',
      address: '55 Legaspi St, Makati City',
      dateOfBirth: DateTime(1991, 11, 17),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 4, 2),
      linkedCardId: 'LP-395041627', walletBalance: 1100,
    ),
    CardOwnerModel(
      id: 'co8', customerId: 'CUS-00131', fullName: 'Isabella Lim',
      phone: '09248889999', email: 'isabella.lim@email.com',
      address: '33 Burgos St, Pasay City',
      dateOfBirth: DateTime(2000, 2, 14),
      status: CardOwnerStatus.suspended,
      registeredDate: DateTime(2026, 4, 20),
      linkedCardId: 'LP-284930516', walletBalance: 0,
    ),
    CardOwnerModel(
      id: 'co9', customerId: 'CUS-00132', fullName: 'Carlos Bautista',
      phone: '09259990000', email: 'carlos.bautista@email.com',
      address: '66 Osmeña Blvd, Manila',
      dateOfBirth: DateTime(1987, 8, 30),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 5, 10),
      walletBalance: 0,
    ),
    CardOwnerModel(
      id: 'co10', customerId: 'CUS-00133', fullName: 'Camille Aquino',
      phone: '09260001111', email: 'camille.aquino@email.com',
      address: '88 Roxas Blvd, Parañaque',
      dateOfBirth: DateTime(1996, 10, 7),
      status: CardOwnerStatus.active,
      registeredDate: DateTime(2026, 5, 25),
      linkedCardId: 'LP-173829405', walletBalance: 4000,
    ),
  ];

  // ── Cards ────────────────────────────────────────────────────────────
  static final List<NfcCardModel> nfcCards = [
    NfcCardModel(
      id: 'nc1', cardId: 'LP-839274615', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 1, 10),
      ownerId: 'co1', ownerName: 'Juan Dela Cruz',
      lastUsed: DateTime(2026, 9, 9, 14, 15),
    ),
    NfcCardModel(
      id: 'nc2', cardId: 'LP-918273645', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 1, 18),
      ownerId: 'co2', ownerName: 'Maria Garcia',
      lastUsed: DateTime(2026, 9, 8, 10, 30),
    ),
    NfcCardModel(
      id: 'nc3', cardId: 'LP-736482910', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 2, 5),
      ownerId: 'co3', ownerName: 'Pedro Santos',
      lastUsed: DateTime(2026, 9, 7, 16, 0),
    ),
    NfcCardModel(
      id: 'nc4', cardId: 'LP-628374591', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 2, 20),
      ownerId: 'co4', ownerName: 'Ana Reyes',
      lastUsed: DateTime(2026, 9, 9, 11, 0),
    ),
    NfcCardModel(
      id: 'nc5', cardId: 'LP-517263849', status: NfcCardStatus.suspended,
      registeredDate: DateTime(2026, 3, 1),
      ownerId: 'co5', ownerName: 'Roberto Cruz',
      lastUsed: DateTime(2026, 8, 20),
    ),
    NfcCardModel(
      id: 'nc6', cardId: 'LP-406152738', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 3, 15),
      ownerId: 'co6', ownerName: 'Sofia Mendoza',
      lastUsed: DateTime(2026, 9, 6, 9, 45),
    ),
    NfcCardModel(
      id: 'nc7', cardId: 'LP-395041627', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 4, 2),
      ownerId: 'co7', ownerName: 'Miguel Torres',
      lastUsed: DateTime(2026, 9, 5, 13, 20),
    ),
    NfcCardModel(
      id: 'nc8', cardId: 'LP-284930516', status: NfcCardStatus.suspended,
      registeredDate: DateTime(2026, 4, 20),
      ownerId: 'co8', ownerName: 'Isabella Lim',
      lastUsed: DateTime(2026, 7, 10),
    ),
    NfcCardModel(
      id: 'nc9', cardId: 'LP-173829405', status: NfcCardStatus.active,
      registeredDate: DateTime(2026, 5, 25),
      ownerId: 'co10', ownerName: 'Camille Aquino',
      lastUsed: DateTime(2026, 9, 9, 8, 30),
    ),
    NfcCardModel(
      id: 'nc10', cardId: 'LP-062718294', status: NfcCardStatus.available,
      registeredDate: DateTime(2026, 9, 1),
    ),
  ];

  // ── Transactions ─────────────────────────────────────────────────────────
  static final List<AdminTransactionModel> transactions = [
    AdminTransactionModel(
      id: 't1', transactionId: 'TXN-001245',
      ownerId: 'co1', ownerName: 'Juan Dela Cruz',
      nfcCardId: 'LP-839274615',
      staffId: 'st1', staffName: 'Maria Santos',
      serviceId: 's1', serviceName: 'Haircut',
      amount: 500, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 9, 14, 15),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't2', transactionId: 'TXN-001244',
      ownerId: 'co4', ownerName: 'Ana Reyes',
      nfcCardId: 'LP-628374591',
      staffId: 'st4', staffName: 'Reyna Lim',
      serviceId: 's7', serviceName: 'Full Body Massage',
      amount: 1500, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 9, 11, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't3', transactionId: 'TXN-001243',
      ownerId: 'co9', ownerName: 'Camille Aquino',
      nfcCardId: 'LP-173829405',
      staffId: 'st1', staffName: 'Maria Santos',
      serviceId: 's2', serviceName: 'Hair Color',
      amount: 1800, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 9, 8, 30),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't4', transactionId: 'TXN-001242',
      ownerId: 'co2', ownerName: 'Maria Garcia',
      nfcCardId: 'LP-918273645',
      staffId: 'st3', staffName: 'Angela Cruz',
      serviceId: 's4', serviceName: 'Manicure',
      amount: 350, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 8, 10, 30),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't5', transactionId: 'TXN-001241',
      ownerId: 'co6', ownerName: 'Sofia Mendoza',
      nfcCardId: 'LP-406152738',
      staffId: 'st4', staffName: 'Reyna Lim',
      serviceId: 's6', serviceName: 'Facial',
      amount: 1200, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 6, 9, 45),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't6', transactionId: 'TXN-001240',
      ownerId: 'co7', ownerName: 'Miguel Torres',
      nfcCardId: 'LP-395041627',
      staffId: 'st2', staffName: 'Carlo Reyes',
      serviceId: 's1', serviceName: 'Haircut',
      amount: 500, paymentMethod: PaymentMethod.cash,
      dateTime: DateTime(2026, 9, 5, 13, 20),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't7', transactionId: 'TXN-001239',
      ownerId: 'co3', ownerName: 'Pedro Santos',
      nfcCardId: 'LP-736482910',
      staffId: 'st1', staffName: 'Maria Santos',
      serviceId: 's3', serviceName: 'Hair Treatment',
      amount: 800, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 7, 16, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't8', transactionId: 'TXN-001238',
      ownerId: 'co4', ownerName: 'Ana Reyes',
      nfcCardId: 'LP-628374591',
      staffId: 'st3', staffName: 'Angela Cruz',
      serviceId: 's5', serviceName: 'Pedicure',
      amount: 400, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 4, 15, 10),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't9', transactionId: 'TXN-001237',
      ownerId: 'co2', ownerName: 'Maria Garcia',
      nfcCardId: 'LP-918273645',
      staffId: 'st4', staffName: 'Reyna Lim',
      serviceId: 's7', serviceName: 'Full Body Massage',
      amount: 1500, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 3, 14, 0),
      status: TransactionStatus.pending,
    ),
    AdminTransactionModel(
      id: 't10', transactionId: 'TXN-001236',
      ownerId: 'co6', ownerName: 'Sofia Mendoza',
      nfcCardId: 'LP-406152738',
      staffId: 'st2', staffName: 'Carlo Reyes',
      serviceId: 's1', serviceName: 'Haircut',
      amount: 500, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 9, 2, 10, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't11', transactionId: 'TXN-001235',
      ownerId: 'co1', ownerName: 'Juan Dela Cruz',
      nfcCardId: 'LP-839274615',
      staffId: 'st1', staffName: 'Maria Santos',
      serviceId: 's2', serviceName: 'Hair Color',
      amount: 1800, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 30, 13, 30),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't12', transactionId: 'TXN-001234',
      ownerId: 'co9', ownerName: 'Camille Aquino',
      nfcCardId: 'LP-173829405',
      staffId: 'st3', staffName: 'Angela Cruz',
      serviceId: 's4', serviceName: 'Manicure',
      amount: 350, paymentMethod: PaymentMethod.cash,
      dateTime: DateTime(2026, 8, 28, 11, 0),
      status: TransactionStatus.cancelled,
    ),
    AdminTransactionModel(
      id: 't13', transactionId: 'TXN-001233',
      ownerId: 'co3', ownerName: 'Pedro Santos',
      nfcCardId: 'LP-736482910',
      staffId: 'st4', staffName: 'Reyna Lim',
      serviceId: 's6', serviceName: 'Facial',
      amount: 1200, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 25, 9, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't14', transactionId: 'TXN-001232',
      ownerId: 'co7', ownerName: 'Miguel Torres',
      nfcCardId: 'LP-395041627',
      staffId: 'st1', staffName: 'Maria Santos',
      serviceId: 's3', serviceName: 'Hair Treatment',
      amount: 800, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 22, 15, 45),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't15', transactionId: 'TXN-001231',
      ownerId: 'co4', ownerName: 'Ana Reyes',
      nfcCardId: 'LP-628374591',
      staffId: 'st2', staffName: 'Carlo Reyes',
      serviceId: 's1', serviceName: 'Haircut',
      amount: 500, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 20, 10, 30),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't16', transactionId: 'TXN-001230',
      ownerId: 'co2', ownerName: 'Maria Garcia',
      nfcCardId: 'LP-918273645',
      staffId: 'st1', staffName: 'Maria Santos',
      serviceId: 's2', serviceName: 'Hair Color',
      amount: 1800, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 18, 14, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't17', transactionId: 'TXN-001229',
      ownerId: 'co6', ownerName: 'Sofia Mendoza',
      nfcCardId: 'LP-406152738',
      staffId: 'st4', staffName: 'Reyna Lim',
      serviceId: 's7', serviceName: 'Full Body Massage',
      amount: 1500, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 15, 16, 30),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't18', transactionId: 'TXN-001228',
      ownerId: 'co1', ownerName: 'Juan Dela Cruz',
      nfcCardId: 'LP-839274615',
      staffId: 'st3', staffName: 'Angela Cruz',
      serviceId: 's5', serviceName: 'Pedicure',
      amount: 400, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 12, 11, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't19', transactionId: 'TXN-001227',
      ownerId: 'co7', ownerName: 'Miguel Torres',
      nfcCardId: 'LP-395041627',
      staffId: 'st2', staffName: 'Carlo Reyes',
      serviceId: 's1', serviceName: 'Haircut',
      amount: 500, paymentMethod: PaymentMethod.cash,
      dateTime: DateTime(2026, 8, 10, 13, 0),
      status: TransactionStatus.completed,
    ),
    AdminTransactionModel(
      id: 't20', transactionId: 'TXN-001226',
      ownerId: 'co9', ownerName: 'Camille Aquino',
      nfcCardId: 'LP-173829405',
      staffId: 'st4', staffName: 'Reyna Lim',
      serviceId: 's6', serviceName: 'Facial',
      amount: 1200, paymentMethod: PaymentMethod.lavishWallet,
      dateTime: DateTime(2026, 8, 8, 9, 30),
      status: TransactionStatus.completed,
    ),
  ];

  // ── Wallets ───────────────────────────────────────────────────────────────
  static final List<WalletModel> wallets = cardOwners.map((o) {
    final ownerTx = transactions
        .where((t) => t.ownerId == o.id && t.status == TransactionStatus.completed)
        .toList();
    final spent = ownerTx.fold(0.0, (sum, t) => sum + t.amount);
    return WalletModel(
      id: 'w_${o.id}',
      ownerId: o.id,
      balance: o.walletBalance,
      totalSpent: spent,
      totalTransactions: ownerTx.length,
      lastTransactionDate:
          ownerTx.isNotEmpty ? ownerTx.first.dateTime : null,
    );
  }).toList();

  // ── Dashboard Stats ───────────────────────────────────────────────────────
  static int get totalCardOwners => cardOwners.length;
  static int get activeNfcCards =>
      nfcCards.where((c) => c.status == NfcCardStatus.active).length;
  static int get availableNfcCards =>
      nfcCards.where((c) => c.status == NfcCardStatus.available).length;
  static int get totalStaff => staff.length;

  static int get todayTransactionCount {
    final today = DateTime.now();
    return transactions
        .where((t) =>
            t.dateTime.year == today.year &&
            t.dateTime.month == today.month &&
            t.dateTime.day == today.day)
        .length;
  }

  static double get todayRevenue {
    final today = DateTime.now();
    return transactions
        .where((t) =>
            t.dateTime.year == today.year &&
            t.dateTime.month == today.month &&
            t.dateTime.day == today.day &&
            t.status == TransactionStatus.completed)
        .fold(0.0, (s, t) => s + t.amount);
  }

  /// All completed transactions (used by sales analytics).
  static List<AdminTransactionModel> get completedTransactions => transactions
      .where((t) => t.status == TransactionStatus.completed)
      .toList();
}
