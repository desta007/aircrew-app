<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('withdrawals', function (Blueprint $table) {
            $table->id();
            $table->string('ref')->unique();          // WD2505180000123
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->bigInteger('nominal');
            $table->bigInteger('fee')->default(0);
            $table->string('speed');                  // h1 (gratis) | h0 (instan 5000)
            $table->string('method');                 // bank | ovo | dana | gopay
            $table->string('account');
            $table->string('status')->default('Proses'); // Proses | Berhasil
            $table->timestamp('requested_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('withdrawals');
    }
};
