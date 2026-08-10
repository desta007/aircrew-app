<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Phase 2 — rotate expired dispatch offers to the next nearest driver.
// Requires the scheduler to run: `php artisan schedule:work` (or a cron entry).
Schedule::command('dispatch:expire')->everyMinute()->withoutOverlapping();
