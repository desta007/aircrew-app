<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 3 — Real payments & disbursement.
 *
 * A payment now models a real gateway charge: it starts `pending` with payment
 * instructions (QRIS string / VA number / redirect URL) and is confirmed `paid`
 * by the gateway webhook. Withdrawals gain a disbursement reference.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            // pending | paid | failed | expired. Existing rows default to paid.
            $table->string('status')->default('paid')->after('method');
            $table->string('gateway')->nullable()->after('status');       // fake | midtrans | xendit
            $table->string('gateway_ref')->nullable()->after('gateway');  // provider transaction id
            $table->json('instructions')->nullable()->after('gateway_ref'); // qr string / va number / url
            $table->timestamp('paid_at')->nullable()->change();           // null until confirmed
        });

        Schema::table('withdrawals', function (Blueprint $table) {
            $table->string('gateway')->nullable()->after('status');
            $table->string('gateway_ref')->nullable()->after('gateway');
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn(['status', 'gateway', 'gateway_ref', 'instructions']);
        });
        Schema::table('withdrawals', function (Blueprint $table) {
            $table->dropColumn(['gateway', 'gateway_ref']);
        });
    }
};
