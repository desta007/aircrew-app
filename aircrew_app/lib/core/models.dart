import 'package:flutter/material.dart';

/// Service type a customer can request.
enum ServiceType { scheduled, rental3, rental5, rental8 }

extension ServiceTypeX on ServiceType {
  String get label => switch (this) {
        ServiceType.scheduled => 'Jemputan Terjadwal',
        ServiceType.rental3 => 'Rental 3 Jam',
        ServiceType.rental5 => 'Rental 5 Jam',
        ServiceType.rental8 => 'Rental 8 Jam',
      };
  bool get isRental => this != ServiceType.scheduled;
}

/// Lifecycle of an order, following the Mitra Driver flow (12 steps).
enum OrderStatus {
  waiting, // order masuk, menunggu didispatch
  offered, // ditawarkan ke driver tertentu (Phase 2 dispatch)
  accepted, // driver terima order
  toPickup, // menuju lokasi jemput
  arrivedPickup, // tiba di lokasi jemput
  onTrip, // penjemputan / dalam perjalanan
  arrivedDest, // tiba di tujuan
  completed, // konfirmasi selesai + biaya final
  cancelled,
  noDriver, // tidak ada driver tersedia (dispatch habis)
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.waiting => 'Menunggu',
        OrderStatus.offered => 'Mencari Driver',
        OrderStatus.accepted => 'Diterima',
        OrderStatus.toPickup => 'Menuju Jemput',
        OrderStatus.arrivedPickup => 'Tiba di Lokasi',
        OrderStatus.onTrip => 'Dalam Perjalanan',
        OrderStatus.arrivedDest => 'Tiba di Tujuan',
        OrderStatus.completed => 'Selesai',
        OrderStatus.cancelled => 'Dibatalkan',
        OrderStatus.noDriver => 'Tidak Ada Driver',
      };
  Color get color => switch (this) {
        OrderStatus.completed => const Color(0xFF17A54A),
        OrderStatus.cancelled => const Color(0xFFE11B22),
        OrderStatus.noDriver => const Color(0xFFE11B22),
        OrderStatus.waiting => const Color(0xFFE07B1A),
        OrderStatus.offered => const Color(0xFFE07B1A),
        _ => const Color(0xFF1E5BE6),
      };
}

/// Maps API service codes / labels to [ServiceType].
ServiceType serviceFromApi(String v) => switch (v) {
      'scheduled' => ServiceType.scheduled,
      'rental3' => ServiceType.rental3,
      'rental5' => ServiceType.rental5,
      'rental8' => ServiceType.rental8,
      _ => ServiceType.scheduled,
    };

String serviceToApi(ServiceType s) => switch (s) {
      ServiceType.scheduled => 'scheduled',
      ServiceType.rental3 => 'rental3',
      ServiceType.rental5 => 'rental5',
      ServiceType.rental8 => 'rental8',
    };

OrderStatus statusFromApi(String v) => switch (v) {
      'no_driver' => OrderStatus.noDriver,
      _ => OrderStatus.values.firstWhere((s) => s.name == v, orElse: () => OrderStatus.waiting),
    };

/// A geographic point (WGS84). Kept dependency-free so models don't require the
/// `latlong2` package; convert at the map-widget boundary.
class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);

  static LatLngPoint? tryFrom(dynamic lat, dynamic lng) {
    if (lat is num && lng is num) return LatLngPoint(lat.toDouble(), lng.toDouble());
    return null;
  }
}

/// Distance/ETA/fare quote returned by `POST /customer/orders/estimate`.
class FareEstimate {
  final double distanceKm;
  final int etaMinutes;
  final double fareEstimate;
  final String source; // 'osrm' | 'haversine'
  const FareEstimate({
    required this.distanceKm,
    required this.etaMinutes,
    required this.fareEstimate,
    this.source = 'osrm',
  });

  factory FareEstimate.fromJson(Map<String, dynamic> j) => FareEstimate(
        distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
        etaMinutes: (j['eta_minutes'] as num?)?.toInt() ?? 0,
        fareEstimate: (j['fare_estimate'] as num?)?.toDouble() ?? 0,
        source: (j['source'] ?? 'osrm') as String,
      );
}

class Vehicle {
  final String name; // e.g. Innova Reborn
  final String plate; // e.g. B 1234 ABC
  const Vehicle(this.name, this.plate);

  factory Vehicle.fromJson(Map<String, dynamic> j) =>
      Vehicle((j['name'] ?? '') as String, (j['plate'] ?? '') as String);
}

class Driver {
  final String id;
  final String name;
  final String area;
  final double rating;
  final Vehicle vehicle;
  bool online;
  LatLngPoint? location; // live GPS position (null until reported)
  Driver({
    required this.id,
    required this.name,
    required this.area,
    required this.rating,
    required this.vehicle,
    this.online = true,
    this.location,
  });

  factory Driver.fromJson(Map<String, dynamic> j) {
    final loc = j['location'];
    return Driver(
      id: j['id'] as String,
      name: j['name'] as String,
      area: (j['area'] ?? '-') as String,
      rating: (j['rating'] as num).toDouble(),
      vehicle: Vehicle.fromJson((j['vehicle'] ?? {}) as Map<String, dynamic>),
      online: (j['online'] ?? false) as bool,
      location: loc is Map<String, dynamic> ? LatLngPoint.tryFrom(loc['lat'], loc['lng']) : null,
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String airline; // e.g. Garuda Indonesia
  final String area;
  const Customer({
    required this.id,
    required this.name,
    required this.airline,
    required this.area,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: j['name'] as String,
        airline: (j['airline'] ?? '') as String,
        area: (j['area'] ?? '-') as String,
      );
}

/// Additional charges added by the driver on completion.
/// Total tagihan = argo + tol + parkir + lainnya.
class OrderCharges {
  double argo;
  double tol;
  double parkir;
  double lainnya;
  String lainnyaNote;
  OrderCharges({
    this.argo = 0,
    this.tol = 0,
    this.parkir = 0,
    this.lainnya = 0,
    this.lainnyaNote = '',
  });

  double get total => argo + tol + parkir + lainnya;

  factory OrderCharges.fromJson(Map<String, dynamic> j) => OrderCharges(
        argo: (j['argo'] as num?)?.toDouble() ?? 0,
        tol: (j['tol'] as num?)?.toDouble() ?? 0,
        parkir: (j['parkir'] as num?)?.toDouble() ?? 0,
        lainnya: (j['lainnya'] as num?)?.toDouble() ?? 0,
        lainnyaNote: (j['lainnya_note'] ?? '') as String,
      );
}

class Order {
  final String id;
  final Customer customer;
  Driver? driver;
  final ServiceType service;
  final String pickup;
  final String destination;
  final LatLngPoint? pickupPoint;
  final LatLngPoint? destPoint;
  final DateTime scheduledAt;
  final double distanceKm;
  final int etaMinutes;
  final double fareEstimate;
  final String note;
  OrderStatus status;
  OrderCharges charges;

  // set after completion
  int? crewRating; // rating from crew to driver
  String? crewFeedback;
  DateTime? completedAt;

  Order({
    required this.id,
    required this.customer,
    this.driver,
    required this.service,
    required this.pickup,
    required this.destination,
    this.pickupPoint,
    this.destPoint,
    required this.scheduledAt,
    required this.distanceKm,
    required this.etaMinutes,
    this.fareEstimate = 0,
    this.note = '',
    this.status = OrderStatus.waiting,
    OrderCharges? charges,
  }) : charges = charges ?? OrderCharges();

  double get total => charges.total;
  String get area => customer.area;

  factory Order.fromJson(Map<String, dynamic> j, {Customer? fallbackCustomer}) {
    final cust = j['customer'] != null
        ? Customer.fromJson(j['customer'] as Map<String, dynamic>)
        : (fallbackCustomer ??
            Customer(id: '-', name: '-', airline: '', area: (j['area'] ?? '-') as String));
    return Order(
      id: j['id'] as String,
      customer: cust,
      driver: j['driver'] != null ? Driver.fromJson(j['driver'] as Map<String, dynamic>) : null,
      service: serviceFromApi((j['service'] ?? 'scheduled') as String),
      pickup: (j['pickup'] ?? '') as String,
      destination: (j['destination'] ?? '') as String,
      pickupPoint: LatLngPoint.tryFrom(j['pickup_lat'], j['pickup_lng']),
      destPoint: LatLngPoint.tryFrom(j['dest_lat'], j['dest_lng']),
      scheduledAt: DateTime.tryParse((j['scheduled_at'] ?? '') as String) ?? DateTime.now(),
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      etaMinutes: (j['eta_minutes'] as num?)?.toInt() ?? 0,
      fareEstimate: (j['fare_estimate'] as num?)?.toDouble() ?? 0,
      note: (j['note'] ?? '') as String,
      status: statusFromApi((j['status'] ?? 'waiting') as String),
      charges: OrderCharges.fromJson((j['charges'] ?? {}) as Map<String, dynamic>),
    )
      ..crewRating = (j['crew_rating'] as num?)?.toInt()
      ..crewFeedback = j['crew_feedback'] as String?
      ..completedAt = j['completed_at'] != null ? DateTime.tryParse(j['completed_at'] as String) : null;
  }
}

enum WalletTxType { income, withdrawal }

class WalletTx {
  final String id;
  final WalletTxType type;
  final double amount;
  final DateTime at;
  final String label;
  const WalletTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.at,
    required this.label,
  });

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as String,
        type: j['type'] == 'income' ? WalletTxType.income : WalletTxType.withdrawal,
        amount: (j['amount'] as num).toDouble(),
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
        label: (j['label'] ?? '') as String,
      );
}

enum WithdrawSpeed { h1, h0 } // H+1 gratis, H+0 instan (biaya 5000)

extension WithdrawSpeedX on WithdrawSpeed {
  String get label => this == WithdrawSpeed.h1 ? 'WD H+1 (Gratis)' : 'WD H+0 (Instan)';
  double get fee => this == WithdrawSpeed.h1 ? 0 : 5000;
}

enum WithdrawMethod { bank, ovo, dana, gopay }

extension WithdrawMethodX on WithdrawMethod {
  String get label => switch (this) {
        WithdrawMethod.bank => 'Transfer Bank',
        WithdrawMethod.ovo => 'OVO',
        WithdrawMethod.dana => 'DANA',
        WithdrawMethod.gopay => 'GoPay',
      };
}

class Withdrawal {
  final String id; // ref no
  final double nominal;
  final double fee;
  final WithdrawSpeed speed;
  final WithdrawMethod method;
  final String account; // rekening / nomor
  final DateTime at;
  final String status; // Proses / Berhasil
  const Withdrawal({
    required this.id,
    required this.nominal,
    required this.fee,
    required this.speed,
    required this.method,
    required this.account,
    required this.at,
    required this.status,
  });
  double get received => nominal - fee;

  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
        id: j['id'] as String,
        nominal: (j['nominal'] as num).toDouble(),
        fee: (j['fee'] as num?)?.toDouble() ?? 0,
        speed: j['speed'] == 'h0' ? WithdrawSpeed.h0 : WithdrawSpeed.h1,
        method: switch (j['method']) {
          'ovo' => WithdrawMethod.ovo,
          'dana' => WithdrawMethod.dana,
          'gopay' => WithdrawMethod.gopay,
          _ => WithdrawMethod.bank,
        },
        account: (j['account'] ?? '') as String,
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
        status: (j['status'] ?? 'Proses') as String,
      );
}

// ---- Customer billing (Tagihan / Invoice) ----

enum PaymentMethod { qris, va, card }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.qris => 'QRIS (Semua Bank)',
        PaymentMethod.va => 'Virtual Account',
        PaymentMethod.card => 'Kartu Kredit',
      };
}

class Payment {
  final String ref;
  final double amount;
  final PaymentMethod method;
  final DateTime at;
  final String status; // pending | paid | failed
  final Map<String, dynamic>? instructions; // gateway QR string / VA number / url
  const Payment({
    required this.ref,
    required this.amount,
    required this.method,
    required this.at,
    this.status = 'paid',
    this.instructions,
  });

  bool get isPaid => status == 'paid';

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        ref: j['ref'] as String,
        amount: (j['amount'] as num).toDouble(),
        method: switch (j['method']) {
          'va' => PaymentMethod.va,
          'card' => PaymentMethod.card,
          _ => PaymentMethod.qris,
        },
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
        status: (j['status'] ?? 'paid') as String,
        instructions: (j['instructions'] as Map?)?.cast<String, dynamic>(),
      );
}

class Invoice {
  final String id;
  final Order order;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueDate;
  final List<Payment> payments;

  Invoice({
    required this.id,
    required this.order,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    List<Payment>? payments,
  }) : payments = payments ?? [];

  double get total => order.total;
  double get paid => payments.fold(0.0, (s, p) => s + p.amount);
  double get remaining => (total - paid).clamp(0, total);
  bool get isPaid => remaining <= 0;
  String get statusLabel => isPaid ? 'Lunas' : (paid > 0 ? 'Sebagian' : 'Belum Lunas');

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: j['id'] as String,
        order: Order.fromJson((j['order'] ?? {}) as Map<String, dynamic>),
        periodStart: DateTime.tryParse((j['period_start'] ?? '') as String) ?? DateTime.now(),
        periodEnd: DateTime.tryParse((j['period_end'] ?? '') as String) ?? DateTime.now(),
        dueDate: DateTime.tryParse((j['due_date'] ?? '') as String) ?? DateTime.now(),
        payments: ((j['payments'] ?? []) as List)
            .map((p) => Payment.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
