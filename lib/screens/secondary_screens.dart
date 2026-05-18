// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class AppColors {
  static Color forStatus(DeviceStatus s) => AC.forStatus(s);
  static const Color text1 = AC.text1;
  static const Color text2 = AC.text2;
  static const Color text3 = AC.text3;
  static const Color text4 = AC.text4;
  static const Color surface = AC.surface;
  static const Color background = AC.bg;
  static const Color primary = AC.blue;
  static const Color blue = AC.blue;
  static const Color green = AC.green;
  static const Color red = AC.red;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapCtrl = MapController();
  TraccarDevice? _selected;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final positions = state.positions;
    final devices   = state.devices;

    final markers = devices.map((d) {
      final p = positions[d.id];
      if (p == null) return null;
      final st  = state.statusFor(d);
      final col = AppColors.forStatus(st);
      final isSel = _selected?.id == d.id;
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: isSel ? 80 : 40,
        height: isSel ? 80 : 40,
        child: GestureDetector(
          onTap: () => setState(() {
            _selected = _selected?.id == d.id ? null : d;
            if (_selected != null) {
              _mapCtrl.move(LatLng(p.latitude, p.longitude), 14);
            }
          }),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isSel) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)]),
              child: Text(d.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col)),
            ),
            if (isSel) const SizedBox(height: 2),
            Icon(Icons.navigation_rounded, color: col, size: isSel ? 28 : 22,
              shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)]),
          ]),
        ),
      );
    }).whereType<Marker>().toList();

    final center = markers.isNotEmpty
      ? LatLng(positions[devices.first.id]?.latitude ?? 30, positions[devices.first.id]?.longitude ?? 70)
      : const LatLng(31.5, 74.3);

    return Stack(children: [
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 11,
          onTap: (_, __) => setState(() => _selected = null),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.axiontrack.app',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
      // Controls
      Positioned(right: 12, top: 12, child: Column(children: [
        _MapBtn(icon: Icons.add, onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
        const SizedBox(height: 8),
        _MapBtn(icon: Icons.remove, onTap: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
        const SizedBox(height: 8),
        _MapBtn(icon: Icons.my_location, onTap: () {
          if (markers.isNotEmpty) _mapCtrl.move(center, 11);
        }),
      ])),
      // Bottom info
      if (_selected != null) Positioned(
        bottom: 0, left: 0, right: 0,
        child: _MapBottomSheet(
          device: _selected!,
          pos: state.posFor(_selected!.id),
          status: state.statusFor(_selected!),
          onClose: () => setState(() => _selected = null),
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
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Icon(icon, size: 20, color: AppColors.text2),
    ),
  );
}

class _MapBottomSheet extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onClose;
  const _MapBottomSheet({required this.device, required this.pos, required this.status, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final col = AppColors.forStatus(status);
    final spd = pos != null ? pos!.speedKmh.round() : 0;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(device.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
            const Spacer(),
            GestureDetector(onTap: onClose, child: const Icon(Icons.close, color: AppColors.text3, size: 20)),
          ]),
          const SizedBox(height: 10),
          _row(Icons.link, statusLabel(status), col),
          const SizedBox(height: 5),
          _row(Icons.access_time, pos?.serverTime != null ? fmtDateTime(pos!.serverTime) : '—', AppColors.text2),
          const SizedBox(height: 5),
          _row(Icons.location_on_outlined, pos?.address ?? (pos != null ? '${pos!.latitude.toStringAsFixed(4)}, ${pos!.longitude.toStringAsFixed(4)}' : '—'), AppColors.text3),
        ])),
        const SizedBox(width: 12),
        Speedometer(speedKmh: spd.toDouble(), size: 90),
      ]),
    );
  }

  Widget _row(IconData ico, String val, Color col) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(ico, size: 16, color: AppColors.text4),
    const SizedBox(width: 8),
    Expanded(child: Text(val, style: TextStyle(fontSize: 12, color: col, fontWeight: FontWeight.w500))),
  ]);
}


// ══════════════════════════════════════════════════════════════════════════════
// lib/screens/alerts_screen.dart
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int? _deviceFilter;
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devMap = {for (final d in state.devices) d.id: d};

    final filtered = state.events.where((e) {
      if (_deviceFilter != null && e.deviceId != _deviceFilter) return false;
      if (_typeFilter != null && e.type != _typeFilter) return false;
      return true;
    }).toList();

    final types = ['all', ...{...state.events.map((e) => e.type)}];

    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: _DropBtn(
            label: _deviceFilter == null ? 'Select Vehicle' : devMap[_deviceFilter]?.name ?? 'Unknown',
            onTap: () => _showDevicePicker(context, state.devices),
          )),
          const SizedBox(width: 10),
          Expanded(child: _DropBtn(
            label: _typeFilter == null ? 'All' : eventMeta(_typeFilter!)['label'] as String,
            badge: '(${filtered.length})',
            badgeColor: AppColors.green,
            onTap: () => _showTypePicker(context, types),
          )),
          const SizedBox(width: 10),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: filtered.isEmpty
          ? const EmptyState(icon: Icons.notifications_none_rounded, message: 'No data received')
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) => EventCard(
                event: filtered[i],
                deviceName: devMap[filtered[i].deviceId]?.name ?? 'Device #${filtered[i].deviceId}',
              ),
            ),
      ),
    ]);
  }

  void _showDevicePicker(BuildContext ctx, List<TraccarDevice> devices) {
    showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent, builder: (_) =>
      _PickerSheet(title: 'Select Vehicle', items: [
        const {'id': null, 'label': 'All Vehicles'},
        ...devices.map((d) => {'id': d.id, 'label': d.name}),
      ], selected: _deviceFilter, onSelect: (v) => setState(() => _deviceFilter = v as int?)));
  }

  void _showTypePicker(BuildContext ctx, List<String> types) {
    showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent, builder: (_) =>
      _PickerSheet(title: 'Filter by Type', items: [
        ...types.map((t) => {'id': t == 'all' ? null : t, 'label': t == 'all' ? 'All Events' : eventMeta(t)['label'] as String}),
      ], selected: _typeFilter, onSelect: (v) => setState(() => _typeFilter = v as String?)));
  }
}

class _DropBtn extends StatelessWidget {
  final String label;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _DropBtn({required this.label, this.badge, this.badgeColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1), overflow: TextOverflow.ellipsis)),
          if (badge != null) ...[const SizedBox(width: 4),
            Text(badge!, style: TextStyle(fontSize: 11, color: badgeColor ?? AppColors.text3))],
        ])),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text3),
      ]),
    ),
  );
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final dynamic selected;
  final Function(dynamic) onSelect;
  const _PickerSheet({required this.title, required this.items, this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(2))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1))),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: items.map((item) => GestureDetector(
          onTap: () { onSelect(item['id']); Navigator.pop(context); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected == item['id'] ? AppColors.blue.withOpacity(0.08) : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: selected == item['id'] ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
            ),
            child: Text(item['label'] as String,
              style: TextStyle(fontSize: 14, fontWeight: selected == item['id'] ? FontWeight.w700 : FontWeight.w500,
                color: selected == item['id'] ? AppColors.primary : AppColors.text1)),
          ),
        )).toList()),
      ),
      SizedBox(height: MediaQuery.of(context).padding.bottom),
    ]),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// lib/screens/settings_screen.dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sess  = state.session;
    return ListView(children: [
      // Profile card
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2.5)),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello! ${sess?.name ?? "Partner"}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 3),
            Text(sess?.email ?? '—', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
            const SizedBox(height: 8),
            Row(children: [
              _Badge(sess?.administrator == true ? 'Administrator' : 'User'),
              const SizedBox(width: 6),
              const _Badge('Axion Track'),
            ]),
          ])),
        ]),
      ),
      const SecHeader('Account Settings'),
      _SettingsGroup(items: [
        _SettingsRow(icon: Icons.lock_outline, iconBg: const Color(0xFFFEF2F2), label: 'Password Change', onTap: () {}),
        _SettingsRow(icon: Icons.notifications_outlined, iconBg: const Color(0xFFFFFBEB), label: 'Notification Settings', onTap: () {}),
      ]),
      const SecHeader('Company Info'),
      _SettingsGroup(items: [
        _SettingsRow(icon: Icons.chat_rounded, iconBg: const Color(0xFFECFDF5), label: 'WhatsApp', onTap: () {}),
        _SettingsRow(icon: Icons.camera_alt_outlined, iconBg: const Color(0xFFFFFBEB), label: 'Instagram', onTap: () {}),
        _SettingsRow(icon: Icons.group_outlined, iconBg: const Color(0xFFEFF6FF), label: 'Facebook', onTap: () {}),
        _SettingsRow(icon: Icons.language_rounded, iconBg: const Color(0xFFF5F3FF), label: 'Website', onTap: () {}),
      ]),
      const SecHeader('Connection'),
      _SettingsGroup(items: [
        _SettingsRow(icon: Icons.dns_rounded, iconBg: const Color(0xFFEFF6FF), label: 'Server',
          trailing: Text(sess != null ? (state.svc?.serverUrl ?? '—') : '—',
            style: const TextStyle(fontSize: 12, color: AppColors.text3), overflow: TextOverflow.ellipsis)),
        _SettingsRow(icon: Icons.wifi_rounded,
          iconBg: state.wsConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          label: 'WebSocket',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: state.wsConnected ? AppColors.green : AppColors.red, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(state.wsConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: state.wsConnected ? AppColors.green : AppColors.red)),
          ])),
        _SettingsRow(icon: Icons.person_outline, iconBg: const Color(0xFFF5F3FF), label: 'User ID',
          trailing: Text('#${sess?.id ?? "—"}', style: const TextStyle(fontSize: 12, color: AppColors.text3))),
        _SettingsRow(icon: Icons.speed_rounded, iconBg: const Color(0xFFFFFBEB), label: 'Speed Unit',
          trailing: Text(sess?.speedUnit ?? 'kmh', style: const TextStyle(fontSize: 12, color: AppColors.text3))),
      ]),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        child: ElevatedButton.icon(
          onPressed: () async {
            await context.read<AppState>().logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEF2F2),
            foregroundColor: AppColors.red,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> items;
  const _SettingsGroup({required this.items});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      for (int i = 0; i < items.length; i++) ...[
        items[i],
        if (i < items.length - 1) const Divider(height: 1, indent: 60, color: Color(0xFFF1F5F9)),
      ],
    ]),
  );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.iconBg, required this.label, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: AppColors.text2)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1))),
        if (trailing != null) Flexible(child: trailing!) else const Icon(Icons.chevron_right_rounded, color: AppColors.text4, size: 20),
      ]),
    ),
  );
}
