import 'dart:math' as math;
// lib/screens/vehicle_detail_screen.dart — v7 (Final Direct-Date Sync Fixed with Arc Bounds Fix)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import 'history_screen.dart';
import 'live_tracking_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final TraccarDevice device;
  const VehicleDetailScreen({super.key, required this.device});
  @override State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  int _tab = 0;
  Timer? _pollTimer;

  static const _tabs = ['Dashboard', 'Trips', 'Alerts', 'Reports', 'Sensor', 'Commands'];

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) context.read<AppState>().refresh();
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final st    = state.statusFor(widget.device);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: AppColors.surface,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.text1)),
                const SizedBox(width: 12),
                Text(widget.device.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text1)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgForStatus(st),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(color: AppColors.forStatus(st), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(statusLabel(st).toUpperCase(),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                        color: AppColors.forStatus(st), letterSpacing: 0.5)),
                    const SizedBox(width: 6),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Scrollable tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: List.generate(_tabs.length, (i) {
                final sel = _tab == i;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(_tabs[i], style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.text3)),
                  ),
                );
              })),
            ),
          ]),
        ),

        // Body
        Expanded(child: IndexedStack(index: _tab, children: [
          _VehicleDashTab(device: widget.device),
          _TripsTab(device: widget.device),
          _VehicleAlertsTab(device: widget.device),
          _ReportsTab(device: widget.device),
          _SensorTab(device: widget.device),
          _CommandsTab(device: widget.device),
        ])),
      ])),
    );
  }
}

// ══════════════════ TAB 0: DASHBOARD ══════════════════════════════════════
class _VehicleDashTab extends StatefulWidget {
  final TraccarDevice device;
  const _VehicleDashTab({required this.device});
  @override State<_VehicleDashTab> createState() => _VehicleDashTabState();
}

class _VehicleDashTabState extends State<_VehicleDashTab> {
  List<TraccarTrip> _todayTrips = [];
  bool _tripsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayTrips();
  }

  Future<void> _loadTodayTrips() async {
    final svc = context.read<AppState>().service;
    if (svc == null) { setState(() => _tripsLoading = false); return; }
    // Build today's range in UTC so it matches Traccar's server-side day boundary.
    // Using local midnight then .toUtc() would shift to 19:00 UTC in PKT (UTC+5),
    // pulling in the last 5 hours of yesterday.
    final nowUtc = DateTime.now().toUtc();
    final from   = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 0, 0, 0);
    final to     = nowUtc;
    try {
      final trips = await svc.getTrips(deviceId: widget.device.id, from: from, to: to);
      if (mounted) setState(() { _todayTrips = trips; _tripsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _tripsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state   = context.watch<AppState>();
    final pos     = state.posFor(widget.device.id);
    final st      = state.statusFor(widget.device);
    final spd     = pos?.speedKmh ?? 0.0;

    final todayDist   = _todayTrips.fold(0.0, (s, t) => s + t.distance) / 1000;
    final todayDur    = _todayTrips.fold(0,   (s, t) => s + t.duration);
    final todayMaxSpd = _todayTrips.fold(0.0, (m, t) => t.maxSpeedKmh > m ? t.maxSpeedKmh : m);
    final todayAvgSpd = _todayTrips.isEmpty ? 0.0
        : _todayTrips.fold(0.0, (s, t) => s + t.averageSpeedKmh) / _todayTrips.length;

    final now = DateTime.now();
    final todayAlerts = state.events.where((e) {
      if (e.deviceId != widget.device.id) return false;
      final t = (e.serverTime ?? e.eventTime)?.toLocal();
      if (t == null) return false;
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }).toList();
    final todayOverspeed = todayAlerts.where((e) => e.type == 'deviceOverspeed').length;
    final todayIdle      = todayAlerts.where((e) => e.type == 'deviceStopped' || e.type == 'deviceMoving').length;
    final todayGeozone   = todayAlerts.where((e) => e.type.startsWith('geofence')).length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppColors.bgForStatus(st), shape: BoxShape.circle),
            child: Icon(Icons.analytics_rounded, color: AppColors.forStatus(st), size: 20)),
          const SizedBox(width: 12),
          const Text('Live Telemetry',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Text(statusLabel(st), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.forStatus(st)))),
        ]),
      ),
      const SizedBox(height: 10),

      Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SpeedArc(speed: spd),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LiveTrackingScreen(device: widget.device))),
            icon: const Icon(Icons.navigation_rounded, size: 16),
            label: const Text('Live Track Vehicle'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )),
        ]),
      ),
      const SizedBox(height: 14),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text("Today's Stats",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
          ),
          _tripsLoading
            ? const SizedBox(height: 36,
                child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
            : Row(children: [
                Expanded(child: _TodayStat('Distance',  '${todayDist.toStringAsFixed(1)} km', Icons.route_rounded)),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.25)),
                Expanded(child: _TodayStat('Max Spd',   '${todayMaxSpd.round()} km/h',        Icons.speed_rounded)),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.25)),
                Expanded(child: _TodayStat('Avg Spd',   '${todayAvgSpd.round()} km/h',        Icons.av_timer_rounded)),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.25)),
                Expanded(child: _TodayStat('Drive Time', fmtDuration(todayDur),                Icons.timer_outlined)),
              ]),
        ]),
      ),
      const SizedBox(height: 14),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(children: [
          _DetailRow('Status', statusLabel(st), valueColor: AppColors.forStatus(st), bold: true),
          const Divider(height: 16, color: AppColors.divider),
          _DetailRow('Vehicle', widget.device.model ?? widget.device.name),
          if (pos != null) ...[
            const Divider(height: 16, color: AppColors.divider),
            GestureDetector(
              onTap: () {
                debugPrint('Open Google Maps: ${pos.latitude}, ${pos.longitude}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Last Known Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    Text('${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ])),
                  const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                ]),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("Today's Alerts",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: todayAlerts.isEmpty ? AppColors.green.withOpacity(0.1) : AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${todayAlerts.length} total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: todayAlerts.isEmpty ? AppColors.green : AppColors.red)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _AlertPill('Overspeed', todayOverspeed, AppColors.red,    const Color(0xFFFEE2E2)),
            const SizedBox(width: 8),
            _AlertPill('Idle/Stop', todayIdle,      AppColors.orange, const Color(0xFFFEF3C7)),
            const SizedBox(width: 8),
            _AlertPill('Geozone',   todayGeozone,   AppColors.purple, const Color(0xFFF5F3FF)),
          ]),
          if (todayAlerts.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Recent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text3)),
            const SizedBox(height: 8),
            ...todayAlerts.take(3).map((e) {
              final meta    = eventMeta(e.type);
              final col     = Color(meta['color'] as int);
              final bg      = Color(meta['bg']    as int);
              final t        = (e.serverTime ?? e.eventTime)?.toLocal();
              final timeStr = t != null ? fmtDateTime(t) : '—';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(meta['icon'] as IconData, color: col, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(meta['label'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text1)),
                    Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                  ])),
                ]),
              );
            }),
          ],
          if (todayAlerts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No alerts today', style: TextStyle(fontSize: 13, color: AppColors.text3))),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

class _TodayStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _TodayStat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 15, color: Colors.white70),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
    Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.65))),
  ]);
}

class _AlertPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color, bg;
  const _AlertPill(this.label, this.count, this.color, this.bg);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    ]),
  ));
}

// ══════════════════ TAB 1: TRIPS ══════════════════════════════════════════
class _TripsTab extends StatefulWidget {
  final TraccarDevice device;
  const _TripsTab({required this.device});
  @override State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  static DateTime _today()     => DateTime.now();
  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _from = _midnight(DateTime.now());
  DateTime _to   = _midnight(DateTime.now());
  List<TraccarTrip> _trips = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _trips = []; _error = null; });
    final svc = context.read<AppState>().service;
    if (svc == null) {
      if (mounted) setState(() { _loading = false; _error = 'Not connected to server'; });
      return;
    }
    try {
      final fromMidnight = _midnight(_from);
      final toEndOfDay   = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
      final t = await svc.getTrips(
        deviceId: widget.device.id,
        from: fromMidnight,
        to: toEndOfDay,
      );
      if (mounted) setState(() => _trips = t);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _today(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _from = _midnight(picked); 
        else        _to   = _midnight(picked); 
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDist = _trips.fold(0.0, (s, t) => s + t.distance);
    final totalDur  = _trips.fold(0,   (s, t) => s + t.duration);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('QUICK SELECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              _QuickBtn('Today', () {
                final today = _midnight(_today());
                setState(() { _from = today; _to = today; });
                _load();
              }),
              _QuickBtn('Yesterday', () {
                final y = _midnight(_today().subtract(const Duration(days: 1)));
                setState(() { _from = y; _to = y; });
                _load();
              }),
              _QuickBtn('This Week', () {
                final now = _today();
                setState(() {
                  _from = _midnight(now.subtract(Duration(days: now.weekday - 1)));
                  _to   = _midnight(now);
                });
                _load();
              }),
              _QuickBtn('Last Week', () {
                final now   = _today();
                final start = _midnight(now.subtract(Duration(days: now.weekday + 6)));
                setState(() {
                  _from = start;
                  _to   = _midnight(start.add(const Duration(days: 6)));
                });
                _load();
              }),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('START DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _pickDate(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(fmtDateShort(_from), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                  ]),
                ),
              ),
            ])),
            const Padding(padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
              child: Icon(Icons.arrow_forward_rounded, color: AppColors.text4, size: 18)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('END DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _pickDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(fmtDateShort(_to), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                  ]),
                ),
              ),
            ])),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // Complete Playback Action Button
      SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => HistoryScreen(
                device: widget.device, 
                jumpToTrip: null,
                initialDate: _from,
              )));
          },
          icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
          label: const Text(
            'Complete History Playback',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withOpacity(0.4), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: AppColors.primary.withOpacity(0.02),
          ),
        ),
      ),
      const SizedBox(height: 16),

      const Text('Trips History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      const SizedBox(height: 10),

      // Summary
      if (_trips.isNotEmpty) Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Expanded(child: _TripStat('Total Trips',    '${_trips.length}',   AppColors.primary)),
          Container(width: 1, height: 36, color: AppColors.primary.withOpacity(0.2)),
          Expanded(child: _TripStat('Total Distance', fmtKm(totalDist),     AppColors.primary)),
          Container(width: 1, height: 36, color: AppColors.primary.withOpacity(0.2)),
          Expanded(child: _TripStat('Total Time',     fmtDuration(totalDur), AppColors.primary)),
        ]),
      ),
      const SizedBox(height: 10),

      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),

      if (!_loading && _error != null) Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.red.withOpacity(0.25)),
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!,
              style: const TextStyle(fontSize: 13, color: AppColors.red))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
      ),

      ..._trips.map((t) => _TripCard(trip: t, onReplay: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
          HistoryScreen(device: widget.device, jumpToTrip: t)));
      })),

      if (!_loading && _error == null && _trips.isEmpty) const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No trips in this period', style: TextStyle(color: AppColors.text3)))),
    ]);
  }
}

class _TripCard extends StatelessWidget {
  final TraccarTrip trip;
  final VoidCallback onReplay;
  const _TripCard({required this.trip, required this.onReplay});
  @override
  Widget build(BuildContext context) {
    final startLocal = trip.startTime?.toLocal();
    final endLocal   = trip.endTime?.toLocal();
    final dateStr = startLocal != null
      ? '${startLocal.month}/${startLocal.day}/${startLocal.year} ${fmtTimeOnly(trip.startTime)}'
      : '—';
    final endStr = endLocal != null
      ? fmtTimeOnly(trip.endTime)
      : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.route_rounded, color: AppColors.primary, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dateStr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
            Text('End: $endStr',
              style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _TripInfo('Distance', '${trip.distanceKm.toStringAsFixed(1)} km'),
          const SizedBox(width: 16),
          _TripInfo('Duration', trip.durationStr),
          const SizedBox(width: 16),
          _TripInfo('Max Spd',  '${trip.maxSpeedKmh.round()} km/h'),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: onReplay,
          icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
          label: const Text('Replay on Map'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )),
      ]),
    );
  }
}

class _TripInfo extends StatelessWidget {
  final String label, value;
  const _TripInfo(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text4)),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
  ]);
}

class _TripStat extends StatelessWidget {
  final String label, value; final Color color;
  const _TripStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
  ]);
}

class _QuickBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _QuickBtn(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text2)),
    ),
  );
}

// ══════════════════ TAB 2: VEHICLE ALERTS ═════════════════════════════════
class _VehicleAlertsTab extends StatelessWidget {
  final TraccarDevice device;
  const _VehicleAlertsTab({required this.device});
  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final events = state.events.where((e) => e.deviceId == device.id).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Align(alignment: Alignment.centerLeft,
          child: const Text('Vehicle Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1))),
      ),
      Expanded(child: events.isEmpty
        ? const Center(child: Text('No alerts', style: TextStyle(color: AppColors.text3)))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            itemBuilder: (_, i) => _VehicleAlertRow(event: events[i]),
          )),
    ]);
  }
}

class _VehicleAlertRow extends StatelessWidget {
  final TraccarEvent event;
  const _VehicleAlertRow({required this.event});
  @override
  Widget build(BuildContext context) {
    final meta  = eventMeta(event.type);
    final col   = Color(meta['color'] as int);
    final bg    = Color(meta['bg']    as int);
    final label = meta['label'] as String;
    final lat   = (event.attributes['latitude']  as num?)?.toDouble();
    final lon   = (event.attributes['longitude'] as num?)?.toDouble();
    final spd   = event.attributes['speed'] != null
      ? '${((event.attributes['speed'] as num) * 1.852).round()} km/h' : null;
    final t        = (event.serverTime ?? event.eventTime)?.toLocal();
    final timeStr  = t != null ? fmtDateTime(t) : '—';
    final hasLoc   = lat != null && lon != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: col, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(meta['icon'] as IconData, color: col, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
              const SizedBox(height: 3),
              Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
              if (spd != null) ...[
                const SizedBox(width: 2),
                Row(children: [
                  const Icon(Icons.speed_rounded, size: 12, color: AppColors.text4),
                  const SizedBox(width: 4),
                  Text(spd, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                ]),
              ],
              if (hasLoc) ...[
                const SizedBox(width: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.text4),
                  const SizedBox(width: 4),
                  Text('${lat!.toStringAsFixed(4)}, ${lon!.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                ]),
              ],
            ])),
          ]),
        ),
        if (hasLoc) ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          child: SizedBox(
            height: 120,
            child: Stack(children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat!, lon!),
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.axiontrack.app'),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(lat, lon),
                      width: 32, height: 32,
                      child: Container(
                        decoration: BoxDecoration(color: bg, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: col.withOpacity(0.4), blurRadius: 6)]),
                        child: Icon(meta['icon'] as IconData, color: col, size: 14)),
                    ),
                  ]),
                ],
              ),
              Positioned(bottom: 6, right: 6, child: GestureDetector(
                onTap: () => debugPrint('Open Maps: $lat, $lon'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.open_in_new_rounded, size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Maps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              )),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════ TAB 3: REPORTS ════════════════════════════════════════
class _ReportsTab extends StatefulWidget {
  final TraccarDevice device;
  const _ReportsTab({required this.device});
  @override State<_ReportsTab> createState() => _ReportsTabState();
}
class _ReportsTabState extends State<_ReportsTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);

  static const _reports = [
    {'icon': Icons.directions_car_rounded, 'label': 'Vehicle Master', 'color': 0xFF7C3AED, 'bg': 0xFFF5F3FF},
    {'icon': Icons.list_alt_rounded,       'label': 'Fleet Summary',  'color': 0xFF7C3AED, 'bg': 0xFFF5F3FF},
    {'icon': Icons.calendar_month_rounded, 'label': 'Daily Summary',  'color': 0xFF1A73E8, 'bg': 0xFFDBEAFE},
    {'icon': Icons.route_rounded,          'label': 'Trip Report',    'color': 0xFF16A34A, 'bg': 0xFFDCFCE7},
    {'icon': Icons.speed_rounded,          'label': 'Speed Report',   'color': 0xFFD97706, 'bg': 0xFFFEF3C7},
    {'icon': Icons.warning_amber_rounded,  'label': 'Alert Report',   'color': 0xFFDC2626, 'bg': 0xFFFEE2E2},
  ];

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('QUICK SELECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            _QuickBtn('Today',     () { final n = DateTime.now(); setState(() { _from = DateTime(n.year, n.month, n.day); _to = DateTime(n.year, n.month, n.day, 23, 59, 59); }); }),
            _QuickBtn('Yesterday', () { final y = DateTime.now().subtract(const Duration(days: 1)); setState(() { _from = DateTime(y.year, y.month, y.day); _to = DateTime(y.year, y.month, y.day, 23, 59, 59); }); }),
            _QuickBtn('This Week', () { final n = DateTime.now(); final s = n.subtract(Duration(days: n.weekday - 1)); setState(() { _from = DateTime(s.year, s.month, s.day); _to = DateTime(n.year, n.month, n.day, 23, 59, 59); }); }),
            _QuickBtn('Last Week', () { final n = DateTime.now(); final s = n.subtract(Duration(days: n.weekday + 6)); final e = s.add(const Duration(days: 6)); setState(() { _from = DateTime(s.year, s.month, s.day); _to = DateTime(e.year, e.month, e.day, 23, 59, 59); }); }),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _DateBtn(label: 'START DATE', date: _from, onTap: () async {
            final p = await showDatePicker(context: context, initialDate: _from, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
            if (p != null) setState(() => _from = p);
          })),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward_rounded, color: AppColors.text4, size: 18)),
          Expanded(child: _DateBtn(label: 'END DATE', date: _to, onTap: () async {
            final p = await showDatePicker(context: context, initialDate: _to, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
            if (p != null) setState(() => _to = p);
          })),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    const Text('Functional Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
    const SizedBox(height: 12),
    GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
      children: _reports.map((r) {
        final col = Color(r['color'] as int);
        final bg  = Color(r['bg']    as int);
        return GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(r['icon'] as IconData, color: col, size: 26)),
              const SizedBox(height: 12),
              Text(r['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('View Report', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }).toList(),
    ),
  ]);
}

class _DateBtn extends StatelessWidget {
  final String label; final DateTime date; final VoidCallback onTap;
  const _DateBtn({required this.label, required this.date, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(fmtDateShort(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
        ]),
      ]),
    ),
  );
}

// ══════════════════ TAB 4: SENSOR ═════════════════════════════════════════
class _SensorTab extends StatelessWidget {
  final TraccarDevice device;
  const _SensorTab({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pos   = state.posFor(device.id);
    final attrs = pos?.attributes ?? {};
    final spd   = pos?.speedKmh ?? 0.0;
    final power = pos?.power;
    final bat   = (attrs['battery'] as num?)?.toDouble();
    final charge= pos?.charging;
    final rssi  = pos?.rssi;
    final sat   = pos?.satellites;
    final ignOn = pos?.ignition == true;
    final blocked = pos?.blocked == true;
    final odo   = pos?.odometer;
    final hrs   = pos?.hours;
    final din1  = attrs['di1'] ?? attrs['in1'] ?? attrs['input1'];

    return ListView(padding: const EdgeInsets.all(16), children: [
      _SensorGroup(
        icon: Icons.battery_charging_full_rounded,
        iconColor: AppColors.green,
        iconBg: const Color(0xFFDCFCE7),
        title: 'Power & Battery Health',
        children: [
          Row(children: [
            Expanded(child: _SensorBox('EXTERNAL BATTERY', power != null ? '${power.toStringAsFixed(1)} V' : '—', 'Alternator Input')),
            const SizedBox(width: 10),
            Expanded(child: _SensorBox('INTERNAL BATTERY', bat != null ? '${bat.toStringAsFixed(1)} V' : '—', 'Backup Cells')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.bolt_rounded, size: 18, color: AppColors.orange),
            const SizedBox(width: 8),
            const Text('Charging Relay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: charge == true ? const Color(0xFFDCFCE7) : AppColors.background,
                borderRadius: BorderRadius.circular(20)),
              child: Text(charge == true ? 'CHARGING' : 'NOT CHARGING',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: charge == true ? AppColors.green : AppColors.text3)),
            ),
          ]),
        ],
      ),
      const SizedBox(height: 14),

      _SensorGroup(
        icon: Icons.wifi_rounded,
        iconColor: AppColors.teal,
        iconBg: const Color(0xFFCCFBF1),
        title: 'Connectivity & Signal',
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Network Signal', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              const SizedBox(height: 4),
              Text(rssi != null ? '$rssi%' : '—',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text1)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('GSM Signal Strength', style: TextStyle(fontSize: 11, color: AppColors.text3)),
              const SizedBox(height: 6),
              Row(children: [
                _SignalBars(rssi ?? 0),
                const SizedBox(width: 6),
                Text(rssi != null ? '${((rssi! / 100) * 5).round()}/5 bars' : '—',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text1)),
              ]),
            ]),
          ]),
          const Divider(height: 18, color: AppColors.divider),
          _SensorRowInline('Device Health',  'ACTIVE', AppColors.green),
          const SizedBox(height: 6),
          _SensorRowInline('Terminal Info',  attrs['terminalInfo']?.toString() ?? '—', AppColors.text1),
        ],
      ),
      const SizedBox(height: 14),

      _SensorGroup(
        icon: Icons.navigation_rounded,
        iconColor: AppColors.orange,
        iconBg: const Color(0xFFFEF3C7),
        title: 'GPS & Compass Telemetry',
        children: [
          Row(children: [
            Expanded(child: _SensorBox('CURRENT SPEED', '${spd.round()} km/h', null, icon: Icons.speed_rounded, iconColor: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _SensorBox('BEARING COURSE',
              pos != null ? '${pos.course.round()}° (${_bearing(pos.course)})' : '—',
              null, icon: Icons.explore_rounded, iconColor: AppColors.orange)),
          ]),
          const SizedBox(height: 10),
          if (pos != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.public_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const Spacer(),
              const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
            ]),
          ),
          const SizedBox(height: 10),
          _SensorRowInline('GPS Satellites',
            sat != null ? '$sat active ($sat raw)' : '—', AppColors.text1,
            icon: Icons.satellite_alt_rounded),
        ],
      ),
      const SizedBox(height: 14),

      _SensorGroup(
        icon: Icons.handyman_rounded,
        iconColor: AppColors.purple,
        iconBg: const Color(0xFFF5F3FF),
        title: 'Relays & Diagnostic Meters',
        children: [
          Row(children: [
            Expanded(child: _RelayBox(
              icon: Icons.vpn_key_rounded,
              label: ignOn ? 'IGNITION ON' : 'IGNITION OFF',
              sub: 'IGNITION STATE',
              color: ignOn ? AppColors.green : AppColors.text3)),
            const SizedBox(width: 10),
            Expanded(child: _RelayBox(
              icon: blocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              label: blocked ? 'ENGINE SECURED' : 'ENGINE ACTIVE',
              sub: 'IMMOBILIZER',
              color: blocked ? AppColors.green : AppColors.text3)),
          ]),
          const SizedBox(height: 12),
          _SensorRowInline('Virtual Odometer', odo != null ? '${(odo/1000).toStringAsFixed(1)} km' : '0.0 km', AppColors.primary),
          const Divider(height: 14, color: AppColors.divider),
          _SensorRowInline('Engine Hours', hrs != null ? '${hrs.toStringAsFixed(1)} hrs' : '0 hrs', AppColors.text1),
          const Divider(height: 14, color: AppColors.divider),
          _SensorRowInline('Digital Input 1 (Relay flag)',
            din1 != null ? 'HIGH (1)' : 'LOW (0)', AppColors.text1),
        ],
      ),
      const SizedBox(height: 24),
    ]);
  }

  String _bearing(double c) {
    const dirs = ['North','NE','East','SE','South','SW','West','NW'];
    return dirs[((c + 22.5) ~/ 45) % 8];
  }
}

class _SensorGroup extends StatelessWidget {
  final IconData icon; final Color iconColor, iconBg;
  final String title; final List<Widget> children;
  const _SensorGroup({required this.icon, required this.iconColor, required this.iconBg, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}

class _SensorBox extends StatelessWidget {
  final String label, value; final String? sub;
  final IconData? icon; final Color? iconColor;
  const _SensorBox(this.label, this.value, this.sub, {this.icon, this.iconColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) Icon(icon!, size: 22, color: iconColor ?? AppColors.primary),
      if (icon != null) const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text1)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text4, letterSpacing: 0.5)),
      if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
    ]),
  );
}

class _SensorRowInline extends StatelessWidget {
  final String label, value; final Color color; final IconData? icon;
  const _SensorRowInline(this.label, this.value, this.color, {this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    if (icon != null) ...[Icon(icon!, size: 16, color: AppColors.text4), const SizedBox(width: 8)],
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text3))),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _OriginalStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SignalBars(100);
  }
}

class _RelayBox extends StatelessWidget {
  final IconData icon; final String label, sub; final Color color;
  const _RelayBox({required this.icon, required this.label, required this.sub, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, size: 24, color: color),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.text4, letterSpacing: 0.4), textAlign: TextAlign.center),
    ]),
  );
}

class _SignalBars extends StatelessWidget {
  final int rssi;
  const _SignalBars(this.rssi);
  @override
  Widget build(BuildContext context) {
    final bars = ((rssi / 100) * 5).round().clamp(0, 5);
    return Row(children: List.generate(5, (i) => Container(
      width: 5, height: 6.0 + i * 3,
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: i < bars ? AppColors.green : AppColors.text4.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2)),
    )));
  }
}

// ══════════════════ TAB 5: COMMANDS ═══════════════════════════════════════
class _CommandsTab extends StatefulWidget {
  final TraccarDevice device;
  const _CommandsTab({required this.device});
  @override State<_CommandsTab> createState() => _CommandsTabState();
}
class _CommandsTabState extends State<_CommandsTab> {
  bool _sending = false;
  String? _result;
  List<Map<String, dynamic>> _history = [];
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    final pos = Provider.of<AppState>(context, listen: false).posFor(widget.device.id);
    _isBlocked = pos?.blocked == true;
  }

  Future<void> _send(String type) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(type == 'engineStop' ? 'Immobilize Engine?' : 'Un-Immobilize Engine?'),
      content: Text(type == 'engineStop'
        ? 'This will send a remote engine stop command. The vehicle will be immobilized.'
        : 'This will remove the engine block and allow the vehicle to start.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: type == 'engineStop' ? AppColors.red : AppColors.green),
          child: const Text('Confirm')),
      ],
    ));
    if (confirm != true) return;

    setState(() { _sending = true; _result = null; });
    final svc = context.read<AppState>().service;
    if (svc != null) {
      final res = await svc.sendCommand(deviceId: widget.device.id, type: type);
      final now = DateTime.now();
      setState(() {
        _result = res['error'] != null ? 'Error: ${res['error']}' : 'Command queued successfully';
        _isBlocked = type == 'engineStop';
        _history.insert(0, {
          'type': type == 'engineStop' ? 'Immobilize' : 'Unimmobilize',
          'time': now,
          'status': res['error'] == null ? 'sent' : 'failed',
          'note': res['error'] == null ? 'Recovery confirmed' : res['error'],
        });
      });
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Remote Immobilization',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1)),
    const SizedBox(height: 14),

    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isBlocked ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _isBlocked ? AppColors.red.withOpacity(0.3) : AppColors.green.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(_isBlocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 28, color: _isBlocked ? AppColors.red : AppColors.green),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isBlocked ? 'Engine immobilized' : 'Engine not immobilized',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: _isBlocked ? AppColors.red : AppColors.green)),
          Text('Status updates when you queue a command and after the device confirms.',
            style: const TextStyle(fontSize: 12, color: AppColors.text3)),
        ])),
      ]),
    ),
    const SizedBox(height: 14),

    if (_result != null) Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _result!.contains('Error') ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(_result!.contains('Error') ? Icons.error_outline : Icons.check_circle_outline,
          color: _result!.contains('Error') ? AppColors.red : AppColors.green, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_result!, style: TextStyle(fontSize: 13,
          color: _result!.contains('Error') ? AppColors.red : AppColors.green))),
      ]),
    ),

    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _sending ? null : () => _send('engineStop'),
      icon: const Icon(Icons.lock_rounded, size: 18),
      label: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Text('Immobilize Engine'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    )),
    const SizedBox(height: 10),

    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _sending ? null : () => _send('engineResume'),
      icon: const Icon(Icons.lock_open_rounded, size: 18),
      label: const Text('Un-Immobilize Engine'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    )),
    const SizedBox(height: 6),
    const Center(child: Text('Commands are queued and sent on next device uplink.',
      style: TextStyle(fontSize: 11, color: AppColors.text4))),
    const SizedBox(height: 20),

    if (_history.isNotEmpty) ...[
      const Text('Command history',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      const SizedBox(height: 10),
      ..._history.map((h) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h['type'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
            const SizedBox(height: 3),
            Text(fmtDateTime(h['time'] as DateTime?), style: const TextStyle(fontSize: 11, color: AppColors.text3)),
            if ((h['note'] as String?)?.isNotEmpty == true)
              Text(h['note'] as String, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: h['status'] == 'sent' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20)),
            child: Text(h['status'] as String, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: h['status'] == 'sent' ? AppColors.green : AppColors.red)),
          ),
        ]),
      )),
    ],
    const SizedBox(height: 24),
  ]);
}

// ── Shared helpers ──────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value; final Color? valueColor; final bool bold;
  const _DetailRow(this.label, this.value, {this.valueColor, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text3)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: valueColor ?? AppColors.text1)),
  ]);
}

class _SpeedArc extends StatelessWidget {
  final double speed;
  const _SpeedArc({required this.speed});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      height: 140,
      child: CustomPaint(
        painter: _ArcPainter(speed),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${speed.round()}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppColors.text1, height: 1)),
              const Text('km/h', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text3)),
              const SizedBox(height: 12), 
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double speed;
  _ArcPainter(this.speed);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 20;
    final r = size.height - 40; 
    
    const startAngle = math.pi;
    const sweep = math.pi;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track Background
    canvas.drawArc(
      arcRect, 
      startAngle, 
      sweep, 
      false,
      Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
    );

    // Track Active Fill Progress
    final pct = (speed / 200).clamp(0.0, 1.0);
    if (pct > 0) {
      canvas.drawArc(
        arcRect, 
        startAngle, 
        sweep * pct, 
        false,
        Paint()
          ..color = speed > 100 
              ? const Color(0xFFDC2626) 
              : speed > 60 
                  ? const Color(0xFFD97706) 
                  : const Color(0xFF1A73E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
      );
    }

    // Ticks & Overlay Values
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [0, 100, 200]) {
      final a = startAngle + sweep * (v / 200);
      
      tp..text = TextSpan(
        text: '$v', 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))
      )..layout();
      
      canvas.drawLine(
        Offset(cx + (r - 12) * math.cos(a), cy + (r - 12) * math.sin(a)),
        Offset(cx + (r - 2) * math.cos(a), cy + (r - 2) * math.sin(a)),
        Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 2.0
      );
      
      final textRadius = r + 14;
      canvas.save();
      canvas.translate(cx + textRadius * math.cos(a), cy + textRadius * math.sin(a));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override bool shouldRepaint(_ArcPainter o) => o.speed != speed;
}