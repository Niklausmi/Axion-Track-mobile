// lib/screens/secondary_screens.dart — v5 (Dark Mode Removed from Settings)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import 'live_tracking_screen.dart';
import 'history_screen.dart';

// ══════════════════════════════════════════════════════════════════════════
// MAP SCREEN
// ══════════════════════════════════════════════════════════════════════════
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _mapCtrl = MapController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;
  TraccarDevice? _selected;
  int _mapStyle = 0;
  Timer? _pollTimer;

  static const _tiles = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ];

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) context.read<AppState>().refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<AppState>();

    final searchFiltered = _query.isEmpty
        ? state.devices
        : state.devices.where((d) =>
            d.name.toLowerCase().contains(_query.toLowerCase()) ||
            d.uniqueId.contains(_query)).toList();

    // Build markers
    final markers = state.devices.map((d) {
      final p = state.positions[d.id];
      if (p == null) return null;
      final st  = state.statusFor(d);
      final col = AppColors.forStatus(st);
      final sel = _selected?.id == d.id;
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: sel ? 90 : 36,
        height: sel ? 52 : 36,
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = _selected?.id == d.id ? null : d);
            if (_selected != null) {
              _mapCtrl.move(LatLng(p.latitude, p.longitude), 14);
            }
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (sel) Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6)],
              ),
              child: Text(d.name,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col),
                overflow: TextOverflow.ellipsis),
            ),
            if (sel) const SizedBox(height: 2),
            Transform.rotate(
              angle: p.course * 3.14159 / 180,
              child: Icon(Icons.navigation_rounded, color: col, size: sel ? 26 : 22,
                shadows: [Shadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)]),
            ),
          ]),
        ),
      );
    }).whereType<Marker>().toList();

    final firstPos = state.devices.map((d) => state.positions[d.id]).firstWhere((p) => p != null, orElse: () => null);
    final center = firstPos != null ? LatLng(firstPos.latitude, firstPos.longitude) : const LatLng(31.5, 74.3);

    return Stack(children: [
      // Map
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 11,
          onTap: (_, __) => setState(() { _selected = null; _showSearch = false; }),
        ),
        children: [
          TileLayer(urlTemplate: _tiles[_mapStyle], userAgentPackageName: 'com.axiontrack.app'),
          MarkerLayer(markers: markers),
        ],
      ),

      // Search overlay
      Positioned(top: 0, left: 0, right: 0,
        child: SafeArea(child: Column(children: [
          // Search bar
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => _showSearch = !_showSearch),
                child: const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.search_rounded, color: AppColors.primary, size: 20)),
              ),
              Expanded(child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() { _query = v; _showSearch = v.isNotEmpty; }),
                onTap: () => setState(() => _showSearch = true),
                decoration: const InputDecoration(
                  hintText: 'Search plate...',
                  hintStyle: TextStyle(color: AppColors.text4, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                ),
              )),
              if (_query.isNotEmpty) GestureDetector(
                onTap: () { _searchCtrl.clear(); setState(() { _query = ''; _showSearch = false; }); },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.close_rounded, color: AppColors.text4, size: 18)),
              ),
            ]),
          ),

          // Search results dropdown
          if (_showSearch && searchFiltered.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: searchFiltered.length,
                itemBuilder: (_, i) {
                  final d  = searchFiltered[i];
                  final st = state.statusFor(d);
                  final col = AppColors.forStatus(st);
                  return GestureDetector(
                    onTap: () {
                      final p = state.positions[d.id];
                      if (p != null) _mapCtrl.move(LatLng(p.latitude, p.longitude), 14);
                      setState(() { _selected = d; _showSearch = false; _searchCtrl.text = d.name; _query = d.name; });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
                          Text(d.model ?? d.uniqueId, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                        ])),
                        Text(statusLabel(st).toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.4)),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ])),
      ),

      // Map controls
      Positioned(right: 12, bottom: _selected != null ? 180 : 60,
        child: Column(children: [
          _MapBtn(icon: Icons.add,     onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
          const SizedBox(height: 8),
          _MapBtn(icon: Icons.remove,  onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
          const SizedBox(height: 8),
          _MapBtn(icon: Icons.layers_outlined, onTap: () => setState(() => _mapStyle = 1 - _mapStyle)),
          const SizedBox(height: 8),
          _MapBtn(icon: Icons.my_location_rounded, onTap: () => _mapCtrl.move(center, 11)),
        ]),
      ),

      // Vehicle count badge
      Positioned(bottom: _selected != null ? 180 : 16, left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('${markers.length} / ${state.devices.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text1)),
          ]),
        ),
      ),

      // Selected vehicle bottom sheet
      if (_selected != null)
        Positioned(bottom: 0, left: 0, right: 0,
          child: _MapVehicleSheet(
            device: _selected!,
            pos: state.posFor(_selected!.id),
            status: state.statusFor(_selected!),
            onClose: () => setState(() => _selected = null),
            onTrack: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LiveTrackingScreen(device: _selected!))),
            onHistory: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => HistoryScreen(device: _selected!))),
          ),
        ),
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
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Icon(icon, size: 20, color: AppColors.text2)),
  );
}

class _MapVehicleSheet extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onClose, onTrack, onHistory;
  const _MapVehicleSheet({required this.device, required this.pos, required this.status,
    required this.onClose, required this.onTrack, required this.onHistory});
  @override
  Widget build(BuildContext context) {
    final col = AppColors.forStatus(status);
    final spd = pos?.speedKmh.round() ?? 0;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.bgForStatus(status), shape: BoxShape.circle),
            child: Icon(Icons.directions_car_rounded, color: col, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(device.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
            Text(device.model ?? device.uniqueId, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.bgForStatus(status), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel(status).toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          GestureDetector(onTap: onClose,
            child: Container(width: 30, height: 30,
              decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.text3))),
        ]),
        const SizedBox(height: 12),
        if (pos != null) Row(children: [
          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.text4),
          const SizedBox(width: 6),
          Text(fmtDateTime(pos!.serverTime), style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          const Spacer(),
          const Icon(Icons.speed_rounded, size: 14, color: AppColors.text4),
          const SizedBox(width: 6),
          Text('$spd km/h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text1)),
        ]),
        if (pos?.address != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(pos!.address!, style: const TextStyle(fontSize: 12, color: AppColors.text3),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: onTrack,
            icon: const Icon(Icons.navigation_rounded, size: 16),
            label: const Text('Live Track'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('History'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ALERTS SCREEN  — All / Unread / Read tabs + Alert Detail
// ══════════════════════════════════════════════════════════════════════════
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Set<int> _readIds = {};
  int _tab = 0; // 0=All, 1=Unread, 2=Read

  void _markAll(List<TraccarEvent> events) {
    setState(() { for (final e in events) _readIds.add(e.id); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state  = context.watch<AppState>();
    final devMap = {for (final d in state.devices) d.id: d};

    final unreadList = state.events.where((e) => !_readIds.contains(e.id)).toList();
    final readList   = state.events.where((e) =>  _readIds.contains(e.id)).toList();
    final allList    = state.events;

    final display = _tab == 0 ? allList : _tab == 1 ? unreadList : readList;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            Row(children: [
              const Text('Events', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text1)),
              const Spacer(),
              if (unreadList.isNotEmpty)
                GestureDetector(
                  onTap: () => _markAll(allList),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.done_all_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      const Text('Mark all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            // Tabs
            Row(children: [
              _AlertTab(label: 'All',    count: allList.length,    selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _AlertTab(label: 'Unread', count: unreadList.length, selected: _tab == 1, onTap: () => setState(() => _tab = 1), badge: true),
              const SizedBox(width: 8),
              _AlertTab(label: 'Read',   count: readList.length,   selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
            ]),
            const SizedBox(height: 12),
          ]),
        ),

        // List
        Expanded(child: display.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.text4),
              SizedBox(height: 12),
              Text('No events', style: TextStyle(fontSize: 15, color: AppColors.text3)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: display.length,
              itemBuilder: (ctx, i) {
                final e    = display[i];
                final dev  = devMap[e.deviceId];
                final isRead = _readIds.contains(e.id);
                return GestureDetector(
                  onTap: () {
                    setState(() => _readIds.add(e.id));
                    Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => AlertDetailScreen(event: e, device: dev)));
                  },
                  child: _AlertCard(event: e, deviceName: dev?.name ?? 'Device #${e.deviceId}', isRead: isRead),
                );
              },
            ),
        ),
      ])),
    );
  }
}

class _AlertTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;
  const _AlertTab({required this.label, required this.count, required this.selected,
    required this.onTap, this.badge = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.text3)),
        if (badge && count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.3) : AppColors.red,
              borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ]),
    ),
  );
}

class _AlertCard extends StatelessWidget {
  final TraccarEvent event;
  final String deviceName;
  final bool isRead;
  const _AlertCard({required this.event, required this.deviceName, required this.isRead});

  @override
  Widget build(BuildContext context) {
    final meta = eventMeta(event.type);
    final col  = Color(meta['color'] as int);
    final bg   = Color(meta['bg']    as int);
    final lat  = event.attributes['latitude']  as num?;
    final lon  = event.attributes['longitude'] as num?;
    final spd  = event.attributes['speed']     as num?;

    final actualTime = event.eventTime ?? event.serverTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isRead ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isRead ? 0.03 : 0.06),
          blurRadius: isRead ? 4 : 10,
          offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(meta['icon'] as IconData, color: col, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(meta['label'] as String,
                    style: TextStyle(fontSize: 13, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: AppColors.text1),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeAgo(actualTime), style: const TextStyle(fontSize: 11, color: AppColors.text4)),
                    if (!isRead) ...[
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(deviceName, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            if (lat != null && lon != null) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: AppColors.text4),
                const SizedBox(width: 4),
                Text('${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.text4)),
                if (spd != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.speed_rounded, size: 12, color: AppColors.text4),
                  const SizedBox(width: 4),
                  Text('${(spd * 3.6).round()} km/h',
                    style: const TextStyle(fontSize: 11, color: AppColors.text4)),
                ],
              ]),
            ),
          ])),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ALERT DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════
class AlertDetailScreen extends StatelessWidget {
  final TraccarEvent event;
  final TraccarDevice? device;
  const AlertDetailScreen({super.key, required this.event, required this.device});

  @override
  Widget build(BuildContext context) {
    final meta  = eventMeta(event.type);
    final col   = Color(meta['color'] as int);
    final bg    = Color(meta['bg']    as int);
    final lat   = (event.attributes['latitude']  as num?)?.toDouble();
    final lon   = (event.attributes['longitude'] as num?)?.toDouble();
    final spd   = (event.attributes['speed']     as num?)?.toDouble();
    final hasLoc = lat != null && lon != null;

    final actualTime = event.eventTime ?? event.serverTime;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.text1))),
            const SizedBox(width: 12),
            const Text('Alert Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1)),
          ]),
        ),

        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          // Event card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Row(children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(meta['icon'] as IconData, color: col, size: 26)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta['label'] as String,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                const SizedBox(height: 4),
                Text(device?.name ?? 'Unknown',
                  style: const TextStyle(fontSize: 13, color: AppColors.text3)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.directions_car_rounded, size: 12, color: AppColors.text3),
                      const SizedBox(width: 5),
                      Text(device?.name ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('open', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ])),
            ]),
          ),
          const SizedBox(height: 14),

          // Map
          if (hasLoc) Container(
            height: 200,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)]),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat!, lon!),
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.axiontrack.app'),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(lat, lon),
                      width: 44, height: 44,
                      child: Container(
                        decoration: BoxDecoration(color: bg, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [BoxShadow(color: col.withOpacity(0.4), blurRadius: 8)]),
                        child: Icon(meta['icon'] as IconData, color: col, size: 20)),
                    ),
                  ]),
                ],
              ),
              Positioned(bottom: 10, right: 10, child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('Open in Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 14),

          // Details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
              const SizedBox(height: 14),
              _DetailItem(Icons.label_outline_rounded, 'EVENT TYPE', meta['label'] as String),
              const Divider(height: 18, color: AppColors.divider),
              _DetailItem(Icons.access_time_rounded, 'OCCURRED AT',
                actualTime != null
                  ? '${_monthName(actualTime.month)} ${actualTime.day}, ${actualTime.year} · ${fmtTimeOnly(actualTime)}'
                  : '—'),
              const Divider(height: 18, color: AppColors.divider),
              _DetailItem(Icons.speed_rounded, 'SPEED',
                spd != null ? '${(spd * 3.6).round()} km/h' : '0 km/h'),
              if (hasLoc) ...[
                const Divider(height: 18, color: AppColors.divider),
                _DetailItem(Icons.location_on_outlined, 'COORDINATES',
                  '${lat!.toStringAsFixed(6)}, ${lon!.toStringAsFixed(6)}'),
              ],
              if (device != null) ...[
                const Divider(height: 18, color: AppColors.divider),
                _DetailItem(Icons.directions_car_rounded, 'VEHICLE', device!.name),
              ],
            ]),
          ),
          const SizedBox(height: 24),
        ])),
      ])),
    );
  }

  String _monthName(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailItem(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 36, height: 36,
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: AppColors.primary)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
    ])),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sess  = state.session;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: ListView(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: const Text('Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text1)),
        ),

        // Profile card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A73E8), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 32)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sess?.name ?? 'Admin',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text(sess?.email ?? '—',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
              const SizedBox(height: 8),
              Row(children: [
                _Badge(sess?.administrator == true ? 'Administrator' : 'User'),
                const SizedBox(width: 8),
                _Badge('Axion Track v3'),
              ]),
            ])),
          ]),
        ),

        _SettingsSection(title: 'Fleet', items: [
          _SettingsRow(
            icon: Icons.directions_car_rounded,
            iconBg: const Color(0xFFDBEAFE),
            iconColor: AppColors.primary,
            label: 'Fleet Vehicles',
            trailing: Text('${state.devices.length}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1))),
          _SettingsRow(
            icon: state.wsConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            iconBg: state.wsConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            iconColor: state.wsConnected ? AppColors.green : AppColors.red,
            label: 'Live Connection',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: state.wsConnected ? AppColors.green : AppColors.red,
                  shape: BoxShape.circle,
                  boxShadow: state.wsConnected ? [BoxShadow(color: AppColors.green.withOpacity(0.5), blurRadius: 6)] : null,
                )),
              const SizedBox(width: 6),
              Text(state.wsConnected ? 'Connected' : 'Reconnecting',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: state.wsConnected ? AppColors.green : AppColors.red)),
            ])),
        ]),

        // Account section
        _SettingsSection(title: 'Account', items: [
          _SettingsRow(icon: Icons.badge_rounded, iconBg: const Color(0xFFF5F3FF), iconColor: AppColors.purple,
            label: 'User ID',
            trailing: Text('#${sess?.id ?? "—"}',
              style: const TextStyle(fontSize: 12, color: AppColors.text3))),
          _SettingsRow(icon: Icons.notifications_rounded, iconBg: const Color(0xFFFEF3C7), iconColor: AppColors.orange,
            label: 'Notifications', onTap: () {}),
          _SettingsRow(icon: Icons.security_rounded, iconBg: const Color(0xFFDCFCE7), iconColor: AppColors.green,
            label: 'Change Password', onTap: () {}),
        ]),

        // App section
        _SettingsSection(title: 'App', items: [
          _SettingsRow(icon: Icons.info_outline_rounded, iconBg: const Color(0xFFDBEAFE), iconColor: AppColors.primary,
            label: 'Version',
            trailing: const Text('3.0.0', style: TextStyle(fontSize: 12, color: AppColors.text3))),
        ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF0EA5E9)]),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Powered by',
                  style: TextStyle(fontSize: 10, color: AppColors.text3, fontWeight: FontWeight.w500)),
                const Text('Axion Track Tech',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ])),
              const Text('© 2026', style: TextStyle(fontSize: 11, color: AppColors.text4)),
            ]),
          ),
        ),

        // Sign out
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              await context.read<AppState>().logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE2E2),
              foregroundColor: AppColors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )),
        ),
      ])),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _SettingsSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.8)),
    ),
    Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1) const Divider(height: 1, indent: 66, color: AppColors.divider),
        ],
      ]),
    ),
  ]);
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.iconBg, required this.iconColor,
    required this.label, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1))),
        if (trailing != null) trailing!
        else if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.text4, size: 20),
      ]),
    ),
  );
}