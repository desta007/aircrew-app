// AirCrew Admin — view router + renderers (vanilla JS, no build step).
const rp = (n) => 'Rp ' + Number(n).toLocaleString('id-ID');
const rpShort = (n) => n >= 1e6 ? 'Rp ' + (n/1e6).toFixed(n%1e6===0?0:1) + ' jt' : rp(n);
const sum = (arr, k) => arr.reduce((s, x) => s + x[k], 0);
const initials = (name) => name.split(' ').slice(0,2).map(w=>w[0]).join('');

const TITLES = {
  dashboard: 'Dashboard Monitoring Area', order: 'Manajemen Order', driver: 'Data Driver',
  customer: 'AirCrew / Customer', area: 'Pembagian Area Kerja', keuangan: 'Keuangan',
  withdrawal: 'Withdrawal Driver', laporan: 'Laporan', pengaturan: 'Pengaturan',
};

function statusTag(s) {
  const map = { Selesai:'green', Berhasil:'green', Berjalan:'blue', Online:'green', Trip:'blue', Proses:'orange', Menunggu:'orange', Offline:'gray' };
  return `<span class="tag ${map[s]||'gray'}">${s}</span>`;
}

// ---------- Views ----------
function vDashboard() {
  const t = DB.totals;
  const stats = [
    { ico:'🚗', bg:'#E6EEFF', c:'#1E5BE6', label:'Total Driver Aktif', value: t.driver, sub:'+3 hari ini' },
    { ico:'🧑‍✈️', bg:'#E6F6EC', c:'#17A54A', label:'Total AirCrew', value: t.aircrew, sub:'+12 minggu ini' },
    { ico:'🧾', bg:'#FCEFDD', c:'#E07B1A', label:'Total Order Hari Ini', value: t.orderToday, sub:'+8% vs kemarin' },
    { ico:'💰', bg:'#FDE8E9', c:'#E11B22', label:'Pendapatan Hari Ini', value: rpShort(t.revenueToday), sub:'+5.4% vs kemarin' },
  ];
  const statHtml = stats.map(s => `
    <div class="stat">
      <div class="ico" style="background:${s.bg};color:${s.c}">${s.ico}</div>
      <div class="label">${s.label}</div>
      <div class="value">${s.value}</div>
      <div class="sub">▲ ${s.sub}</div>
    </div>`).join('');

  const rows = DB.areas.map(a => `
    <tr>
      <td><span class="area-name"><span class="dot-lg" style="background:${a.color}"></span>${a.area}</span></td>
      <td>${a.driver}</td><td>${a.aircrew}</td><td>${a.order}</td>
      <td class="money">${rp(a.revenue)}</td>
      <td><button class="btn" onclick="go('area')">Lihat Detail</button></td>
    </tr>`).join('');

  return `
    <div class="stats">${statHtml}</div>
    <div class="grid-2">
      <div class="card">
        <div class="card-head"><h3>Data Area</h3><button class="btn primary" onclick="go('area')">Kelola Area</button></div>
        <table>
          <thead><tr><th>Area</th><th>Driver Aktif</th><th>AirCrew</th><th>Order Hari Ini</th><th>Pendapatan</th><th>Aksi</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
      <div class="card">
        <div class="card-head"><h3>Peta Sebaran Order Hari Ini</h3></div>
        ${mapHtml()}
      </div>
    </div>
    <div class="grid-2">
      <div class="card">
        <div class="card-head"><h3>Tren Order & Pendapatan (7 Hari)</h3></div>
        ${barChart()}
      </div>
      <div class="card">
        <div class="card-head"><h3>Order Terbaru</h3><button class="btn" onclick="go('order')">Semua</button></div>
        <table><tbody>${DB.orders.slice(0,5).map(o=>`
          <tr><td><b>${o.id}</b><div class="sub-txt">${o.route}</div></td>
          <td>${statusTag(o.status)}</td><td class="money">${rp(o.total)}</td></tr>`).join('')}</tbody></table>
      </div>
    </div>`;
}

function mapHtml() {
  // positions roughly matching the infographic layout
  const pos = { Utara:[52,22], Timur:[78,52], Pusat:[50,50], Barat:[24,52], Selatan:[50,82] };
  const bubbles = DB.areas.map(a => {
    const [x,y] = pos[a.area];
    return `<div class="bubble" style="left:${x}%;top:${y}%;background:${a.color}">${a.order}<small>${a.area}</small></div>`;
  }).join('');
  return `<div class="map-wrap">${bubbles}<div class="map-legend">● Angka = jumlah order hari ini per area</div></div>`;
}

function barChart() {
  const max = Math.max(...DB.trend.map(d=>d.orders));
  return `<div class="chart">${DB.trend.map(d=>`
    <div class="bar-col">
      <b>${d.orders}</b>
      <div class="bar" style="height:${(d.orders/max*100).toFixed(0)}%" title="${rp(d.revenue)}"></div>
      <span>${d.d}</span>
    </div>`).join('')}</div>
    <div class="sub-txt" style="margin-top:10px">Hover bar untuk melihat pendapatan harian.</div>`;
}

function vOrder() {
  const rows = DB.orders.map(o => `
    <tr>
      <td><b>${o.id}</b></td>
      <td>${o.crew}</td><td>${o.driver}</td>
      <td><span class="area-name"><span class="dot-lg" style="background:${areaColor(o.area)}"></span>${o.area}</span></td>
      <td>${o.service}</td><td>${o.route}</td>
      <td class="money">${rp(o.total)}</td><td>${statusTag(o.status)}</td>
    </tr>`).join('');
  return card('Semua Order', filters(['Semua','Selesai','Berjalan','Menunggu']) + `
    <table><thead><tr><th>Order ID</th><th>Crew</th><th>Driver</th><th>Area</th><th>Layanan</th><th>Rute</th><th>Total</th><th>Status</th></tr></thead>
    <tbody>${rows}</tbody></table>`);
}

function vDriver() {
  const rows = DB.drivers.map(d => `
    <tr>
      <td><div class="avatar-cell"><div class="av">${initials(d.name)}</div><div><b>${d.name}</b><div class="sub-txt">${d.id}</div></div></div></td>
      <td><span class="area-name"><span class="dot-lg" style="background:${areaColor(d.area)}"></span>${d.area}</span></td>
      <td>${d.vehicle}</td>
      <td>⭐ ${d.rating}</td><td>${d.trips}</td>
      <td class="money">${rp(d.balance)}</td>
      <td>${statusTag(d.status)}</td>
    </tr>`).join('');
  return card('Data Driver (Mitra)', `
    <table><thead><tr><th>Driver</th><th>Area</th><th>Unit</th><th>Rating</th><th>Trip</th><th>Saldo</th><th>Status</th></tr></thead>
    <tbody>${rows}</tbody></table>`);
}

function vCustomer() {
  const rows = DB.customers.map(c => `
    <tr>
      <td><div class="avatar-cell"><div class="av" style="background:#1E5BE6">${initials(c.name)}</div><div><b>${c.name}</b><div class="sub-txt">${c.id}</div></div></div></td>
      <td>${c.airline}</td>
      <td><span class="area-name"><span class="dot-lg" style="background:${areaColor(c.area)}"></span>${c.area}</span></td>
      <td>${c.orders}</td><td class="money">${rp(c.spend)}</td>
    </tr>`).join('');
  return card('AirCrew / Customer', `
    <table><thead><tr><th>Crew</th><th>Maskapai</th><th>Area</th><th>Total Order</th><th>Total Belanja</th></tr></thead>
    <tbody>${rows}</tbody></table>`);
}

function vArea() {
  const cards = DB.areas.map((a,i)=>`
    <div class="hier-card" style="background:linear-gradient(135deg,${a.color},${shade(a.color)})">
      <div style="opacity:.8;font-size:12px">Area ${i+1}</div>
      <h4>${a.area}</h4>
      <div class="nums">
        <div><b>${a.driver}</b>Mitra Driver</div>
        <div><b>${a.aircrew}</b>Customer</div>
      </div>
    </div>`).join('');
  const rows = DB.areas.map(a => {
    const load = (a.order / a.driver).toFixed(1);
    return `<tr>
      <td><span class="area-name"><span class="dot-lg" style="background:${a.color}"></span>${a.area}</span></td>
      <td>${a.driver}</td><td>${a.aircrew}</td><td>${a.order}</td><td class="money">${rp(a.revenue)}</td>
      <td>${load} order/driver</td></tr>`;
  }).join('');
  return `
    <div class="card">
      <h3>Sistem Area Tertutup</h3>
      <div class="muted">Setiap customer hanya dilayani driver di area yang sama. 6 area operasional dikelola Kantor Pusat.</div>
      <div class="hierarchy">${cards}
        <div class="hier-card" style="background:linear-gradient(135deg,#C2185B,#8A0F41)">
          <div style="opacity:.8;font-size:12px">Area 6</div><h4>Tangerang</h4>
          <div class="nums"><div><b>10</b>Mitra Driver</div><div><b>100</b>Customer</div></div>
        </div>
      </div>
    </div>
    <div class="card">
      <div class="card-head"><h3>Beban Kerja per Area</h3></div>
      <table><thead><tr><th>Area</th><th>Driver</th><th>Customer</th><th>Order Hari Ini</th><th>Pendapatan</th><th>Beban</th></tr></thead>
      <tbody>${rows}</tbody></table>
    </div>`;
}

function vKeuangan() {
  const totalRev = sum(DB.areas,'revenue');
  const totalWd = sum(DB.withdrawals,'nominal');
  const komisi = Math.round(totalRev * 0.2);
  const stats = [
    { ico:'💵', bg:'#E6F6EC', c:'#17A54A', label:'Pendapatan Kotor Hari Ini', value: rpShort(totalRev) },
    { ico:'🏦', bg:'#E6EEFF', c:'#1E5BE6', label:'Total Withdrawal', value: rpShort(totalWd) },
    { ico:'📈', bg:'#FCEFDD', c:'#E07B1A', label:'Komisi Platform (20%)', value: rpShort(komisi) },
    { ico:'💳', bg:'#FDE8E9', c:'#E11B22', label:'Saldo Driver (Total)', value: rpShort(sum(DB.drivers,'balance')) },
  ];
  const statHtml = stats.map(s=>`<div class="stat"><div class="ico" style="background:${s.bg};color:${s.c}">${s.ico}</div><div class="label">${s.label}</div><div class="value">${s.value}</div></div>`).join('');
  const rows = DB.areas.map(a=>{
    const komisiA = Math.round(a.revenue*0.2), driverShare = a.revenue - komisiA;
    return `<tr><td><span class="area-name"><span class="dot-lg" style="background:${a.color}"></span>${a.area}</span></td>
      <td class="money">${rp(a.revenue)}</td><td class="money">${rp(komisiA)}</td><td class="money">${rp(driverShare)}</td>
      <td><div class="progress"><div style="width:${(a.revenue/9750000*100)}%;background:${a.color}"></div></div></td></tr>`;
  }).join('');
  return `<div class="stats">${statHtml}</div>` + card('Rincian Keuangan per Area', `
    <table><thead><tr><th>Area</th><th>Pendapatan</th><th>Komisi Platform</th><th>Bagian Driver</th><th>Kontribusi</th></tr></thead>
    <tbody>${rows}</tbody></table>`);
}

function vWithdrawal() {
  const rows = DB.withdrawals.map(w=>`
    <tr><td><b>${w.id}</b></td>
      <td><div class="avatar-cell"><div class="av">${initials(w.driver)}</div><div><b>${w.driver}</b><div class="sub-txt">${w.area}</div></div></div></td>
      <td>${w.method}</td>
      <td class="money">${rp(w.nominal)}</td>
      <td><span class="tag ${w.speed==='H+1'?'green':'orange'}">${w.speed}${w.fee?' • '+rp(w.fee):' • Gratis'}</span></td>
      <td>${statusTag(w.status)}</td>
      <td>${w.status==='Proses'?'<button class="btn primary">Setujui</button>':'<button class="btn">Detail</button>'}</td>
    </tr>`).join('');
  return card('Permintaan Withdrawal', filters(['Semua','Proses','Berhasil']) + `
    <table><thead><tr><th>Ref</th><th>Driver</th><th>Metode</th><th>Nominal</th><th>Waktu Proses</th><th>Status</th><th>Aksi</th></tr></thead>
    <tbody>${rows}</tbody></table>`);
}

function vLaporan() {
  const totalRev = sum(DB.areas,'revenue');
  return `
    <div class="two-col">
      <div class="card"><h3>Ringkasan Laporan Harian</h3><div class="muted">28 Juli 2026</div>
        ${[['Total Order', DB.totals.orderToday],['Order Selesai', 218],['Order Dibatalkan', 12],['Driver Aktif', DB.totals.driver],['Pendapatan Kotor', rp(totalRev)],['Rata-rata per Order', rp(Math.round(totalRev/DB.totals.orderToday))]]
          .map(r=>`<div class="kpi-row"><span>${r[0]}</span><b>${r[1]}</b></div>`).join('')}
        <button class="btn primary" style="margin-top:14px" onclick="alert('Demo: laporan diekspor ke PDF/Excel')">⬇ Export Laporan</button>
      </div>
      <div class="card"><h3>Performa Area</h3><div class="muted">Kontribusi pendapatan</div>
        ${DB.areas.map(a=>`<div style="margin-bottom:12px"><div class="kpi-row" style="border:none;padding:4px 0"><span>${a.area}</span><b>${rp(a.revenue)}</b></div>
          <div class="progress"><div style="width:${(a.revenue/totalRev*100).toFixed(0)}%;background:${a.color}"></div></div></div>`).join('')}
      </div>
    </div>
    ${card('Tren Order & Pendapatan (7 Hari)', barChart())}`;
}

function vPengaturan() {
  return `
    <div class="two-col">
      <div class="card"><h3>Konfigurasi Platform</h3>
        ${[['Komisi Platform','20%'],['Biaya WD H+0','Rp 5.000'],['Minimal Withdrawal','Rp 50.000'],['Jam Proses WD','09:00 - 17:00'],['Minimal Pembayaran','Rp 10.000']]
          .map(r=>`<div class="kpi-row"><span>${r[0]}</span><b>${r[1]}</b></div>`).join('')}
      </div>
      <div class="card"><h3>Metode Pembayaran Aktif</h3>
        ${['QRIS (Semua Bank)','Virtual Account','Transfer Bank','OVO','DANA','GoPay'].map(m=>`<div class="kpi-row"><span>${m}</span><span class="tag green">Aktif</span></div>`).join('')}
      </div>
    </div>
    <div class="card"><h3>Akun Admin Area</h3>
      <table><thead><tr><th>Area</th><th>Admin</th><th>Role</th><th>Status</th></tr></thead>
      <tbody>${DB.areas.map(a=>`<tr><td>${a.area}</td><td>Admin ${a.area}</td><td>Area Manager</td><td>${statusTag('Online')}</td></tr>`).join('')}</tbody></table>
    </div>`;
}

// ---------- helpers ----------
function card(title, inner) { return `<div class="card"><div class="card-head"><h3>${title}</h3></div>${inner}</div>`; }
function filters(items) { return `<div class="filters">${items.map((f,i)=>`<div class="chip ${i===0?'active':''}" onclick="toggleChip(this)">${f}</div>`).join('')}</div>`; }
function areaColor(name) { const a = DB.areas.find(x=>x.area===name); return a ? a.color : '#6B7590'; }
function shade(hex) {
  const n = parseInt(hex.slice(1),16); let r=(n>>16)-40, g=((n>>8)&255)-40, b=(n&255)-40;
  r=Math.max(0,r); g=Math.max(0,g); b=Math.max(0,b);
  return '#'+((1<<24)+(r<<16)+(g<<8)+b).toString(16).slice(1);
}
function toggleChip(el){ el.parentNode.querySelectorAll('.chip').forEach(c=>c.classList.remove('active')); el.classList.add('active'); }

const VIEWS = { dashboard:vDashboard, order:vOrder, driver:vDriver, customer:vCustomer, area:vArea, keuangan:vKeuangan, withdrawal:vWithdrawal, laporan:vLaporan, pengaturan:vPengaturan };

function go(view) {
  document.getElementById('content').innerHTML = VIEWS[view]();
  document.getElementById('pageTitle').textContent = TITLES[view];
  document.querySelectorAll('#menu a').forEach(a => a.classList.toggle('active', a.dataset.view === view));
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('content').scrollTo(0,0);
}

document.getElementById('menu').addEventListener('click', e => {
  const a = e.target.closest('a'); if (a) go(a.dataset.view);
});
document.getElementById('hamburger').addEventListener('click', () => document.getElementById('sidebar').classList.toggle('open'));

// Load live data from the Laravel API (falls back to static data.js), then render.
(async () => {
  await bootstrapData();
  go('dashboard');
})();
