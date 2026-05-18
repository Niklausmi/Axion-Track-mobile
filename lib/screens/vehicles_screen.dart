// lib/screens/vehicles_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _ctrl = TextEditingController();
  String _q = '';
  DeviceStatus? _filter;
  String _sort = 'name'; // name | status | updated

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final list = state.devices.where((d) {
      final s = state.statusFor(d);
      if (_filter != null && s != _filter) return false;
      if (_q.isNotEmpty && !d.name.toLowerCase().contains(_q.toLowerCase()) &&
          !d.uniqueId.contains(_q)) {
        return false;
      }
      return true;
    }).toList();

    // Sort
    list.sort((a, b) {
      if (_sort == 'status') return state.statusFor(a).index.compareTo(state.statusFor(b).index);
      if (_sort == 'updated') {
        final pa = state.posFor(a.id)?.serverTime, pb = state.posFor(b.id)?.serverTime;
        if (pa == null && pb == null) return 0;
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pb.compareTo(pa);
      }
      return a.name.compareTo(b.name);
    });

    return Column(children: [
      // Search + sort
      Container(
        color: AC.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            onChanged: (v) => setState(() => _q = v),
            style: const TextStyle(color: AC.text1, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by plate number…',
              prefixIcon: const Icon(Icons.search, color: AC.text3, size: 20),
              suffixIcon: _q.isNotEmpty ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: AC.text3),
                onPressed: () { _ctrl.clear(); setState(() => _q = ''); }) : null,
            ),
          )),
          const SizedBox(width: 8),
          _SortBtn(current: _sort, onChange: (v) => setState(() => _sort = v)),
        ]),
      ),

      // Filter chips
      Container(
        color: AC.surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FChip(label: 'All', selected: _filter == null, color: AC.text2, onTap: () => setState(() => _filter = null)),
            const SizedBox(width: 6),
            ...DeviceStatus.values.map((s) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FChip(
                label: statusLabel(s),
                count: state.statusCounts[s] ?? 0,
                selected: _filter == s,
                color: AC.forStatus(s),
                onTap: () => setState(() => _filter = _filter == s ? null : s)))),
          ]),
        ),
      ),

      // List
      Expanded(child: state.isLoading
        ? ListView.builder(padding: const EdgeInsets.all(16),
            itemCount: 4, itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 10), child: ShimmerCard(height: 160)))
        : list.isEmpty
          ? const EmptyState(icon: Icons.directions_car_outlined, message: 'No vehicles found')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final d = list[i];
                final p = state.posFor(d.id);
                final s = state.statusFor(d);
                return _VehicleCard(device: d, pos: p, status: s,
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => VehicleDetailScreen(device: d))));
              })),
    ]);
  }
}

class _VehicleCard extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onTap;
  const _VehicleCard({required this.device, required this.pos, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = AC.forStatus(status);
    final spd = pos?.speedKmh.round() ?? 0;
    final stLabel = status == DeviceStatus.stopped && pos?.serverTime != null
      ? 'Stopped (${stoppedFor(pos!.serverTime)})' : statusLabel(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0,2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              // Coloured car icon
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.directions_car_rounded, color: col, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
                Text(device.model ?? device.uniqueId,
                  style: const TextStyle(fontSize: 12, color: AC.text3)),
              ])),
              StatusBadge(status),
            ]),
          ),

          // Coords + open maps
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AC.blue),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  pos?.address ?? (pos != null
                    ? '${pos!.latitude.toStringAsFixed(5)}, ${pos!.longitude.toStringAsFixed(5)}'
                    : device.lastUpdate != null ? 'Last active ${timeAgo(device.lastUpdate)}' : 'No position'),
                  style: const TextStyle(fontSize: 12, color: AC.blue, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
                const Icon(Icons.open_in_new_rounded, size: 14, color: AC.blue),
              ]),
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(children: [
              _Stat(Icons.speed_rounded, '$spd km/h'),
              const SizedBox(width: 16),
              _Stat(Icons.vpn_key_rounded, pos?.ignition == true ? 'ON' : 'OFF',
                col: pos?.ignition == true ? AC.green : AC.text3),
              const SizedBox(width: 16),
              _Stat(Icons.access_time_rounded,
                pos?.serverTime != null ? _shortTime(pos!.serverTime!) : device.lastUpdate != null ? _shortTime(device.lastUpdate!) : '—'),
            ]),
          ),
        ]),
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour, ap = h >= 12 ? 'PM' : 'AM', h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')} $ap';
  }

  Widget _Stat(IconData ico, String val, {Color? col}) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(ico, size: 14, color: col ?? AC.text3),
    const SizedBox(width: 4),
    Text(val, style: TextStyle(fontSize: 13, color: col ?? AC.text2, fontWeight: FontWeight.w600)),
  ]);
}

class _FChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FChip({required this.label, this.count, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.2) : AC.surface2,
        borderRadius: BorderRadius.circular(20),
        border: selected ? Border.all(color: color, width: 1.5) : null),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (count != null) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? color : AC.text3)),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text('($count)', style: TextStyle(fontSize: 11, color: selected ? color : AC.text4)),
        ],
      ]),
    ),
  );
}

class _SortBtn extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const _SortBtn({required this.current, required this.onChange});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AC.surface3, borderRadius: BorderRadius.circular(2))),
        const Padding(padding: EdgeInsets.all(16),
          child: Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1))),
        ...[('name','Name'),('status','Status'),('updated','Last Updated')].map((e) =>
          ListTile(
            title: Text(e.$2, style: TextStyle(color: current == e.$1 ? AC.blue : AC.text1, fontWeight: FontWeight.w600)),
            trailing: current == e.$1 ? const Icon(Icons.check_rounded, color: AC.blue) : null,
            onTap: () { onChange(e.$1); Navigator.pop(context); })),
        const SizedBox(height: 16),
      ]),
    ),
    child: Container(
      width: 40, height: 48,
      decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.sort_rounded, color: AC.text2, size: 20)));
}
