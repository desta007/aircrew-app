import 'package:flutter_test/flutter_test.dart';
import 'package:aircrew_app/core/api.dart';

/// Integration test against a locally running Laravel API (php artisan serve).
/// Skips automatically if the backend is offline.
void main() {
  final api = ApiClient.instance..baseUrl = 'http://127.0.0.1:8000/api';

  test('Sanctum login + protected endpoints parse into models', () async {
    if (!await api.ping()) {
      markTestSkipped('Laravel API offline — skip integration test');
      return;
    }

    // Wrong password must be rejected (401 → ApiException).
    api.token = null;
    await expectLater(
      api.loginMitra('drv-001@aircrew.id', 'salah'),
      throwsA(isA<ApiException>()),
    );

    // ---- Mitra login → token → protected calls ----
    final driver = await api.loginMitra('drv-001@aircrew.id', 'demo1234');
    expect(driver.id, 'DRV-001');
    expect(api.token, isNotNull);

    final me = await api.mitraMe();
    expect(me['driver']['id'], 'DRV-001');

    final incoming = await api.mitraIncoming();
    expect(incoming, isNotNull);
    expect(incoming!.charges.total, greaterThan(0));

    expect(await api.mitraOrders(), isNotEmpty);
    expect(await api.mitraWithdrawals(), isNotEmpty);

    // ---- Customer login → token → protected calls ----
    final customer = await api.loginCustomer('budi.crew@garuda.co.id', 'demo1234');
    expect(customer.id, 'CST-001');

    final invoices = await api.customerInvoices();
    expect(invoices, isNotEmpty);
    final inv = invoices.firstWhere((i) => i.id == 'INV-250S-00012');
    expect(inv.total, 5250000); // argo + tol + parkir + lainnya
    expect(inv.remaining, 3250000);

    final drivers = await api.customerDrivers();
    expect(drivers.every((d) => d.area == drivers.first.area), isTrue,
        reason: 'closed-area: all drivers share the customer area');

    // ---- Logout revokes the token ----
    await api.logout();
    expect(api.token, isNull);
  });
}
