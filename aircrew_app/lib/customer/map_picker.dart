import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/location_service.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Full-screen map picker (OpenStreetMap tiles, no API key). Tap the map or drag
/// to move the centre pin, then confirm to return the selected [LatLngPoint].
///
/// Used by the customer order flow to choose pickup and destination points that
/// feed the distance-based fare estimate (Phase 1).
class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({
    super.key,
    required this.title,
    this.initial,
  });

  /// e.g. "Pilih Titik Jemput" / "Pilih Tujuan".
  final String title;

  /// Starting centre; defaults to Soekarno-Hatta (CGK) area when null.
  final LatLngPoint? initial;

  static Future<LatLngPoint?> show(BuildContext context, {required String title, LatLngPoint? initial}) {
    return Navigator.of(context).push<LatLngPoint>(
      MaterialPageRoute(builder: (_) => MapLocationPicker(title: title, initial: initial)),
    );
  }

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  // Default centre near Soekarno-Hatta International Airport.
  static const _fallback = LatLng(-6.1256, 106.6558);

  final MapController _map = MapController();
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initial != null ? LatLng(widget.initial!.lat, widget.initial!.lng) : _fallback;
  }

  Future<void> _useMyLocation() async {
    final pos = await LocationService.instance.current();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi tidak tersedia. Aktifkan GPS & izin lokasi.')),
        );
      }
      return;
    }
    setState(() => _center = LatLng(pos.lat, pos.lng));
    _map.move(_center, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.aircrew.app',
                maxZoom: 19,
              ),
            ],
          ),
          // Fixed centre pin — the map moves underneath it.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_pin, size: 48, color: AirColors.red),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton(
              heroTag: 'myloc',
              onPressed: _useMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () => Navigator.of(context).pop(LatLngPoint(_center.latitude, _center.longitude)),
              icon: const Icon(Icons.check),
              label: const Text('Pilih Titik Ini'),
            ),
          ),
        ],
      ),
    );
  }
}
