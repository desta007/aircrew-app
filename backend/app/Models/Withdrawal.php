<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Withdrawal extends Model
{
    protected $fillable = [
        'ref', 'driver_id', 'nominal', 'fee', 'speed', 'method', 'account', 'status', 'requested_at',
    ];

    protected $casts = ['requested_at' => 'datetime'];

    public function getReceivedAttribute(): int
    {
        return (int) ($this->nominal - $this->fee);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }
}
