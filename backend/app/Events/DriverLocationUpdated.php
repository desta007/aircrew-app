<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * The assigned driver moved — pushed to the active order's channel so the
 * customer app animates the driver marker live (no polling).
 */
class DriverLocationUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(
        public string $orderCode,
        public float $lat,
        public float $lng,
    ) {}

    public function broadcastOn(): Channel
    {
        return new Channel('order.'.$this->orderCode);
    }

    public function broadcastAs(): string
    {
        return 'driver.location';
    }

    public function broadcastWith(): array
    {
        return ['lat' => $this->lat, 'lng' => $this->lng];
    }
}
