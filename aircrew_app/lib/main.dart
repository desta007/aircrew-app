import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'mitra/mitra_login.dart';
import 'customer/customer_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const AirCrewApp());
}

class AirCrewApp extends StatelessWidget {
  const AirCrewApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..pingApi(),
      child: MaterialApp(
        title: 'AirCrew',
        debugShowCheckedModeBanner: false,
        theme: AirTheme.light(),
        home: const RoleSelector(),
      ),
    );
  }
}

/// Landing screen — pick which demo app to open (Mitra Driver or Customer/Crew).
class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AirColors.navyDark, AirColors.navy, AirColors.navyLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                const AirLogo(size: 40, light: true),
                const SizedBox(height: 12),
                const Text('Mobility Platform for Airline Crew',
                    style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Demo • Pilih aplikasi',
                    style: TextStyle(color: AirColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(flex: 1),
                _RoleCard(
                  icon: Icons.directions_car_filled_rounded,
                  color: AirColors.red,
                  title: 'Aplikasi Mitra Driver',
                  subtitle: 'Terima order, jalankan trip,\ntambah biaya, withdraw saldo',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MitraLogin())),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.airline_seat_recline_extra_rounded,
                  color: AirColors.blue,
                  title: 'Aplikasi Customer (Crew)',
                  subtitle: 'Pesan jemputan/rental, bayar\ntagihan QRIS, unduh bukti',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerLogin())),
                ),
                const Spacer(flex: 2),
                Center(
                  child: Consumer<AppState>(
                    builder: (context, app, _) {
                      final on = app.apiConnected;
                      return Column(children: [
                        GestureDetector(
                          onTap: () => _showApiSettings(context, app),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (on ? AirColors.green : AirColors.gold).withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(app.booting ? Icons.sync : (on ? Icons.cloud_done : Icons.cloud_off),
                                  size: 14, color: on ? AirColors.green : AirColors.gold),
                              const SizedBox(width: 6),
                              Text(
                                  app.booting
                                      ? 'Menghubungkan…'
                                      : (on ? 'Terhubung API Laravel + PostgreSQL' : 'Mode demo (ketuk untuk atur API)'),
                                  style: TextStyle(color: on ? AirColors.green : AirColors.gold, fontSize: 11.5, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              Icon(Icons.settings, size: 12, color: (on ? AirColors.green : AirColors.gold).withValues(alpha: .7)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Sistem area tertutup • 6 area • Driver melayani area yang sama',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 12)),
                      ]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AirColors.navy)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AirColors.textDim, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AirColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user point the app at a different API base URL — needed for a
/// physical device (host LAN IP) since 10.0.2.2/127.0.0.1 only work on
/// emulator/desktop.
void _showApiSettings(BuildContext context, AppState app) {
  final ctrl = TextEditingController(text: app.apiBaseUrl);
  showDialog(
    context: context,
    builder: (dialogCtx) {
      String? status;
      bool testing = false;
      return StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('Pengaturan API'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Device fisik: gunakan IP LAN komputer (satu Wi-Fi). '
                'Emulator Android: 10.0.2.2. Web/desktop: 127.0.0.1.',
                style: TextStyle(fontSize: 12.5, color: AirColors.textDim),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://192.168.x.x:8000/api',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final u in ['http://192.168.118.10:8000/api', 'http://10.0.2.2:8000/api', 'http://127.0.0.1:8000/api'])
                  ActionChip(
                    label: Text(u.replaceAll('http://', '').replaceAll('/api', ''), style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => ctrl.text = u),
                  ),
              ]),
              if (status != null) ...[
                const SizedBox(height: 10),
                Text(status!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: status!.startsWith('✓') ? AirColors.green : AirColors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Tutup')),
            ElevatedButton(
              onPressed: testing
                  ? null
                  : () async {
                      setState(() {
                        testing = true;
                        status = 'Menghubungkan…';
                      });
                      final ok = await app.reconnect(ctrl.text);
                      setState(() {
                        testing = false;
                        status = ok ? '✓ Terhubung ke API' : '✗ Gagal — cek IP, firewall, & php artisan serve --host=0.0.0.0';
                      });
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AirColors.navy, minimumSize: const Size(110, 44)),
              child: const Text('Hubungkan'),
            ),
          ],
        ),
      );
    },
  );
}
