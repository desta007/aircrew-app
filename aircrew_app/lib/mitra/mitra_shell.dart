import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'mitra_home.dart';
import 'mitra_orders.dart';
import 'mitra_pendapatan.dart';
import 'mitra_account.dart';

/// Bottom-nav shell for the Mitra Driver app.
class MitraShell extends StatefulWidget {
  const MitraShell({super.key});
  @override
  State<MitraShell> createState() => _MitraShellState();
}

class _MitraShellState extends State<MitraShell> {
  int _index = 0;

  final _pages = const [
    MitraHome(),
    MitraOrders(),
    MitraPendapatan(),
    MitraAccount(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AirColors.navy.withValues(alpha: .1),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Order'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Pendapatan'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
