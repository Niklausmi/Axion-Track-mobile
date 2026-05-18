// lib/screens/status_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import 'live_tracking_screen.dart';
import 'history_screen.dart';
import 'sensors_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  DeviceStatus? _filter;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _showMenu(BuildContext ctx, TraccarDevice device) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(
        device: device,
        onTrack:    () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(builder: (_) => LiveTrackingScreen(device: device))); },
        onHistory:  () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(builder: (_) => HistoryScreen(device: device))); },
        onSensors:  () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(builder: (_) => SensorsScreen(device: device))); },
        onReports:  () => Navigator.pop(ctx),
        onImmob:    () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final counts = state.statusCounts;
    final total  = state.devices.length;

    final filtered = state.devices.where((d) {
          final s = state.statusFor(d);
      if (_filter != null && s != _filter) return false;
      if (_query.isNotEmpty &&
          !d.name.toLowerCase().contains(_query.toLowerCase()) &&
          !d.uniqueId.contains(_query)) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
          onRefresh: state.refresh,
          color: AC.blue,
      child: CustomScrollView(slivers: [
        // ── Filter pills ──
        SliverToBoxAdapter(child: Container(
          color: AC.surface,
          child: Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(children: [
                _Pill(key: null, label: 'All', count: total, color: const Color(0xFF334155),
                  bg: const Color(0xFFF1F5F9), selected: _filter == null,
                  onTap: () => setState(() => _filter = null)),
                _statusPill(DeviceStatus.moving, counts, 'Moving'),
                _statusPill(DeviceStatus.stopped, counts, 'Stopped'),
                _statusPill(DeviceStatus.idle,    counts, 'Idle'),
                _statusPill(DeviceStatus.offline, counts, 'Offline'),
                _statusPill(DeviceStatus.nodata,  counts, 'No Data'),
                _statusPill(DeviceStatus.inactive, counts, 'Inactive'),
              ]),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by vehicle…',
                      prefixIcon: const Icon(Icons.search, color: AC.text4, size: 20),
                  suffixIcon: _query.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AC.text4),
                    onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                  ) : null,
                ),
              ),
            ),
          ]),
        )),

        // ── Group label ──
        const SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Group : ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.text3)),
                Text('All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.blue)),
          ]),
        )),

        // ── Loading ──
        if (state.isLoading) SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => const ShimmerCard(), childCount: 3)),

        // ── Empty ──
        if (!state.isLoading && filtered.isEmpty) const SliverFillRemaining(
          child: EmptyState(icon: Icons.directions_car_outlined, message: 'No vehicles found')),

        // ── Cards ──
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final d = filtered[i];
              final p = state.posFor(d.id);
              final s = state.statusFor(d);
              return VehicleCard(
                device: d, pos: p, status: s,
                onTap: () => _showMenu(ctx, d),
              );
            },
            childCount: filtered.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ]),
    );
  }

  Widget _statusPill(DeviceStatus s, Map<DeviceStatus, int> counts, String label) =>
    _Pill(
      label: label,
      count: counts[s] ?? 0,
      color: AC.forStatus(s),
          bg: AC.bgForStatus(s),
      selected: _filter == s,
      onTap: () => setState(() => _filter = _filter == s ? null : s),
    );
}

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({super.key, required this.label, required this.count,
    required this.color, required this.bg, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? bg : AC.surface2,
        borderRadius: BorderRadius.circular(20),
        border: selected ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? color : AC.text3)),
        const SizedBox(width: 5),
        Text('($count)', style: TextStyle(fontSize: 11, color: selected ? color : AC.text4)),
      ]),
    ),
  );
}

class VehicleCard extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onTap;

  const VehicleCard({
    super.key,
    required this.device,
    required this.pos,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AC.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AC.surface2),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AC.bgForStatus(status),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.directions_car_rounded, color: AC.forStatus(status), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.text2)),
                  const SizedBox(height: 4),
                  Text(device.uniqueId, style: const TextStyle(fontSize: 12, color: AC.text4)),
                  if (pos != null) ...[
                    const SizedBox(height: 8),
                    const Text('Location available', style: TextStyle(fontSize: 11, color: AC.text3)),
                  ],
                ],
              )),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AC.bgForStatus(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.forStatus(status)),
                ),
              ),
            ]),
          ),
        ),
      );

  static String _statusLabel(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.moving:
        return 'Moving';
      case DeviceStatus.stopped:
        return 'Stopped';
      case DeviceStatus.idle:
        return 'Idle';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.nodata:
        return 'No Data';
      case DeviceStatus.inactive:
        return 'Inactive';
    }
  }
}

class _ActionSheet extends StatelessWidget {
  final TraccarDevice device;
  final VoidCallback onTrack, onHistory, onSensors, onReports, onImmob;

  const _ActionSheet({required this.device, required this.onTrack, required this.onHistory,
    required this.onSensors, required this.onReports, required this.onImmob});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final status = state.statusFor(device);
        final col = AC.forStatus(status);
    return Container(
      decoration: const BoxDecoration(
            color: AC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: AC.bg, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(
              color: AC.bgForStatus(status), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.directions_car_rounded, color: col, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(device.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
                  Text(device.uniqueId, style: const TextStyle(fontSize: 11, color: AC.text4)),
            ])),
          ]),
        ),
            const Divider(height: 1, color: Color(0xFF0A0E1A)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _Action(ico: Icons.map_outlined,       bg: const Color(0xFFEFF6FF), label: 'Track',       onTap: onTrack),
            _Action(ico: Icons.history,             bg: const Color(0xFFECFDF5), label: 'History',    onTap: onHistory),
            _Action(ico: Icons.bar_chart_rounded,   bg: const Color(0xFFFFF7ED), label: 'Reports',    onTap: onReports),
            _Action(ico: Icons.shield_outlined,     bg: const Color(0xFFFEF2F2), label: 'Immobilizer',onTap: onImmob),
            _Action(ico: Icons.sensors,             bg: const Color(0xFFF5F3FF), label: 'Sensors',    onTap: onSensors),
          ]),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData ico;
  final Color bg;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.ico, required this.bg, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Icon(ico, color: AC.text2, size: 24)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.text2),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}
