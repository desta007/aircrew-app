<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\WalletTransaction;
use App\Services\DispatchService;
use App\Services\RealtimeService;
use App\Support\Present;
use Illuminate\Http\Request;

class MitraController extends Controller
{
    public function __construct(
        private DispatchService $dispatch,
        private RealtimeService $realtime,
    ) {}

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
     * Store the driver's live GPS position (Phase 1). Called periodically by the
     * driver app while online/on-trip; consumed later for nearest-driver dispatch
     * and live tracking on the customer app.
     */
    public function updateLocation(Request $request)
    {
        $data = $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
        ]);
        $d = $this->driver($request);
        $d->current_lat = $data['lat'];
        $d->current_lng = $data['lng'];
        $d->location_updated_at = now();
        $d->save();

        // Stream the position to the customer of this driver's active trip (if any).
        $activeCode = Order::whereIn('status', ['accepted', 'toPickup', 'arrivedPickup', 'onTrip', 'arrivedDest'])
            ->where('driver_id', $d->id)
            ->value('code');
        if ($activeCode) {
            $this->realtime->driverLocationUpdated($activeCode, (float) $data['lat'], (float) $data['lng']);
        }

        return response()->json(['ok' => true, 'location_updated_at' => $d->location_updated_at->toIso8601String()]);
    }

    /**
     * The order currently offered to THIS driver by the dispatcher (Phase 2),
     * not yet expired. Returns null when nothing is offered so the app shows a
     * "menunggu order" empty state. Expires stale offers first (best-effort).
     */
    public function incoming(Request $request)
    {
        $d = $this->driver($request);
        $this->dispatch->expireStale();
        $order = $this->dispatch->currentOfferFor($d);

        return response()->json(['order' => $order ? Present::order($order) : null]);
    }

    public function accept(Request $request, string $code)
    {
        $d = $this->driver($request);
        $order = Order::where('code', $code)->firstOrFail();
        $accepted = $this->dispatch->accept($order, $d);
        return response()->json(['order' => Present::order($accepted)]);
    }

    public function reject(Request $request, string $code)
    {
        $d = $this->driver($request);
        $order = Order::where('code', $code)->firstOrFail();
        $this->dispatch->decline($order, $d);
        return response()->json(['ok' => true]);
    }

    /** Register/refresh an FCM device token for push notifications (Phase 2). */
    public function registerDeviceToken(Request $request)
    {
        $data = $request->validate([
            'token' => 'required|string',
            'platform' => 'nullable|string',
        ]);
        $d = $this->driver($request);
        \App\Models\DeviceToken::updateOrCreate(
            ['token' => $data['token']],
            ['driver_id' => $d->id, 'customer_id' => null, 'platform' => $data['platform'] ?? null],
        );
        return response()->json(['ok' => true]);
    }

    public function advance(Request $request, string $code)
    {
        // Restrict to the real trip states — no free-form status writes (hardening).
        $data = $request->validate([
            'status' => 'required|in:toPickup,arrivedPickup,onTrip,arrivedDest,cancelled',
        ]);
        $order = Order::with('customer', 'driver', 'area')->where('code', $code)->firstOrFail();
        $order->status = $data['status'];
        $order->save();
        $this->realtime->orderStatusChanged($order);
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

        $this->realtime->orderStatusChanged($order);

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
        // Real figures derived from the driver's income wallet transactions
        // (hardening — previously hardcoded demo constants). Fresh query per line.
        $income = fn () => WalletTransaction::where('driver_id', $d->id)->where('type', 'income');

        return [
            'saldo_tersedia' => (int) $d->balance,
            'saldo_tertahan' => (int) $d->held_balance,
            'total_pendapatan' => (int) $income()->sum('amount'),
            'hari_ini' => (int) $income()->whereDate('occurred_at', now()->toDateString())->sum('amount'),
            'minggu_ini' => (int) $income()->where('occurred_at', '>=', now()->startOfWeek())->sum('amount'),
            'bulan_ini' => (int) $income()->where('occurred_at', '>=', now()->startOfMonth())->sum('amount'),
        ];
    }
}
