<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Sanctum\HasApiTokens;

class Driver extends Model
{
    use HasApiTokens;

    protected $fillable = [
        'code', 'name', 'email', 'password', 'area_id', 'rating', 'status', 'online',
        'balance', 'held_balance', 'trips', 'vehicle_name', 'vehicle_plate',
        'current_lat', 'current_lng', 'location_updated_at',
    ];

    protected $hidden = ['password'];

    protected $casts = [
        'online' => 'boolean',
        'rating' => 'decimal:2',
        'current_lat' => 'decimal:7',
        'current_lng' => 'decimal:7',
        'location_updated_at' => 'datetime',
    ];

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function walletTransactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }

    public function withdrawals(): HasMany
    {
        return $this->hasMany(Withdrawal::class);
    }

    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }
}
