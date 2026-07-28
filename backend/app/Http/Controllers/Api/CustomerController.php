<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Invoice;
use App\Models\Order;
use App\Support\Present;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    private function customer(Request $request): Customer
    {
        $user = $request->user();
        if ($user instanceof Customer) {
            return $user->loadMissing('area');
        }
        $code = $request->query('customer', 'CST-001');
        return Customer::with('area')->where('code', $code)->firstOrFail();
    }

    public function me(Request $request)
    {
        $c = $this->customer($request);
        return response()->json(['customer' => Present::customer($c)]);
    }

    /** Drivers available in the customer's area (closed-area system). */
    public function drivers(Request $request)
    {
        $c = $this->customer($request);
        $drivers = Driver::with('area')->where('area_id', $c->area_id)->orderByDesc('rating')->get();
        if ($drivers->isEmpty()) {
            $drivers = Driver::with('area')->orderByDesc('rating')->limit(3)->get();
        }
        return response()->json(['drivers' => $drivers->map(fn ($d) => Present::driver($d))->values()]);
    }

    /**
     * Create an order from the customer app.
     *
     * Normal flow: the order is created with status `waiting` so it appears in
     * the driver's incoming list (closed-area system) and the driver can accept
     * it. The invoice is generated later by the driver on completion.
     *
     * Legacy/offline flow: when `completed` is true the order is finalised
     * immediately with charges (argo + tol + parkir + lainnya) and an invoice
     * is generated — giving a full DB-backed order → invoice → payment chain.
     */
    public function storeOrder(Request $request)
    {
        $data = $request->validate([
            'service' => 'required|in:scheduled,rental3,rental5,rental8',
            'pickup' => 'required|string',
            'destination' => 'required|string',
            'scheduled_at' => 'required|date',
            'driver' => 'nullable|string',
            'argo' => 'required|integer|min:0',
            'tol' => 'nullable|integer|min:0',
            'parkir' => 'nullable|integer|min:0',
            'lainnya' => 'nullable|integer|min:0',
            'completed' => 'nullable|boolean',
        ]);

        $c = $this->customer($request);
        $driver = ($data['driver'] ?? null)
            ? Driver::where('code', $data['driver'])->first()
            : Driver::where('area_id', $c->area_id)->first();

        $completed = $data['completed'] ?? false;
        $scheduledAt = \Illuminate\Support\Carbon::parse($data['scheduled_at']);

        $order = Order::create([
            'code' => 'ORD-'.now()->format('ymd').'-'.random_int(10000, 99999),
            'customer_id' => $c->id,
            'driver_id' => $driver?->id,
            'area_id' => $c->area_id,
            'service' => $data['service'],
            'pickup' => $data['pickup'],
            'destination' => $data['destination'],
            'scheduled_at' => $data['scheduled_at'],
            'distance_km' => 12,
            'eta_minutes' => 25,
            'status' => $completed ? 'completed' : 'waiting',
            'argo' => $data['argo'],
            'tol' => $data['tol'] ?? 0,
            'parkir' => $data['parkir'] ?? 0,
            'lainnya' => $data['lainnya'] ?? 0,
            'completed_at' => $completed ? now() : null,
        ]);

        $invoice = null;
        if ($completed) {
            $invoice = Invoice::create([
                'code' => 'INV-'.now()->format('ymd').'-'.random_int(1000, 9999),
                'order_id' => $order->id,
                'customer_id' => $c->id,
                'period_start' => $scheduledAt->copy()->startOfMonth()->toDateString(),
                'period_end' => $scheduledAt->copy()->endOfMonth()->toDateString(),
                'due_date' => now()->addDays(14)->toDateString(),
            ]);
        }

        return response()->json([
            'order' => Present::order($order->load('customer', 'driver', 'area')),
            'invoice' => $invoice ? Present::invoice($invoice->load('order.customer', 'order.driver', 'payments')) : null,
        ], 201);
    }

    public function orderHistory(Request $request)
    {
        $c = $this->customer($request);
        $orders = Order::with('customer', 'driver', 'area')
            ->where('customer_id', $c->id)
            ->latest('scheduled_at')
            ->get();
        return response()->json(['orders' => $orders->map(fn ($o) => Present::order($o))->values()]);
    }

    /**
     * Show a single order (used by the customer app to poll live status while a
     * driver picks it up and drives the trip: waiting → accepted → … → completed).
     */
    public function showOrder(Request $request, string $code)
    {
        $c = $this->customer($request);
        $order = Order::with('customer', 'driver', 'area')
            ->where('code', $code)
            ->where('customer_id', $c->id)
            ->firstOrFail();
        return response()->json(['order' => Present::order($order)]);
    }

    /** Customer (crew) rates the driver after the trip is completed. */
    public function rateOrder(Request $request, string $code)
    {
        $data = $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string',
        ]);
        $c = $this->customer($request);
        $order = Order::where('code', $code)->where('customer_id', $c->id)->firstOrFail();
        $order->crew_rating = $data['rating'];
        $order->crew_feedback = $data['feedback'] ?? null;
        $order->save();
        return response()->json(['ok' => true]);
    }
}
