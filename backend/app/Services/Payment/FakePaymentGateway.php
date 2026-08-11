<?php

namespace App\Services\Payment;

/**
 * Deterministic in-house gateway for development, demos and automated tests.
 * Generates realistic-looking payment instructions and signs its own webhooks
 * with an HMAC so the confirmation path can be exercised without an external
 * provider. Mirrors the shape a real gateway (Midtrans/Xendit) returns.
 */
class FakePaymentGateway implements PaymentGateway
{
    public function name(): string
    {
        return 'fake';
    }

    public function createCharge(string $ref, int $amount, string $method, array $meta = []): array
    {
        $status = config('payment.fake.auto_confirm') ? 'paid' : 'pending';

        return [
            'gateway' => 'fake',
            'gateway_ref' => 'FAKE-'.strtoupper(bin2hex(random_bytes(5))),
            'status' => $status,
            'instructions' => $this->instructions($ref, $amount, $method),
        ];
    }

    private function instructions(string $ref, int $amount, string $method): array
    {
        return match ($method) {
            'va' => ['type' => 'va', 'bank' => 'BCA', 'va_number' => '8808'.substr(preg_replace('/\D/', '', $ref).'00000000', 0, 10)],
            'card' => ['type' => 'redirect', 'url' => 'https://pay.fake.local/checkout/'.$ref],
            default => ['type' => 'qris', 'qr_string' => 'FAKEQR|'.$ref.'|'.$amount],
        };
    }

    public function verifyWebhook(array $payload, ?string $signature): bool
    {
        return hash_equals($this->sign($payload), (string) $signature);
    }

    public function parseWebhook(array $payload): array
    {
        return [
            'ref' => $payload['ref'] ?? null,
            'gateway_ref' => $payload['gateway_ref'] ?? null,
            'status' => $payload['status'] ?? 'pending',
        ];
    }

    /** Signature a caller (or our own test) must send in the X-Callback-Signature header. */
    public function sign(array $payload): string
    {
        $base = ($payload['ref'] ?? '').'|'.($payload['gateway_ref'] ?? '').'|'.($payload['status'] ?? '');
        return hash_hmac('sha256', $base, (string) config('payment.fake.webhook_secret'));
    }
}
