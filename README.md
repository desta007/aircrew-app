# AirCrew — Mobility Platform for Airline Crew (Demo)

Demo lengkap sesuai flow di folder [`docs/`](docs/). Arsitektur **3 tier**:

| Tier | Teknologi | Folder |
|------|-----------|--------|
| Backend API + Database | **Laravel 13 + PostgreSQL** | [`backend/`](backend/) |
| Aplikasi mobile (Mitra Driver & Customer/Crew) | **Flutter** | [`aircrew_app/`](aircrew_app/) |
| Dashboard admin | **Web (HTML/CSS/JS)** | [`admin_dashboard/`](admin_dashboard/) |

Flutter app & dashboard **mengambil data dari API Laravel**; bila API offline keduanya
otomatis **fallback ke data demo** sehingga tetap jalan.

> Sistem **area tertutup**: setiap customer hanya dilayani driver di area yang sama
> (6 area: Utara, Timur, Pusat, Barat, Selatan, Tangerang). Dikelola oleh Kantor Pusat.

---

## 0. Backend Laravel + PostgreSQL — `backend/`

### Setup
```bash
cd backend
composer install
cp .env.example .env        # (sudah ada .env terisi untuk demo)
php artisan key:generate
# .env — sesuaikan koneksi PostgreSQL:
#   DB_CONNECTION=pgsql
#   DB_HOST=127.0.0.1
#   DB_PORT=5433
#   DB_DATABASE=aircrew
#   DB_USERNAME=postgres
#   DB_PASSWORD=Babeh123
createdb aircrew            # atau: CREATE DATABASE aircrew; via psql
php artisan migrate:fresh --seed
php artisan serve           # http://127.0.0.1:8000
```

### Skema database (9 tabel inti)
`areas` · `drivers` · `customers` · `orders` (menyimpan argo/tol/parkir/lainnya) ·
`wallet_transactions` · `withdrawals` · `invoices` · `payments`
(+ tabel bawaan Laravel). Relasi lengkap via Eloquent di [`backend/app/Models/`](backend/app/Models/).

### Endpoint API (prefix `/api`)
- **Mitra**: `GET /mitra/me`, `POST /mitra/online`, `GET /mitra/incoming`,
  `POST /mitra/orders/{code}/{accept|reject|advance|complete|rate}`,
  `GET /mitra/orders`, `GET /mitra/pendapatan`, `GET|POST /mitra/withdrawals`
- **Customer**: `GET /customer/{me|drivers|orders|invoices}`,
  `GET /customer/invoices/{code}`, `POST /customer/invoices/{code}/pay`, `POST /customer/orders`
- **Admin**: `GET /admin/{dashboard|areas|orders|drivers|customers|withdrawals|keuangan}`

> Seeder ada di [`backend/database/seeders/DatabaseSeeder.php`](backend/database/seeders/DatabaseSeeder.php)
> — 6 area, 6 driver, 5 customer, 7 order, 2 invoice + pembayaran.
> Total tagihan order = **argo + tol + parkir + lainnya** (dihitung di model `Order`).

### Akun demo (login cek database + token Sanctum)
Semua akun berpassword **`demo1234`**. Login menerima **email atau kode**.

| Peran | Email | Kode |
|-------|-------|------|
| **Mitra Driver** | `drv-001@aircrew.id` | `DRV-001` |
| Mitra Driver | `drv-004@aircrew.id` | `DRV-004` |
| **Customer (Crew)** | `budi.crew@garuda.co.id` | `CST-001` |
| Customer (Crew) | `rina.crew@citilink.co.id` | `CST-002` |
| Customer (Crew) | `andi.crew@lionair.co.id` | `CST-003` |

**Autentikasi: Laravel Sanctum (bearer token).**
- `POST /api/auth/mitra/login` & `POST /api/auth/customer/login` → mengembalikan `token`.
- Semua endpoint `mitra/*` & `customer/*` dilindungi `auth:sanctum`; kirim header
  `Authorization: Bearer <token>`. Tanpa token → `401`.
- `GET /api/auth/me` (info user token), `POST /api/auth/logout` (revoke token).
- Password diverifikasi `Hash::check`; salah password → `401`.
- Endpoint `admin/*` tetap publik (dashboard demo).

Di app Flutter: driver & customer kini punya **layar login masing-masing**; token
disimpan di `ApiClient` dan otomatis dikirim di setiap request. Tombol **Keluar**
memanggil `/auth/logout`.

---

## 1. Flutter App — `aircrew_app/`

Satu project Flutter dengan **role selector** di layar awal → pilih **Mitra Driver** atau **Customer (Crew)**.
Karena data & model dipakai bersama, keduanya berada dalam satu codebase; untuk produksi bisa
di-split jadi 2 APK memakai Flutter flavors.

### Menjalankan
```bash
cd aircrew_app
flutter pub get
flutter run                 # pilih device (Android / Chrome / Windows)
# atau bangun APK:
flutter build apk --debug   # -> build/app/outputs/flutter-apk/app-debug.apk
```

**Koneksi ke API**: base URL diatur otomatis di [`lib/core/api.dart`](aircrew_app/lib/core/api.dart) —
`10.0.2.2:8000` untuk emulator Android, `127.0.0.1:8000` untuk Chrome/desktop. Layar awal
menampilkan badge **"Terhubung API Laravel + PostgreSQL"** bila backend aktif, atau
**"Mode demo"** bila offline. Test integrasi: `flutter test test/api_integration_test.dart`
(otomatis skip bila server mati).

### Aplikasi Mitra Driver — sesuai flow "Proses Orderan Mitra Driver" & "Withdrawal Saldo"
- Beranda: status **Online/Offline**, saldo, kartu **order masuk** (Terima/Tolak).
- Siklus order 12 langkah: terima → menuju jemput → tiba → mulai perjalanan → tiba tujuan →
  **konfirmasi selesai** → rating dari crew → ringkasan → pendapatan masuk → riwayat.
- **Konfirmasi selesai + biaya tambahan** (permintaan klien):
  **Total = argo + tol + parkir + lainnya** (dengan keterangan).
- Pendapatan: saldo tersedia/tertahan/total, ringkasan harian/mingguan/bulanan, riwayat transaksi.
- **Withdrawal 8 langkah**: metode (Transfer Bank / OVO / DANA / GoPay) → **WD H+1 gratis / H+0 instan Rp 5.000**
  → nominal (min. Rp 50.000) → konfirmasi → **PIN** → berhasil + riwayat withdraw.

### Aplikasi Customer (Crew) — sesuai flow "Proses Order dari Crew" & "Pembayaran QRIS"
- Login → Beranda (total tagihan) → **Pilih Layanan** (Jemputan Terjadwal / Rental 3-5-8 Jam).
- Order: detail → **pilih driver & unit** (Favorit/Random, hanya area sama) → konfirmasi →
  order diterima → **tracking** driver → selesai + **rating driver**.
- **Tagihan/Invoice**: rincian biaya → **pilih pembayaran** (QRIS/VA/Kartu) → **partial payment** →
  **QRIS** (QR di-generate) → berhasil → status & riwayat pembayaran.
- **Unduh Bukti Transaksi** (permintaan klien): setiap pembayaran menghasilkan **PDF bukti transaksi**
  yang bisa disimpan / dibagikan / dicetak (via plugin `printing`).

---

## 2. Admin Web Dashboard — `admin_dashboard/`

Web statis (HTML/CSS/JS, tanpa build step) sesuai flow **"Dashboard Monitoring Area"**.

### Menjalankan
Buka `admin_dashboard/index.html` langsung di browser, atau:
```bash
cd admin_dashboard
python -m http.server 8080      # atau: npx serve .
# buka http://localhost:8080
```

### Menu
Dashboard (stat cards + tabel area + **peta sebaran** + tren 7 hari), Order, Driver, AirCrew/Customer,
**Area** (sistem area tertutup + beban kerja), Keuangan (komisi platform 20%), **Withdrawal**
(approve WD), Laporan (export demo), Pengaturan.

---

## Struktur
```
aircrew-app/
├── docs/                     # screenshot flow (referensi)
├── backend/                  # Laravel 13 + PostgreSQL (API + database)
│   ├── app/Models/           # Eloquent: Area, Driver, Customer, Order, ...
│   ├── app/Http/Controllers/Api/   # Mitra, Customer, Invoice, Withdrawal, Admin
│   ├── app/Support/Present.php     # transform model -> JSON
│   ├── database/migrations/  # skema 9 tabel
│   ├── database/seeders/     # DatabaseSeeder (data demo)
│   └── routes/api.php        # definisi endpoint
├── aircrew_app/              # Flutter app (Mitra + Customer)
│   └── lib/
│       ├── core/             # theme, models(+fromJson), seed, app_state, api, widgets
│       ├── mitra/            # aplikasi driver
│       └── customer/         # aplikasi crew (+ receipt PDF)
└── admin_dashboard/          # web dashboard (index.html, app.js, api.js, data.js, styles.css)
```

## Cara menjalankan semuanya (urutan)
```bash
# 1) Backend
cd backend && php artisan migrate:fresh --seed && php artisan serve
# 2) Dashboard admin (terminal lain)
cd admin_dashboard && python -m http.server 8080     # buka http://localhost:8080
# 3) Flutter (terminal lain)
cd aircrew_app && flutter run
```
Jalankan backend lebih dulu agar Flutter & dashboard menarik data live dari PostgreSQL.

## Catatan Demo
- Sumber data utama: **PostgreSQL via API Laravel** (seeder `DatabaseSeeder`). Bila API mati,
  Flutter memakai `aircrew_app/lib/core/seed.dart` dan dashboard memakai `admin_dashboard/data.js`.
- Order baru, penyelesaian order (+biaya), withdrawal, dan pembayaran **tersimpan ke database**
  saat API aktif (mutasi lewat endpoint POST).
- Pembayaran QRIS & withdrawal disimulasikan (tombol "Demo") — belum ada payment gateway nyata.
- PIN withdrawal menerima 4 digit apa saja untuk keperluan demo.
- Autentikasi masih demo (driver/customer default via query `?driver=` / `?customer=`);
  siap ditingkatkan ke Laravel Sanctum untuk produksi.
