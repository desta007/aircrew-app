import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Drives the driver trip through its lifecycle (steps 3-9 of the flow):
/// menuju jemput → tiba → mulai → tiba tujuan → konfirmasi selesai (+biaya) →
/// rating dari crew → ringkasan order.
class MitraTripPage extends StatelessWidget {
  const MitraTripPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final o = app.activeOrder;
    if (o == null) return const Scaffold(body: Center(child: Text('Tidak ada order aktif')));

    return Scaffold(
      appBar: AppBar(title: Text(_title(o.status))),
      body: SafeArea(
        child: switch (o.status) {
          OrderStatus.accepted ||
          OrderStatus.toPickup ||
          OrderStatus.arrivedPickup ||
          OrderStatus.onTrip ||
          OrderStatus.arrivedDest =>
            _navView(context, app, o),
          OrderStatus.completed => o.crewRating == null
              ? _ratingView(context, app, o)
              : _summaryView(context, app, o),
          _ => const SizedBox(),
        },
      ),
    );
  }

  String _title(OrderStatus s) => switch (s) {
        OrderStatus.accepted => 'Detail Order',
        OrderStatus.toPickup => 'Menuju Lokasi Jemput',
        OrderStatus.arrivedPickup => 'Tiba di Lokasi',
        OrderStatus.onTrip => 'Dalam Perjalanan',
        OrderStatus.arrivedDest => 'Tiba di Tujuan',
        OrderStatus.completed => 'Ringkasan Order',
        _ => 'Order',
      };

  int _stepIndex(OrderStatus s) => switch (s) {
        OrderStatus.accepted => 0,
        OrderStatus.toPickup => 1,
        OrderStatus.arrivedPickup => 2,
        OrderStatus.onTrip => 3,
        OrderStatus.arrivedDest => 4,
        _ => 5,
      };

  Widget _navView(BuildContext context, AppState app, Order o) {
    final banner = switch (o.status) {
      OrderStatus.toPickup => '250 m • Jl. Airport Road',
      OrderStatus.onTrip => 'via Jl. Airport Road',
      _ => null,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: StepDots(total: 5, current: _stepIndex(o.status)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              MapPlaceholder(banner: banner, height: 220),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Avatar(o.customer.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.customer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(o.customer.airline, style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
                      ]),
                    ),
                    _circleBtn(Icons.call, AirColors.green),
                    const SizedBox(width: 8),
                    _circleBtn(Icons.chat_bubble, AirColors.blue),
                  ]),
                  const Divider(height: 24),
                  KVRow('Layanan', o.service.label),
                  KVRow('Waktu Jemput', '${fTime(o.scheduledAt)} • ${fDate(o.scheduledAt)}'),
                  KVRow('Pickup', o.pickup, bold: true),
                  KVRow('Tujuan', o.destination, bold: true),
                  KVRow('Unit', '${o.driver!.vehicle.name} • ${o.driver!.vehicle.plate}'),
                  KVRow('Argo', rp(o.charges.argo), bold: true, valueColor: AirColors.navy),
                ]),
              ),
            ],
          ),
        ),
        _navAction(context, app, o),
      ],
    );
  }

  Widget _navAction(BuildContext context, AppState app, Order o) {
    late String label;
    late Color color;
    late OrderStatus next;
    switch (o.status) {
      case OrderStatus.accepted:
        label = 'Mulai — Menuju Lokasi Jemput';
        color = AirColors.blue;
        next = OrderStatus.toPickup;
      case OrderStatus.toPickup:
        label = 'Saya Sudah Tiba di Lokasi';
        color = AirColors.blue;
        next = OrderStatus.arrivedPickup;
      case OrderStatus.arrivedPickup:
        label = 'Mulai Perjalanan (Crew di Kendaraan)';
        color = AirColors.green;
        next = OrderStatus.onTrip;
      case OrderStatus.onTrip:
        label = 'Akhiri Perjalanan';
        color = AirColors.red;
        next = OrderStatus.arrivedDest;
      case OrderStatus.arrivedDest:
        label = 'Konfirmasi Selesai & Rincian Biaya';
        color = AirColors.navy;
        next = OrderStatus.completed;
      default:
        label = '';
        color = AirColors.navy;
        next = o.status;
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PrimaryButton(label, color: color, onPressed: () {
          if (next == OrderStatus.completed) {
            _openCompletionSheet(context, app, o);
          } else {
            app.advanceOrder(next);
          }
        }),
      ),
    );
  }

  // ---- Step 7: completion sheet with additional charges ----
  void _openCompletionSheet(BuildContext context, AppState app, Order o) {
    showAirSheet(context, _CompletionSheet(order: o, app: app));
  }

  // ---- Step 8: rating from crew ----
  Widget _ratingView(BuildContext context, AppState app, Order o) {
    return _RatingView(order: o, app: app);
  }

  // ---- Step 9-12: order summary ----
  Widget _summaryView(BuildContext context, AppState app, Order o) {
    final c = o.charges;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: AirColors.greenLight, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: AirColors.green, size: 48),
                  ),
                  const SizedBox(height: 12),
                  const Text('Order Selesai', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text('Pendapatan otomatis masuk ke saldo Anda',
                      style: TextStyle(color: AirColors.textDim, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(o.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Pill('Selesai', AirColors.green),
                  ]),
                  const Divider(height: 22),
                  KVRow('Pickup', '${o.pickup}\n${fTime(o.scheduledAt)}'),
                  KVRow('Tujuan', o.destination),
                  KVRow('Crew', '${o.customer.name} • ${o.customer.airline}'),
                  if (o.crewRating != null)
                    KVRow('Rating dari Crew', '${'⭐' * o.crewRating!} (${o.crewRating})'),
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Rincian Pendapatan', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  KVRow('Argo', rp(c.argo)),
                  KVRow('Tol', rp(c.tol)),
                  KVRow('Parkir', rp(c.parkir)),
                  KVRow('Lainnya${c.lainnyaNote.isEmpty ? '' : ' (${c.lainnyaNote})'}', rp(c.lainnya)),
                  const Divider(height: 20),
                  KVRow('Total Diterima', rp(o.total), bold: true, valueColor: AirColors.green),
                ]),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton('Selesai — Siap Terima Order Baru', color: AirColors.green, onPressed: () {
              app.clearActive();
              Navigator.pop(context);
            }),
          ),
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

/// Bottom sheet where the driver enters the final charges before completing.
/// Total tagihan = argo + tol + parkir + lainnya.
class _CompletionSheet extends StatefulWidget {
  final Order order;
  final AppState app;
  const _CompletionSheet({required this.order, required this.app});
  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet> {
  late final TextEditingController _tol = TextEditingController();
  late final TextEditingController _parkir = TextEditingController();
  late final TextEditingController _lainnya = TextEditingController();
  final TextEditingController _lainnyaNote = TextEditingController();

  double get _argo => widget.order.charges.argo;
  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  double get _total => _argo + _num(_tol) + _num(_parkir) + _num(_lainnya);

  @override
  void dispose() {
    _tol.dispose();
    _parkir.dispose();
    _lainnya.dispose();
    _lainnyaNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AirColors.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Konfirmasi Selesai', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Tambahkan biaya tambahan bila ada. Total = argo + tol + parkir + lainnya.',
                style: TextStyle(color: AirColors.textDim, fontSize: 13)),
            const SizedBox(height: 18),
            _readonlyRow('Argo (tarif dasar)', rp(_argo)),
            const SizedBox(height: 12),
            _amountField('Biaya Tol', _tol, Icons.toll),
            const SizedBox(height: 12),
            _amountField('Biaya Parkir', _parkir, Icons.local_parking),
            const SizedBox(height: 12),
            _amountField('Biaya Lainnya', _lainnya, Icons.add_circle_outline),
            const SizedBox(height: 12),
            TextField(
              controller: _lainnyaNote,
              decoration: const InputDecoration(
                labelText: 'Keterangan biaya lainnya (opsional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AirColors.navy, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('Total Tagihan', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(),
                Text(rp(_total), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 16),
            PrimaryButton('Konfirmasi Selesai', color: AirColors.green, onPressed: () {
              widget.app.completeOrder(OrderCharges(
                argo: _argo,
                tol: _num(_tol),
                parkir: _num(_parkir),
                lainnya: _num(_lainnya),
                lainnyaNote: _lainnyaNote.text,
              ));
              Navigator.pop(context);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _readonlyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AirColors.textDim, fontSize: 13.5)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _amountField(String label, TextEditingController c, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: 'Rp ',
        hintText: '0',
      ),
    );
  }
}

class _RatingView extends StatefulWidget {
  final Order order;
  final AppState app;
  const _RatingView({required this.order, required this.app});
  @override
  State<_RatingView> createState() => _RatingViewState();
}

class _RatingViewState extends State<_RatingView> {
  int _stars = 5;
  final _fb = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(children: const [
                  Icon(Icons.emoji_events, color: AirColors.gold, size: 44),
                  SizedBox(height: 8),
                  Text('Rating dari Crew', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(children: [
                  Avatar(o.customer.name, radius: 28),
                  const SizedBox(height: 8),
                  Text(o.customer.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(o.customer.airline, style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () => setState(() => _stars = i + 1),
                        icon: Icon(i < _stars ? Icons.star : Icons.star_border, color: AirColors.gold, size: 36),
                      );
                    }),
                  ),
                  TextField(
                    controller: _fb,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Feedback (opsional)', alignLabelWithHint: true),
                  ),
                ]),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton('Kirim', onPressed: () => widget.app.submitCrewRating(_stars, _fb.text)),
          ),
        ),
      ],
    );
  }
}
