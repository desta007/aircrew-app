<?php

namespace App\Services;

use App\Models\Driver;
use App\Models\Order;
use Illuminate\Support\Facades\DB;

/**
 * Phase 2 dispatch engine.
 *
 * Offers a waiting order to the nearest eligible online driver in the order's
 * area (closed-area system), one at a time, each with an expiry. On decline or
 * timeout the order is re-offered to the next nearest driver; when no candidate
 * remains the order becomes `no_driver`. Replaces the old "any driver in the
 * area sees the latest waiting order" behaviour.
 */
class DispatchService
{
    /** Statuses in which a driver is considered busy (unavailable for new offers). */
    private const BUSY_STATUSES = ['offered', 'accepted', 'toPickup', 'arrivedPickup', 'onTrip', 'arrivedDest'];

    public function __construct(
        private RealtimeService $realtime,
        private PushNotificationService $push,
    ) {}

    /**
     * Offer [$order] to the next best driver. Pass [$preferredDriverId] (e.g. the
     * driver the customer picked) to try that driver first.
     */
    public function dispatch(Order $order, ?int $preferredDriverId = null): Order
    {
        $driver = $this->nextCandidate($order, $preferredDriverId);

        if (! $driver) {
            $order->forceFill([
                'offered_to_driver_id' => null,
                'offer_expires_at' => null,
                'driver_id' => null,
                'status' => 'no_driver',
            ])->save();
            $this->realtime->orderStatusChanged($order);
            if ($order->customer) {
                $this->push->toCustomer($order->customer, 'Belum ada driver',
                    'Belum ada driver tersedia di area Anda. Coba lagi sebentar.', ['code' => $order->code]);
            }
            return $order;
        }

        $order->forceFill([
            'offered_to_driver_id' => $driver->id,
            'driver_id' => null,
            'status' => 'offered',
            'offer_expires_at' => now()->addSeconds((int) config('dispatch.offer_ttl', 45)),
        ])->save();

        $this->realtime->orderOffered($order, $driver->id);
        $this->realtime->orderStatusChanged($order);
        $this->push->toDriver($driver, 'Order baru masuk',
            $order->pickup.' → '.$order->destination, ['code' => $order->code]);

        return $order;
    }

    /**
     * Driver accepts the order offered to them. Locked so two drivers can never
     * accept the same order. Throws on a stale/foreign accept.
     */
    public function accept(Order $order, Driver $driver): Order
    {
        [$result, $alreadyHeld] = DB::transaction(function () use ($order, $driver) {
            $fresh = Order::whereKey($order->id)->lockForUpdate()->firstOrFail();

            // Idempotent: this driver already holds the order.
            if ($fresh->status === 'accepted' && (int) $fresh->driver_id === (int) $driver->id) {
                return [$fresh->load('customer', 'driver', 'area'), true];
            }
            if ($fresh->status !== 'offered' || (int) $fresh->offered_to_driver_id !== (int) $driver->id) {
                abort(409, 'Order sudah tidak tersedia untuk Anda.');
            }

            $fresh->forceFill([
                'driver_id' => $driver->id,
                'offered_to_driver_id' => null,
                'offer_expires_at' => null,
                'status' => 'accepted',
            ])->save();

            return [$fresh->load('customer', 'driver', 'area'), false];
        });

        if (! $alreadyHeld) {
            $this->realtime->orderStatusChanged($result);
            if ($result->customer) {
                $this->push->toCustomer($result->customer, 'Driver ditemukan',
                    ($result->driver?->name ?? 'Driver').' akan menjemput Anda.', ['code' => $result->code]);
            }
        }

        return $result;
    }

    /** Driver declines — record it and re-offer to the next nearest driver. */
    public function decline(Order $order, Driver $driver): Order
    {
        $declined = $order->declined_driver_ids ?? [];
        $declined[] = (int) $driver->id;
        $order->forceFill([
            'declined_driver_ids' => array_values(array_unique($declined)),
            'offered_to_driver_id' => null,
            'offer_expires_at' => null,
            'status' => 'waiting',
        ])->save();

        return $this->dispatch($order->fresh());
    }

    /**
     * Expire offers past their TTL and re-dispatch them (treated as a decline by
     * the driver who let it lapse). Called by the `dispatch:expire` command and
     * best-effort on driver poll. Returns the number of orders re-dispatched.
     */
    public function expireStale(): int
    {
        $expired = Order::where('status', 'offered')
            ->whereNotNull('offer_expires_at')
            ->where('offer_expires_at', '<', now())
            ->get();

        foreach ($expired as $order) {
            $driverId = $order->offered_to_driver_id;
            if ($driverId && $driver = Driver::find($driverId)) {
                $this->decline($order, $driver);
            } else {
                $this->dispatch($order);
            }
        }

        return $expired->count();
    }

    /** The order currently offered to [$driver] and not yet expired, if any. */
    public function currentOfferFor(Driver $driver): ?Order
    {
        return Order::with('customer', 'driver', 'area')
            ->where('status', 'offered')
            ->where('offered_to_driver_id', $driver->id)
            ->where(function ($q) {
                $q->whereNull('offer_expires_at')->orWhere('offer_expires_at', '>=', now());
            })
            ->latest('id')
            ->first();
    }

    /**
     * Pick the next eligible driver: online, in the order's area, not already
     * declined, not busy on another order. Ranked by distance from the pickup
     * point (nearest first) when coordinates are known.
     */
    private function nextCandidate(Order $order, ?int $preferredDriverId): ?Driver
    {
        $declined = $order->declined_driver_ids ?? [];
        $busy = $this->busyDriverIds($order->id);

        $candidates = Driver::where('area_id', $order->area_id)
            ->where('online', true)
            ->whereNotIn('id', $declined)
            ->whereNotIn('id', $busy)
            ->get();

        if ($candidates->isEmpty()) {
            return null;
        }

        // Honour the customer's preferred driver when still eligible.
        if ($preferredDriverId) {
            $preferred = $candidates->firstWhere('id', $preferredDriverId);
            if ($preferred) {
                return $preferred;
            }
        }

        // Rank by distance from the pickup point when we have coordinates.
        if ($order->pickup_lat !== null && $order->pickup_lng !== null) {
            $sorted = $candidates->sortBy(function (Driver $d) use ($order) {
                if ($d->current_lat === null || $d->current_lng === null) {
                    return PHP_FLOAT_MAX; // unknown location → last
                }
                return RoutingService::haversineKm(
                    (float) $order->pickup_lat, (float) $order->pickup_lng,
                    (float) $d->current_lat, (float) $d->current_lng,
                );
            });
            return $sorted->first();
        }

        // No pickup coordinates: fall back to the highest-rated driver.
        return $candidates->sortByDesc('rating')->first();
    }

    /** @return array<int> driver ids busy on another non-terminal order */
    private function busyDriverIds(int $exceptOrderId): array
    {
        $assigned = Order::whereIn('status', self::BUSY_STATUSES)
            ->where('id', '!=', $exceptOrderId)
            ->pluck('driver_id');
        $offered = Order::whereIn('status', self::BUSY_STATUSES)
            ->where('id', '!=', $exceptOrderId)
            ->pluck('offered_to_driver_id');

        return $assigned->merge($offered)->filter()->map(fn ($id) => (int) $id)->unique()->values()->all();
    }
}
