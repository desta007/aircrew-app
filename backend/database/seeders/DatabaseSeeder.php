<?php

namespace Database\Seeders;

use App\Models\Area;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\Payment;
use App\Models\WalletTransaction;
use App\Models\Withdrawal;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /** Demo password for every seeded account. */
    private const DEMO_PASSWORD = 'demo1234';

    public function run(): void
    {
        // ---- Areas (6 closed areas) ----
        // center_lat/lng anchor the map default; fare rule: argo = base + km*per_km + min*per_min (>= min_fare).
        $areaDefs = [
            ['name' => 'Utara',     'color' => '#2E63C4', 'lat' => -6.1385, 'lng' => 106.8637, 'base' => 10000, 'km' => 4000, 'min' => 500, 'minfare' => 20000],
            ['name' => 'Timur',     'color' => '#17A54A', 'lat' => -6.2250, 'lng' => 106.9004, 'base' => 10000, 'km' => 4000, 'min' => 500, 'minfare' => 20000],
            ['name' => 'Pusat',     'color' => '#E07B1A', 'lat' => -6.1865, 'lng' => 106.8340, 'base' => 12000, 'km' => 4500, 'min' => 600, 'minfare' => 25000],
            ['name' => 'Barat',     'color' => '#7A3EC4', 'lat' => -6.1683, 'lng' => 106.7588, 'base' => 10000, 'km' => 4000, 'min' => 500, 'minfare' => 20000],
            ['name' => 'Selatan',   'color' => '#E11B22', 'lat' => -6.2615, 'lng' => 106.8106, 'base' => 12000, 'km' => 4500, 'min' => 600, 'minfare' => 25000],
            ['name' => 'Tangerang', 'color' => '#C2185B', 'lat' => -6.1783, 'lng' => 106.6319, 'base' => 10000, 'km' => 4000, 'min' => 500, 'minfare' => 20000],
        ];
        $areas = [];
        foreach ($areaDefs as $a) {
            $areas[$a['name']] = Area::create([
                'name' => $a['name'], 'color' => $a['color'],
                'center_lat' => $a['lat'], 'center_lng' => $a['lng'],
                'base_fare' => $a['base'], 'per_km' => $a['km'], 'per_min' => $a['min'], 'min_fare' => $a['minfare'],
            ]);
        }

        // ---- Drivers (mitra) ----
        $driverDefs = [
            ['code' => 'DRV-001', 'name' => 'Budi Santoso',  'area' => 'Pusat',   'rating' => 4.92, 'status' => 'online',  'online' => true,  'balance' => 1250000, 'held' => 150000, 'trips' => 312, 'v' => 'Innova Reborn', 'p' => 'B 1234 ABC'],
            ['code' => 'DRV-002', 'name' => 'Andi Wijaya',   'area' => 'Pusat',   'rating' => 4.80, 'status' => 'online',  'online' => true,  'balance' => 890000,  'held' => 0,      'trips' => 268, 'v' => 'Avanza',        'p' => 'B 0678 DEF'],
            ['code' => 'DRV-003', 'name' => 'Slamet Riyadi', 'area' => 'Pusat',   'rating' => 4.90, 'status' => 'trip',    'online' => true,  'balance' => 1520000, 'held' => 90000,  'trips' => 301, 'v' => 'Innova Zenix',  'p' => 'B 9101 GHI'],
            ['code' => 'DRV-004', 'name' => 'Asep Kurnia',   'area' => 'Utara',   'rating' => 4.85, 'status' => 'online',  'online' => true,  'balance' => 640000,  'held' => 0,      'trips' => 199, 'v' => 'Xpander',       'p' => 'B 2222 JKL'],
            ['code' => 'DRV-005', 'name' => 'Rudi Hartono',  'area' => 'Selatan', 'rating' => 4.70, 'status' => 'offline', 'online' => false, 'balance' => 430000,  'held' => 0,      'trips' => 154, 'v' => 'Avanza',        'p' => 'B 3333 MNO'],
            ['code' => 'DRV-006', 'name' => 'Joko Susilo',   'area' => 'Barat',   'rating' => 4.88, 'status' => 'online',  'online' => true,  'balance' => 720000,  'held' => 0,      'trips' => 221, 'v' => 'Ertiga',        'p' => 'B 4444 PQR'],
        ];
        $drivers = [];
        foreach ($driverDefs as $d) {
            $area = $areas[$d['area']];
            // Seed a starting position jittered ~1km around the area centre.
            $jitter = fn () => (mt_rand(-90, 90) / 10000);
            $drivers[$d['code']] = Driver::create([
                'code' => $d['code'], 'name' => $d['name'], 'area_id' => $area->id,
                'email' => strtolower($d['code']).'@aircrew.id',
                'password' => Hash::make(self::DEMO_PASSWORD),
                'rating' => $d['rating'], 'status' => $d['status'], 'online' => $d['online'],
                'balance' => $d['balance'], 'held_balance' => $d['held'], 'trips' => $d['trips'],
                'vehicle_name' => $d['v'], 'vehicle_plate' => $d['p'],
                'current_lat' => $area->center_lat + $jitter(),
                'current_lng' => $area->center_lng + $jitter(),
                'location_updated_at' => now(),
            ]);
        }

        // ---- Customers (crew) ----
        $customerDefs = [
            ['code' => 'CST-001', 'name' => 'Budi Santoso',   'email' => 'budi.crew@garuda.co.id',   'airline' => 'Garuda Indonesia', 'area' => 'Pusat'],
            ['code' => 'CST-002', 'name' => 'Rina Permata',   'email' => 'rina.crew@citilink.co.id',  'airline' => 'Citilink',         'area' => 'Pusat'],
            ['code' => 'CST-003', 'name' => 'Andi Pratama',   'email' => 'andi.crew@lionair.co.id',   'airline' => 'Lion Air',         'area' => 'Utara'],
            ['code' => 'CST-004', 'name' => 'Dewi Anggraini', 'email' => 'dewi.crew@batikair.co.id',  'airline' => 'Batik Air',        'area' => 'Selatan'],
            ['code' => 'CST-005', 'name' => 'Fajar Nugroho',  'email' => 'fajar.crew@garuda.co.id',   'airline' => 'Garuda Indonesia', 'area' => 'Barat'],
        ];
        $customers = [];
        foreach ($customerDefs as $c) {
            $customers[$c['code']] = Customer::create([
                'code' => $c['code'], 'name' => $c['name'],
                'email' => $c['email'], 'password' => Hash::make(self::DEMO_PASSWORD),
                'airline' => $c['airline'], 'area_id' => $areas[$c['area']]->id,
            ]);
        }

        // ---- Orders ----
        $orderDefs = [
            ['code' => 'ORD-180525-00123', 'cust' => 'CST-001', 'drv' => 'DRV-001', 'service' => 'scheduled', 'pickup' => 'Hotel Novotel Bandara', 'dest' => 'Terminal 3 - CGK', 'at' => '2026-05-18 03:45', 'km' => 12, 'eta' => 25, 'status' => 'completed', 'argo' => 125000, 'tol' => 0,     'parkir' => 0, 'lainnya' => 0, 'rating' => 5,    'done' => '2026-05-18 04:10'],
            ['code' => 'ORD-180525-00098', 'cust' => 'CST-002', 'drv' => 'DRV-002', 'service' => 'scheduled', 'pickup' => 'Hilton Hotel',          'dest' => 'Terminal 2 - CGK', 'at' => '2026-05-18 02:35', 'km' => 9,  'eta' => 18, 'status' => 'completed', 'argo' => 100000, 'tol' => 10000, 'parkir' => 0, 'lainnya' => 0, 'rating' => 5,    'done' => '2026-05-18 02:40'],
            ['code' => 'ORD-180525-00087', 'cust' => 'CST-003', 'drv' => 'DRV-004', 'service' => 'rental3',   'pickup' => 'Apartemen Green',       'dest' => 'Terminal 1 - CGK', 'at' => '2026-05-18 01:15', 'km' => 7,  'eta' => 15, 'status' => 'onTrip',    'argo' => 350000, 'tol' => 0,     'parkir' => 0, 'lainnya' => 0, 'rating' => null, 'done' => null],
            ['code' => 'ORD-180525-00075', 'cust' => 'CST-004', 'drv' => 'DRV-005', 'service' => 'scheduled', 'pickup' => 'Rumah Crew',            'dest' => 'Terminal 2 - CGK', 'at' => '2026-05-18 05:40', 'km' => 14, 'eta' => 28, 'status' => 'waiting',   'argo' => 95000,  'tol' => 0,     'parkir' => 0, 'lainnya' => 0, 'rating' => null, 'done' => null],
            ['code' => 'ORD-180525-00061', 'cust' => 'CST-005', 'drv' => 'DRV-006', 'service' => 'rental8',   'pickup' => 'Kantor Pusat',          'dest' => 'Terminal 3 - CGK', 'at' => '2026-05-18 08:00', 'km' => 40, 'eta' => 60, 'status' => 'completed', 'argo' => 800000, 'tol' => 0,     'parkir' => 0, 'lainnya' => 0, 'rating' => 5,    'done' => '2026-05-18 16:00'],
        ];
        foreach ($orderDefs as $o) {
            Order::create([
                'code' => $o['code'],
                'customer_id' => $customers[$o['cust']]->id,
                'driver_id' => $drivers[$o['drv']]->id,
                'area_id' => $customers[$o['cust']]->area_id,
                'service' => $o['service'], 'pickup' => $o['pickup'], 'destination' => $o['dest'],
                'scheduled_at' => $o['at'], 'distance_km' => $o['km'], 'eta_minutes' => $o['eta'],
                'note' => 'Mohon standby di lobby hotel', 'status' => $o['status'],
                'argo' => $o['argo'], 'tol' => $o['tol'], 'parkir' => $o['parkir'], 'lainnya' => $o['lainnya'],
                'crew_rating' => $o['rating'], 'completed_at' => $o['done'],
            ]);
        }

        // ---- Wallet transactions ----
        $me = $drivers['DRV-001'];
        WalletTransaction::create(['driver_id' => $me->id, 'ref' => 'ORD-180525-00123', 'type' => 'income',     'amount' => 125000,  'label' => 'Pendapatan order',      'occurred_at' => '2026-05-18 04:10']);
        WalletTransaction::create(['driver_id' => $me->id, 'ref' => 'WD2505180000123',  'type' => 'withdrawal', 'amount' => 1000000, 'label' => 'Withdraw Transfer Bank', 'occurred_at' => '2026-05-18 10:25']);
        WalletTransaction::create(['driver_id' => $drivers['DRV-002']->id, 'ref' => 'ORD-180525-00098', 'type' => 'income', 'amount' => 110000, 'label' => 'Pendapatan order', 'occurred_at' => '2026-05-18 02:40']);

        // ---- Withdrawals ----
        Withdrawal::create(['ref' => 'WD2505180000123', 'driver_id' => $drivers['DRV-001']->id, 'nominal' => 1000000, 'fee' => 0,    'speed' => 'h1', 'method' => 'bank', 'account' => 'BCA • 1234 5678 9012', 'status' => 'Proses',   'requested_at' => '2026-05-19 10:25']);
        Withdrawal::create(['ref' => 'WD2505180000098', 'driver_id' => $drivers['DRV-002']->id, 'nominal' => 750000,  'fee' => 5000, 'speed' => 'h0', 'method' => 'ovo',  'account' => 'OVO • 0812 3456 7890',  'status' => 'Berhasil', 'requested_at' => '2026-05-18 14:32']);
        Withdrawal::create(['ref' => 'WD2505170000076', 'driver_id' => $drivers['DRV-004']->id, 'nominal' => 500000,  'fee' => 0,    'speed' => 'h1', 'method' => 'bank', 'account' => 'BRI • 1234 5678 9012', 'status' => 'Berhasil', 'requested_at' => '2026-05-17 09:45']);
        Withdrawal::create(['ref' => 'WD2505170000055', 'driver_id' => $drivers['DRV-005']->id, 'nominal' => 300000,  'fee' => 5000, 'speed' => 'h0', 'method' => 'dana', 'account' => 'DANA • 0812 3456 7890', 'status' => 'Berhasil', 'requested_at' => '2026-05-17 08:15']);

        // ---- Invoices + payments (customer billing) ----
        $inv1Order = Order::create([
            'code' => 'ORD-INV-00012', 'customer_id' => $customers['CST-001']->id, 'driver_id' => $drivers['DRV-001']->id,
            'area_id' => $customers['CST-001']->area_id, 'service' => 'scheduled', 'pickup' => 'Hotel Novotel Bandara',
            'destination' => 'Terminal 3 - CGK', 'scheduled_at' => '2026-05-18 03:45', 'distance_km' => 12, 'eta_minutes' => 25,
            'status' => 'completed', 'argo' => 5000000, 'tol' => 150000, 'parkir' => 50000, 'lainnya' => 50000,
            'lainnya_note' => 'Biaya tunggu', 'crew_rating' => 5, 'completed_at' => '2026-05-18 04:10',
        ]);
        $inv1 = Invoice::create(['code' => 'INV-250S-00012', 'order_id' => $inv1Order->id, 'customer_id' => $customers['CST-001']->id, 'period_start' => '2026-05-01', 'period_end' => '2026-05-31', 'due_date' => '2026-06-05']);
        Payment::create(['ref' => 'QRIS2505180310', 'invoice_id' => $inv1->id, 'amount' => 2000000, 'method' => 'qris', 'paid_at' => '2026-05-18 10:25']);

        $inv2Order = Order::create([
            'code' => 'ORD-250425-00089', 'customer_id' => $customers['CST-001']->id, 'driver_id' => $drivers['DRV-002']->id,
            'area_id' => $customers['CST-001']->area_id, 'service' => 'rental8', 'pickup' => 'Kantor Pusat',
            'destination' => 'Terminal 2 - CGK', 'scheduled_at' => '2026-04-20 08:00', 'distance_km' => 40, 'eta_minutes' => 60,
            'status' => 'completed', 'argo' => 4750000, 'tol' => 0, 'parkir' => 0, 'lainnya' => 0, 'completed_at' => '2026-04-20 16:00',
        ]);
        $inv2 = Invoice::create(['code' => 'INV-2504-00089', 'order_id' => $inv2Order->id, 'customer_id' => $customers['CST-001']->id, 'period_start' => '2026-04-01', 'period_end' => '2026-04-30', 'due_date' => '2026-05-05']);
        Payment::create(['ref' => 'VA2504300930', 'invoice_id' => $inv2->id, 'amount' => 4750000, 'method' => 'va', 'paid_at' => '2026-04-30 09:30']);

        $this->command->info('Seeded: '.Area::count().' areas, '.Driver::count().' drivers, '.Customer::count().' customers, '.Order::count().' orders, '.Invoice::count().' invoices.');
    }
}
