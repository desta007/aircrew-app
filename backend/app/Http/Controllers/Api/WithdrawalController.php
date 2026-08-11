<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\WalletTransaction;
use App\Models\Withdrawal;
use App\Services\DisbursementService;
use App\Support\Present;
use Illuminate\Http\Request;

class WithdrawalController extends Controller
{
    public function __construct(private DisbursementService $disbursement) {}

    private function driver(Request $request): Driver
    {
        $user = $request->user();
        if ($user instanceof Driver) {
            return $user->loadMissing('area');
        }
        $code = $request->query('driver', 'DRV-001');
        return Driver::with('area')->where('code', $code)->firstOrFail();
    }

    public function index(Request $request)
    {
        $d = $this->driver($request);
        $items = $d->withdrawals()->latest('requested_at')->get();
        return response()->json(['withdrawals' => $items->map(fn ($w) => Present::withdrawal($w))->values()]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'nominal' => 'required|integer|min:50000',
            'speed' => 'required|in:h1,h0',
            'method' => 'required|in:bank,ovo,dana,gopay',
            'account' => 'required|string',
        ]);

        $d = $this->driver($request);
        if ($data['nominal'] > $d->balance) {
            return response()->json(['message' => 'Nominal melebihi saldo tersedia.'], 422);
        }

        $fee = $data['speed'] === 'h0' ? 5000 : 0;
        $ref = 'WD'.now()->format('ymdHis').random_int(10, 99);

        $w = Withdrawal::create([
            'ref' => $ref,
            'driver_id' => $d->id,
            'nominal' => $data['nominal'],
            'fee' => $fee,
            'speed' => $data['speed'],
            'method' => $data['method'],
            'account' => $data['account'],
            'status' => 'Proses',
            'requested_at' => now(),
        ]);

        $d->decrement('balance', $data['nominal']);
        WalletTransaction::create([
            'driver_id' => $d->id,
            'ref' => $ref,
            'type' => 'withdrawal',
            'amount' => $data['nominal'],
            'label' => 'Withdraw '.strtoupper($data['method']),
            'occurred_at' => now(),
        ]);

        // Submit the payout to the disbursement provider (sets gateway/ref/status).
        $this->disbursement->disburse($w);

        return response()->json(['withdrawal' => Present::withdrawal($w->load('driver'))], 201);
    }
}
