import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/seed.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'map_picker.dart';

/// Full customer order flow (end-to-end, connected to the driver app):
/// detail → pilih driver & unit → konfirmasi → order dibuat (waiting) →
/// driver menerima → tracking status live → trip selesai → rating driver.
///
/// When the backend is reachable the order is created as a real `waiting` order
/// and its status is polled while a driver accepts and drives the trip. Offline
/// it falls back to a self-contained local demo so the flow still works.
class CustomerOrderFlow extends StatefulWidget {
  final ServiceType initialService;
  const CustomerOrderFlow({super.key, required this.initialService});
  @override
  State<CustomerOrderFlow> createState() => _CustomerOrderFlowState();
}

class _CustomerOrderFlowState extends State<CustomerOrderFlow> {
  int _step = 0; // 0 detail, 1 driver, 2 confirm, 3 accepted, 4 tracking, 5 done
  late ServiceType _service = widget.initialService;
  final _pickup = TextEditingController(text: 'Hotel Novotel Bandara');
  final _dest = TextEditingController(text: 'Terminal 3 - CGK');
  DateTime _schedule = _defaultSchedule();
  // Default pickup time: next round hour from now, today.
  static DateTime _defaultSchedule() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1, 0);
  }
  Driver? _driver;
  bool _favorite = true;
  int _rating = 5;
  final _comment = TextEditingController();

  // Phase 1 — map-selected coordinates + live distance-based fare estimate.
  LatLngPoint? _pickupPoint;
  LatLngPoint? _destPoint;
  FareEstimate? _estimate;
  bool _estimating = false;

  // End-to-end (online) order tracking.
  String? _orderCode; // set when a real waiting order is created
  bool _online = false; // this order is DB-backed and being polled
  bool _submitting = false;
  OrderStatus _serverStatus = OrderStatus.waiting;
  Order? _lastOrder; // most recent snapshot from the poll
  Timer? _poll;

  // Drivers in the customer's area (closed-area system). Loaded from the API
  // when online; falls back to seed data filtered by the customer's area.
  List<Driver> _areaDrivers = [];
  bool _driversLoaded = false;

  /// Live distance-based estimate when both map points are picked; otherwise a
  /// static per-service fallback (used offline or before points are chosen).
  double get _price => _estimate?.fareEstimate ?? switch (_service) {
        ServiceType.scheduled => 125000,
        ServiceType.rental3 => 350000,
        ServiceType.rental5 => 550000,
        ServiceType.rental8 => 800000,
      };

  /// Open the map picker for pickup/destination, store the point, then refresh
  /// the fare estimate once both ends are known.
  Future<void> _pickOnMap({required bool isPickup}) async {
    final picked = await MapLocationPicker.show(
      context,
      title: isPickup ? 'Pilih Titik Jemput' : 'Pilih Tujuan',
      initial: isPickup ? _pickupPoint : _destPoint,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickupPoint = picked;
      } else {
        _destPoint = picked;
      }
    });
    await _refreshEstimate();
  }

  /// Recompute distance/ETA/fare from the backend when both points are set.
  Future<void> _refreshEstimate() async {
    final p = _pickupPoint, d = _destPoint;
    if (p == null || d == null) return;
    final app = context.read<AppState>();
    setState(() => _estimating = true);
    final est = await app.estimateFare(service: _service, pickup: p, destination: d);
    if (!mounted) return;
    setState(() {
      _estimate = est;
      _estimating = false;
    });
  }

  // "Searching" covers waiting/offered/no-driver; a driver is truly assigned
  // only once the order advances to accepted or beyond.
  bool get _accepted => _serverStatus != OrderStatus.waiting &&
      _serverStatus != OrderStatus.offered &&
      _serverStatus != OrderStatus.noDriver;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  /// Load the drivers serving the customer's area (closed-area system).
  Future<void> _loadDrivers() async {
    final app = context.read<AppState>();
    final fromApi = await app.areaDrivers();
    if (!mounted) return;
    setState(() {
      _areaDrivers = fromApi.isNotEmpty
          ? fromApi
          : Seed.drivers.where((d) => d.area == app.crew.area).toList();
      if (_areaDrivers.isEmpty) _areaDrivers = Seed.drivers.take(3).toList();
      _driversLoaded = true;
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pickup.dispose();
    _dest.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        leading: BackButton(onPressed: () {
          if (_step == 0 || _step >= 3) {
            _poll?.cancel();
            Navigator.pop(context);
          } else {
            setState(() => _step--);
          }
        }),
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => _detailStep(),
          1 => _driverStep(),
          2 => _confirmStep(),
          3 => _acceptedStep(),
          4 => _trackingStep(),
          _ => _doneStep(),
        },
      ),
    );
  }

  String _title() => switch (_step) {
        0 => 'Detail Order',
        1 => 'Pilih Driver',
        2 => 'Konfirmasi Order',
        3 => _accepted ? 'Order Diterima' : 'Mencari Driver',
        4 => 'Perjalanan Anda',
        _ => 'Perjalanan Selesai',
      };

  // ---- Order creation + status polling (online path) ----

  Future<void> _submitOrder() async {
    final app = context.read<AppState>();
    if (app.apiConnected) {
      setState(() => _submitting = true);
      final order = await app.createWaitingOrder(
        service: _service,
        pickup: _pickup.text,
        destination: _dest.text,
        scheduledAt: _schedule,
        driver: _driver?.id,
        argo: _price,
        pickupPoint: _pickupPoint,
        destPoint: _destPoint,
      );
      if (!mounted) return;
      if (order != null) {
        _orderCode = order.id;
        _online = true;
        _serverStatus = order.status;
        _lastOrder = order;
        setState(() {
          _submitting = false;
          _step = 3;
        });
        _startPolling();
        return;
      }
      // Fall through to the local demo if creation failed.
      setState(() => _submitting = false);
    }
    // Offline / fallback: pretend the driver accepts immediately.
    setState(() {
      _online = false;
      _serverStatus = OrderStatus.accepted;
      _step = 3;
    });
  }

  void _startPolling() {
    _poll?.cancel();
    final app = context.read<AppState>();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final code = _orderCode;
      if (code == null) return;
      final o = await app.refreshCustomerOrder(code);
      if (!mounted || o == null) return;
      setState(() {
        _serverStatus = o.status;
        _lastOrder = o;
        if (o.driver != null) _driver = o.driver;
      });
      if (o.status == OrderStatus.completed) {
        _poll?.cancel();
        await app.refreshInvoices();
        if (mounted) setState(() => _step = 5);
      }
    });
  }

  // Step: order detail
  Widget _detailStep() {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Jenis Layanan', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: ServiceType.values.map((s) {
            final sel = _service == s;
            return ChoiceChip(
              label: Text(s.label),
              selected: sel,
              onSelected: (_) {
                setState(() => _service = s);
                _refreshEstimate();
              },
              selectedColor: AirColors.navy,
              labelStyle: TextStyle(color: sel ? Colors.white : AirColors.text, fontWeight: FontWeight.w600),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AirColors.line)),
            );
          }).toList()),
          const SizedBox(height: 16),
          _field('Waktu Jemput', '${fTime(_schedule)} • ${fDate(_schedule)}', Icons.event, onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: _schedule.isBefore(now) ? now : _schedule,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 1, now.month, now.day),
            );
            if (d == null || !mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_schedule));
            if (t != null) setState(() => _schedule = DateTime(d.year, d.month, d.day, t.hour, t.minute));
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _pickup,
            decoration: InputDecoration(
              labelText: 'Lokasi Jemput',
              prefixIcon: const Icon(Icons.trip_origin, color: AirColors.green),
              suffixIcon: IconButton(
                icon: Icon(Icons.map, color: _pickupPoint != null ? AirColors.green : AirColors.navy),
                tooltip: 'Pilih di peta',
                onPressed: () => _pickOnMap(isPickup: true),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dest,
            decoration: InputDecoration(
              labelText: 'Tujuan',
              prefixIcon: const Icon(Icons.location_on, color: AirColors.red),
              suffixIcon: IconButton(
                icon: Icon(Icons.map, color: _destPoint != null ? AirColors.green : AirColors.navy),
                tooltip: 'Pilih di peta',
                onPressed: () => _pickOnMap(isPickup: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(children: [
              Row(children: [
                const Text('Estimasi Harga', style: TextStyle(color: AirColors.textDim)),
                const Spacer(),
                if (_estimating)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: AirColors.navy))
                else
                  Text(rp(_price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AirColors.navy)),
              ]),
              if (_estimate != null) ...[
                const Divider(height: 18),
                Row(children: [
                  const Icon(Icons.route, size: 15, color: AirColors.textDim),
                  const SizedBox(width: 6),
                  Text('${_estimate!.distanceKm.toStringAsFixed(1)} km • ${_estimate!.etaMinutes} mnt',
                      style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
                  const Spacer(),
                  Text(_estimate!.source == 'osrm' ? 'rute peta' : 'estimasi', style: const TextStyle(color: AirColors.textDim, fontSize: 11)),
                ]),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 14, color: AirColors.textDim),
                    SizedBox(width: 6),
                    Expanded(child: Text('Pilih titik jemput & tujuan di peta untuk tarif berbasis jarak.',
                        style: TextStyle(color: AirColors.textDim, fontSize: 11.5))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      _bottom(PrimaryButton('Lanjutkan', onPressed: () => setState(() => _step = 1))),
    ]);
  }

  // Step: pick driver + unit
  Widget _driverStep() {
    final app = context.read<AppState>();
    if (!_driversLoaded) {
      return const Center(child: CircularProgressIndicator(color: AirColors.navy));
    }
    final drivers = _areaDrivers;
    _driver ??= drivers.first;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: _tab('Favorit', _favorite, () => setState(() => _favorite = true))),
          Expanded(child: _tab('Random', !_favorite, () => setState(() { _favorite = false; _driver = (drivers..shuffle()).first; }))),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final d in drivers) _driverTile(d),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AirColors.textDim),
              const SizedBox(width: 8),
              Expanded(child: Text('Hanya menampilkan driver di Area ${app.crew.area}.', style: const TextStyle(fontSize: 12.5, color: AirColors.textDim))),
            ]),
          ),
        ]),
      ),
      _bottom(PrimaryButton('Lanjutkan', onPressed: () => setState(() => _step = 2))),
    ]);
  }

  Widget _driverTile(Driver d) {
    final sel = _driver == d;
    return GestureDetector(
      onTap: () => setState(() => _driver = d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? AirColors.navy : AirColors.line, width: sel ? 1.6 : 1),
        ),
        child: Row(children: [
          Avatar(d.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${d.vehicle.name} • ${d.vehicle.plate}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [const Icon(Icons.star, color: AirColors.gold, size: 15), Text(' ${d.rating}')]),
            if (sel) const Icon(Icons.check_circle, color: AirColors.navy, size: 18),
          ]),
        ]),
      ),
    );
  }

  // Step: confirm
  Widget _confirmStep() {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            child: Column(children: [
              KVRow('Layanan', _service.label),
              KVRow('Waktu Jemput', '${fTime(_schedule)} • ${fDate(_schedule)}'),
              KVRow('Lokasi Jemput', _pickup.text),
              KVRow('Tujuan', _dest.text),
              const Divider(),
              Row(children: [
                Avatar(_driver!.name, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_driver!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${_driver!.vehicle.name} • ${_driver!.vehicle.plate}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
                  ]),
                ),
                Row(children: [const Icon(Icons.star, color: AirColors.gold, size: 15), Text(' ${_driver!.rating}')]),
              ]),
              const Divider(),
              KVRow('Estimasi Harga', rp(_price), bold: true, valueColor: AirColors.navy),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('Argo final dapat bertambah bila ada tol/parkir/biaya lain yang diinput driver saat perjalanan selesai.',
              style: TextStyle(color: AirColors.textDim, fontSize: 12)),
        ]),
      ),
      _bottom(PrimaryButton(
        _submitting ? 'Mengirim Order...' : 'Konfirmasi Order',
        color: AirColors.red,
        onPressed: _submitting ? null : _submitOrder,
      )),
    ]);
  }

  // Step: waiting for a driver / order accepted
  Widget _acceptedStep() {
    // Online and still waiting for a driver to accept.
    if (_online && !_accepted) {
      return Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const SizedBox(height: 30),
            Center(
              child: Column(children: const [
                SizedBox(width: 54, height: 54, child: CircularProgressIndicator(color: AirColors.navy)),
                SizedBox(height: 18),
                Text('Mencari Driver...', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              ]),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Order Anda dikirim ke driver di area Anda.\nMenunggu driver menerima.',
                textAlign: TextAlign.center, style: TextStyle(color: AirColors.textDim))),
            const SizedBox(height: 20),
            SectionCard(
              child: Column(children: [
                KVRow('Kode Order', _orderCode ?? '-'),
                KVRow('Layanan', _service.label),
                KVRow('Lokasi Jemput', _pickup.text),
                KVRow('Tujuan', _dest.text),
              ]),
            ),
          ]),
        ),
        _bottom(OutlinedButton(
          onPressed: () {
            _poll?.cancel();
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Tutup (order tetap berjalan)'),
        )),
      ]);
    }

    // Accepted — show the assigned driver.
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 20),
          Center(
            child: Column(children: const [
              Icon(Icons.check_circle, color: AirColors.green, size: 64),
              SizedBox(height: 12),
              Text('Order Anda Diterima', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ]),
          ),
          const SizedBox(height: 8),
          Center(child: Text('${_driver!.name} akan menjemput Anda', style: const TextStyle(color: AirColors.textDim))),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(children: [
              Row(children: [
                Avatar(_driver!.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_driver!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${_driver!.vehicle.name} • ${_driver!.vehicle.plate}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
                  ]),
                ),
                Row(children: [const Icon(Icons.star, color: AirColors.gold, size: 15), Text(' ${_driver!.rating}')]),
              ]),
              const Divider(height: 22),
              KVRow('Waktu Jemput', '${fDate(_schedule)} • ${fTime(_schedule)}'),
              KVRow('Lokasi Jemput', _pickup.text),
            ]),
          ),
        ]),
      ),
      _bottom(Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat), label: const Text('Chat Driver'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(width: 12),
        Expanded(child: PrimaryButton('Lihat Perjalanan', onPressed: () => setState(() => _step = 4))),
      ])),
    ]);
  }

  // Step: live tracking
  Widget _trackingStep() {
    final statusLabel = _online ? _serverStatus.label : 'Driver Menuju Lokasi';
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          MapPlaceholder(banner: 'Driver • $statusLabel', height: 260),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(children: [
              Row(children: [
                Avatar(_driver!.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_driver!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${_driver!.vehicle.name} • ${_driver!.vehicle.plate}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.phone, color: AirColors.green),
              ]),
              const Divider(height: 22),
              KVRow('Status', statusLabel, bold: true, valueColor: _serverStatus.color),
              if (!_online) KVRow('Estimasi Tiba', '15 menit lagi'),
            ]),
          ),
          if (_online) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(children: const [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: AirColors.navy)),
                SizedBox(width: 10),
                Expanded(child: Text('Status diperbarui otomatis mengikuti driver. Tagihan muncul saat perjalanan selesai.',
                    style: TextStyle(fontSize: 12.5, color: AirColors.textDim))),
              ]),
            ),
          ],
        ]),
      ),
      if (!_online)
        _bottom(Row(children: [
          Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(foregroundColor: AirColors.red, side: const BorderSide(color: AirColors.red), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Batalkan'))),
          const SizedBox(width: 12),
          Expanded(child: PrimaryButton('Selesaikan (Demo)', color: AirColors.green, onPressed: _finishTripOffline)),
        ]))
      else
        _bottom(OutlinedButton(
          onPressed: () {
            _poll?.cancel();
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Tutup (perjalanan tetap berjalan)'),
        )),
    ]);
  }

  /// Offline demo completion: build a local completed order + invoice so it
  /// still shows up in Tagihan when the backend is unreachable.
  void _finishTripOffline() {
    final app = context.read<AppState>();
    final charges = OrderCharges(argo: _price, tol: 15000, parkir: 10000);
    final order = Order(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      customer: app.crew,
      driver: _driver,
      service: _service,
      pickup: _pickup.text,
      destination: _dest.text,
      scheduledAt: _schedule,
      distanceKm: 12,
      etaMinutes: 25,
      status: OrderStatus.completed,
      charges: charges,
    )..completedAt = Seed.now;
    final inv = Invoice(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      order: order,
      periodStart: DateTime(_schedule.year, _schedule.month, 1),
      periodEnd: DateTime(_schedule.year, _schedule.month + 1, 0),
      dueDate: _schedule.add(const Duration(days: 14)),
    );
    app.invoices.insert(0, inv);
    _lastOrder = order;
    setState(() => _step = 5);
  }

  // Step: trip done + rating
  Widget _doneStep() {
    final total = _lastOrder?.total ?? (_price + 25000);
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 16),
          Center(child: Column(children: const [
            Text('Terima kasih!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AirColors.navy)),
            SizedBox(height: 4),
            Text('Perjalanan Anda telah selesai', style: TextStyle(color: AirColors.textDim)),
          ])),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(children: [
              const Text('Total Biaya', style: TextStyle(color: AirColors.textDim)),
              Text(rp(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: AirColors.navy)),
              const SizedBox(height: 4),
              const Text('argo + tol + parkir + lainnya', style: TextStyle(color: AirColors.textDim, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('Beri Rating untuk Driver', style: TextStyle(fontWeight: FontWeight.w700))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
            return IconButton(onPressed: () => setState(() => _rating = i + 1), icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: AirColors.gold, size: 38));
          })),
          TextField(controller: _comment, maxLines: 3, decoration: const InputDecoration(labelText: 'Tulis komentar (opsional)', alignLabelWithHint: true)),
        ]),
      ),
      _bottom(PrimaryButton('Kirim & Lihat Tagihan', onPressed: () {
        final app = context.read<AppState>();
        if (_online && _orderCode != null) app.rateDriver(_orderCode!, _rating, _comment.text);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terima kasih! Tagihan tersedia di menu Tagihan.')));
        Navigator.pop(context);
      })),
    ]);
  }

  // helpers
  Widget _tab(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AirColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AirColors.navy : AirColors.line),
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : AirColors.text, fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _field(String label, String value, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AirColors.line)),
        child: Row(children: [
          Icon(icon, color: AirColors.navy, size: 20),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AirColors.textDim, fontSize: 11.5)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AirColors.textDim),
        ]),
      ),
    );
  }

  Widget _bottom(Widget child) => SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: child));
}
