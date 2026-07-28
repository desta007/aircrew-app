import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'customer_order_flow.dart';

/// Customer home — greeting, quick balance of tagihan, and service picker
/// (Jemputan Terjadwal / Rental) that starts the order flow.
class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AirColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Avatar(app.crew.name, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Selamat Datang,', style: TextStyle(color: AirColors.textDim, fontSize: 13)),
                  Text(app.crew.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  Text('${app.crew.airline} • Area ${app.crew.area}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.notifications_none_rounded, color: AirColors.navy),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AirColors.blue, AirColors.navyLight]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total Tagihan Belum Lunas', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(rp(app.totalTagihanRemaining), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ]),
                ),
                const Icon(Icons.receipt_long, color: Colors.white54, size: 40),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Pilih Layanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Layanan hanya dilayani driver di area Anda.', style: TextStyle(color: AirColors.textDim, fontSize: 12.5)),
            const SizedBox(height: 14),
            _serviceCard(
              context,
              icon: Icons.schedule,
              color: AirColors.blue,
              title: 'Jemputan Terjadwal',
              subtitle: 'Antar jemput sesuai jadwal penerbangan',
              service: ServiceType.scheduled,
            ),
            const SizedBox(height: 12),
            _serviceCard(
              context,
              icon: Icons.directions_car_filled,
              color: AirColors.red,
              title: 'Rental (3, 5, 8 Jam)',
              subtitle: 'Sewa mobil + driver dengan durasi',
              service: ServiceType.rental3,
            ),
            const SizedBox(height: 20),
            const Text('Driver Favorit di Area Anda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            ..._favDrivers(context),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required ServiceType service}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerOrderFlow(initialService: service))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AirColors.line)),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AirColors.textDim),
          ]),
        ),
      ),
    );
  }

  List<Widget> _favDrivers(BuildContext context) {
    final drivers = context.read<AppState>();
    return [
      for (final d in [drivers.driver])
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AirColors.line)),
          child: Row(children: [
            Avatar(d.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${d.vehicle.name} • ${d.vehicle.plate}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
              ]),
            ),
            Row(children: [const Icon(Icons.star, color: AirColors.gold, size: 15), Text(' ${d.rating}')]),
          ]),
        ),
    ];
  }
}
