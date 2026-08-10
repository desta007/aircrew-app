<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Area extends Model
{
    protected $fillable = [
        'name', 'color', 'center_lat', 'center_lng',
        'base_fare', 'per_km', 'per_min', 'min_fare',
    ];

    public function drivers(): HasMany
    {
        return $this->hasMany(Driver::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }
}
