import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'customer_order_flow.dart';

/// Customer order history (Riwayat Order).
class CustomerOrders extends StatelessWidget {
  const CustomerOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final orders = app.invoices.map((i) => i.order).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Order'), automaticallyImplyLeading: false),
      body: orders.isEmpty
          ? _empty(context)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _tile(orders[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AirColors.red,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerOrderFlow(initialService: ServiceType.scheduled))),
        icon: const Icon(Icons.add),
        label: const Text('Pesan'),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.receipt_long, size: 48, color: AirColors.textDim),
        SizedBox(height: 10),
        Text('Belum ada order', style: TextStyle(fontWeight: FontWeight.w700)),
        Text('Buat order pertama Anda dari Beranda.', style: TextStyle(color: AirColors.textDim, fontSize: 13)),
      ]),
    );
  }

  Widget _tile(Order o) {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(o.id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const Spacer(),
          Pill(o.status.label, o.status.color),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.trip_origin, size: 14, color: AirColors.green),
          const SizedBox(width: 6),
          Expanded(child: Text(o.pickup, style: const TextStyle(fontSize: 13))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.location_on, size: 14, color: AirColors.red),
          const SizedBox(width: 6),
          Expanded(child: Text(o.destination, style: const TextStyle(fontSize: 13))),
        ]),
        const Divider(height: 20),
        Row(children: [
          Text('${o.service.label} • ${fDate(o.scheduledAt)}', style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
          const Spacer(),
          Text(rp(o.total), style: const TextStyle(fontWeight: FontWeight.w900, color: AirColors.navy)),
        ]),
      ]),
    );
  }
}
