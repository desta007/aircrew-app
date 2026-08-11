<?php

namespace App\Services\Payment;

use Illuminate\Support\Facades\Http;

/**
 * Midtrans Core API gateway (QRIS / bank VA / card). Guarded — only bound when
 * PAYMENT_GATEWAY=midtrans and the server key is configured. Not exercised by
 * the test suite (needs a real sandbox account); the contract mirrors
 * FakePaymentGateway so the rest of the app is provider-agnostic.
 *
 * @see https://docs.midtrans.com/reference/core-api
 */
class MidtransGateway implements PaymentGateway
{
    public function name(): string
    {
        return 'midtrans';
    }

    private function serverKey(): string
    {
        return (string) config('payment.midtrans.server_key');
    }

    public function createCharge(string $ref, int $amount, string $method, array $meta = []): array
    {
        $payload = [
            'transaction_details' => ['order_id' => $ref, 'gross_amount' => $amount],
        ] + $this->methodPayload($method);

        $res = Http::withBasicAuth($this->serverKey(), '')
            ->acceptJson()
            ->post(config('payment.midtrans.base_url').'/v2/charge', $payload)
            ->json();

        return [
            'gateway' => 'midtrans',
            'gateway_ref' => $res['transaction_id'] ?? $ref,
            'status' => $this->mapStatus($res['transaction_status'] ?? 'pending'),
            'instructions' => $this->extractInstructions($method, $res ?? []),
        ];
    }

    private function methodPayload(string $method): array
    {
        return match ($method) {
            'va' => ['payment_type' => 'bank_transfer', 'bank_transfer' => ['bank' => 'bca']],
            'card' => ['payment_type' => 'credit_card'],
            default => ['payment_type' => 'qris', 'qris' => ['acquirer' => 'gopay']],
        };
    }

    private function extractInstructions(string $method, array $res): array
    {
        return match ($method) {
            'va' => ['type' => 'va', 'bank' => 'BCA', 'va_number' => $res['va_numbers'][0]['va_number'] ?? null],
            'card' => ['type' => 'redirect', 'url' => $res['redirect_url'] ?? null],
            default => ['type' => 'qris', 'qr_string' => collect($res['actions'] ?? [])->firstWhere('name', 'generate-qr-code')['url'] ?? null],
        };
    }

    public function verifyWebhook(array $payload, ?string $signature): bool
    {
        $expected = hash('sha512',
            ($payload['order_id'] ?? '').($payload['status_code'] ?? '').
            ($payload['gross_amount'] ?? '').$this->serverKey()
        );
        return hash_equals($expected, (string) ($payload['signature_key'] ?? $signature));
    }

    public function parseWebhook(array $payload): array
    {
        return [
            'ref' => $payload['order_id'] ?? null,
            'gateway_ref' => $payload['transaction_id'] ?? null,
            'status' => $this->mapStatus($payload['transaction_status'] ?? 'pending'),
        ];
    }

    private function mapStatus(string $s): string
    {
        return match ($s) {
            'capture', 'settlement' => 'paid',
            'deny', 'cancel', 'expire' => 'failed',
            default => 'pending',
        };
    }
}
