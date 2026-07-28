<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();               // ORD-180525-00123
            $table->foreignId('customer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('driver_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('area_id')->constrained()->cascadeOnDelete();
            $table->string('service');                      // scheduled | rental3 | rental5 | rental8
            $table->string('pickup');
            $table->string('destination');
            $table->timestamp('scheduled_at');
            $table->decimal('distance_km', 6, 1)->default(0);
            $table->unsignedInteger('eta_minutes')->default(0);
            $table->string('note')->nullable();
            $table->string('status')->default('waiting');   // waiting..completed | cancelled

            // Charges — Total tagihan = argo + tol + parkir + lainnya
            $table->bigInteger('argo')->default(0);
            $table->bigInteger('tol')->default(0);
            $table->bigInteger('parkir')->default(0);
            $table->bigInteger('lainnya')->default(0);
            $table->string('lainnya_note')->nullable();

            $table->unsignedTinyInteger('crew_rating')->nullable();
            $table->string('crew_feedback')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
