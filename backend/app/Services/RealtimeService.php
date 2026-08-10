<?php

namespace App\Services;

use App\Events\DriverLocationUpdated;
use App\Events\OrderOffered;
use App\Events\OrderStatusChanged;
use App\Models\Order;
use Illuminate\Support\Facades\Log;

/**
 * Central place to emit realtime events. Every call is wrapped so a broadcasting
 * misconfiguration (or the default "null" connection before Reverb is set up)
 * can never break an API request — realtime is an enhancement, not a dependency.
 */
class RealtimeService
{
    public function orderOffered(Order $order, int $driverId): void
    {
        $this->safe(fn () => broadcast(new OrderOffered($order, $driverId)));
    }

    public function orderStatusChanged(Order $order): void
    {
        $this->safe(fn () => broadcast(new OrderStatusChanged($order)));
    }

    public function driverLocationUpdated(string $orderCode, float $lat, float $lng): void
    {
        $this->safe(fn () => broadcast(new DriverLocationUpdated($orderCode, $lat, $lng)));
    }

    private function safe(callable $fn): void
    {
        try {
            $fn();
        } catch (\Throwable $e) {
            Log::debug('Realtime broadcast skipped: '.$e->getMessage());
        }
    }
}
