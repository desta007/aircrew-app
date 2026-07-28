import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Akun Saya — driver profile + area-system info + menu.
class MitraAccount extends StatelessWidget {
  const MitraAccount({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.driver;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Saya'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(children: [
              Avatar(d.name, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  Text('${d.id} • Mitra Driver', style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star, color: AirColors.gold, size: 15),
                    Text(' ${d.rating}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 10),
                    Pill('Area ${d.area}', AirColors.blue),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Unit Kendaraan', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.directions_car, color: AirColors.navy),
                const SizedBox(width: 10),
                Text('${d.vehicle.name}  •  ${d.vehicle.plate}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AirColors.navy, AirColors.navyLight]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Row(children: [
                Icon(Icons.hub, color: AirColors.gold, size: 20),
                SizedBox(width: 8),
                Text('Sistem Area Tertutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
              SizedBox(height: 8),
              Text(
                'Anda hanya menerima order dari customer di area yang sama. '
                'Setiap area dikelola ~10 mitra driver & ~100 customer.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _menu(Icons.account_balance_wallet, 'Rekening & E-Wallet'),
          _menu(Icons.lock, 'PIN & Keamanan'),
          _menu(Icons.help_outline, 'Bantuan / Support 24/7'),
          _menu(Icons.description, 'Ketentuan & Kebijakan'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              context.read<AppState>().logout();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            icon: const Icon(Icons.logout, color: AirColors.red),
            label: const Text('Keluar', style: TextStyle(color: AirColors.red, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: AirColors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AirColors.line)),
      child: ListTile(
        leading: Icon(icon, color: AirColors.navy),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, color: AirColors.textDim),
      ),
    );
  }
}
