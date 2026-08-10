<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Computes distance & travel time between two points.
 *
 * Primary source is OSRM (free, no API key). If OSRM is unreachable we fall back
 * to a straight-line haversine estimate with a road-winding factor so an order
 * can always be priced even offline. Swap `driver()` for Google Directions later
 * without touching callers.
 */
class RoutingService
{
    /** Public OSRM demo server; override via config/services.php ['osrm']['url']. */
    private string $osrmUrl;

    /** Assumed average speed (km/h) for the haversine fallback ETA. */
    private const FALLBACK_SPEED_KMH = 28;

    /** Straight-line distance is shorter than road distance; scale it up. */
    private const ROAD_WINDING_FACTOR = 1.35;

    public function __construct()
    {
        $this->osrmUrl = (string) config('services.osrm.url', 'https://router.project-osrm.org');
    }

    /**
     * @return array{distance_km: float, eta_minutes: int, source: string}
     */
    public function route(float $fromLat, float $fromLng, float $toLat, float $toLng): array
    {
        try {
            $url = sprintf(
                '%s/route/v1/driving/%F,%F;%F,%F',
                rtrim($this->osrmUrl, '/'),
                $fromLng, $fromLat, $toLng, $toLat
            );
            $res = Http::timeout(4)->get($url, ['overview' => 'false']);
            if ($res->ok() && ($res->json('code') === 'Ok')) {
                $r = $res->json('routes.0');
                return [
                    'distance_km' => round(($r['distance'] ?? 0) / 1000, 1),
                    'eta_minutes' => (int) ceil(($r['duration'] ?? 0) / 60),
                    'source' => 'osrm',
                ];
            }
        } catch (\Throwable $e) {
            Log::info('RoutingService OSRM fallback: '.$e->getMessage());
        }

        return $this->haversineEstimate($fromLat, $fromLng, $toLat, $toLng);
    }

    /** @return array{distance_km: float, eta_minutes: int, source: string} */
    private function haversineEstimate(float $fromLat, float $fromLng, float $toLat, float $toLng): array
    {
        $km = self::haversineKm($fromLat, $fromLng, $toLat, $toLng) * self::ROAD_WINDING_FACTOR;
        return [
            'distance_km' => round($km, 1),
            'eta_minutes' => (int) ceil($km / self::FALLBACK_SPEED_KMH * 60),
            'source' => 'haversine',
        ];
    }

    /** Great-circle distance in kilometres. */
    public static function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earth = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        return $earth * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
