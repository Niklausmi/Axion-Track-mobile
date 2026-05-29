// lib/screens/vehicles_screen.dart — v3
// Matches reference: search bar, vehicle cards with plate/model/status/sensors
// Tapping opens VehicleDetailScreen with tabs: Dashboard|Trips|Alerts|Reports|Sensor|Commands
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  String _query = '';
  DeviceStatus? _filter;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<AppState>();
    final filtered = state.devices.where((d) {
      if (_filter != null && state.statusFor(d) != _filter) return false;
      if (_query.isNotEmpty && !d.name.toLowerCase().contains(_query.toLowerCase()) &&
          !d.uniqueId.contains(_query)) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft,
              child: Text('Vehicles', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text1))),
            const SizedBox(height: 12),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by plate number...',
                  hintStyle: const TextStyle(color: AppColors.text4),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.text4, size: 20),
                  suffixIcon: _query.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.text4),
                    onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                  ) : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Filter pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _pill('All', null, state),
                _pill('Moving',   DeviceStatus.running, state),
                _pill('Stopped',  DeviceStatus.stopped, state),
                _pill('Idle',     DeviceStatus.idle,    state),
                _pill('Inactive', DeviceStatus.offline, state),
              ]),
            ),
            const SizedBox(height: 10),
          ]),
        ),

        // List
        Expanded(child: state.isLoading && state.devices.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : filtered.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.directions_car_outlined, size: 56, color: AppColors.text4),
                SizedBox(height: 12),
                Text('No vehicles found', style: TextStyle(fontSize: 15, color: AppColors.text3)),
              ]))
            : RefreshIndicator(
                onRefresh: state.refresh,
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final d = filtered[i];
                    final p = state.posFor(d.id);
                    final s = state.statusFor(d);
                    return _VehicleCard(
                      device: d, pos: p, status: s,
                      onTap: () => Navigator.push(ctx, MaterialPageRoute(
                        builder: (_) => VehicleDetailScreen(device: d))),
                    );
                  },
                ),
              ),
        ),
      ])),
    );
  }

  Widget _pill(String label, DeviceStatus? status, AppState state) {
    final selected = _filter == status;
    final col = status != null ? AppColors.forStatus(status) : AppColors.primary;
    final count = status == null ? state.devices.length
        : state.statusCounts[status] ?? 0;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? col.withOpacity(0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: col, width: 1.5) : Border.all(color: AppColors.divider),
        ),
        child: Text('$label ($count)', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? col : AppColors.text3)),
      ),
    );
  }
}

// ── Vehicle card — matches reference image 4 ─────────────────────────────
class _VehicleCard extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onTap;
  const _VehicleCard({required this.device, required this.pos, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col  = AppColors.forStatus(status);
    final bg   = AppColors.bgForStatus(status);
    final spd  = pos?.speedKmh.round() ?? 0;
    final ignOn = pos?.ignition == true;
    final blocked = pos?.blocked == true;
    final hasLoc = pos != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              // Car icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(Icons.directions_car_rounded, color: col, size: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(device.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                Text(device.model ?? device.uniqueId,
                  style: const TextStyle(fontSize: 12, color: AppColors.text3)),
              ])),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _PulseDot(color: col, pulse: status == DeviceStatus.running),
                  const SizedBox(width: 5),
                  Text(statusLabel(status).toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.5)),
                ]),
              ),
            ]),
          ),

          // Location strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasLoc && pos!.address != null ? AppColors.primary.withOpacity(0.06) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.location_on_rounded, size: 16,
                  color: hasLoc ? AppColors.primary : AppColors.text4),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  hasLoc
                    ? (pos!.address ?? '${pos!.latitude.toStringAsFixed(5)}, ${pos!.longitude.toStringAsFixed(5)}')
                    : 'Location unavailable\nLast active: Never',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: hasLoc ? AppColors.primary : AppColors.text3),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (hasLoc) const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
              ]),
            ),
          ),

          // Sensor row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              _SensorPill(Icons.speed_rounded,            '$spd km/h'),
              const SizedBox(width: 12),
              _SensorPill(Icons.vpn_key_rounded,          ignOn ? 'ON' : 'OFF',    color: ignOn ? AppColors.green : null),
              const SizedBox(width: 12),
              _SensorPill(blocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                blocked ? 'LOCKED' : 'OPEN',
                color: blocked ? AppColors.red : null),
              const Spacer(),
              if (pos?.serverTime != null)
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: AppColors.text4),
                  const SizedBox(width: 4),
                  Text(fmtTimeOnly(pos!.serverTime),
                    style: const TextStyle(fontSize: 11, color: AppColors.text4)),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SensorPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _SensorPill(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: color ?? AppColors.text4),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AppColors.text3)),
  ]);
}

class _PulseDot extends StatefulWidget {
  final Color color; final bool pulse;
  const _PulseDot({required this.color, required this.pulse});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) return Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    return ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: widget.color.withOpacity(0.6), blurRadius: 4, spreadRadius: 1)])));
  }
}
