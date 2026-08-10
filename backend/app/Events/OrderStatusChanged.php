<?php

namespace App\Events;

use App\Models\Order;
use App\Support\Present;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * An order's status advanced (accepted → … → completed / cancelled / no_driver).
 * Pushed to the per-order channel so the customer app tracks it live.
 */
class OrderStatusChanged implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public Order $order) {}

    public function broadcastOn(): Channel
    {
        return new Channel('order.'.$this->order->code);
    }

    public function broadcastAs(): string
    {
        return 'order.status';
    }

    public function broadcastWith(): array
    {
        return ['order' => Present::order($this->order->loadMissing('customer', 'driver', 'area'))];
    }
}
