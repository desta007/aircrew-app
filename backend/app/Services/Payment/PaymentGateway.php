<?php

namespace App\Services\Payment;

/**
 * A payment gateway. Implementations create a charge (returning payment
 * instructions) and verify + parse the provider's confirmation webhook.
 */
interface PaymentGateway
{
    /**
     * Create a charge for [$amount] (Rupiah) using [$method] (qris|va|card).
     *
     * @return array{gateway:string, gateway_ref:string, status:string, instructions:array}
     *         status is one of: pending | paid | failed
     */
    public function createCharge(string $ref, int $amount, string $method, array $meta = []): array;

    /** Verify the authenticity of a webhook payload against its signature. */
    public function verifyWebhook(array $payload, ?string $signature): bool;

    /**
     * Normalise a webhook payload.
     *
     * @return array{ref:?string, gateway_ref:?string, status:string}
     */
    public function parseWebhook(array $payload): array;

    public function name(): string;
}
