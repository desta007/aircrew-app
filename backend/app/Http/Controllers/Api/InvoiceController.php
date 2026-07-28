<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Invoice;
use App\Models\Payment;
use App\Support\Present;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
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

    /** Record a (possibly partial) payment against an invoice. */
    public function pay(Request $request, string $code)
    {
        $data = $request->validate([
            'amount' => 'required|integer|min:10000',
            'method' => 'required|in:qris,va,card',
        ]);

        $inv = Invoice::with('order', 'payments')->where('code', $code)->firstOrFail();
        if ($data['amount'] > $inv->remaining) {
            return response()->json(['message' => 'Nominal melebihi sisa tagihan.'], 422);
        }

        $prefix = strtoupper($data['method']);
        $payment = Payment::create([
            'ref' => $prefix.now()->format('ymdHis').random_int(10, 99),
            'invoice_id' => $inv->id,
            'amount' => $data['amount'],
            'method' => $data['method'],
            'paid_at' => now(),
        ]);

        $inv->load('order.customer', 'order.driver', 'payments');
        return response()->json([
            'payment' => Present::payment($payment),
            'invoice' => Present::invoice($inv),
        ], 201);
    }
}
