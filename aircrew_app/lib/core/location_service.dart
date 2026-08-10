import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'models.dart';

/// Thin wrapper over `geolocator` for one-shot position reads plus a periodic
/// reporter that pushes the driver's live GPS to the API while online (Phase 1).
///
/// All methods degrade gracefully: if location services or permissions are
/// unavailable they return null / no-op rather than throwing, so the demo keeps
/// working on devices/emulators without GPS.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Ensure location services are enabled and permission is granted.
  /// Returns false when the user denies or the platform has no location.
  Future<bool> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('ensurePermission: $e');
      return false;
    }
  }

  /// Current device position as a [LatLngPoint], or null if unavailable.
  Future<LatLngPoint?> current() async {
    if (!await ensurePermission()) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLngPoint(p.latitude, p.longitude);
    } catch (e) {
      debugPrint('current position: $e');
      return null;
    }
  }
}

/// Periodically reports the driver's position to `POST /mitra/location` while
/// the driver is online. Start on going online, stop on going offline/logout.
class DriverLocationReporter {
  DriverLocationReporter(this._api);
  final ApiClient _api;
  Timer? _timer;

  static const _interval = Duration(seconds: 8);

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_timer != null) return;
    if (!await LocationService.instance.ensurePermission()) return;
    await _tick(); // report immediately, then on an interval
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final pos = await LocationService.instance.current();
    if (pos == null) return;
    try {
      await _api.updateLocation(pos.lat, pos.lng);
    } catch (e) {
      debugPrint('location report: $e');
    }
  }
}
