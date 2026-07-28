# Deploy Backend AirCrew ke Railway

Panduan deploy **Laravel 13 + PostgreSQL** ke [Railway](https://railway.app).
Build memakai `backend/Dockerfile` (sudah disediakan) sehingga hasilnya deterministik.

> Ringkas: buat project → tambah PostgreSQL → deploy service dari repo (root =
> `backend`) → set environment variables → seed data sekali → arahkan Flutter ke
> URL Railway.

---

## 0. Prasyarat

- Akun Railway (login pakai GitHub paling mudah).
- Repo ini sudah di-push ke GitHub (Railway deploy dari GitHub).
- Railway CLI (opsional, untuk seed & log): `npm i -g @railway/cli` lalu `railway login`.

---

## 1. Buat Project + Database PostgreSQL

1. Railway → **New Project** → **Deploy PostgreSQL** (atau *Empty Project* lalu
   **+ New → Database → PostgreSQL**).
2. Service database bernama **`Postgres`** akan otomatis punya variabel:
   `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `DATABASE_URL`.

---

## 2. Tambah Service Backend (dari GitHub)

1. Di project yang sama: **+ New → GitHub Repo** → pilih repo ini.
2. Buka service → **Settings**:
   - **Root Directory**: `backend`  ← penting, karena Laravel ada di subfolder.
   - **Builder**: **Dockerfile** (Railway otomatis mendeteksi `backend/Dockerfile`).
3. **Networking → Generate Domain** untuk mendapat URL publik, mis.
   `https://aircrew-backend-production.up.railway.app`.

---

## 3. Environment Variables

Buka service backend → tab **Variables** → tambahkan berikut.

**Cara koneksi DB yang disarankan: satu variabel `DB_URL`** (paling anti-gagal —
tidak bergantung pada nama variabel per-field yang rawan salah ketik):

```bash
APP_NAME=AirCrew
APP_ENV=production
APP_DEBUG=false
APP_KEY=            # isi dari langkah 3a
APP_URL=https://<domain-railway-anda>.up.railway.app

LOG_CHANNEL=stderr  # log tampil di Railway Deploy Logs

DB_CONNECTION=pgsql
DB_URL=${{Postgres.DATABASE_URL}}
```

`DATABASE_URL` disediakan otomatis oleh service Postgres (format
`postgresql://user:pass@host:port/db`). Laravel mem-parsing-nya dan otomatis
mengisi host/port/database/user/password — mengabaikan `DB_HOST` dkk.

> **PENTING soal nama service:** `${{Postgres.DATABASE_URL}}` mereferensikan
> service database bernama **`Postgres`**. Bila service database Anda bernama lain
> (lihat di sidebar Railway), ganti `Postgres` sesuai nama itu — mis.
> `${{postgres.DATABASE_URL}}` atau `${{railway-db.DATABASE_URL}}`. Referensi yang
> salah nama membuat variabel kosong → Laravel jatuh ke default `127.0.0.1`
> (lihat bagian **Troubleshooting**).

### Alternatif: variabel per-field

Bila lebih suka eksplisit, ganti `DB_URL` dengan lima variabel ini (semua
memakai reference ke service Postgres — sesuaikan nama `Postgres`):

```bash
DB_CONNECTION=pgsql
DB_HOST=${{Postgres.PGHOST}}
DB_PORT=${{Postgres.PGPORT}}
DB_DATABASE=${{Postgres.PGDATABASE}}
DB_USERNAME=${{Postgres.PGUSER}}
DB_PASSWORD=${{Postgres.PGPASSWORD}}
```

> Jangan campur keduanya. `DB_URL` menang bila keduanya ada. Koneksi lewat jaringan
> privat Railway, jadi `DB_SSLMODE` default (`prefer`) sudah aman.
> **Jangan** set `DB_PORT=5433` (itu port lokal Anda) — biarkan dari reference.

### 3a. APP_KEY

Laravel wajib punya `APP_KEY`. Generate di lokal lalu tempel nilainya ke Variables:

```bash
cd backend
php artisan key:generate --show     # keluaran: base64:xxxxxxxx...
```

Salin `base64:...` ke variable `APP_KEY` di Railway.

---

## 4. Deploy & Migrasi

- Setiap push ke branch yang terhubung memicu build ulang.
- Saat container start, `Dockerfile` menjalankan `php artisan migrate --force`
  otomatis (idempotent — aman dijalankan berulang).

### Seed data demo (sekali saja)

Migrasi hanya membuat tabel kosong. Untuk mengisi 6 area / 6 driver / 5 customer /
order / invoice demo, jalankan **sekali** lewat shell service:

```bash
# via Railway CLI (dari folder backend, sudah `railway link` ke project)
railway run php artisan db:seed --force

# atau reset penuh + seed (menghapus semua data lalu isi ulang):
railway run php artisan migrate:fresh --seed --force
```

Alternatif tanpa CLI: Railway → service → **⋯ → Shell**, lalu jalankan perintah
`php artisan db:seed --force` di sana.

Akun demo (password semua `demo1234`):
`drv-001@aircrew.id` / `DRV-001` (driver), `budi.crew@garuda.co.id` / `CST-001` (customer).

---

## 5. Verifikasi

```bash
curl https://<domain-railway-anda>.up.railway.app/api/ping
# -> {"app":"AirCrew API","status":"ok"}
```

Uji login + alur end-to-end:

```bash
# login customer → dapat token
curl -X POST https://<domain>/api/auth/customer/login \
  -H "Content-Type: application/json" \
  -d '{"email":"budi.crew@garuda.co.id","password":"demo1234"}'

# buat order (status "waiting") — pakai token dari respons di atas
curl -X POST https://<domain>/api/customer/orders \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"service":"scheduled","pickup":"Hotel A","destination":"CGK T3","scheduled_at":"2026-08-01T03:45:00Z","argo":125000}'

# driver melihat order masuk di areanya
curl https://<domain>/api/mitra/incoming \
  -H "Authorization: Bearer <TOKEN_DRIVER>"
```

---

## 6. Arahkan Aplikasi ke Railway

**Flutter** — build dengan base URL produksi:

```bash
cd aircrew_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<domain-railway-anda>.up.railway.app/api
```

Atau ubah saat runtime lewat menu **Pengaturan API** di app (fitur `reconnect`).

**Admin dashboard** — set base URL API di `admin_dashboard/api.js` ke domain Railway.

---

## 7. Catatan Produksi

- **`php artisan serve`** dipakai agar demo cepat jalan. Untuk trafik nyata, ganti
  ke Nginx + PHP-FPM atau image seperti `serversideup/php` (ubah `CMD` di Dockerfile).
- **CORS**: `config/cors.php` default mengizinkan `api/*` dari semua origin — cukup
  untuk demo. Batasi `allowed_origins` ke domain dashboard Anda untuk produksi.
- **Auth**: Sanctum memakai *bearer token* (bukan cookie), jadi tidak perlu
  `SANCTUM_STATEFUL_DOMAINS`.
- **Log**: `LOG_CHANNEL=stderr` menampilkan log Laravel langsung di Railway Logs.
- **Storage**: filesystem Railway *ephemeral* (hilang saat redeploy). PDF bukti
  transaksi di app dibuat di sisi Flutter, jadi tidak terpengaruh.

---

## Troubleshooting

### `SQLSTATE[08006] connection to server at "127.0.0.1", port 5433 failed: Connection refused`

Laravel mencoba konek ke `127.0.0.1` (localhost container itu sendiri), bukan ke
service Postgres. Artinya **variabel koneksi DB tidak terbaca** dan Laravel jatuh
ke nilai default/lokal. Penyebab & solusi:

1. **Variabel DB belum di-set / referensi salah nama service.** Buka service backend
   → **Variables** → pastikan ada `DB_CONNECTION=pgsql` dan `DB_URL=${{Postgres.DATABASE_URL}}`
   (atau lima variabel per-field). Cek nama service database di sidebar — reference
   harus persis (`${{<NamaService>.DATABASE_URL}}`). Setelah diubah, Railway otomatis
   redeploy.
2. **Masih ada `DB_HOST`/`DB_PORT` lama.** Hapus `DB_HOST=127.0.0.1` atau
   `DB_PORT=5433` yang mungkin ter-copy dari `.env` lokal. Nilai ini menimpa koneksi.
3. **Database dan backend beda project.** `DATABASE_URL` privat hanya bisa diakses
   dalam project yang sama. Pastikan Postgres dan backend berada di **satu project**.
   Bila terpaksa lintas project, pakai `${{Postgres.DATABASE_PUBLIC_URL}}`.
4. **Verifikasi cepat** dari Shell service backend:
   ```bash
   php artisan tinker --execute="echo config('database.connections.pgsql.host');"
   # harus menampilkan host Railway (mis. *.railway.internal), BUKAN 127.0.0.1
   ```

Setelah host benar, migrasi (yang jalan otomatis saat start) akan berhasil.

### `No application encryption key has been specified`

`APP_KEY` belum di-set. Lihat langkah 3a — generate `php artisan key:generate --show`
lalu tempel ke variable `APP_KEY`.

---

## Alternatif: Nixpacks (tanpa Dockerfile)

Bila ingin tanpa Docker, hapus/rename `Dockerfile` dan set **Builder = Nixpacks**,
lalu tambah **Custom Start Command** di Settings:

```bash
php artisan migrate --force && php artisan serve --host 0.0.0.0 --port $PORT
```

Nixpacks akan mendeteksi PHP dari `composer.json`. Pendekatan Dockerfile di atas
lebih disarankan karena eksplisit memasang ekstensi `pdo_pgsql`.
