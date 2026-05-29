// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import 'vehicle_detail_screen.dart';
import 'live_tracking_screen.dart';

// Pre-computed mathematical translation constant to optimize projection loops
const double _degToRad = 0.017453292519943295;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapCtrl = MapController();
  TraccarDevice? _selected;
  bool _showSearch = false;
  
  // Explicit tracking parameters to decouple target coordinates from continuous stream loops
  LatLng _initialCenter = const LatLng(31.5, 74.3);
  bool _hasAnchoredCamera = false;

  @override
  Widget build(BuildContext context) {
    // Listening to state changes safely
    final state = context.watch<AppState>();
    final devices = state.devices;
    
    // Anchor dynamic center configuration exactly once to prevent track jumping on canvas updates
    if (!_hasAnchoredCamera && devices.isNotEmpty) {
      final leadPos = state.posFor(devices.first.id); // Aligned to int
      if (leadPos != null) {
        _initialCenter = LatLng(leadPos.latitude, leadPos.longitude);
        _hasAnchoredCamera = true;
      }
    }

    final selPos = _selected != null ? state.posFor(_selected!.id) : null; // Aligned to int
    final selSt = _selected != null ? state.statusFor(_selected!) : DeviceStatus.offline;

    // Map processing loops optimized through static angle translation scalars
    final markers = devices.map((d) {
      final p = state.posFor(d.id); // Aligned to int
      if (p == null) return null;
      final st = state.statusFor(d);
      final col = AppColors.forStatus(st);
      final sel = _selected?.id == d.id;
      
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: sel ? 100 : 44, 
        height: sel ? 80 : 44,
        child: GestureDetector(
          onTap: () {
            setState(() { _selected = _selected?.id == d.id ? null : d; });
            if (_selected != null) {
              _mapCtrl.move(LatLng(p.latitude, p.longitude), 15);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              if (sel) AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.card, 
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                ),
                child: Text(
                  d.name, 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sel) const SizedBox(height: 2),
              Transform.rotate(
                angle: p.course * _degToRad,
                child: Icon(
                  Icons.navigation_rounded, 
                  color: col, 
                  size: sel ? 30 : 22,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      );
    }).whereType<Marker>().toList();

    return Stack(
      children: [
        // ── Map Canvas Renderer ──
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _initialCenter, 
            initialZoom: 12,
            onTap: (_, __) => setState(() { _selected = null; _showSearch = false; }),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.axiontrack.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // ── Header/Search Controller Overlay ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _showSearch
                ? _SearchOverlay(
                    devices: devices,
                    statusFor: state.statusFor,
                    posFor: state.posFor,
                    onSelect: (d, targetCoord) {
                      if (targetCoord != null) _mapCtrl.move(targetCoord, 15);
                      setState(() { _selected = d; _showSearch = false; });
                    },
                    onClose: () => setState(() => _showSearch = false),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showSearch = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.card.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                            ),
                            child: Row(
                              children: [
                                if (_selected != null) ...[
                                  Container(
                                    width: 8, height: 8, 
                                    decoration: BoxDecoration(color: AppColors.forStatus(selSt), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_selected!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
                                ] else ...[
                                  const Icon(Icons.search, color: AppColors.text4, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('Search plate…', style: TextStyle(fontSize: 14, color: AppColors.text3)),
                                ],
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.text3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MapBtn(icon: Icons.layers_rounded, onTap: () {}),
                      const SizedBox(width: 8),
                      _MapBtn(icon: Icons.fullscreen_rounded, onTap: () {}),
                    ],
                  ),
            ),
          ),
        ),

        // ── Map Control Triggers (Right Panel) ──
        Positioned(
          right: 12, top: 90,
          child: Column(
            children: [
              _MapBtn(icon: Icons.add, onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.remove, onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.my_location_rounded, onTap: () => _mapCtrl.move(_initialCenter, 12)),
            ],
          ),
        ),

        // ── Dynamic Context Sheet Panel ──
        if (_selected != null) 
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomSheet(
              device: _selected!, pos: selPos, status: selSt,
              onClose: () => setState(() => _selected = null),
              onDashboard: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => VehicleDetailScreen(device: _selected!))),
              onLiveTrack: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LiveTrackingScreen(device: _selected!))),
            ),
          ),
      ],
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.95), 
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
      ),
      child: Icon(icon, size: 20, color: AppColors.text2),
    ),
  );
}

class _BottomSheet extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onClose, onDashboard, onLiveTrack;
  
  const _BottomSheet({
    required this.device, required this.pos, required this.status,
    required this.onClose, required this.onDashboard, required this.onLiveTrack,
  });

  @override
  Widget build(BuildContext context) {
    final col = AppColors.forStatus(status);
    final bgCol = AppColors.bgForStatus(status);
    final spd = pos?.speedKmh.round() ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Container(
            width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: col.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  device.name, 
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: col, fontFamily: 'Inter'),
                ),
              ),
              const SizedBox(width: 10),
              Text(device.model ?? '', style: const TextStyle(fontSize: 14, color: AppColors.text3)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.text3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.blue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pos?.address ?? (pos != null ? '${pos!.latitude.toStringAsFixed(6)}, ${pos!.longitude.toStringAsFixed(6)}' : '—'),
                    style: const TextStyle(fontSize: 13, color: AppColors.text2, fontWeight: FontWeight.w500), 
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.open_in_new_rounded, color: AppColors.text4, size: 14),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(Icons.speed_rounded, '$spd', 'KM/H', AppColors.text2),
              const SizedBox(width: 8),
              _Stat(Icons.vpn_key_rounded, pos?.ignition == true ? 'ON' : 'OFF', 'ENGINE', pos?.ignition == true ? AppColors.green : AppColors.text4),
              const SizedBox(width: 8),
              _Stat(Icons.radio_button_on_rounded, status.name.toUpperCase(), 'STATUS', col),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDashboard,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    foregroundColor: AppColors.text2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Inter')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onLiveTrack,
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: const Text('Live Track', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _Stat(IconData ico, String val, String lbl, Color col) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(ico, color: col.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1, fontFamily: 'Inter')),
          Text(lbl, style: const TextStyle(fontSize: 10, color: AppColors.text4, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    ),
  );
}

// Dedicated context component containing filtering rules out of the layout bounds
class _SearchOverlay extends StatefulWidget {
  final List<TraccarDevice> devices;
  final DeviceStatus Function(TraccarDevice) statusFor;
  final TraccarPosition? Function(int) posFor; // Changed parameter signature from String to int
  final void Function(TraccarDevice, LatLng?) onSelect;
  final VoidCallback onClose;

  const _SearchOverlay({
    required this.devices,
    required this.statusFor,
    required this.posFor,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.devices.where((d) =>
        _searchQ.isEmpty || d.name.toLowerCase().contains(_searchQ.toLowerCase())).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.text2, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQ = v),
                    autofocus: true,
                    style: const TextStyle(color: AppColors.text1, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search plate…', 
                      border: InputBorder.none,
                      isDense: true, 
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(color: AppColors.text4),
                      fillColor: Colors.transparent, // Inherit container card canvas background
                    ),
                  ),
                ),
                if (_searchQ.isNotEmpty) GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() => _searchQ = ''); },
                  child: const Icon(Icons.close_rounded, color: AppColors.text3, size: 18),
                ),
              ],
            ),
          ),
          if (filtered.isNotEmpty) Container(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true, 
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final d = filtered[i]; 
                final s = widget.statusFor(d); 
                final col = AppColors.forStatus(s);
                return ListTile(
                  leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  title: Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
                  subtitle: Text(d.model ?? d.uniqueId, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgForStatus(s),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.name.toUpperCase(), 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col),
                    ),
                  ),
                  onTap: () {
                    final pos = widget.posFor(d.id); // Aligned cleanly to native int lookup parameters
                    final targetCoord = pos != null ? LatLng(pos.latitude, pos.longitude) : null;
                    widget.onSelect(d, targetCoord);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}