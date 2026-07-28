<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Area;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Order;
use App\Models\Withdrawal;
use App\Support\Present;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    /**
     * Operational monitoring snapshot per area (matches the infographic).
     * Kept as representative "today" figures; the record lists below are live DB data.
     */
    private const AREA_SNAPSHOT = [
        ['area' => 'Utara',   'driver' => 8,  'aircrew' => 76,  'order' => 48, 'revenue' => 5620000],
        ['area' => 'Timur',   'driver' => 6,  'aircrew' => 62,  'order' => 36, 'revenue' => 3840000],
        ['area' => 'Pusat',   'driver' => 12, 'aircrew' => 120, 'order' => 85, 'revenue' => 9750000],
        ['area' => 'Barat',   'driver' => 7,  'aircrew' => 68,  'order' => 41, 'revenue' => 3980000],
        ['area' => 'Selatan', 'driver' => 5,  'aircrew' => 50,  'order' => 35, 'revenue' => 1660000],
    ];

    private const TREND = [
        ['d' => 'Sen', 'orders' => 198, 'revenue' => 19800000],
        ['d' => 'Sel', 'orders' => 212, 'revenue' => 21400000],
        ['d' => 'Rab', 'orders' => 187, 'revenue' => 18600000],
        ['d' => 'Kam', 'orders' => 234, 'revenue' => 23900000],
        ['d' => 'Jum', 'orders' => 256, 'revenue' => 26100000],
        ['d' => 'Sab', 'orders' => 241, 'revenue' => 24500000],
        ['d' => 'Min', 'orders' => 245, 'revenue' => 24850000],
    ];

    private function areaColors(): array
    {
        return Area::pluck('color', 'name')->toArray();
    }

    public function dashboard()
    {
        $colors = $this->areaColors();
        $areas = collect(self::AREA_SNAPSHOT)->map(fn ($a) => $a + ['color' => $colors[$a['area']] ?? '#6B7590']);

        return response()->json([
            'totals' => [
                'driver' => 38,
                'aircrew' => 376,
                'order_today' => 245,
                'revenue_today' => 24850000,
            ],
            'areas' => $areas->values(),
            'trend' => self::TREND,
            'recent_orders' => Order::with('customer', 'driver', 'area')->latest('id')->limit(5)->get()
                ->map(fn ($o) => Present::order($o))->values(),
        ]);
    }

    public function areas()
    {
        $colors = $this->areaColors();
        $areas = collect(self::AREA_SNAPSHOT)->map(fn ($a) => $a + ['color' => $colors[$a['area']] ?? '#6B7590']);
        return response()->json(['areas' => $areas->values()]);
    }

    public function orders()
    {
        $orders = Order::with('customer', 'driver', 'area')->latest('id')->get();
        return response()->json(['orders' => $orders->map(fn ($o) => Present::order($o))->values()]);
    }

    public function drivers()
    {
        $drivers = Driver::with('area')->orderBy('code')->get();
        return response()->json(['drivers' => $drivers->map(fn ($d) => Present::driver($d))->values()]);
    }

    public function customers()
    {
        $customers = Customer::with('area')->withCount('orders')->orderBy('code')->get();
        return response()->json([
            'customers' => $customers->map(fn ($c) => Present::customer($c) + [
                'orders' => $c->orders_count,
                'spend' => (int) $c->orders->sum(fn ($o) => $o->total),
            ])->values(),
        ]);
    }

    public function withdrawals()
    {
        $items = Withdrawal::with('driver.area')->latest('requested_at')->get();
        return response()->json(['withdrawals' => $items->map(fn ($w) => Present::withdrawal($w))->values()]);
    }

    public function keuangan()
    {
        $colors = $this->areaColors();
        $areas = collect(self::AREA_SNAPSHOT)->map(function ($a) use ($colors) {
            $komisi = (int) round($a['revenue'] * 0.2);
            return $a + [
                'color' => $colors[$a['area']] ?? '#6B7590',
                'komisi' => $komisi,
                'driver_share' => $a['revenue'] - $komisi,
            ];
        });
        $totalRevenue = $areas->sum('revenue');
        return response()->json([
            'areas' => $areas->values(),
            'total_revenue' => $totalRevenue,
            'total_komisi' => (int) round($totalRevenue * 0.2),
            'total_withdrawal' => (int) Withdrawal::sum('nominal'),
            'driver_balance_total' => (int) Driver::sum('balance'),
        ]);
    }
}
