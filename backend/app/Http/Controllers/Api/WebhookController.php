<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Payment\PaymentService;
use App\Support\Present;
use Illuminate\Http\Request;

/**
 * Public payment gateway callback. Unauthenticated by design (the gateway calls
 * it) but every payload is signature-verified inside PaymentService before any
 * state changes; confirmation is idempotent.
 */
class WebhookController extends Controller
{
    public function __construct(private PaymentService $payments) {}

    public function payment(Request $request)
    {
        // Signature travels in a header (fake/Xendit style) or in the body
        // (Midtrans puts signature_key in the payload).
        $signature = $request->header('X-Callback-Signature');
        $payment = $this->payments->handleWebhook($request->all(), $signature);

        return response()->json(['ok' => true, 'payment' => Present::payment($payment)]);
    }
}
