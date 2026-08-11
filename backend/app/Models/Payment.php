<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    protected $fillable = [
        'ref', 'invoice_id', 'amount', 'method', 'status',
        'gateway', 'gateway_ref', 'instructions', 'paid_at',
    ];

    protected $casts = [
        'paid_at' => 'datetime',
        'instructions' => 'array',
    ];

    public function isPaid(): bool
    {
        return $this->status === 'paid';
    }

    public function invoice(): BelongsTo
    {
        return $this->belongsTo(Invoice::class);
    }
}
