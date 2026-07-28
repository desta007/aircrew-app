import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Riwayat Order — history of completed trips (step 11 of the flow).
class MitraOrders extends StatelessWidget {
  const MitraOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final orders = app.orderHistory;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Order'), automaticallyImplyLeading: false),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _tile(context, orders[i]),
      ),
    );
  }

  Widget _tile(BuildContext context, Order o) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            Text(o.completedAt != null ? fDateTime(o.completedAt!) : fDateTime(o.scheduledAt),
                style: const TextStyle(color: AirColors.textDim, fontSize: 12)),
            const Spacer(),
            Text(rp(o.total), style: const TextStyle(fontWeight: FontWeight.w900, color: AirColors.navy)),
          ]),
        ],
      ),
    );
  }
}
