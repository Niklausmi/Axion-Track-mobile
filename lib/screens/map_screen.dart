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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapCtrl = MapController();
  TraccarDevice? _selected;
  bool _showSearch = false;
  String _searchQ  = '';
  final _searchCtrl = TextEditingController();

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state   = context.watch<AppState>();
    final devices = state.devices;
    final selPos  = _selected != null ? state.posFor(_selected!.id) : null;
    final selSt   = _selected != null ? state.statusFor(_selected!) : DeviceStatus.offline;

    // Build markers
    final markers = devices.map((d) {
      final p = state.posFor(d.id);
      if (p == null) return null;
      final st  = state.statusFor(d);
      final col = AC.forStatus(st);
      final sel = _selected?.id == d.id;
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: sel ? 100 : 44, height: sel ? 80 : 44,
        child: GestureDetector(
          onTap: () {
            setState(() { _selected = _selected?.id == d.id ? null : d; });
            if (_selected != null) _mapCtrl.move(LatLng(p.latitude, p.longitude), 15);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (sel) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)]),
              child: Text(d.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col),
                overflow: TextOverflow.ellipsis)),
            if (sel) const SizedBox(height: 2),
            Transform.rotate(
              angle: p.course * 3.14159 / 180,
              child: Icon(Icons.navigation_rounded, color: col, size: sel ? 30 : 22,
                shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)])),
          ]),
        ),
      );
    }).whereType<Marker>().toList();

    final center = devices.isNotEmpty && state.posFor(devices.first.id) != null
      ? LatLng(state.posFor(devices.first.id)!.latitude, state.posFor(devices.first.id)!.longitude)
      : const LatLng(31.5, 74.3);

    return Stack(children: [
      // ── Map ──
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: center, initialZoom: 12,
          onTap: (_, __) => setState(() { _selected = null; _showSearch = false; })),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.axiontrack.app'),
          MarkerLayer(markers: markers),
        ],
      ),

      // ── Top bar ──
      Positioned(top: 0, left: 0, right: 0,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: _showSearch
            ? _SearchOverlay(
                ctrl: _searchCtrl, query: _searchQ,
                devices: devices.where((d) =>
                  _searchQ.isEmpty || d.name.toLowerCase().contains(_searchQ.toLowerCase())).toList(),
                statusFor: state.statusFor,
                onChanged: (v) => setState(() => _searchQ = v),
                onSelect: (d) {
                  final p = state.posFor(d.id);
                  if (p != null) { _mapCtrl.move(LatLng(p.latitude, p.longitude), 15); }
                  setState(() { _selected = d; _showSearch = false; _searchCtrl.clear(); _searchQ = ''; });
                },
                onClose: () => setState(() { _showSearch = false; _searchCtrl.clear(); _searchQ = ''; }),
              )
            : Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _showSearch = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AC.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)]),
                    child: Row(children: [
                      if (_selected != null) ...[
                        Container(width: 8, height: 8, decoration: BoxDecoration(
                          color: AC.forStatus(selSt), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(_selected!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.text1)),
                      ] else ...[
                        const Icon(Icons.search, color: AC.text3, size: 18),
                        const SizedBox(width: 8),
                        const Text('Search plate…', style: TextStyle(fontSize: 14, color: AC.text3)),
                      ],
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AC.text3),
                    ]),
                  ),
                )),
                const SizedBox(width: 8),
                _MapBtn(icon: Icons.layers_rounded, onTap: () {}),
                const SizedBox(width: 8),
                _MapBtn(icon: Icons.fullscreen_rounded, onTap: () {}),
              ]),
        ))),

      // ── Right controls ──
      Positioned(right: 12, top: 90,
        child: Column(children: [
          _MapBtn(icon: Icons.add, onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
          const SizedBox(height: 8),
          _MapBtn(icon: Icons.remove, onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
          const SizedBox(height: 8),
          _MapBtn(icon: Icons.my_location_rounded, onTap: () => _mapCtrl.move(center, 12)),
        ])),

      // ── Bottom sheet ──
      if (_selected != null) Positioned(
        bottom: 0, left: 0, right: 0,
        child: _BottomSheet(
          device: _selected!, pos: selPos, status: selSt,
          onClose: () => setState(() => _selected = null),
          onDashboard: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => VehicleDetailScreen(device: _selected!))),
          onLiveTrack: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LiveTrackingScreen(device: _selected!))),
        )),
    ]);
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
      decoration: BoxDecoration(color: AC.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)]),
      child: Icon(icon, size: 20, color: AC.text2)));
}

class _BottomSheet extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onClose, onDashboard, onLiveTrack;
  const _BottomSheet({required this.device, required this.pos, required this.status,
    required this.onClose, required this.onDashboard, required this.onLiveTrack});

  @override
  Widget build(BuildContext context) {
    final col = AC.forStatus(status);
    final spd = pos?.speedKmh.round() ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)]),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AC.surface3, borderRadius: BorderRadius.circular(2))),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: col.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col, width: 1.5)),
            child: Text(device.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: col))),
          const SizedBox(width: 10),
          Text(device.model ?? '', style: const TextStyle(fontSize: 14, color: AC.text3)),
          const Spacer(),
          GestureDetector(onTap: onClose,
            child: Container(width: 30, height: 30,
              decoration: const BoxDecoration(color: AC.surface2, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: AC.text3))),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.location_on_rounded, color: AC.blue, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
              pos?.address ?? (pos != null
                ? '${pos!.latitude.toStringAsFixed(6)}, ${pos!.longitude.toStringAsFixed(6)}'
                : '—'),
              style: const TextStyle(fontSize: 12, color: AC.blue), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.open_in_new_rounded, color: AC.blue, size: 12),
          ])),
        const SizedBox(height: 14),
        Row(children: [
          _Stat(Icons.speed_rounded, '$spd', 'KM/H', AC.text2),
          const SizedBox(width: 8),
          _Stat(Icons.vpn_key_rounded, pos?.ignition == true ? 'ON' : 'OFF', 'ENGINE',
            pos?.ignition == true ? AC.green : AC.text3),
          const SizedBox(width: 8),
          _Stat(Icons.radio_button_on_rounded, statusLabel(status).toUpperCase(), 'STATUS', col),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onDashboard,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AC.blue),
              foregroundColor: AC.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13)),
            child: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700)))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: onLiveTrack,
            icon: const Icon(Icons.navigation_rounded, size: 16),
            label: const Text('Live Track', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13)))),
        ]),
      ]),
    );
  }

  Widget _Stat(IconData ico, String val, String lbl, Color col) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Icon(ico, color: col, size: 22),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: col)),
      Text(lbl, style: const TextStyle(fontSize: 9, color: AC.text3, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    ])));
}

class _SearchOverlay extends StatelessWidget {
  final TextEditingController ctrl;
  final String query;
  final List<TraccarDevice> devices;
  final DeviceStatus Function(TraccarDevice) statusFor;
  final ValueChanged<String> onChanged;
  final ValueChanged<TraccarDevice> onSelect;
  final VoidCallback onClose;
  const _SearchOverlay({required this.ctrl, required this.query, required this.devices,
    required this.statusFor, required this.onChanged, required this.onSelect, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AC.surface.withOpacity(0.97), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          GestureDetector(onTap: onClose,
            child: const Icon(Icons.arrow_back_rounded, color: AC.text2, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: ctrl, onChanged: onChanged, autofocus: true,
            style: const TextStyle(color: AC.text1, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search plate…', border: InputBorder.none,
              isDense: true, contentPadding: EdgeInsets.zero,
              hintStyle: TextStyle(color: AC.text3)))),
          if (query.isNotEmpty) GestureDetector(
            onTap: () { ctrl.clear(); onChanged(''); },
            child: const Icon(Icons.close_rounded, color: AC.text3, size: 18)),
        ])),
      if (devices.isNotEmpty) Container(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.builder(
          shrinkWrap: true, padding: EdgeInsets.zero,
          itemCount: devices.length,
          itemBuilder: (_, i) {
            final d = devices[i]; final s = statusFor(d); final col = AC.forStatus(s);
            return ListTile(
              leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
              title: Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.text1)),
              subtitle: Text(d.model ?? d.uniqueId, style: const TextStyle(fontSize: 12, color: AC.text3)),
              trailing: Text(statusLabel(s).toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: col)),
              onTap: () => onSelect(d));
          })),
    ]));
}
