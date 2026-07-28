// AirCrew Admin — API loader.
// Tries the Laravel API; on any failure the dashboard falls back to the
// static demo data in data.js so it always renders.
const API_BASE = (localStorage.getItem('aircrew_api') || 'http://127.0.0.1:8000/api');

const SERVICE_LABEL = {
  scheduled: 'Jemputan Terjadwal', rental3: 'Rental 3 Jam', rental5: 'Rental 5 Jam', rental8: 'Rental 8 Jam',
};
const STATUS_LABEL = {
  waiting: 'Menunggu', accepted: 'Diterima', toPickup: 'Menuju Jemput', arrivedPickup: 'Tiba di Lokasi',
  onTrip: 'Berjalan', arrivedDest: 'Tiba di Tujuan', completed: 'Selesai', cancelled: 'Dibatalkan',
};
const METHOD_LABEL = { bank: 'Transfer Bank', ovo: 'OVO', dana: 'DANA', gopay: 'GoPay' };

async function getJson(path) {
  const res = await fetch(API_BASE + path, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(path + ' -> ' + res.status);
  return res.json();
}

// Map API responses into the DB shape app.js already renders.
async function loadFromApi() {
  const [dash, drivers, customers, orders, withdrawals] = await Promise.all([
    getJson('/admin/dashboard'), getJson('/admin/drivers'), getJson('/admin/customers'),
    getJson('/admin/orders'), getJson('/admin/withdrawals'),
  ]);

  DB.totals = {
    driver: dash.totals.driver, aircrew: dash.totals.aircrew,
    orderToday: dash.totals.order_today, revenueToday: dash.totals.revenue_today,
  };
  DB.areas = dash.areas.map(a => ({ area: a.area, color: a.color, driver: a.driver, aircrew: a.aircrew, order: a.order, revenue: a.revenue }));
  DB.trend = dash.trend;

  DB.drivers = drivers.drivers.map(d => ({
    id: d.id, name: d.name, area: d.area, vehicle: `${d.vehicle.name} • ${d.vehicle.plate}`,
    rating: d.rating, status: cap(d.status), trips: d.trips, balance: d.balance,
  }));
  DB.customers = customers.customers.map(c => ({
    id: c.id, name: c.name, airline: c.airline, area: c.area, orders: c.orders, spend: c.spend,
  }));
  DB.orders = orders.orders.map(o => ({
    id: o.id, crew: o.customer ? o.customer.name : '-', driver: o.driver ? o.driver.name : '-',
    area: o.area, service: SERVICE_LABEL[o.service] || o.service, route: `${o.pickup} → ${o.destination}`,
    total: o.total, status: STATUS_LABEL[o.status] || o.status, time: '',
  }));
  DB.withdrawals = withdrawals.withdrawals.map(w => ({
    id: w.id, driver: w.driver, area: w.area, method: METHOD_LABEL[w.method] || w.method,
    nominal: w.nominal, speed: w.speed === 'h1' ? 'H+1' : 'H+0', fee: w.fee, status: w.status,
  }));
}

function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

// Called by app.js before first render.
async function bootstrapData() {
  const badge = document.getElementById('sourceBadge');
  try {
    await loadFromApi();
    if (badge) { badge.textContent = '● Data: API Laravel (live)'; badge.className = 'src-badge live'; }
  } catch (e) {
    console.warn('API tidak tersedia, memakai data demo statis:', e.message);
    if (badge) { badge.textContent = '● Data: demo statis (API off)'; badge.className = 'src-badge off'; }
  }
}
