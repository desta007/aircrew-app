<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 2 — Realtime & Dispatch.
 *
 * Adds the dispatch state to orders (which driver an order is currently offered
 * to, when that offer expires, and who already declined) and a device_tokens
 * table for push notifications (FCM).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // Driver the order is currently offered to (status = 'offered').
            $table->foreignId('offered_to_driver_id')->nullable()->after('driver_id')->constrained('drivers')->nullOnDelete();
            $table->timestamp('offer_expires_at')->nullable()->after('offered_to_driver_id');
            // Drivers who declined/timed-out — never re-offer to them for this order.
            $table->json('declined_driver_ids')->nullable()->after('offer_expires_at');
        });

        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('token');
            $table->string('platform')->nullable(); // android | ios | web
            $table->timestamps();
            $table->unique('token');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropConstrainedForeignId('offered_to_driver_id');
            $table->dropColumn(['offer_expires_at', 'declined_driver_ids']);
        });
        Schema::dropIfExists('device_tokens');
    }
};
