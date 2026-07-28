// AirCrew Admin — demo seed data (mirrors the Flutter app seed).
const DB = {
  totals: { driver: 38, aircrew: 376, orderToday: 245, revenueToday: 24850000 },
  areas: [
    { area: 'Utara',   color: '#2E63C4', driver: 8,  aircrew: 76,  order: 48, revenue: 5620000 },
    { area: 'Timur',   color: '#17A54A', driver: 6,  aircrew: 62,  order: 36, revenue: 3840000 },
    { area: 'Pusat',   color: '#E07B1A', driver: 12, aircrew: 120, order: 85, revenue: 9750000 },
    { area: 'Barat',   color: '#7A3EC4', driver: 7,  aircrew: 68,  order: 41, revenue: 3980000 },
    { area: 'Selatan', color: '#E11B22', driver: 5,  aircrew: 50,  order: 35, revenue: 1660000 },
  ],
  drivers: [
    { id: 'DRV-001', name: 'Budi Santoso', area: 'Pusat',   vehicle: 'Innova Reborn • B 1234 ABC', rating: 4.92, status: 'Online',  trips: 312, balance: 1250000 },
    { id: 'DRV-002', name: 'Andi Wijaya',  area: 'Pusat',   vehicle: 'Avanza • B 0678 DEF',       rating: 4.80, status: 'Online',  trips: 268, balance: 890000  },
    { id: 'DRV-003', name: 'Slamet Riyadi',area: 'Pusat',   vehicle: 'Innova Zenix • B 9101 GHI', rating: 4.90, status: 'Trip',    trips: 301, balance: 1520000 },
    { id: 'DRV-004', name: 'Asep Kurnia',  area: 'Utara',   vehicle: 'Xpander • B 2222 JKL',      rating: 4.85, status: 'Online',  trips: 199, balance: 640000  },
    { id: 'DRV-005', name: 'Rudi Hartono', area: 'Selatan', vehicle: 'Avanza • B 3333 MNO',       rating: 4.70, status: 'Offline', trips: 154, balance: 430000  },
    { id: 'DRV-006', name: 'Joko Susilo',  area: 'Barat',   vehicle: 'Ertiga • B 4444 PQR',       rating: 4.88, status: 'Online',  trips: 221, balance: 720000  },
  ],
  customers: [
    { id: 'CST-001', name: 'Budi Santoso',    airline: 'Garuda Indonesia', area: 'Pusat',   orders: 24, spend: 6200000 },
    { id: 'CST-002', name: 'Rina Permata',    airline: 'Citilink',         area: 'Pusat',   orders: 12, spend: 2400000 },
    { id: 'CST-003', name: 'Andi Pratama',    airline: 'Lion Air',         area: 'Utara',   orders: 18, spend: 3600000 },
    { id: 'CST-004', name: 'Dewi Anggraini',  airline: 'Batik Air',        area: 'Selatan', orders: 9,  spend: 1800000 },
    { id: 'CST-005', name: 'Fajar Nugroho',   airline: 'Garuda Indonesia', area: 'Barat',   orders: 15, spend: 3100000 },
  ],
  orders: [
    { id: 'ORD-180525-00123', crew: 'Budi Santoso',   driver: 'Budi Santoso',  area: 'Pusat',   service: 'Jemputan Terjadwal', route: 'Novotel → T3 CGK', total: 125000, status: 'Selesai',  time: '04:10' },
    { id: 'ORD-180525-00098', crew: 'Rina Permata',   driver: 'Andi Wijaya',   area: 'Pusat',   service: 'Jemputan Terjadwal', route: 'Hilton → T2 CGK',  total: 110000, status: 'Selesai',  time: '02:35' },
    { id: 'ORD-180525-00087', crew: 'Andi Pratama',   driver: 'Asep Kurnia',   area: 'Utara',   service: 'Rental 3 Jam',       route: 'Apartemen → T1',  total: 350000, status: 'Berjalan', time: '01:15' },
    { id: 'ORD-180525-00075', crew: 'Dewi Anggraini', driver: 'Rudi Hartono',  area: 'Selatan', service: 'Jemputan Terjadwal', route: 'Rumah → T2 CGK',   total: 95000,  status: 'Menunggu', time: '05:40' },
    { id: 'ORD-180525-00061', crew: 'Fajar Nugroho',  driver: 'Joko Susilo',   area: 'Barat',   service: 'Rental 8 Jam',       route: 'Kantor → T3 CGK', total: 800000, status: 'Selesai',  time: '08:00' },
  ],
  withdrawals: [
    { id: 'WD2505180000123', driver: 'Budi Santoso',  area: 'Pusat',   method: 'Transfer Bank - BCA', nominal: 1000000, speed: 'H+1', fee: 0,     status: 'Proses'   },
    { id: 'WD2505180000098', driver: 'Andi Wijaya',   area: 'Pusat',   method: 'OVO',                 nominal: 750000,  speed: 'H+0', fee: 5000,  status: 'Berhasil' },
    { id: 'WD2505170000076', driver: 'Asep Kurnia',   area: 'Utara',   method: 'Transfer Bank - BRI', nominal: 500000,  speed: 'H+1', fee: 0,     status: 'Berhasil' },
    { id: 'WD2505170000055', driver: 'Rudi Hartono',  area: 'Selatan', method: 'DANA',                nominal: 300000,  speed: 'H+0', fee: 5000,  status: 'Berhasil' },
  ],
  // last 7 days orders + revenue for the chart
  trend: [
    { d: 'Sen', orders: 198, revenue: 19800000 },
    { d: 'Sel', orders: 212, revenue: 21400000 },
    { d: 'Rab', orders: 187, revenue: 18600000 },
    { d: 'Kam', orders: 234, revenue: 23900000 },
    { d: 'Jum', orders: 256, revenue: 26100000 },
    { d: 'Sab', orders: 241, revenue: 24500000 },
    { d: 'Min', orders: 245, revenue: 24850000 },
  ],
};
