import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Thin HTTP client for the AirCrew Laravel API.
///
/// Base URL can be overridden at runtime (e.g. from a settings field).
/// Android emulator uses 10.0.2.2 to reach the host machine; web/desktop use
/// 127.0.0.1. Every method throws on non-2xx so callers can fall back to seed
/// data when the backend is offline.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Optional compile-time override:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  static const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String defaultBaseUrl() {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 = host loopback for the Android *emulator*.
      // For a PHYSICAL device set the host LAN IP via the in-app API settings
      // or --dart-define=API_BASE_URL=http://<LAN-IP>:8000/api
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  String baseUrl = defaultBaseUrl();

  /// Current logged-in identities (set after a successful login).
  String currentDriver = 'DRV-001';
  String currentCustomer = 'CST-001';

  /// Sanctum bearer token, set after a successful login.
  String? token;
  bool get isLoggedIn => token != null;

  Duration timeout = const Duration(seconds: 6);

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers()).timeout(timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException('GET $path -> ${res.statusCode}');
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {Map<String, String>? query, Duration? overrideTimeout}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http
        .post(uri, headers: _headers(json: true), body: jsonEncode(body))
        .timeout(overrideTimeout ?? timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException('POST $path -> ${res.statusCode}: ${res.body}');
  }

  Map<String, String> get _driverQ => {'driver': currentDriver};
  Map<String, String> get _custQ => {'customer': currentCustomer};

  Future<bool> ping() async {
    try {
      await _get('/ping');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- Auth (against database, Sanctum token) ----------
  // Auth uses a longer timeout: a free-tier server may cold-start on the first
  // request and mobile networks are slower than the default poll timeout.
  static const _authTimeout = Duration(seconds: 30);

  Future<Customer> loginCustomer(String email, String password) async {
    final j = await _post('/auth/customer/login', {'email': email, 'password': password}, overrideTimeout: _authTimeout);
    token = j['token'] as String?;
    final c = Customer.fromJson(j['customer'] as Map<String, dynamic>);
    currentCustomer = c.id;
    return c;
  }

  Future<Driver> loginMitra(String email, String password) async {
    final j = await _post('/auth/mitra/login', {'email': email, 'password': password}, overrideTimeout: _authTimeout);
    token = j['token'] as String?;
    final d = Driver.fromJson(j['driver'] as Map<String, dynamic>);
    currentDriver = d.id;
    return d;
  }

  Future<void> logout() async {
    try {
      if (token != null) await _post('/auth/logout', {});
    } catch (_) {
      // ignore network errors on logout
    }
    token = null;
  }

  // ---------- Mitra ----------
  Future<Map<String, dynamic>> mitraMe() => _get('/mitra/me', query: _driverQ);
  Future<Map<String, dynamic>> mitraPendapatan() => _get('/mitra/pendapatan', query: _driverQ);

  Future<Order?> mitraIncoming() async {
    final j = await _get('/mitra/incoming', query: _driverQ);
    return j['order'] == null ? null : Order.fromJson(j['order'] as Map<String, dynamic>);
  }

  Future<List<Order>> mitraOrders() async {
    final j = await _get('/mitra/orders', query: _driverQ);
    return (j['orders'] as List).map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
  }

  Future<List<Withdrawal>> mitraWithdrawals() async {
    final j = await _get('/mitra/withdrawals', query: _driverQ);
    return (j['withdrawals'] as List).map((w) => Withdrawal.fromJson(w as Map<String, dynamic>)).toList();
  }

  Future<void> setOnline(bool online) => _post('/mitra/online', {'online': online}, query: _driverQ);
  Future<Order> acceptOrder(String code) async =>
      Order.fromJson((await _post('/mitra/orders/$code/accept', {}, query: _driverQ))['order'] as Map<String, dynamic>);
  Future<void> rejectOrder(String code) => _post('/mitra/orders/$code/reject', {}, query: _driverQ);
  Future<void> advanceOrder(String code, String status) => _post('/mitra/orders/$code/advance', {'status': status}, query: _driverQ);
  Future<Order> completeOrder(String code, OrderCharges c) async => Order.fromJson((await _post('/mitra/orders/$code/complete', {
        'argo': c.argo.toInt(),
        'tol': c.tol.toInt(),
        'parkir': c.parkir.toInt(),
        'lainnya': c.lainnya.toInt(),
        'lainnya_note': c.lainnyaNote,
      }, query: _driverQ))['order'] as Map<String, dynamic>);
  Future<void> rateOrder(String code, int rating, String feedback) =>
      _post('/mitra/orders/$code/rate', {'rating': rating, 'feedback': feedback}, query: _driverQ);

  Future<Withdrawal> createWithdrawal({
    required double nominal,
    required WithdrawSpeed speed,
    required WithdrawMethod method,
    required String account,
  }) async {
    final j = await _post('/mitra/withdrawals', {
      'nominal': nominal.toInt(),
      'speed': speed == WithdrawSpeed.h1 ? 'h1' : 'h0',
      'method': method.name,
      'account': account,
    }, query: _driverQ);
    return Withdrawal.fromJson(j['withdrawal'] as Map<String, dynamic>);
  }

  // ---------- Customer ----------
  Future<List<Invoice>> customerInvoices() async {
    final j = await _get('/customer/invoices', query: _custQ);
    return (j['invoices'] as List).map((i) => Invoice.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<Driver>> customerDrivers() async {
    final j = await _get('/customer/drivers', query: _custQ);
    return (j['drivers'] as List).map((d) => Driver.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> payInvoice(String code, double amount, PaymentMethod method) =>
      _post('/customer/invoices/$code/pay', {'amount': amount.toInt(), 'method': method.name}, query: _custQ);

  /// Create an order and return the created [Order] plus its [Invoice] (only
  /// present when [completed] is true — otherwise the invoice is generated later
  /// by the driver on completion). New orders default to status `waiting` so the
  /// driver in the same area can accept them.
  Future<({Order order, Invoice? invoice})> createOrder({
    required ServiceType service,
    required String pickup,
    required String destination,
    required DateTime scheduledAt,
    String? driver,
    required double argo,
    double tol = 0,
    double parkir = 0,
    double lainnya = 0,
    bool completed = false,
  }) async {
    final j = await _post('/customer/orders', {
      'service': serviceToApi(service),
      'pickup': pickup,
      'destination': destination,
      'scheduled_at': scheduledAt.toIso8601String(),
      'driver': driver,
      'argo': argo.toInt(),
      'tol': tol.toInt(),
      'parkir': parkir.toInt(),
      'lainnya': lainnya.toInt(),
      'completed': completed,
    }, query: _custQ);
    return (
      order: Order.fromJson(j['order'] as Map<String, dynamic>),
      invoice: j['invoice'] == null ? null : Invoice.fromJson(j['invoice'] as Map<String, dynamic>),
    );
  }

  /// Fetch a single customer order (used to poll live status while the driver
  /// accepts and drives the trip).
  Future<Order> customerOrder(String code) async {
    final j = await _get('/customer/orders/$code', query: _custQ);
    return Order.fromJson(j['order'] as Map<String, dynamic>);
  }

  /// Customer rates the driver after the trip completes.
  Future<void> customerRateOrder(String code, int rating, String feedback) =>
      _post('/customer/orders/$code/rate', {'rating': rating, 'feedback': feedback}, query: _custQ);
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
