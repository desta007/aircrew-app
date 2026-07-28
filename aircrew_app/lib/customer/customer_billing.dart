import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'receipt.dart';

/// Tagihan / Invoice list — entry to the payment (QRIS partial) flow.
class CustomerBilling extends StatelessWidget {
  const CustomerBilling({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan Saya'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AirColors.navy, AirColors.navyLight]), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Tagihan', style: TextStyle(color: Colors.white70)),
              Text(rp(app.totalTagihan), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Belum lunas: ${rp(app.totalTagihanRemaining)}', style: const TextStyle(color: AirColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Daftar Invoice', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          ...app.invoices.map((inv) => _invoiceCard(context, inv)),
        ],
      ),
    );
  }

  Widget _invoiceCard(BuildContext context, Invoice inv) {
    final ok = inv.isPaid;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: inv))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AirColors.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(inv.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Pill(inv.statusLabel, ok ? AirColors.green : (inv.paid > 0 ? AirColors.blue : AirColors.red)),
              ]),
              const SizedBox(height: 4),
              Text('${fDate(inv.periodStart)} - ${fDate(inv.periodEnd)}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
              const Divider(height: 20),
              Row(children: [
                _miniCol('Total', rp(inv.total)),
                const SizedBox(width: 20),
                _miniCol('Sisa', rp(inv.remaining), color: inv.remaining > 0 ? AirColors.red : AirColors.green),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AirColors.textDim),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniCol(String label, String value, {Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AirColors.textDim, fontSize: 11.5)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
    ]);
  }
}

/// Invoice detail — shows charges breakdown, payments, and pay/receipt actions.
class InvoiceDetailPage extends StatelessWidget {
  final Invoice invoice;
  const InvoiceDetailPage({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>(); // rebuild after payment
    final inv = invoice;
    final c = inv.order.charges;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Invoice')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              SectionCard(
                child: Column(children: [
                  Row(children: [
                    Text(inv.id, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    Pill(inv.statusLabel, inv.isPaid ? AirColors.green : AirColors.blue),
                  ]),
                  const Divider(height: 22),
                  KVRow('Order', inv.order.id),
                  KVRow('Rute', '${inv.order.pickup} → ${inv.order.destination}'),
                  KVRow('Jatuh Tempo', fDate(inv.dueDate)),
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Rincian Tagihan', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  KVRow('Argo', rp(c.argo)),
                  KVRow('Tol', rp(c.tol)),
                  KVRow('Parkir', rp(c.parkir)),
                  KVRow('Lainnya', rp(c.lainnya)),
                  const Divider(),
                  KVRow('Total Tagihan', rp(inv.total), bold: true),
                  KVRow('Sudah Dibayar', rp(inv.paid), valueColor: AirColors.green),
                  KVRow('Sisa Tagihan', rp(inv.remaining), bold: true, valueColor: inv.remaining > 0 ? AirColors.red : AirColors.green),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('Riwayat Pembayaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              if (inv.payments.isEmpty)
                const Text('Belum ada pembayaran.', style: TextStyle(color: AirColors.textDim))
              else
                ...inv.payments.map((p) => _paymentTile(context, inv, p)),
            ]),
          ),
          if (!inv.isPaid)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton('Bayar Sekarang', color: AirColors.red, onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentFlow(invoice: inv)));
                }),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _paymentTile(BuildContext context, Invoice inv, Payment p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AirColors.line)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AirColors.greenLight, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.check, color: AirColors.green, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.method.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text('${p.ref} • ${fDateTime(p.at)}', style: const TextStyle(color: AirColors.textDim, fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(rp(p.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          GestureDetector(
            onTap: () => Receipt.share(inv, p),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.download_rounded, size: 14, color: AirColors.blue),
              Text(' Unduh Bukti', style: TextStyle(color: AirColors.blue, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

/// Payment flow (QRIS partial): pilih metode → nominal → QRIS → berhasil.
class PaymentFlow extends StatefulWidget {
  final Invoice invoice;
  const PaymentFlow({super.key, required this.invoice});
  @override
  State<PaymentFlow> createState() => _PaymentFlowState();
}

class _PaymentFlowState extends State<PaymentFlow> {
  int _step = 0; // 0 method, 1 nominal, 2 qris, 3 success
  PaymentMethod _method = PaymentMethod.qris;
  bool _partial = true;
  late double _amount = widget.invoice.remaining;
  Payment? _paid;

  Invoice get inv => widget.invoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        leading: BackButton(onPressed: () {
          if (_step == 0 || _step == 3) {
            Navigator.pop(context);
          } else {
            setState(() => _step--);
          }
        }),
      ),
      body: SafeArea(child: switch (_step) {
        0 => _methodStep(),
        1 => _nominalStep(),
        2 => _qrisStep(),
        _ => _successStep(),
      }),
    );
  }

  String _title() => switch (_step) {
        0 => 'Pilih Metode Pembayaran',
        1 => 'Pembayaran Partial',
        2 => 'QRIS Payment',
        _ => 'Pembayaran Berhasil',
      };

  Widget _methodStep() {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(child: Column(children: [
            KVRow('Total Tagihan', rp(inv.total)),
            KVRow('Sudah Dibayar', rp(inv.paid), valueColor: AirColors.green),
            KVRow('Sisa Tagihan', rp(inv.remaining), bold: true, valueColor: AirColors.red),
          ])),
          const SizedBox(height: 16),
          const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...PaymentMethod.values.map(_methodTile),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _partial,
            onChanged: (v) => setState(() => _partial = v),
            title: const Text('Pembayaran Partial', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Saya ingin bayar sebagian', style: TextStyle(fontSize: 12)),
            activeThumbColor: AirColors.navy,
            contentPadding: EdgeInsets.zero,
          ),
        ]),
      ),
      _bottom(PrimaryButton('Lanjutkan', onPressed: () => setState(() {
            _amount = _partial ? (inv.remaining / 2).roundToDouble() : inv.remaining;
            _step = _partial ? 1 : 2;
          }))),
    ]);
  }

  Widget _methodTile(PaymentMethod m) {
    final sel = _method == m;
    final icons = {PaymentMethod.qris: Icons.qr_code_2, PaymentMethod.va: Icons.account_balance, PaymentMethod.card: Icons.credit_card};
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? AirColors.navy : AirColors.line, width: sel ? 1.6 : 1)),
        child: Row(children: [
          Icon(icons[m], color: AirColors.navy),
          const SizedBox(width: 12),
          Expanded(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AirColors.navy : AirColors.line),
        ]),
      ),
    );
  }

  Widget _nominalStep() {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(child: KVRow('Sisa Tagihan', rp(inv.remaining), bold: true)),
          const SizedBox(height: 16),
          const Text('Masukkan Nominal Pembayaran', style: TextStyle(color: AirColors.textDim)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _amount.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(prefixText: 'Rp  ', prefixStyle: TextStyle(fontSize: 22, color: AirColors.navy, fontWeight: FontWeight.w900)),
            onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, children: [
            for (final v in [500000.0, 1000000.0, inv.remaining])
              GestureDetector(
                onTap: () => setState(() => _amount = v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AirColors.line)),
                  child: Text(v == inv.remaining ? 'Lunasi' : rp(v).replaceAll('Rp ', ''), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          const Text('Minimal pembayaran Rp 10.000', style: TextStyle(color: AirColors.textDim, fontSize: 12)),
        ]),
      ),
      _bottom(PrimaryButton('Lanjutkan', onPressed: _amount >= 10000 && _amount <= inv.remaining ? () => setState(() => _step = 2) : null)),
    ]);
  }

  Widget _qrisStep() {
    final payload = 'AIRCREW|${inv.id}|${_amount.toStringAsFixed(0)}|${DateTime.now().millisecondsSinceEpoch}';
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AirColors.line)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AirColors.red, borderRadius: BorderRadius.circular(4)), child: const Text('QRIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                ]),
                const SizedBox(height: 16),
                QrImageView(data: payload, size: 200, version: QrVersions.auto),
                const SizedBox(height: 16),
                const Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.w800)),
                const Text('Gunakan aplikasi mobile banking / e-wallet favorit Anda', textAlign: TextAlign.center, style: TextStyle(color: AirColors.textDim, fontSize: 12)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(10)), child: Text('Nominal: ${rp(_amount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                const SizedBox(height: 8),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.timer, size: 14, color: AirColors.textDim), SizedBox(width: 4), Text('Berlaku dalam 09:48', style: TextStyle(color: AirColors.textDim, fontSize: 12))]),
              ]),
            ),
          ),
        ]),
      ),
      _bottom(PrimaryButton('Simulasikan Pembayaran (Demo)', color: AirColors.green, onPressed: () {
        context.read<AppState>().payInvoice(inv, _amount, _method);
        _paid = inv.payments.last;
        setState(() => _step = 3);
      })),
    ]);
  }

  Widget _successStep() {
    final p = _paid!;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 16),
          Center(child: Column(children: const [
            Icon(Icons.check_circle, color: AirColors.green, size: 64),
            SizedBox(height: 10),
            Text('Pembayaran Berhasil', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ])),
          const SizedBox(height: 18),
          SectionCard(child: Column(children: [
            KVRow('Nominal', rp(p.amount), bold: true),
            KVRow('Metode Pembayaran', p.method.label),
            KVRow('Waktu', fDateTime(p.at)),
            KVRow('No. Referensi', p.ref),
            const Divider(),
            KVRow('Sisa Tagihan', rp(inv.remaining), bold: true, valueColor: inv.remaining > 0 ? AirColors.red : AirColors.green),
          ])),
          const SizedBox(height: 16),
          // Download bukti transaksi (requirement)
          PrimaryButton('Unduh Bukti Transaksi', icon: Icons.download_rounded, color: AirColors.blue, onPressed: () => Receipt.share(inv, p)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Receipt.preview(inv, p),
            icon: const Icon(Icons.visibility),
            label: const Text('Lihat / Cetak Bukti'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
      _bottom(PrimaryButton('Selesai', onPressed: () => Navigator.pop(context))),
    ]);
  }

  Widget _bottom(Widget child) => SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: child));
}
