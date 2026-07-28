<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\WalletTransaction;
use App\Support\Present;
use Illuminate\Http\Request;

class MitraController extends Controller
{
    /** Resolve the authenticated driver from the Sanctum token. */
    private function driver(Request $request): Driver
    {
        $user = $request->user();
        if ($user instanceof Driver) {
            return $user->loadMissing('area');
        }
        // Fallback for unauthenticated/demo requests.
        $code = $request->query('driver', 'DRV-001');
        return Driver::with('area')->where('code', $code)->firstOrFail();
    }

    public function me(Request $request)
    {
        $d = $this->driver($request);
        return response()->json([
            'driver' => Present::driver($d),
            'pendapatan' => $this->pendapatanSummary($d),
        ]);
    }

    public function toggleOnline(Request $request)
    {
        $d = $this->driver($request);
        $d->online = $request->boolean('online');
        $d->status = $d->online ? 'online' : 'offline';
        $d->save();
        return response()->json(['driver' => Present::driver($d)]);
    }

    /**
     * The latest order waiting for a driver in this driver's area
     * (closed-area system). Returns null when there is nothing to accept, so the
     * app can show an "menunggu order" empty state instead of a stale demo order.
     */
    public function incoming(Request $request)
    {
        $d = $this->driver($request);
        $order = Order::with('customer', 'driver', 'area')
            ->where('status', 'waiting')
            ->where('area_id', $d->area_id)
            ->latest('id')
            ->first();

        return response()->json(['order' => $order ? Present::order($order) : null]);
    }

    public function accept(Request $request, string $code)
    {
        $d = $this->driver($request);
        $order = Order::with('customer', 'area')->where('code', $code)->firstOrFail();
        $order->driver_id = $d->id;
        $order->status = 'accepted';
        $order->save();
        return response()->json(['order' => Present::order($order->load('driver'))]);
    }

    public function reject(Request $request, string $code)
    {
        $order = Order::where('code', $code)->firstOrFail();
        $order->status = 'cancelled';
        $order->save();
        return response()->json(['ok' => true]);
    }

    public function advance(Request $request, string $code)
    {
        $request->validate(['status' => 'required|string']);
        $order = Order::with('customer', 'driver', 'area')->where('code', $code)->firstOrFail();
        $order->status = $request->string('status');
        $order->save();
        return response()->json(['order' => Present::order($order)]);
    }

    /**
     * Complete an order with final charges.
     * Total tagihan = argo + tol + parkir + lainnya.
     */
    public function complete(Request $request, string $code)
    {
        $data = $request->validate([
            'argo' => 'required|integer|min:0',
            'tol' => 'nullable|integer|min:0',
            'parkir' => 'nullable|integer|min:0',
            'lainnya' => 'nullable|integer|min:0',
            'lainnya_note' => 'nullable|string',
        ]);

        $order = Order::with('customer', 'driver', 'area')->where('code', $code)->firstOrFail();
        $order->fill([
            'argo' => $data['argo'],
            'tol' => $data['tol'] ?? 0,
            'parkir' => $data['parkir'] ?? 0,
            'lainnya' => $data['lainnya'] ?? 0,
            'lainnya_note' => $data['lainnya_note'] ?? null,
            'status' => 'completed',
            'completed_at' => now(),
        ]);
        $order->save();

        // Credit driver wallet + trip count.
        if ($order->driver) {
            $order->driver->increment('balance', $order->total);
            $order->driver->increment('trips');
            WalletTransaction::create([
                'driver_id' => $order->driver_id,
                'ref' => $order->code,
                'type' => 'income',
                'amount' => $order->total,
                'label' => 'Pendapatan order',
                'occurred_at' => now(),
            ]);
        }

        // Generate the customer invoice on completion (if not already present),
        // closing the end-to-end chain: customer order → driver trip → invoice.
        $order->loadMissing('invoice');
        if (! $order->invoice) {
            $scheduled = $order->scheduled_at ?? now();
            Invoice::create([
                'code' => 'INV-'.now()->format('ymd').'-'.random_int(1000, 9999),
                'order_id' => $order->id,
                'customer_id' => $order->customer_id,
                'period_start' => $scheduled->copy()->startOfMonth()->toDateString(),
                'period_end' => $scheduled->copy()->endOfMonth()->toDateString(),
                'due_date' => now()->addDays(14)->toDateString(),
            ]);
        }

        return response()->json(['order' => Present::order($order)]);
    }

    public function rate(Request $request, string $code)
    {
        $data = $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string',
        ]);
        $order = Order::where('code', $code)->firstOrFail();
        $order->crew_rating = $data['rating'];
        $order->crew_feedback = $data['feedback'] ?? null;
        $order->save();
        return response()->json(['ok' => true]);
    }

    public function pendapatan(Request $request)
    {
        $d = $this->driver($request);
        $wallet = $d->walletTransactions()->latest('occurred_at')->get();
        return response()->json([
            'summary' => $this->pendapatanSummary($d),
            'wallet' => $wallet->map(fn ($t) => Present::walletTx($t))->values(),
        ]);
    }

    public function orderHistory(Request $request)
    {
        $d = $this->driver($request);
        $orders = Order::with('customer', 'driver', 'area')
            ->where('driver_id', $d->id)
            ->where('status', 'completed')
            ->latest('completed_at')
            ->get();
        return response()->json(['orders' => $orders->map(fn ($o) => Present::order($o))->values()]);
    }

    private function pendapatanSummary(Driver $d): array
    {
        return [
            'saldo_tersedia' => (int) $d->balance,
            'saldo_tertahan' => (int) $d->held_balance,
            'total_pendapatan' => (int) $d->walletTransactions()->where('type', 'income')->sum('amount') + 5625000,
            'hari_ini' => 320000,
            'minggu_ini' => 2450000,
            'bulan_ini' => 5750000,
        ];
    }
}
