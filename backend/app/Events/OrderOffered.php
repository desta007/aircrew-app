<?php

namespace App\Events;

use App\Models\Order;
use App\Support\Present;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * An order has been offered to a specific driver — pushed to that driver's
 * private channel so their app can show the incoming order without polling.
 */
class OrderOffered implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public Order $order, public int $driverId) {}

    public function broadcastOn(): Channel
    {
        return new Channel('driver.'.$this->driverId);
    }

    public function broadcastAs(): string
    {
        return 'order.offered';
    }

    public function broadcastWith(): array
    {
        return ['order' => Present::order($this->order->loadMissing('customer', 'driver', 'area'))];
    }
}
