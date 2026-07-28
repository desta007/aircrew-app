import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'mitra_shell.dart';

/// Mitra Driver login — authenticates against the database (Sanctum token).
class MitraLogin extends StatefulWidget {
  const MitraLogin({super.key});
  @override
  State<MitraLogin> createState() => _MitraLoginState();
}

class _MitraLoginState extends State<MitraLogin> {
  final _id = TextEditingController(text: 'drv-001@aircrew.id');
  final _pw = TextEditingController(text: 'demo1234');
  bool _obscure = true;
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    final result = await app.loginMitra(_id.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case LoginResult.success:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MitraShell()));
      case LoginResult.invalidCredentials:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email atau password salah.'), backgroundColor: AirColors.red),
        );
      case LoginResult.offline:
        _offerDemo();
    }
  }

  Future<void> _offerDemo() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server tidak terjangkau'),
        content: const Text('Tidak dapat terhubung ke server AirCrew. Periksa koneksi internet Anda, atau masuk mode demo dengan data contoh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mode Demo')),
        ],
      ),
    );
    if (go == true && mounted) {
      context.read<AppState>().enterDemoMode();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MitraShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            Center(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AirColors.red, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                const AirLogo(size: 30),
                const SizedBox(height: 6),
                const Text('Aplikasi Mitra Driver', style: TextStyle(color: AirColors.textDim, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(height: 36),
            const Text('Masuk Mitra Driver 🚗', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 4),
            const Text('Login untuk menerima order di area Anda.', style: TextStyle(color: AirColors.textDim)),
            const SizedBox(height: 24),
            TextField(controller: _id, decoration: const InputDecoration(labelText: 'Email / ID Driver', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 14),
            TextField(
              controller: _pw,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerRight, child: Text('Lupa Password?', style: TextStyle(color: AirColors.blue, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            PrimaryButton(_loading ? 'Memproses…' : 'Login', color: AirColors.red, onPressed: _loading ? null : _login),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AirColors.surface, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AirColors.textDim),
                SizedBox(width: 8),
                Expanded(child: Text('Demo: drv-001@aircrew.id / demo1234', style: TextStyle(fontSize: 12.5, color: AirColors.textDim))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
