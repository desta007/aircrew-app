<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Invoice;
use App\Services\Payment\PaymentService;
use App\Support\Present;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
    public function __construct(private PaymentService $payments) {}

    private function customer(Request $request): Customer
    {
        $user = $request->user();
        if ($user instanceof Customer) {
            return $user;
        }
        $code = $request->query('customer', 'CST-001');
        return Customer::where('code', $code)->firstOrFail();
    }

    public function index(Request $request)
    {
        $c = $this->customer($request);
        $invoices = Invoice::with('order.customer', 'order.driver', 'payments')
            ->where('customer_id', $c->id)
            ->latest('id')
            ->get();
        return response()->json([
            'invoices' => $invoices->map(fn ($i) => Present::invoice($i))->values(),
            'total_tagihan' => (int) $invoices->sum(fn ($i) => $i->total),
            'total_remaining' => (int) $invoices->sum(fn ($i) => $i->remaining),
        ]);
    }

    public function show(string $code)
    {
        $inv = Invoice::with('order.customer', 'order.driver', 'payments')->where('code', $code)->firstOrFail();
        return response()->json(['invoice' => Present::invoice($inv)]);
    }

    /**
     * Start a (possibly partial) payment against an invoice via the payment
     * gateway. Returns the payment (with instructions — QRIS string / VA number /
     * redirect URL) and the invoice. Instant methods / the fake gateway confirm
     * immediately; otherwise the payment stays `pending` until the webhook.
     */
    public function pay(Request $request, string $code)
    {
        $data = $request->validate([
            'amount' => 'required|integer|min:10000',
            'method' => 'required|in:qris,va,card',
        ]);

        $c = $this->customer($request);
        $inv = Invoice::with('order', 'payments')
            ->where('code', $code)
            ->where('customer_id', $c->id)
            ->firstOrFail();

        $payment = $this->payments->initiate($inv, $data['amount'], $data['method']);

        $inv->load('order.customer', 'order.driver', 'payments');
        return response()->json([
            'payment' => Present::payment($payment),
            'invoice' => Present::invoice($inv),
        ], 201);
    }
}
