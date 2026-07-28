import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';
import 'seed.dart';

/// Outcome of a login attempt.
enum LoginResult {
  success, // valid credentials, signed in against the API
  invalidCredentials, // server rejected the email/password (401)
  offline, // server unreachable — offer demo mode explicitly
}

/// Single in-memory store shared by the Mitra and Customer demo apps.
///
/// On startup it tries to load everything from the Laravel API. If the backend
/// is offline it silently falls back to the bundled [Seed] data, so the demo
/// always works. Mutations are sent to the API best-effort while local state is
/// updated immediately for a snappy UI.
class AppState extends ChangeNotifier {
  AppState() {
    _orderHistory = Seed.history();
    _wallet = Seed.walletHistory();
    _withdrawals = Seed.withdrawals();
    _invoices = Seed.invoices();
  }

  final ApiClient api = ApiClient.instance;

  final Driver driver = Seed.me;
  final Customer crew = Seed.crew;

  /// Whether the last bootstrap reached the Laravel API.
  bool apiConnected = false;
  bool booting = false;
  String get apiBaseUrl => api.baseUrl;

  /// Ping the API just to update the connectivity badge (no auth needed).
  Future<void> pingApi() async {
    booting = true;
    notifyListeners();
    apiConnected = await api.ping();
    booting = false;
    notifyListeners();
  }

  /// Point the app at a new API base URL (e.g. host LAN IP for a physical
  /// device) and re-check connectivity. Returns true if the API responded.
  Future<bool> reconnect(String baseUrl) async {
    api.baseUrl = baseUrl.trim();
    await pingApi();
    return apiConnected;
  }

  Customer? loggedInCustomer;
  Driver? loggedInDriver;

  /// Mitra (driver) login against the database → Sanctum token → load data.
  ///
  /// Distinguishes three outcomes so a wrong password is never silently
  /// accepted: [LoginResult.success] (valid credentials),
  /// [LoginResult.invalidCredentials] (server rejected — 401), and
  /// [LoginResult.offline] (server unreachable — the UI can then offer demo
  /// mode as an explicit choice rather than logging in with any password).
  Future<LoginResult> loginMitra(String email, String password) async {
    try {
      loggedInDriver = await api.loginMitra(email, password);
    } on ApiException catch (e) {
      debugPrint('loginMitra rejected: $e');
      return LoginResult.invalidCredentials;
    } catch (e) {
      debugPrint('loginMitra offline: $e');
      return LoginResult.offline;
    }
    // Credentials accepted; token is set. Load data best-effort — a transient
    // failure here must not turn a valid login into a demo session.
    apiConnected = true;
    try {
      await _loadMitraData();
    } catch (e) {
      debugPrint('loginMitra data load partial: $e');
    }
    notifyListeners();
    return LoginResult.success;
  }

  /// Customer login against the database → Sanctum token → load invoices.
  /// Same three-way outcome as [loginMitra].
  Future<LoginResult> loginCustomer(String email, String password) async {
    try {
      loggedInCustomer = await api.loginCustomer(email, password);
    } on ApiException catch (e) {
      debugPrint('loginCustomer rejected: $e');
      return LoginResult.invalidCredentials;
    } catch (e) {
      debugPrint('loginCustomer offline: $e');
      return LoginResult.offline;
    }
    apiConnected = true;
    try {
      await _loadCustomerData();
    } catch (e) {
      debugPrint('loginCustomer data load partial: $e');
    }
    notifyListeners();
    return LoginResult.success;
  }

  /// Enter the offline demo session explicitly (user-chosen from the login
  /// screen when the server is unreachable). Uses bundled seed data.
  void enterDemoMode() {
    apiConnected = false;
    _apiSaldo = _apiHeld = _apiTotal = _apiHariIni = _apiMinggu = _apiBulan = null;
    _active = null;
    incoming = Seed.incomingOrder();
    _orderHistory = Seed.history();
    _wallet = Seed.walletHistory();
    _withdrawals = Seed.withdrawals();
    _invoices = Seed.invoices();
    notifyListeners();
  }

  /// Revoke the token and reset to a clean (seed) state.
  Future<void> logout() async {
    await api.logout();
    loggedInCustomer = null;
    loggedInDriver = null;
    _apiSaldo = _apiHeld = _apiTotal = _apiHariIni = _apiMinggu = _apiBulan = null;
    _active = null;
    incoming = Seed.incomingOrder();
    _orderHistory = Seed.history();
    _wallet = Seed.walletHistory();
    _withdrawals = Seed.withdrawals();
    _invoices = Seed.invoices();
    notifyListeners();
  }

  Future<void> _loadMitraData() async {
    final me = await api.mitraMe();
    final pd = me['pendapatan'] as Map<String, dynamic>;
    _apiSaldo = (pd['saldo_tersedia'] as num).toDouble();
    _apiHeld = (pd['saldo_tertahan'] as num).toDouble();
    _apiTotal = (pd['total_pendapatan'] as num).toDouble();
    _apiHariIni = (pd['hari_ini'] as num).toDouble();
    _apiMinggu = (pd['minggu_ini'] as num).toDouble();
    _apiBulan = (pd['bulan_ini'] as num).toDouble();
    _online = (me['driver']?['online'] ?? true) as bool;

    incoming = await api.mitraIncoming();

    _orderHistory = await api.mitraOrders();
    _withdrawals = await api.mitraWithdrawals();

    final pend = await api.mitraPendapatan();
    _wallet = (pend['wallet'] as List).map((t) => WalletTx.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<void> _loadCustomerData() async {
    _invoices = await api.customerInvoices();
  }

  /// Create a WAITING customer order in the database and return it so the
  /// customer app can poll its status while a driver accepts and drives it.
  /// Returns null when offline or on error (the UI then runs a local demo).
  Future<Order?> createWaitingOrder({
    required ServiceType service,
    required String pickup,
    required String destination,
    required DateTime scheduledAt,
    String? driver,
    required double argo,
  }) async {
    if (!apiConnected) return null;
    try {
      final r = await api.createOrder(
        service: service,
        pickup: pickup,
        destination: destination,
        scheduledAt: scheduledAt,
        driver: driver,
        argo: argo,
        completed: false,
      );
      return r.order;
    } catch (e) {
      debugPrint('createWaitingOrder: $e');
      return null;
    }
  }

  /// Poll a customer order's live status (waiting → accepted → … → completed).
  Future<Order?> refreshCustomerOrder(String code) async {
    if (!apiConnected) return null;
    try {
      return await api.customerOrder(code);
    } catch (e) {
      debugPrint('refreshCustomerOrder: $e');
      return null;
    }
  }

  /// Customer rates the driver after the trip completes.
  Future<void> rateDriver(String code, int stars, String feedback) async {
    if (!apiConnected) return;
    try {
      await api.customerRateOrder(code, stars, feedback);
    } catch (e) {
      debugPrint('rateDriver: $e');
    }
  }

  /// Reload invoices from the backend (called once the trip is completed so the
  /// freshly generated tagihan appears).
  Future<void> refreshInvoices() async {
    if (!apiConnected) return;
    try {
      _invoices = await api.customerInvoices();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshInvoices: $e');
    }
  }

  /// Persist a completed customer order + its invoice directly (used by the
  /// offline/local demo path when the backend is unreachable).
  Future<void> persistCompletedOrder({
    required ServiceType service,
    required String pickup,
    required String destination,
    required DateTime scheduledAt,
    String? driver,
    required OrderCharges charges,
  }) async {
    if (!apiConnected) return;
    try {
      await api.createOrder(
        service: service,
        pickup: pickup,
        destination: destination,
        scheduledAt: scheduledAt,
        driver: driver,
        argo: charges.argo,
        tol: charges.tol,
        parkir: charges.parkir,
        lainnya: charges.lainnya,
        completed: true,
      );
      _invoices = await api.customerInvoices();
      notifyListeners();
    } catch (e) {
      debugPrint('persistCompletedOrder: $e');
    }
  }

  // ---- Driver online state ----
  bool _online = true;
  bool get online => _online;
  void setOnline(bool v) {
    _online = v;
    notifyListeners();
    if (apiConnected) api.setOnline(v).catchError((_) {});
  }

  // ---- Active order ----
  Order? _active;
  Order? get activeOrder => _active;

  /// Order currently offered to the driver (waiting for accept/reject). Null
  /// when there is nothing to accept in the driver's area. Offline it starts as
  /// a demo order so the driver app still has something to show.
  Order? incoming = Seed.incomingOrder();

  /// Re-fetch the latest waiting order in the driver's area (called by a poll on
  /// the driver home so a freshly created customer order shows up live).
  Future<void> refreshIncoming() async {
    if (!apiConnected || _active != null) return;
    try {
      incoming = await api.mitraIncoming();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshIncoming: $e');
    }
  }

  void acceptOrder() {
    final o = incoming;
    if (o == null) return;
    o.status = OrderStatus.accepted;
    o.driver = driver;
    _active = o;
    incoming = null;
    notifyListeners();
    if (apiConnected) api.acceptOrder(o.id).catchError((e) => o);
  }

  void rejectOrder() {
    final o = incoming;
    if (apiConnected && o != null) {
      api.rejectOrder(o.id).whenComplete(refreshIncoming);
      incoming = null;
    } else {
      incoming = Seed.incomingOrder();
    }
    notifyListeners();
  }

  void advanceOrder(OrderStatus status) {
    final o = _active;
    o?.status = status;
    notifyListeners();
    if (apiConnected && o != null) api.advanceOrder(o.id, status.name).catchError((_) {});
  }

  void completeOrder(OrderCharges charges) {
    final o = _active;
    if (o == null) return;
    o.charges = charges;
    o.status = OrderStatus.completed;
    o.completedAt = DateTime(2026, 5, 18, 4, 10);
    _orderHistory = [o, ..._orderHistory];
    _wallet = [
      WalletTx(id: o.id, type: WalletTxType.income, amount: o.total, at: o.completedAt!, label: 'Pendapatan order'),
      ..._wallet,
    ];
    if (_apiSaldo != null) _apiSaldo = _apiSaldo! + o.total;
    notifyListeners();
    if (apiConnected) api.completeOrder(o.id, charges).catchError((e) => o);
  }

  void submitCrewRating(int stars, String feedback) {
    final o = _active;
    o?.crewRating = stars;
    o?.crewFeedback = feedback;
    notifyListeners();
    if (apiConnected && o != null) api.rateOrder(o.id, stars, feedback).catchError((_) {});
  }

  void clearActive() {
    _active = null;
    incoming = apiConnected ? null : Seed.incomingOrder();
    notifyListeners();
    if (apiConnected) refreshIncoming();
  }

  // ---- Wallet / pendapatan ----
  List<WalletTx> _wallet = [];
  List<WalletTx> get wallet => _wallet;

  double? _apiSaldo, _apiHeld, _apiTotal, _apiHariIni, _apiMinggu, _apiBulan;

  double get saldoTersedia {
    if (_apiSaldo != null) return _apiSaldo!;
    final income = _wallet.where((t) => t.type == WalletTxType.income).fold(0.0, (s, t) => s + t.amount);
    final wd = _wallet.where((t) => t.type == WalletTxType.withdrawal).fold(0.0, (s, t) => s + t.amount);
    return 1250000 + income - wd - 235000;
  }

  double get saldoTertahan => _apiHeld ?? 150000;
  double get totalPendapatan => _apiTotal ?? 5750000;
  double get pendapatanHariIni => _apiHariIni ?? _wallet.where((t) => t.type == WalletTxType.income).fold(0.0, (s, t) => s + t.amount);
  double get ringkasanMingguIni => _apiMinggu ?? 2450000;
  double get ringkasanBulanIni => _apiBulan ?? 5750000;

  // ---- Withdrawals ----
  List<Withdrawal> _withdrawals = [];
  List<Withdrawal> get withdrawals => _withdrawals;

  Withdrawal createWithdrawal({
    required double nominal,
    required WithdrawSpeed speed,
    required WithdrawMethod method,
    required String account,
  }) {
    final ref = 'WD${DateTime.now().millisecondsSinceEpoch.toString().substring(2, 15)}';
    final w = Withdrawal(
      id: ref,
      nominal: nominal,
      fee: speed.fee,
      speed: speed,
      method: method,
      account: account,
      at: Seed.now,
      status: 'Proses',
    );
    _withdrawals = [w, ..._withdrawals];
    _wallet = [
      WalletTx(id: ref, type: WalletTxType.withdrawal, amount: nominal, at: Seed.now, label: 'Withdraw ${method.label}'),
      ..._wallet,
    ];
    if (_apiSaldo != null) _apiSaldo = _apiSaldo! - nominal;
    notifyListeners();
    if (apiConnected) {
      api.createWithdrawal(nominal: nominal, speed: speed, method: method, account: account).catchError((e) => w);
    }
    return w;
  }

  // ---- Order history ----
  List<Order> _orderHistory = [];
  List<Order> get orderHistory => _orderHistory;

  // ---- Customer invoices ----
  List<Invoice> _invoices = [];
  List<Invoice> get invoices => _invoices;

  double get totalTagihan => _invoices.fold(0.0, (s, i) => s + i.total);
  double get totalTagihanRemaining => _invoices.fold(0.0, (s, i) => s + i.remaining);

  void payInvoice(Invoice inv, double amount, PaymentMethod method) {
    final ref = 'QRIS${DateTime.now().millisecondsSinceEpoch.toString().substring(2, 15)}';
    inv.payments.add(Payment(ref: ref, amount: amount, method: method, at: Seed.now));
    notifyListeners();
    if (apiConnected) api.payInvoice(inv.id, amount, method).catchError((e) => <String, dynamic>{});
  }
}
