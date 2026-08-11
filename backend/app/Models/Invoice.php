<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Invoice extends Model
{
    protected $fillable = [
        'code', 'order_id', 'customer_id', 'period_start', 'period_end', 'due_date',
    ];

    protected $casts = [
        'period_start' => 'date',
        'period_end' => 'date',
        'due_date' => 'date',
    ];

    public function getTotalAttribute(): int
    {
        return (int) ($this->order?->total ?? 0);
    }

    public function getPaidAttribute(): int
    {
        // Only confirmed (paid) payments reduce the outstanding balance; pending
        // gateway charges do not count until the webhook confirms them.
        return (int) $this->payments->where('status', 'paid')->sum('amount');
    }

    public function getRemainingAttribute(): int
    {
        return (int) max(0, $this->total - $this->paid);
    }

    public function getStatusLabelAttribute(): string
    {
        if ($this->remaining <= 0) return 'Lunas';
        return $this->paid > 0 ? 'Sebagian' : 'Belum Lunas';
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }
}
