<?php

namespace App\Support;

use App\Models\Driver;
use App\Models\Customer;
use App\Models\Order;
use App\Models\Withdrawal;
use App\Models\WalletTransaction;
use App\Models\Invoice;
use App\Models\Payment;

/**
 * Converts Eloquent models into the JSON shapes consumed by the Flutter apps
 * and the admin dashboard. Kept in one place so both sides stay in sync.
 */
class Present
{
    public static function driver(Driver $d): array
    {
        return [
            'id' => $d->code,
            'name' => $d->name,
            'area' => $d->area?->name,
            'rating' => (float) $d->rating,
            'status' => $d->status,
            'online' => (bool) $d->online,
            'balance' => (int) $d->balance,
            'held_balance' => (int) $d->held_balance,
            'trips' => (int) $d->trips,
            'vehicle' => [
                'name' => $d->vehicle_name,
                'plate' => $d->vehicle_plate,
            ],
            'location' => ($d->current_lat !== null && $d->current_lng !== null) ? [
                'lat' => (float) $d->current_lat,
                'lng' => (float) $d->current_lng,
                'updated_at' => optional($d->location_updated_at)->toIso8601String(),
            ] : null,
        ];
    }

    public static function customer(Customer $c): array
    {
        return [
            'id' => $c->code,
            'name' => $c->name,
            'airline' => $c->airline,
            'area' => $c->area?->name,
        ];
    }

    public static function order(Order $o): array
    {
        return [
            'id' => $o->code,
            'service' => $o->service,
            'pickup' => $o->pickup,
            'destination' => $o->destination,
            'pickup_lat' => $o->pickup_lat !== null ? (float) $o->pickup_lat : null,
            'pickup_lng' => $o->pickup_lng !== null ? (float) $o->pickup_lng : null,
            'dest_lat' => $o->dest_lat !== null ? (float) $o->dest_lat : null,
            'dest_lng' => $o->dest_lng !== null ? (float) $o->dest_lng : null,
            'scheduled_at' => optional($o->scheduled_at)->toIso8601String(),
            'distance_km' => (float) $o->distance_km,
            'eta_minutes' => (int) $o->eta_minutes,
            'note' => $o->note,
            'status' => $o->status,
            'payment_mode' => $o->payment_mode,
            'fare_estimate' => (int) $o->fare_estimate,
            'offer_expires_at' => optional($o->offer_expires_at)->toIso8601String(),
            'area' => $o->area?->name,
            'charges' => [
                'argo' => (int) $o->argo,
                'tol' => (int) $o->tol,
                'parkir' => (int) $o->parkir,
                'lainnya' => (int) $o->lainnya,
                'lainnya_note' => $o->lainnya_note,
                'total' => (int) $o->total,
            ],
            'total' => (int) $o->total,
            'crew_rating' => $o->crew_rating,
            'crew_feedback' => $o->crew_feedback,
            'completed_at' => optional($o->completed_at)->toIso8601String(),
            'customer' => $o->relationLoaded('customer') && $o->customer ? self::customer($o->customer) : null,
            'driver' => $o->relationLoaded('driver') && $o->driver ? self::driver($o->driver) : null,
        ];
    }

    public static function withdrawal(Withdrawal $w): array
    {
        return [
            'id' => $w->ref,
            'nominal' => (int) $w->nominal,
            'fee' => (int) $w->fee,
            'received' => (int) $w->received,
            'speed' => $w->speed,
            'method' => $w->method,
            'account' => $w->account,
            'status' => $w->status,
            'at' => optional($w->requested_at)->toIso8601String(),
            'driver' => $w->relationLoaded('driver') && $w->driver ? $w->driver->name : null,
            'area' => $w->relationLoaded('driver') && $w->driver ? $w->driver->area?->name : null,
        ];
    }

    public static function walletTx(WalletTransaction $t): array
    {
        return [
            'id' => $t->ref,
            'type' => $t->type,
            'amount' => (int) $t->amount,
            'label' => $t->label,
            'at' => optional($t->occurred_at)->toIso8601String(),
        ];
    }

    public static function payment(Payment $p): array
    {
        return [
            'ref' => $p->ref,
            'amount' => (int) $p->amount,
            'method' => $p->method,
            'at' => optional($p->paid_at)->toIso8601String(),
        ];
    }

    public static function invoice(Invoice $inv): array
    {
        return [
            'id' => $inv->code,
            'period_start' => optional($inv->period_start)->toDateString(),
            'period_end' => optional($inv->period_end)->toDateString(),
            'due_date' => optional($inv->due_date)->toDateString(),
            'total' => (int) $inv->total,
            'paid' => (int) $inv->paid,
            'remaining' => (int) $inv->remaining,
            'status_label' => $inv->status_label,
            'is_paid' => $inv->remaining <= 0,
            'order' => $inv->order ? self::order($inv->order->loadMissing('customer', 'driver')) : null,
            'payments' => $inv->payments->map(fn ($p) => self::payment($p))->values(),
        ];
    }
}
