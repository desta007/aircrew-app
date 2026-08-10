<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Sanctum\HasApiTokens;

class Customer extends Model
{
    use HasApiTokens;

    protected $fillable = ['code', 'name', 'email', 'password', 'airline', 'area_id'];

    protected $hidden = ['password'];

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }
}
