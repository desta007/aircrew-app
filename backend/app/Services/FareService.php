<?php

namespace App\Services;

use App\Models\Area;

/**
 * Distance-based fare (argo) calculator.
 *
 *   argo = max(min_fare, base_fare + distance_km*per_km + eta_minutes*per_min)
 *
 * Rates are configured per area (closed-area system). Rental services are priced
 * by a flat package rather than distance. Tol / parkir / lainnya remain manual,
 * added by the driver on completion — this only produces the estimated argo.
 */
class FareService
{
    /** Flat package price (Rupiah) per rental service code. */
    private const RENTAL_PACKAGES = [
        'rental3' => 350000,
        'rental5' => 550000,
        'rental8' => 800000,
    ];

    /** Round the argo up to the nearest 1.000 for tidy pricing. */
    private const ROUND_TO = 1000;

    public function estimate(Area $area, string $service, float $distanceKm, int $etaMinutes): int
    {
        if (isset(self::RENTAL_PACKAGES[$service])) {
            return self::RENTAL_PACKAGES[$service];
        }

        $base = (int) ($area->base_fare ?? 10000);
        $perKm = (int) ($area->per_km ?? 4000);
        $perMin = (int) ($area->per_min ?? 500);
        $minFare = (int) ($area->min_fare ?? 20000);

        $raw = $base + (int) round($distanceKm * $perKm) + ($etaMinutes * $perMin);
        $fare = max($minFare, $raw);

        return (int) (ceil($fare / self::ROUND_TO) * self::ROUND_TO);
    }
}
