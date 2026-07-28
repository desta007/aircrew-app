<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('drivers', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();               // DRV-001
            $table->string('name');
            $table->foreignId('area_id')->constrained()->cascadeOnDelete();
            $table->decimal('rating', 3, 2)->default(5);
            $table->string('status')->default('offline');   // online | offline | trip
            $table->boolean('online')->default(false);
            $table->bigInteger('balance')->default(0);       // saldo tersedia (Rupiah)
            $table->bigInteger('held_balance')->default(0);  // saldo tertahan
            $table->unsignedInteger('trips')->default(0);
            $table->string('vehicle_name')->nullable();
            $table->string('vehicle_plate')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('drivers');
    }
};
