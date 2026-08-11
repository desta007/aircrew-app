<?php

namespace App\Services;

use App\Models\Withdrawal;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Pays out a driver withdrawal to their bank/e-wallet. Defaults to a "fake"
 * provider that succeeds instantly (demo/tests). With DISBURSEMENT_PROVIDER=xendit
 * and a secret key it calls Xendit; the final status normally arrives via a
 * disbursement webhook (out of scope here — see docs).
 *
 * @see https://developers.xendit.co/api-reference/#create-disbursement
 */
class DisbursementService
{
    /** Submit a withdrawal for payout; sets gateway/gateway_ref and status. */
    public function disburse(Withdrawal $withdrawal): Withdrawal
    {
        $provider = (string) config('payment.disbursement.provider', 'fake');

        if ($provider === 'xendit' && config('payment.disbursement.xendit_secret')) {
            return $this->xendit($withdrawal);
        }

        // Fake provider — instant success (H+0) / accepted for processing (H+1).
        $withdrawal->forceFill([
            'gateway' => 'fake',
            'gateway_ref' => 'DIS-'.strtoupper(bin2hex(random_bytes(4))),
            'status' => $withdrawal->speed === 'h0' ? 'Berhasil' : 'Proses',
        ])->save();

        return $withdrawal;
    }

    private function xendit(Withdrawal $withdrawal): Withdrawal
    {
        try {
            $res = Http::withBasicAuth((string) config('payment.disbursement.xendit_secret'), '')
                ->acceptJson()
                ->post('https://api.xendit.co/disbursements', [
                    'external_id' => $withdrawal->ref,
                    'amount' => $withdrawal->received,
                    'bank_code' => strtoupper($withdrawal->method),
                    'account_holder_name' => $withdrawal->driver?->name ?? 'Driver',
                    'account_number' => preg_replace('/\D/', '', $withdrawal->account),
                ])->json();

            $withdrawal->forceFill([
                'gateway' => 'xendit',
                'gateway_ref' => $res['id'] ?? null,
                'status' => 'Proses', // final state arrives via webhook
            ])->save();
        } catch (\Throwable $e) {
            Log::warning('Xendit disbursement failed: '.$e->getMessage());
        }

        return $withdrawal;
    }
}
