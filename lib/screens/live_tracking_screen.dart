// lib/screens/live_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class LiveTrackingScreen extends StatefulWidget {
  final TraccarDevice device;
  const LiveTrackingScreen({super.key, required this.device});
  @override State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _mapCtrl   = MapController();
  bool _follow     = true;
  bool _satellite  = false;

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final pos    = state.posFor(widget.device.id);
    final status = state.statusFor(widget.device);
    final col    = AC.forStatus(status);
    final spd    = pos?.speedKmh ?? 0.0;
    final dist   = (pos?.totalDistance ?? 0) / 1000;
    final center = pos != null
      ? LatLng(pos.latitude, pos.longitude)
      : const LatLng(31.5, 74.3);

    // Auto-follow
    if (_follow && pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try { _mapCtrl.move(center, _mapCtrl.camera.zoom); } catch (_) {}
      });
    }

    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(child: Column(children: [
        // ── Header ──
        Container(
          color: AC.surface,
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AC.text1),
              onPressed: () => Navigator.pop(context)),
            const Expanded(child: Text('Live Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AC.text1))),
            // Follow toggle
            GestureDetector(
              onTap: () => setState(() => _follow = !_follow),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _follow ? AC.blue.withOpacity(0.2) : AC.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: _follow ? Border.all(color: AC.blue) : null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.navigation_rounded, size: 14,
                    color: _follow ? AC.blue : AC.text3),
                  const SizedBox(width: 4),
                  Text('Follow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _follow ? AC.blue : AC.text3)),
                ]))),
          ]),
        ),

        // ── Map ──
        Expanded(child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: center, initialZoom: 16,
              onTap: (_, __) => setState(() => _follow = false)),
            children: [
              TileLayer(
                urlTemplate: _satellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.axiontrack.app'),
              if (pos != null) MarkerLayer(markers: [
                Marker(
                  point: center, width: 50, height: 50,
                  child: Transform.rotate(
                    angle: (pos.course * 3.14159 / 180),
                    child: Icon(Icons.navigation_rounded, color: col, size: 38,
                      shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)]))),
              ]),
            ],
          ),

          // Top info pill
          Positioned(top: 12, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AC.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('VEHICLE', style: TextStyle(fontSize: 9, color: AC.text3,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  Text(widget.device.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: col)),
                ]),
                const Spacer(),
                Icon(Icons.directions_car_rounded, color: col, size: 26),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('DISTANCE', style: TextStyle(fontSize: 9, color: AC.text3,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  Text('${dist.toStringAsFixed(2)} km',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AC.text1)),
                ]),
              ])),
          ),

          // Map controls
          Positioned(right: 12, top: 80, child: Column(children: [
            _MBtn(Icons.add, () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
            const SizedBox(height: 8),
            _MBtn(Icons.remove, () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
            const SizedBox(height: 8),
            _MBtn(Icons.layers_rounded, () => setState(() => _satellite = !_satellite),
              active: _satellite),
            const SizedBox(height: 8),
            _MBtn(Icons.my_location_rounded, () {
              setState(() => _follow = true);
              _mapCtrl.move(center, 16);
            }, active: _follow),
          ])),

          // No GPS overlay
          if (pos == null) Center(child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AC.surface.withOpacity(0.9), borderRadius: BorderRadius.circular(16)),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.gps_off_rounded, color: AC.text3, size: 40),
              SizedBox(height: 10),
              Text('No GPS position', style: TextStyle(color: AC.text3, fontWeight: FontWeight.w600)),
            ]))),
        ])),

        // ── Bottom info ──
        Container(
          color: AC.surface,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Status
              Row(children: [
                Icon(Icons.link_rounded, size: 15, color: col),
                const SizedBox(width: 8),
                Text(statusLabel(status),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: col)),
              ]),
              const SizedBox(height: 8),
              // Time
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.access_time_rounded, size: 15, color: AC.text3),
                const SizedBox(width: 8),
                Flexible(child: Text(fmtDateTime(pos?.serverTime ?? pos?.fixTime),
                  style: const TextStyle(fontSize: 12, color: AC.text2))),
              ]),
              const SizedBox(height: 8),
              // Address
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AC.text3),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  pos?.address ?? (pos != null
                    ? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
                    : '—'),
                  style: const TextStyle(fontSize: 12, color: AC.text2))),
              ]),
            ])),
            const SizedBox(width: 12),
            Speedometer(speedKmh: spd, size: 96),
          ]),
        ),
      ])),
    );
  }

  Widget _MBtn(IconData ico, VoidCallback onTap, {bool active = false}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: active ? AC.blue.withOpacity(0.2) : AC.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: AC.blue) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)]),
      child: Icon(ico, size: 20, color: active ? AC.blue : AC.text2)));
}
