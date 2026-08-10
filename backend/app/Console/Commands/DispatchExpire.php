<?php

namespace App\Console\Commands;

use App\Services\DispatchService;
use Illuminate\Console\Command;

/**
 * Expire offers past their TTL and re-dispatch them to the next nearest driver.
 * Scheduled every minute (see routes/console.php); the driver poll also triggers
 * this best-effort so offers rotate promptly even between scheduler ticks.
 */
class DispatchExpire extends Command
{
    protected $signature = 'dispatch:expire';

    protected $description = 'Re-dispatch orders whose driver offer has expired';

    public function handle(DispatchService $dispatch): int
    {
        $count = $dispatch->expireStale();
        $this->info("Re-dispatched {$count} expired offer(s).");
        return self::SUCCESS;
    }
}
