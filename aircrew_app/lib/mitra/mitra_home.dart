import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'mitra_trip.dart';

/// Driver home — online toggle + incoming order card (steps 1-2 of the flow).
/// Polls the backend for freshly created customer orders while online and idle.
class MitraHome extends StatefulWidget {
  const MitraHome({super.key});

  @override
  State<MitraHome> createState() => _MitraHomeState();
}

class _MitraHomeState extends State<MitraHome> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Poll for incoming orders in this driver's area every few seconds while
    // online and not already on a trip.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      final app = context.read<AppState>();
      if (app.online && app.activeOrder == null) app.refreshIncoming();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.activeOrder;
    final incoming = app.incoming;
    return Scaffold(
      backgroundColor: AirColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(context, app),
            const SizedBox(height: 16),
            _balanceStrip(app),
            const SizedBox(height: 16),
            if (!app.online)
              _offlineNotice()
            else if (active != null && active.status != OrderStatus.completed)
              _activeCard(context, active)
            else if (incoming != null)
              _incomingOrder(context, app, incoming)
            else
              _waitingForOrder(),
            const SizedBox(height: 16),
            _statsRow(app),
          ],
        ),
      ),
    );
  }

  Widget _waitingForOrder() {
    return SectionCard(
      child: Column(children: const [
        SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3, color: AirColors.navy),
        ),
        SizedBox(height: 14),
        Text('Menunggu Order Masuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        SizedBox(height: 6),
        Text('Anda online. Order dari crew di area Anda akan muncul di sini secara otomatis.',
            textAlign: TextAlign.center, style: TextStyle(color: AirColors.textDim, fontSize: 13)),
      ]),
    );
  }

  Widget _header(BuildContext context, AppState app) {
    return Row(
      children: [
        Avatar(app.driver.name, radius: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selamat Pagi,', style: TextStyle(color: AirColors.textDim, fontSize: 13)),
              Text(app.driver.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Row(children: [
                const Icon(Icons.star, color: AirColors.gold, size: 15),
                Text(' ${app.driver.rating}  •  Area ${app.driver.area}',
                    style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
              ]),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => app.setOnline(!app.online),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: app.online ? AirColors.greenLight : AirColors.line,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 10, color: app.online ? AirColors.green : AirColors.textDim),
              const SizedBox(width: 6),
              Text(app.online ? 'Online' : 'Offline',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: app.online ? AirColors.green : AirColors.textDim)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _balanceStrip(AppState app) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AirColors.navy, AirColors.navyLight]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Saldo Tersedia', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(rp(app.saldoTersedia), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ]),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Order Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${app.orderHistory.length + (app.activeOrder == null ? 0 : 1)}',
                style: const TextStyle(color: AirColors.gold, fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
        ],
      ),
    );
  }

  Widget _offlineNotice() {
    return SectionCard(
      child: Column(children: const [
        Icon(Icons.nightlight_round, size: 40, color: AirColors.textDim),
        SizedBox(height: 10),
        Text('Anda sedang Offline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        SizedBox(height: 6),
        Text('Aktifkan status Online untuk mulai menerima order di area Anda.',
            textAlign: TextAlign.center, style: TextStyle(color: AirColors.textDim, fontSize: 13)),
      ]),
    );
  }

  Widget _activeCard(BuildContext context, Order o) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AirColors.blue.withValues(alpha: .4), width: 1.4),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Pill('Order Berjalan • ${o.status.label}', AirColors.blue),
            const Spacer(),
            Text(o.id, style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          _route(o),
          const SizedBox(height: 14),
          PrimaryButton('Lanjutkan Perjalanan', icon: Icons.navigation_rounded, color: AirColors.blue,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MitraTripPage()))),
        ],
      ),
    );
  }

  Widget _incomingOrder(BuildContext context, AppState app, Order o) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AirColors.red.withValues(alpha: .35), width: 1.4),
        boxShadow: [BoxShadow(color: AirColors.red.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Pill('Order Baru • Terjadwal', AirColors.red),
            const Spacer(),
            Text(o.service.label, style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Avatar(o.customer.name),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.customer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(o.customer.airline, style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
            ]),
          ]),
          const SizedBox(height: 14),
          _route(o),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AirColors.textDim),
              const SizedBox(width: 8),
              Expanded(child: Text(o.note, style: const TextStyle(fontSize: 12.5, color: AirColors.textDim))),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _chip(Icons.route, '${o.distanceKm.toStringAsFixed(0)} km'),
            const SizedBox(width: 8),
            _chip(Icons.schedule, 'Est. ${o.etaMinutes} mnt'),
            const Spacer(),
            Text(rp(o.charges.argo), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AirColors.navy)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  app.rejectOrder();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ditolak. Menunggu order berikutnya...')));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AirColors.red,
                  side: const BorderSide(color: AirColors.red),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton('Terima', color: AirColors.red, onPressed: () {
                app.acceptOrder();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MitraTripPage()));
              }),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _route(Order o) {
    return Column(
      children: [
        _routeRow(Icons.trip_origin, AirColors.green, 'Pickup', o.pickup),
        Padding(
          padding: const EdgeInsets.only(left: 9),
          child: Container(width: 2, height: 18, color: AirColors.line),
        ),
        _routeRow(Icons.location_on, AirColors.red, 'Tujuan', o.destination),
      ],
    );
  }

  Widget _routeRow(IconData icon, Color c, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AirColors.textDim, fontSize: 11.5)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AirColors.textDim),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AirColors.textDim)),
      ]),
    );
  }

  Widget _statsRow(AppState app) {
    return Row(children: [
      Expanded(child: _stat('Hari Ini', rp(app.pendapatanHariIni + 320000), Icons.today, AirColors.blue)),
      const SizedBox(width: 12),
      Expanded(child: _stat('Rating', '${app.driver.rating}', Icons.star, AirColors.gold)),
    ]);
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AirColors.textDim, fontSize: 11.5)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
