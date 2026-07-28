import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Customer (Crew) account/profile screen.
class CustomerAccount extends StatelessWidget {
  const CustomerAccount({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = app.crew;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Saya'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(children: [
              Avatar(c.name, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  Text('${c.id} • Airline Crew', style: const TextStyle(color: AirColors.textDim, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Row(children: [Pill(c.airline, AirColors.blue), const SizedBox(width: 8), Pill('Area ${c.area}', AirColors.green)]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _menu(Icons.receipt_long, 'Riwayat Transaksi & Bukti'),
          _menu(Icons.credit_card, 'Metode Pembayaran'),
          _menu(Icons.favorite_border, 'Driver Favorit'),
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
