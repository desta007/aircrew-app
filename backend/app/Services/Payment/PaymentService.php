<?php

namespace App\Services\Payment;

use App\Models\Invoice;
use App\Models\Payment;
use App\Services\PushNotificationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Orchestrates real gateway payments against an invoice: initiate a charge
 * (returning payment instructions) and confirm it via the gateway webhook.
 * Provider-agnostic — the concrete PaymentGateway is bound in AppServiceProvider.
 */
class PaymentService
{
    public function __construct(
        private PaymentGateway $gateway,
        private PushNotificationService $push,
    ) {}

    /**
     * Start a (possibly partial) payment for [$invoice]. Creates a Payment that
     * is either already `paid` (instant methods / fake auto-confirm) or `pending`
     * with instructions the customer follows, later confirmed by the webhook.
     */
    public function initiate(Invoice $invoice, int $amount, string $method): Payment
    {
        if ($amount > $invoice->remaining) {
            throw ValidationException::withMessages(['amount' => 'Nominal melebihi sisa tagihan.']);
        }

        $ref = strtoupper($method).now()->format('ymdHis').random_int(10, 99);
        $charge = $this->gateway->createCharge($ref, $amount, $method, ['invoice' => $invoice->code]);

        $payment = Payment::create([
            'ref' => $ref,
            'invoice_id' => $invoice->id,
            'amount' => $amount,
            'method' => $method,
            'status' => $charge['status'],
            'gateway' => $charge['gateway'],
            'gateway_ref' => $charge['gateway_ref'],
            'instructions' => $charge['instructions'],
            'paid_at' => $charge['status'] === 'paid' ? now() : null,
        ]);

        if ($payment->status === 'paid') {
            $this->onPaid($payment);
        }

        return $payment;
    }

    /**
     * Handle a gateway webhook: verify signature, then confirm/fail the matching
     * payment. Idempotent — a repeated "paid" callback is a no-op.
     */
    public function handleWebhook(array $payload, ?string $signature): Payment
    {
        if (! $this->gateway->verifyWebhook($payload, $signature)) {
            abort(403, 'Invalid webhook signature.');
        }

        $data = $this->gateway->parseWebhook($payload);

        return DB::transaction(function () use ($data) {
            $payment = Payment::where('gateway_ref', $data['gateway_ref'])
                ->when(! $data['gateway_ref'], fn ($q) => $q->orWhere('ref', $data['ref']))
                ->lockForUpdate()
                ->firstOrFail();

            if ($payment->status === 'paid') {
                return $payment; // idempotent
            }

            if ($data['status'] === 'paid') {
                $payment->forceFill(['status' => 'paid', 'paid_at' => now()])->save();
                $this->onPaid($payment);
            } elseif ($data['status'] === 'failed') {
                $payment->forceFill(['status' => 'failed'])->save();
            }

            return $payment;
        });
    }

    private function onPaid(Payment $payment): void
    {
        $customer = $payment->invoice?->loadMissing('customer')->customer;
        if ($customer) {
            $this->push->toCustomer($customer, 'Pembayaran diterima',
                'Pembayaran '.$payment->ref.' berhasil.', ['invoice' => $payment->invoice->code]);
        }
    }
}
