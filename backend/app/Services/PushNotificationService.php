<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\DeviceToken;
use App\Models\Driver;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Sends push notifications via Firebase Cloud Messaging (FCM legacy HTTP API).
 *
 * No-op when no server key is configured (services.fcm.key), so the app runs
 * without Firebase during development — a log line records what *would* be sent.
 * Swap for the FCM HTTP v1 API + service-account auth for production hardening.
 */
class PushNotificationService
{
    public function toDriver(Driver $driver, string $title, string $body, array $data = []): void
    {
        $this->send($driver->deviceTokens()->pluck('token')->all(), $title, $body, $data);
    }

    public function toCustomer(Customer $customer, string $title, string $body, array $data = []): void
    {
        $this->send($customer->deviceTokens()->pluck('token')->all(), $title, $body, $data);
    }

    /** @param string[] $tokens */
    public function send(array $tokens, string $title, string $body, array $data = []): void
    {
        $tokens = array_values(array_filter($tokens));
        if (empty($tokens)) {
            return;
        }

        $key = config('services.fcm.key');
        if (empty($key)) {
            Log::info('FCM disabled — would notify', compact('title', 'body') + ['tokens' => count($tokens)]);
            return;
        }

        try {
            Http::withToken($key, 'key=')->acceptJson()->post('https://fcm.googleapis.com/fcm/send', [
                'registration_ids' => $tokens,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => $data,
            ]);
        } catch (\Throwable $e) {
            Log::warning('FCM send failed: '.$e->getMessage());
        }
    }
}
