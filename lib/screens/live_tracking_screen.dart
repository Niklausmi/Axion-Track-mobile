// lib/screens/live_tracking_screen.dart  — v2 (live trail, auto-center, map layers)
import 'dart:async';
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
  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _mapCtrl = MapController();
  bool _followVehicle = true;
  bool _showInfo = true;
  int _mapStyle = 0;   // 0=streets, 1=satellite, 2=dark
  final List<LatLng> _trail = [];
  TraccarPosition? _lastPos;

  // FIX: manual 10s poll for this screen so it always has fresh data
  Timer? _pollTimer;

  static const _tileUrls = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
  ];
  static const _styleLabels = ['Streets', 'Satellite', 'Dark'];

  @override
  void initState() {
    super.initState();
    // Start 10s live refresh specific to this screen
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      context.read<AppState>().refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _updateTrail(TraccarPosition pos) {
    if (_lastPos == null || pos.id != _lastPos!.id) {
      final pt = LatLng(pos.latitude, pos.longitude);
      if (_trail.isEmpty || (_trail.last.latitude - pos.latitude).abs() > 0.00005
          || (_trail.last.longitude - pos.longitude).abs() > 0.00005) {
        _trail.add(pt);
        if (_trail.length > 200) _trail.removeAt(0);
      }
      _lastPos = pos;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final pos    = state.posFor(widget.device.id);
    final status = state.statusFor(widget.device);
    final col    = AppColors.forStatus(status);
    final spd    = pos?.speedKmh ?? 0.0;
    final center = pos != null ? LatLng(pos.latitude, pos.longitude) : const LatLng(31.5, 74.3);
    final dist   = (pos?.totalDistance ?? 0) / 1000;

    if (pos != null) _updateTrail(pos);

    if (_followVehicle && pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try { _mapCtrl.move(center, _mapCtrl.camera.zoom); } catch (_) {}
      });
    }

    return Scaffold(
      body: SafeArea(child: Column(children: [
        // ── Header ──
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _CircleBtn(icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context)),
            const Expanded(child: Text('Live Tracking', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1))),
            _CircleBtn(
              icon: _followVehicle ? Icons.navigation_rounded : Icons.navigation_outlined,
              color: _followVehicle ? AppColors.primary : null,
              onTap: () => setState(() => _followVehicle = !_followVehicle)),
          ]),
        ),

        // ── Map ──
        Expanded(child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onTap: (_, __) => setState(() => _followVehicle = false),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrls[_mapStyle],
                userAgentPackageName: 'com.axiontrack.app',
              ),
              // Trail polyline
              if (_trail.length >= 2) PolylineLayer<Object>(polylines: [
                Polyline(points: _trail, strokeWidth: 3,
                  color: col.withOpacity(0.6)),
              ]),
              if (pos != null) MarkerLayer(markers: [
                Marker(
                  point: center, width: 52, height: 52,
                  child: Transform.rotate(
                    angle: pos.course * 3.14159 / 180,
                    child: Container(
                      decoration: BoxDecoration(
                        color: col.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.navigation_rounded, color: col, size: 32,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)]),
                    ),
                  ),
                ),
              ]),
            ],
          ),

          // ── Top pill ──
          Positioned(top: 12, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('VEHICLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
                  Text(widget.device.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col)),
                ]),
                const Spacer(),
                StatusBadge(status),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('TOTAL DIST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
                  Text('${dist.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text1)),
                ]),
              ]),
            ),
          ),

          // ── Map controls ──
          Positioned(right: 12, bottom: _showInfo ? 270 : 90, child: Column(children: [
            _MapBtn(icon: Icons.add,        onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
            const SizedBox(height: 8),
            _MapBtn(icon: Icons.remove,     onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
            const SizedBox(height: 8),
            _MapBtn(icon: Icons.layers_outlined, onTap: () => setState(() => _mapStyle = (_mapStyle + 1) % 3),
              label: _styleLabels[_mapStyle]),
            const SizedBox(height: 8),
            _MapBtn(icon: _showInfo ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              onTap: () => setState(() => _showInfo = !_showInfo)),
          ])),

          // ── GPS coords pill ──
          if (pos != null) Positioned(bottom: _showInfo ? 220 : 40, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
              ),
              child: Text(
                '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.text2, fontFamily: 'monospace'),
              ),
            ),
          ),
        ])),

        // ── Bottom info panel ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: _showInfo ? null : 0,
          child: _showInfo ? Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _InfoRow(Icons.link_rounded,          statusLabel(status), valueColor: col),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.access_time_rounded,   fmtDateTime(pos?.serverTime ?? pos?.fixTime)),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.explore_rounded,       pos != null ? '${pos.course.round()}° · ${pos.altitude.round()} m alt' : '—'),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.location_on_outlined,
                    pos?.address ?? (pos != null ? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}' : '—')),
                ])),
                const SizedBox(width: 12),
                Speedometer(speedKmh: spd, size: 100),
              ]),
              if (pos != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  if (pos.ignition != null)
                    _InfoChip(Icons.power_settings_new_rounded,
                      pos.ignition! ? 'IGN On' : 'IGN Off',
                      pos.ignition! ? AppColors.green : AppColors.text3),
                  if (pos.satellites != null) ...[
                    const SizedBox(width: 8),
                    _InfoChip(Icons.satellite_alt, '${pos.satellites} sat', AppColors.purple),
                  ],
                  if (pos.rssi != null) ...[
                    const SizedBox(width: 8),
                    _InfoChip(Icons.signal_cellular_alt, '${pos.rssi}%',
                      (pos.rssi ?? 0) > 50 ? AppColors.green : AppColors.orange),
                  ],
                  if (pos.power != null) ...[
                    const SizedBox(width: 8),
                    _InfoChip(Icons.electric_bolt_rounded, '${pos.power!.toStringAsFixed(1)}V', AppColors.orange),
                  ],
                ]),
              ],
            ]),
          ) : const SizedBox.shrink(),
        ),
      ])),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color != null ? color!.withOpacity(0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 16, color: color ?? AppColors.text1),
    ),
  );
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  const _MapBtn({required this.icon, required this.onTap, this.label});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: label != null ? 52 : 44,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: AppColors.text2),
        if (label != null) Text(label!, style: const TextStyle(fontSize: 8, color: AppColors.text3, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.icon, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: AppColors.text4),
    const SizedBox(width: 8),
    Expanded(child: Text(value, style: TextStyle(fontSize: 13,
      color: valueColor ?? AppColors.text1,
      fontWeight: valueColor != null ? FontWeight.w700 : FontWeight.w500))),
  ]);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}
