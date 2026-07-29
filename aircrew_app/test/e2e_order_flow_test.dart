import 'package:flutter_test/flutter_test.dart';
import 'package:aircrew_app/core/api.dart';
import 'package:aircrew_app/core/models.dart';

/// End-to-end live test of the full order lifecycle against a running Laravel
/// API (php artisan serve). Drives the exact [ApiClient] methods the Flutter
/// apps call: customer creates an order → driver accepts & drives it → driver
/// completes with extra charges → invoice is generated → customer pays (QRIS
/// partial) → customer rates the driver.
///
/// Skips automatically if the backend is offline.
void main() {
  final api = ApiClient.instance..baseUrl = 'http://127.0.0.1:8000/api';

  test('full lifecycle: customer order → driver trip → complete → pay', () async {
    if (!await api.ping()) {
      markTestSkipped('Laravel API offline — skip e2e test');
      return;
    }

    // ---- 1. Customer creates a WAITING order ----
    api.token = null;
    final customer = await api.loginCustomer('budi.crew@garuda.co.id', 'demo1234');
    expect(customer.id, 'CST-001');

    final created = await api.createOrder(
      service: ServiceType.scheduled,
      pickup: 'Hotel Novotel Bandara',
      destination: 'Terminal 3 - CGK',
      scheduledAt: DateTime(2026, 7, 29, 3, 45),
      argo: 125000,
      completed: false,
    );
    final code = created.order.id;
    expect(code, startsWith('ORD-'));
    expect(created.order.status, OrderStatus.waiting);
    expect(created.invoice, isNull, reason: 'invoice is generated later on completion');

    // New waiting order shows up in the customer's Riwayat Order (new method).
    final history = await api.customerOrders();
    expect(history.any((o) => o.id == code), isTrue,
        reason: 'customerOrders() must include the freshly created order');

    // ---- 2. Driver sees it in their area and accepts ----
    final driver = await api.loginMitra('drv-001@aircrew.id', 'demo1234');
    expect(driver.id, 'DRV-001');
    expect(driver.area, 'Pusat');

    final incoming = await api.mitraIncoming();
    expect(incoming, isNotNull, reason: 'a waiting order exists in the driver area');

    final accepted = await api.acceptOrder(code);
    expect(accepted.status, OrderStatus.accepted);
    expect(accepted.driver?.id, 'DRV-001',
        reason: 'accept assigns the driver + returns the authoritative order');
    expect(accepted.customer.id, 'CST-001');

    // ---- 3. Driver drives the trip through every status ----
    for (final s in [
      OrderStatus.toPickup,
      OrderStatus.arrivedPickup,
      OrderStatus.onTrip,
      OrderStatus.arrivedDest,
    ]) {
      await api.advanceOrder(code, s.name);
    }

    // Customer polling sees the live status advance.
    final midway = await api.customerOrder(code);
    expect(midway.status, OrderStatus.arrivedDest);

    // ---- 4. Driver completes with extra charges (argo+tol+parkir+lainnya) ----
    final completed = await api.completeOrder(
      code,
      OrderCharges(argo: 125000, tol: 15000, parkir: 10000, lainnya: 5000, lainnyaNote: 'Biaya tunggu'),
    );
    expect(completed.status, OrderStatus.completed);
    expect(completed.total, 155000, reason: '125000 + 15000 + 10000 + 5000');

    // ---- 5. Invoice generated for the customer; poll shows completed ----
    await api.loginCustomer('budi.crew@garuda.co.id', 'demo1234');
    final polled = await api.customerOrder(code);
    expect(polled.status, OrderStatus.completed);
    expect(polled.total, 155000);

    final invoices = await api.customerInvoices();
    final inv = invoices.firstWhere((i) => i.order.id == code,
        orElse: () => throw StateError('invoice for $code not found'));
    expect(inv.total, 155000);
    expect(inv.remaining, 155000, reason: 'unpaid at first');

    // ---- 6. Customer pays partially via QRIS ----
    await api.payInvoice(inv.id, 100000, PaymentMethod.qris);
    final afterPay = (await api.customerInvoices()).firstWhere((i) => i.id == inv.id);
    expect(afterPay.paid, 100000);
    expect(afterPay.remaining, 55000);
    expect(afterPay.statusLabel, 'Sebagian');

    // ---- 7. Customer rates the driver ----
    await api.customerRateOrder(code, 5, 'Driver ramah dan tepat waktu');
    final rated = await api.customerOrder(code);
    expect(rated.crewRating, 5);

    await api.logout();
    expect(api.token, isNull);
  });
}
