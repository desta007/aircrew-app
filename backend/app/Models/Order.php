<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    protected $fillable = [
        'code', 'customer_id', 'driver_id', 'area_id', 'service', 'pickup',
        'destination', 'scheduled_at', 'distance_km', 'eta_minutes', 'note',
        'status', 'argo', 'tol', 'parkir', 'lainnya', 'lainnya_note',
        'crew_rating', 'crew_feedback', 'completed_at',
    ];

    protected $casts = [
        'scheduled_at' => 'datetime',
        'completed_at' => 'datetime',
        'distance_km' => 'decimal:1',
    ];

    // Total tagihan = argo + tol + parkir + lainnya
    public function getTotalAttribute(): int
    {
        return (int) ($this->argo + $this->tol + $this->parkir + $this->lainnya);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class);
    }

    public function invoice(): HasOne
    {
        return $this->hasOne(Invoice::class);
    }
}
