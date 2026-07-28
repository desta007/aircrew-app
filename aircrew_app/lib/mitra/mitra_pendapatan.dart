import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'mitra_withdraw.dart';

/// Pendapatan — saldo, ringkasan, riwayat & entry to withdrawal (flow step 1-2).
class MitraPendapatan extends StatelessWidget {
  const MitraPendapatan({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pendapatan'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AirColors.navy, AirColors.navyLight]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Saldo Tersedia', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(rp(app.saldoTersedia), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _miniStat('Saldo Tertahan', rp(app.saldoTertahan))),
                Container(width: 1, height: 34, color: Colors.white24),
                Expanded(child: _miniStat('Total Pendapatan', rp(app.totalPendapatan))),
              ]),
              const SizedBox(height: 16),
              PrimaryButton('Withdraw Saldo', icon: Icons.account_balance, color: AirColors.red, onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MitraWithdrawFlow()));
              }),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Ringkasan Pendapatan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _summary('Hari Ini', rp(app.pendapatanHariIni), AirColors.blue)),
            const SizedBox(width: 10),
            Expanded(child: _summary('Minggu Ini', rp(app.ringkasanMingguIni), AirColors.green)),
            const SizedBox(width: 10),
            Expanded(child: _summary('Bulan Ini', rp(app.ringkasanBulanIni), AirColors.gold)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MitraWithdrawHistory())),
              child: const Text('Riwayat Withdraw'),
            ),
          ]),
          const SizedBox(height: 4),
          ...app.wallet.map(_txTile),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
    ]);
  }

  Widget _summary(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AirColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AirColors.textDim, fontSize: 11.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _txTile(WalletTx t) {
    final income = t.type == WalletTxType.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AirColors.line)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: (income ? AirColors.green : AirColors.red).withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
          child: Icon(income ? Icons.south_west : Icons.north_east, color: income ? AirColors.green : AirColors.red, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text('${t.id} • ${fDateTime(t.at)}', style: const TextStyle(color: AirColors.textDim, fontSize: 11.5)),
          ]),
        ),
        Text('${income ? '+' : '-'} ${rp(t.amount)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: income ? AirColors.green : AirColors.red, fontSize: 13.5)),
      ]),
    );
  }
}
