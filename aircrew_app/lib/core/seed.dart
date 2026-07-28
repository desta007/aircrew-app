import 'models.dart';

/// Static demo/seed data for the AirCrew platform.
class Seed {
  static const areas = ['Utara', 'Timur', 'Pusat', 'Barat', 'Selatan', 'Tangerang'];

  // Aggregate numbers used by dashboard + hierarchy screen.
  static const areaStats = <Map<String, dynamic>>[
    {'area': 'Utara', 'driver': 8, 'aircrew': 76, 'order': 48, 'pendapatan': 5620000},
    {'area': 'Timur', 'driver': 6, 'aircrew': 62, 'order': 36, 'pendapatan': 3840000},
    {'area': 'Pusat', 'driver': 12, 'aircrew': 120, 'order': 85, 'pendapatan': 9750000},
    {'area': 'Barat', 'driver': 7, 'aircrew': 68, 'order': 41, 'pendapatan': 3980000},
    {'area': 'Selatan', 'driver': 5, 'aircrew': 50, 'order': 35, 'pendapatan': 1660000},
  ];

  static final drivers = <Driver>[
    Driver(id: 'DRV-001', name: 'Budi Santoso', area: 'Pusat', rating: 4.92, vehicle: const Vehicle('Innova Reborn', 'B 1234 ABC')),
    Driver(id: 'DRV-002', name: 'Andi Wijaya', area: 'Pusat', rating: 4.80, vehicle: const Vehicle('Avanza', 'B 0678 DEF')),
    Driver(id: 'DRV-003', name: 'Slamet Riyadi', area: 'Pusat', rating: 4.90, vehicle: const Vehicle('Innova Zenix', 'B 9101 GHI')),
    Driver(id: 'DRV-004', name: 'Asep Kurnia', area: 'Utara', rating: 4.85, vehicle: const Vehicle('Xpander', 'B 2222 JKL')),
    Driver(id: 'DRV-005', name: 'Rudi Hartono', area: 'Selatan', rating: 4.70, vehicle: const Vehicle('Avanza', 'B 3333 MNO')),
  ];

  static final customers = <Customer>[
    const Customer(id: 'CST-001', name: 'Budi Santoso', airline: 'Garuda Indonesia', area: 'Pusat'),
    const Customer(id: 'CST-002', name: 'Rina Permata', airline: 'Citilink', area: 'Pusat'),
    const Customer(id: 'CST-003', name: 'Andi Pratama', airline: 'Lion Air', area: 'Utara'),
    const Customer(id: 'CST-004', name: 'Dewi Anggraini', airline: 'Batik Air', area: 'Selatan'),
  ];

  /// The logged-in driver for the Mitra app.
  static Driver get me => drivers.first;

  /// The logged-in crew for the Customer app.
  static Customer get crew => customers.first;

  static final _now = DateTime(2026, 7, 28, 9, 41);

  /// Incoming order shown on the driver home (waiting for accept).
  static Order incomingOrder() => Order(
        id: 'ORD-180525-00123',
        customer: customers[0],
        service: ServiceType.scheduled,
        pickup: 'Hotel Novotel Bandara',
        destination: 'Terminal 3 - CGK',
        scheduledAt: DateTime(2026, 5, 18, 3, 45),
        distanceKm: 12,
        etaMinutes: 25,
        note: 'Mohon standby di lobby hotel',
        charges: OrderCharges(argo: 125000),
      );

  /// Completed order history for the driver + customer.
  static List<Order> history() => [
        Order(
          id: 'ORD-180525-00098',
          customer: customers[1],
          driver: drivers[0],
          service: ServiceType.scheduled,
          pickup: 'Hilton Hotel',
          destination: 'Terminal 2 - CGK',
          scheduledAt: DateTime(2026, 5, 18, 2, 35),
          distanceKm: 9,
          etaMinutes: 18,
          status: OrderStatus.completed,
          charges: OrderCharges(argo: 100000, tol: 10000),
        )..crewRating = 5..completedAt = DateTime(2026, 5, 18, 2, 35),
        Order(
          id: 'ORD-180525-00087',
          customer: customers[2],
          driver: drivers[0],
          service: ServiceType.rental3,
          pickup: 'Apartemen Green',
          destination: 'Terminal 1 - CGK',
          scheduledAt: DateTime(2026, 5, 18, 1, 15),
          distanceKm: 7,
          etaMinutes: 15,
          status: OrderStatus.completed,
          charges: OrderCharges(argo: 90000),
        )..crewRating = 5..completedAt = DateTime(2026, 5, 18, 1, 15),
      ];

  static List<WalletTx> walletHistory() => [
        WalletTx(id: 'ORD-180525-00123', type: WalletTxType.income, amount: 125000, at: DateTime(2026, 5, 18, 4, 10), label: 'Pendapatan order'),
        WalletTx(id: 'WD2505180000123', type: WalletTxType.withdrawal, amount: 1000000, at: DateTime(2026, 5, 18, 10, 25), label: 'Withdraw Transfer Bank'),
        WalletTx(id: 'ORD-180525-00098', type: WalletTxType.income, amount: 110000, at: DateTime(2026, 5, 18, 2, 40), label: 'Pendapatan order'),
      ];

  static List<Withdrawal> withdrawals() => [
        Withdrawal(id: 'WD2505180000123', nominal: 1000000, fee: 0, speed: WithdrawSpeed.h1, method: WithdrawMethod.bank, account: 'BCA • 1234 5678 9012', at: DateTime(2026, 5, 19, 10, 25), status: 'Proses'),
        Withdrawal(id: 'WD2505180000098', nominal: 750000, fee: 5000, speed: WithdrawSpeed.h0, method: WithdrawMethod.ovo, account: 'OVO • 0812 3456 7890', at: DateTime(2026, 5, 18, 14, 32), status: 'Berhasil'),
        Withdrawal(id: 'WD2505170000076', nominal: 500000, fee: 0, speed: WithdrawSpeed.h1, method: WithdrawMethod.bank, account: 'BCA • 1234 5678 9012', at: DateTime(2026, 5, 17, 9, 45), status: 'Berhasil'),
      ];

  /// Outstanding invoices for the customer's billing screen.
  static List<Invoice> invoices() {
    final inv1Order = Order(
      id: 'ORD-180525-00123',
      customer: customers[0],
      driver: drivers[0],
      service: ServiceType.scheduled,
      pickup: 'Hotel Novotel Bandara',
      destination: 'Terminal 3 - CGK',
      scheduledAt: DateTime(2026, 5, 18, 3, 45),
      distanceKm: 12,
      etaMinutes: 25,
      status: OrderStatus.completed,
      charges: OrderCharges(argo: 5000000, tol: 150000, parkir: 50000, lainnya: 50000, lainnyaNote: 'Biaya tunggu'),
    );
    final inv2Order = Order(
      id: 'ORD-250425-00089',
      customer: customers[0],
      driver: drivers[1],
      service: ServiceType.rental8,
      pickup: 'Kantor Pusat',
      destination: 'Terminal 2 - CGK',
      scheduledAt: DateTime(2026, 4, 20, 8, 0),
      distanceKm: 40,
      etaMinutes: 60,
      status: OrderStatus.completed,
      charges: OrderCharges(argo: 4750000),
    );
    return [
      Invoice(
        id: 'INV-250S-00012',
        order: inv1Order,
        periodStart: DateTime(2026, 5, 1),
        periodEnd: DateTime(2026, 5, 31),
        dueDate: DateTime(2026, 6, 5),
        payments: [
          Payment(ref: 'QRIS2505180310', amount: 2000000, method: PaymentMethod.qris, at: DateTime(2026, 5, 18, 10, 25)),
        ],
      ),
      Invoice(
        id: 'INV-2504-00089',
        order: inv2Order,
        periodStart: DateTime(2026, 4, 1),
        periodEnd: DateTime(2026, 4, 30),
        dueDate: DateTime(2026, 5, 5),
        payments: [
          Payment(ref: 'VA2504300930', amount: 4750000, method: PaymentMethod.va, at: DateTime(2026, 4, 30, 9, 30)),
        ],
      ),
    ];
  }

  static DateTime get now => _now;
}
