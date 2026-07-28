import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Withdrawal flow (8 steps): metode → nominal → konfirmasi → PIN → berhasil.
class MitraWithdrawFlow extends StatefulWidget {
  const MitraWithdrawFlow({super.key});
  @override
  State<MitraWithdrawFlow> createState() => _MitraWithdrawFlowState();
}

class _MitraWithdrawFlowState extends State<MitraWithdrawFlow> {
  int _step = 0; // 0 method, 1 nominal, 2 confirm, 3 pin, 4 success
  WithdrawMethod _method = WithdrawMethod.bank;
  WithdrawSpeed _speed = WithdrawSpeed.h1;
  double _nominal = 1000000;
  Withdrawal? _result;

  final _accounts = const {
    WithdrawMethod.bank: 'BCA • 1234 5678 9012 (Budi Santoso)',
    WithdrawMethod.ovo: 'OVO • 0812 3456 7890',
    WithdrawMethod.dana: 'DANA • 0812 3456 7890',
    WithdrawMethod.gopay: 'GoPay • 0812 3456 7890',
  };

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        leading: BackButton(onPressed: () {
          if (_step == 0 || _step == 4) {
            Navigator.pop(context);
          } else {
            setState(() => _step--);
          }
        }),
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => _methodStep(app),
          1 => _nominalStep(app),
          2 => _confirmStep(app),
          3 => _pinStep(app),
          _ => _successStep(),
        },
      ),
    );
  }

  String _title() => switch (_step) {
        0 => 'Withdraw',
        1 => 'Nominal Withdraw',
        2 => 'Konfirmasi Withdraw',
        3 => 'Verifikasi PIN',
        _ => 'Withdraw Berhasil',
      };

  Widget _balanceCard(AppState app) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AirColors.navy, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Text('Saldo Tersedia', style: TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(rp(app.saldoTersedia), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
      );

  // Step 1: method + speed
  Widget _methodStep(AppState app) {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _balanceCard(app),
          const SizedBox(height: 18),
          const Text('Pilih Metode Withdrawal', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...WithdrawMethod.values.map((m) => _methodTile(m)),
          const SizedBox(height: 18),
          const Text('Pilih Waktu Withdrawal', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _speedTile(WithdrawSpeed.h1, 'Dana masuk 1 hari kerja • Gratis biaya admin', Icons.calendar_month),
          const SizedBox(height: 10),
          _speedTile(WithdrawSpeed.h0, 'Dana masuk hari yang sama • Biaya Rp 5.000/trx', Icons.bolt),
        ]),
      ),
      _bottom(PrimaryButton('Lanjutkan', onPressed: () => setState(() => _step = 1))),
    ]);
  }

  Widget _methodTile(WithdrawMethod m) {
    final sel = _method == m;
    final icons = {
      WithdrawMethod.bank: Icons.account_balance,
      WithdrawMethod.ovo: Icons.account_balance_wallet,
      WithdrawMethod.dana: Icons.account_balance_wallet,
      WithdrawMethod.gopay: Icons.account_balance_wallet,
    };
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AirColors.navy : AirColors.line, width: sel ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(icons[m], color: AirColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(_accounts[m]!, style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
            ]),
          ),
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AirColors.navy : AirColors.line),
        ]),
      ),
    );
  }

  Widget _speedTile(WithdrawSpeed s, String desc, IconData icon) {
    final sel = _speed == s;
    final color = s == WithdrawSpeed.h1 ? AirColors.green : AirColors.red;
    return GestureDetector(
      onTap: () => setState(() => _speed = s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : AirColors.line, width: sel ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              Text(desc, style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
            ]),
          ),
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? color : AirColors.line),
        ]),
      ),
    );
  }

  // Step 2: nominal
  Widget _nominalStep(AppState app) {
    final presets = [100000.0, 500000.0, 1000000.0, app.saldoTersedia];
    final labels = ['100.000', '500.000', '1.000.000', 'Semua'];
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _balanceCard(app),
          const SizedBox(height: 18),
          const Text('Masukkan Nominal', style: TextStyle(color: AirColors.textDim)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _nominal.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(prefixText: 'Rp  ', prefixStyle: TextStyle(fontSize: 22, color: AirColors.navy, fontWeight: FontWeight.w900)),
            onChanged: (v) => _nominal = double.tryParse(v) ?? 0,
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: List.generate(4, (i) {
            return GestureDetector(
              onTap: () => setState(() => _nominal = presets[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AirColors.line)),
                child: Text(labels[i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            );
          })),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(children: [
              KVRow('Nominal Withdrawal', rp(_nominal)),
              KVRow('Biaya Admin', rp(_speed.fee)),
              const Divider(),
              KVRow('Dana yang Diterima', rp(_nominal - _speed.fee), bold: true, valueColor: AirColors.green),
              KVRow('Waktu Proses', _speed.label),
            ]),
          ),
          const SizedBox(height: 8),
          const Text('Minimal nominal withdraw Rp 50.000', style: TextStyle(color: AirColors.textDim, fontSize: 12)),
        ]),
      ),
      _bottom(PrimaryButton('Lanjutkan', onPressed: _nominal >= 50000 && _nominal <= app.saldoTersedia ? () => setState(() => _step = 2) : null)),
    ]);
  }

  // Step 3: confirm
  Widget _confirmStep(AppState app) {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            child: Column(children: [
              KVRow('Metode', _method.label),
              KVRow('Tujuan', _accounts[_method]!),
              const Divider(),
              KVRow('Nominal Withdraw', rp(_nominal)),
              KVRow('Biaya Admin', rp(_speed.fee)),
              KVRow('Dana yang Diterima', rp(_nominal - _speed.fee), bold: true, valueColor: AirColors.green),
              KVRow('Waktu Proses', _speed.label),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AirColors.greenLight, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.verified_user, color: AirColors.green, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Pastikan data rekening / e-wallet benar sebelum melanjutkan.', style: TextStyle(fontSize: 12.5))),
            ]),
          ),
        ]),
      ),
      _bottom(PrimaryButton('Konfirmasi', onPressed: () => setState(() => _step = 3))),
    ]);
  }

  // Step 4: PIN
  Widget _pinStep(AppState app) {
    return _PinPad(onComplete: () {
      _result = app.createWithdrawal(nominal: _nominal, speed: _speed, method: _method, account: _accounts[_method]!);
      setState(() => _step = 4);
    });
  }

  // Step 5: success
  Widget _successStep() {
    final w = _result!;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 16),
          Center(
            child: Column(children: const [
              Icon(Icons.check_circle, color: AirColors.green, size: 64),
              SizedBox(height: 10),
              Text('Permintaan Withdraw\nBerhasil Dibuat', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(children: [
              KVRow('Nominal', rp(w.nominal)),
              KVRow('Metode', w.method.label),
              KVRow('No. Referensi', w.id),
              KVRow('Waktu Proses', w.speed.label),
              KVRow('Status', w.status, valueColor: AirColors.blue, bold: true),
            ]),
          ),
        ]),
      ),
      _bottom(PrimaryButton('OK, Selesai', color: AirColors.green, onPressed: () => Navigator.pop(context))),
    ]);
  }

  Widget _bottom(Widget child) => SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: child));
}

/// Numeric PIN pad (verifikasi keamanan) — accepts any 4-digit PIN in demo.
class _PinPad extends StatefulWidget {
  final VoidCallback onComplete;
  const _PinPad({required this.onComplete});
  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> {
  String _pin = '';

  void _tap(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 30),
      const Text('Masukkan PIN Transaksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < _pin.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AirColors.navy : Colors.transparent,
              border: Border.all(color: AirColors.navy, width: 1.6),
            ),
          );
        }),
      ),
      const SizedBox(height: 12),
      const Text('Lupa PIN?', style: TextStyle(color: AirColors.blue, fontWeight: FontWeight.w600)),
      const Spacer(),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.7,
        children: [
          for (var n = 1; n <= 9; n++) _key('$n'),
          const SizedBox(),
          _key('0'),
          _key('⌫', isBack: true),
        ],
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _key(String label, {bool isBack = false}) {
    return InkWell(
      onTap: () {
        if (isBack) {
          if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
        } else {
          _tap(label);
        }
      },
      child: Center(
        child: Text(label, style: TextStyle(fontSize: isBack ? 22 : 26, fontWeight: FontWeight.w700, color: AirColors.navy)),
      ),
    );
  }
}

/// Riwayat Withdrawal list.
class MitraWithdrawHistory extends StatelessWidget {
  const MitraWithdrawHistory({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Withdraw')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: app.withdrawals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final w = app.withdrawals[i];
          final ok = w.status == 'Berhasil';
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(w.id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                Pill(w.status, ok ? AirColors.green : AirColors.blue),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('${w.method.label}\n${fDateTime(w.at)}', style: const TextStyle(color: AirColors.textDim, fontSize: 12))),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(rp(w.nominal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(w.speed == WithdrawSpeed.h1 ? 'H+1' : 'H+0', style: const TextStyle(color: AirColors.textDim, fontSize: 11)),
                ]),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
