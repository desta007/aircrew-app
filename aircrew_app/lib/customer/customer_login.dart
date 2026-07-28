import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'customer_shell.dart';

/// Customer (Crew) login — step 1 of the customer order flow.
class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});
  @override
  State<CustomerLogin> createState() => _CustomerLoginState();
}

class _CustomerLoginState extends State<CustomerLogin> {
  final _id = TextEditingController(text: 'budi.crew@garuda.co.id');
  final _pw = TextEditingController(text: 'demo1234');
  bool _obscure = true;
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    final result = await app.loginCustomer(_id.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case LoginResult.success:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerShell()));
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerShell()));
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
                  decoration: BoxDecoration(color: AirColors.navy, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                const AirLogo(size: 30),
                const SizedBox(height: 6),
                const Text('Mobility Platform for Airline Crew', style: TextStyle(color: AirColors.textDim, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(height: 36),
            const Text('Selamat Datang, Crew 👋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 4),
            const Text('Masuk untuk memesan jemputan & rental.', style: TextStyle(color: AirColors.textDim)),
            const SizedBox(height: 24),
            TextField(controller: _id, decoration: const InputDecoration(labelText: 'Email / ID Crew', prefixIcon: Icon(Icons.person_outline))),
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
            PrimaryButton(_loading ? 'Memproses…' : 'Login', onPressed: _loading ? null : _login),
            const SizedBox(height: 20),
            Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AirColors.textDim, fontSize: 13),
                  children: [
                    TextSpan(text: 'Belum punya akun? '),
                    TextSpan(text: 'Daftar', style: TextStyle(color: AirColors.red, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
