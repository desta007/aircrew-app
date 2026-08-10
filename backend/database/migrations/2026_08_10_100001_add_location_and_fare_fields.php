<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 1 — Location foundation.
 *
 * Adds real geocoordinates to drivers & orders and distance-based fare rules to
 * areas, so orders carry actual pickup/destination points and the argo can be
 * estimated from distance (see App\Services\FareService / RoutingService).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('areas', function (Blueprint $table) {
            // Area centre (used as a map default and dispatch anchor).
            $table->decimal('center_lat', 10, 7)->nullable()->after('color');
            $table->decimal('center_lng', 10, 7)->nullable()->after('center_lat');
            // Fare rule per area: argo = base_fare + km*per_km + min*per_min (>= min_fare).
            $table->bigInteger('base_fare')->default(10000)->after('center_lng');
            $table->bigInteger('per_km')->default(4000)->after('base_fare');
            $table->bigInteger('per_min')->default(500)->after('per_km');
            $table->bigInteger('min_fare')->default(20000)->after('per_min');
        });

        Schema::table('drivers', function (Blueprint $table) {
            $table->decimal('current_lat', 10, 7)->nullable()->after('vehicle_plate');
            $table->decimal('current_lng', 10, 7)->nullable()->after('current_lat');
            $table->timestamp('location_updated_at')->nullable()->after('current_lng');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->decimal('pickup_lat', 10, 7)->nullable()->after('pickup');
            $table->decimal('pickup_lng', 10, 7)->nullable()->after('pickup_lat');
            $table->decimal('dest_lat', 10, 7)->nullable()->after('destination');
            $table->decimal('dest_lng', 10, 7)->nullable()->after('dest_lat');
            // 'invoice' = billed on a periodic invoice (B2B, default), 'prepaid' = paid per trip.
            $table->string('payment_mode')->default('invoice')->after('status');
            // Fare quoted to the customer at order time (argo may still be adjusted on completion).
            $table->bigInteger('fare_estimate')->default(0)->after('payment_mode');
        });
    }

    public function down(): void
    {
        Schema::table('areas', function (Blueprint $table) {
            $table->dropColumn(['center_lat', 'center_lng', 'base_fare', 'per_km', 'per_min', 'min_fare']);
        });
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropColumn(['current_lat', 'current_lng', 'location_updated_at']);
        });
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['pickup_lat', 'pickup_lng', 'dest_lat', 'dest_lng', 'payment_mode', 'fare_estimate']);
        });
    }
};
