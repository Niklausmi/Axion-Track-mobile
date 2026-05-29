// lib/screens/history_screen.dart  — v2.1
// Clicking replay on a trip collapses the timeline, expands the map
// fullscreen, and plays only that trip's route segment.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class HistoryScreen extends StatefulWidget {
  final TraccarDevice device;
  final TraccarTrip? jumpToTrip;
  const HistoryScreen({super.key, required this.device, this.jumpToTrip});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  // ── Data ──
  DateTime _date = DateTime.now();
  List<TraccarTrip>     _trips = [];
  List<TraccarStop>     _stops = [];
  List<TraccarPosition> _route = [];
  bool _loading = false;

  // ── Playback ──
  double _prog   = 0;
  bool   _playing = false;
  int    _playIdx = 0;
  int    _speed   = 1;
  static const _speeds = [1, 2, 5, 10, 20];

  // ── Trip-focus mode ──
  // When non-null, the user tapped replay on a specific trip.
  // The map goes fullscreen, timeline collapses, and we play only that segment.
  TraccarTrip? _focusedTrip;
  List<TraccarPosition> _focusedRoute = [];  // sub-slice of _route for focused trip
  late final AnimationController _collapseCtrl;
  late final Animation<double>   _collapseAnim;

  // ── Map ──
  final _mapCtrl  = MapController();
  bool _mapExpanded = false;  // manual expand (non-focus mode)

  @override
  void initState() {
    super.initState();
    _collapseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _collapseAnim = CurvedAnimation(
        parent: _collapseCtrl, curve: Curves.easeInOutCubic);
    _load();
  }

  @override
  void dispose() {
    _collapseCtrl.dispose();
    super.dispose();
  }

  // ── Loading ──
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _trips = []; _stops = []; _route = [];
      _prog = 0; _playing = false; _playIdx = 0;
      _focusedTrip = null; _focusedRoute = [];
    });
    _collapseCtrl.reverse();
    final svc = context.read<AppState>().service;
    if (svc == null) { setState(() => _loading = false); return; }
    final from = DateTime(_date.year, _date.month, _date.day);
    final to   = DateTime(_date.year, _date.month, _date.day, 23, 59, 59);
    try {
      final results = await Future.wait([
        svc.getTrips(deviceId: widget.device.id, from: from, to: to),
        svc.getStops(deviceId: widget.device.id, from: from, to: to),
        svc.getRoute( deviceId: widget.device.id, from: from, to: to),
      ]);
      if (!mounted) return;
      setState(() {
        _trips = results[0] as List<TraccarTrip>;
        _stops = results[1] as List<TraccarStop>;
        _route = results[2] as List<TraccarPosition>;
      });
      _fitFullRoute();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _fitFullRoute() {
    if (_route.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final bounds = LatLngBounds.fromPoints(
            _route.map((p) => LatLng(p.latitude, p.longitude)).toList());
        _mapCtrl.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)));
      } catch (_) {}
    });
  }

  // ── Trip replay ──
  void _replayTrip(TraccarTrip trip) {
    if (_route.isEmpty) return;

    // Slice _route to positions that fall within this trip's time window
    final from = trip.startTime;
    final to   = trip.endTime;
    List<TraccarPosition> segment;
    if (from != null && to != null) {
      segment = _route.where((p) {
        final t = p.fixTime ?? p.serverTime;
        if (t == null) return false;
        return !t.isBefore(from) && !t.isAfter(to);
      }).toList();
    } else {
      segment = List.from(_route);
    }
    if (segment.isEmpty) segment = List.from(_route);

    setState(() {
      _focusedTrip  = trip;
      _focusedRoute = segment;
      _playing = false;
      _playIdx = 0;
      _prog    = 0;
      _mapExpanded = false;
    });

    // Animate collapse of timeline
    _collapseCtrl.forward();

    // Fit map to this trip's segment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (segment.length >= 2) {
          final bounds = LatLngBounds.fromPoints(
              segment.map((p) => LatLng(p.latitude, p.longitude)).toList());
          _mapCtrl.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
        } else if (segment.isNotEmpty) {
          _mapCtrl.move(LatLng(segment.first.latitude, segment.first.longitude), 14);
        }
      } catch (_) {}
    });

    // Auto-start playback after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _focusedTrip == trip) {
        setState(() => _playing = true);
        _playNext();
      }
    });
  }

  // ── Exit focus mode ──
  void _exitFocus() {
    setState(() {
      _focusedTrip  = null;
      _focusedRoute = [];
      _playing = false;
      _playIdx = 0;
      _prog    = 0;
    });
    _collapseCtrl.reverse();
    _fitFullRoute();
  }

  // ── Playback engine ──
  List<TraccarPosition> get _activeRoute =>
      _focusedTrip != null ? _focusedRoute : _route;

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) _playNext();
  }

  void _playNext() {
    if (!_playing || _activeRoute.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || !_playing) return;
      final route = _activeRoute;
      setState(() {
        _playIdx = (_playIdx + _speed).clamp(0, route.length - 1);
        _prog    = _playIdx / (route.length - 1) * 100;
        if (_playIdx >= route.length - 1) _playing = false;
        final cur = route[_playIdx];
        try {
          _mapCtrl.move(LatLng(cur.latitude, cur.longitude), _mapCtrl.camera.zoom);
        } catch (_) {}
      });
      if (_playing) _playNext();
    });
  }

  // ── Date picker ──
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _load();
    }
  }

  // ── Computed ──
  double get _totalDist => _trips.fold(0, (s, t) => s + t.distance);
  int    get _totalDur  => _trips.fold(0, (s, t) => s + t.duration);
  int    get _totalStop => _stops.fold(0, (s, t) => s + t.duration);
  double get _maxSpeed  => _trips.fold(0.0, (m, t) => t.maxSpeed * 3.6 > m ? t.maxSpeed * 3.6 : m);

  List<Map<String, dynamic>> get _timeline {
    final items = <Map<String, dynamic>>[];
    for (final t in _trips) items.add({'type': 'trip', 'data': t, 'time': t.startTime});
    for (final s in _stops) items.add({'type': 'stop', 'data': s, 'time': s.startTime});
    items.sort((a, b) {
      final ta = a['time'] as DateTime?, tb = b['time'] as DateTime?;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute  = _activeRoute;
    final routePoints  = activeRoute.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final allPoints    = _route.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final curPos       = activeRoute.isNotEmpty && _playIdx < activeRoute.length
        ? activeRoute[_playIdx] : null;
    final dateStr      = '${_date.day.toString().padLeft(2, '0')}-'
        '${_date.month.toString().padLeft(2, '0')}-${_date.year}';
    final isFocused    = _focusedTrip != null;

    // Map height: fullscreen when focused, expandable otherwise
    final screenH = MediaQuery.of(context).size.height;
    final mapHeight = isFocused
        ? screenH * 0.62
        : (_mapExpanded ? 320.0 : 200.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // ── Header ──
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: isFocused ? _exitFocus : () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: isFocused
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  isFocused ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isFocused ? AppColors.primary : AppColors.text1,
                ),
              ),
            ),
            Expanded(child: Column(children: [
              Text(
                isFocused ? 'Trip Replay' : widget.device.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1),
              ),
              if (isFocused) Text(
                '${fmtKm(_focusedTrip!.distance)} · ${_focusedTrip!.maxSpeedKmh.round()} km/h max',
                style: const TextStyle(fontSize: 11, color: AppColors.text3),
              ),
            ])),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              ),
            ),
          ]),
        ),

        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
            : ListView(padding: EdgeInsets.zero, children: [

          // ── Map ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            height: mapHeight,
            child: Stack(children: [
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: allPoints.isNotEmpty
                      ? allPoints[allPoints.length ~/ 2]
                      : const LatLng(31.5, 74.3),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.axiontrack.app',
                  ),
                  // Full-day route (faded) shown behind focused segment
                  if (isFocused && allPoints.length >= 2)
                    PolylineLayer<Object>(polylines: [
                      Polyline(
                        points: allPoints,
                        strokeWidth: 2,
                        color: AppColors.text4.withOpacity(0.3),
                      ),
                    ]),
                  // Active route (full day or focused trip)
                  if (routePoints.length >= 2)
                    PolylineLayer<Object>(polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: isFocused ? 4 : 3,
                        color: isFocused
                            ? AppColors.primary.withOpacity(0.85)
                            : AppColors.primary.withOpacity(0.7),
                      ),
                    ]),
                  // Markers
                  if (routePoints.isNotEmpty)
                    MarkerLayer(markers: [
                      // Start
                      Marker(
                        point: routePoints.first, width: 22, height: 22,
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 10)),
                      ),
                      // End
                      Marker(
                        point: routePoints.last, width: 22, height: 22,
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.stop, color: Colors.white, size: 10)),
                      ),
                      // Playback vehicle
                      if (curPos != null)
                        Marker(
                          point: LatLng(curPos.latitude, curPos.longitude),
                          width: 36, height: 36,
                          child: Transform.rotate(
                            angle: curPos.course * 3.14159 / 180,
                            child: Container(
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.navigation_rounded,
                                  color: AppColors.primary, size: 28,
                                  shadows: [Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4)]),
                            ),
                          ),
                        ),
                    ]),
                ],
              ),

              // Playback overlay bar (shown in focus mode)
              if (isFocused)
                Positioned(bottom: 0, left: 0, right: 0,
                  child: _PlaybackOverlay(
                    route: activeRoute,
                    playIdx: _playIdx,
                    prog: _prog,
                    playing: _playing,
                    speed: _speed,
                    speeds: _speeds,
                    curPos: curPos,
                    onTogglePlay: _togglePlay,
                    onScrub: (pct) {
                      setState(() {
                        _prog    = pct * 100;
                        _playIdx = (pct * (activeRoute.length - 1)).round();
                      });
                    },
                    onSpeedChange: () {
                      final idx = _speeds.indexOf(_speed);
                      setState(() => _speed = _speeds[(idx + 1) % _speeds.length]);
                    },
                    onExit: _exitFocus,
                  ),
                ),

              // Expand/collapse button (non-focus mode only)
              if (!isFocused)
                Positioned(bottom: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _mapExpanded = !_mapExpanded),
                    child: Container(width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.12), blurRadius: 8)]),
                      child: Icon(
                        _mapExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        size: 18, color: AppColors.text2)),
                  )),

              // Focused-trip info pill (top of map)
              if (isFocused && curPos != null)
                Positioned(top: 10, left: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.93),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                    child: Row(children: [
                      const Icon(Icons.speed_rounded, size: 14, color: AppColors.text3),
                      const SizedBox(width: 6),
                      Text('${curPos.speedKmh.round()} km/h',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.text3),
                      const SizedBox(width: 6),
                      Text(fmtTimeOnly(curPos.fixTime),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                      const Spacer(),
                      Text('${_playIdx + 1}/${activeRoute.length}',
                          style: const TextStyle(fontSize: 11, color: AppColors.text4)),
                    ]),
                  )),
            ]),
          ),

          // ── Collapsible section (summary + timeline) ──
          SizeTransition(
            sizeFactor: ReverseAnimation(_collapseAnim),
            axisAlignment: -1,
            child: Column(children: [

              // Summary card
              if (_trips.isNotEmpty) Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06), blurRadius: 12,
                      offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.summarize_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(dateStr,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text2)),
                    const Spacer(),
                    Text('${_trips.length} trips · ${_stops.length} stops',
                        style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: StatTile(label: 'Distance',   value: fmtKm(_totalDist),          icon: Icons.route_rounded,        color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(label: 'Max Speed',  value: '${_maxSpeed.round()} km/h', icon: Icons.speed_rounded,        color: AppColors.orange)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: StatTile(label: 'Drive Time', value: fmtDuration(_totalDur),      icon: Icons.drive_eta_rounded,    color: AppColors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(label: 'Stop Time',  value: fmtDuration(_totalStop),     icon: Icons.stop_circle_outlined, color: AppColors.red)),
                  ]),
                  const SizedBox(height: 16),

                  // Full-day playback controls (non-focus mode)
                  _PlaybackBar(
                    route: _route,
                    playIdx: _playIdx,
                    prog: _prog,
                    playing: _playing,
                    speed: _speed,
                    speeds: _speeds,
                    curPos: _route.isNotEmpty && _playIdx < _route.length ? _route[_playIdx] : null,
                    onTogglePlay: _togglePlay,
                    onScrub: (pct) => setState(() {
                      _prog    = pct * 100;
                      _playIdx = (pct * (_route.length - 1)).round();
                    }),
                    onSpeedChange: () {
                      final idx = _speeds.indexOf(_speed);
                      setState(() => _speed = _speeds[(idx + 1) % _speeds.length]);
                    },
                  ),
                ]),
              ),

              // Timeline
              const SizedBox(height: 12),
              ..._timeline.map((item) {
                if (item['type'] == 'trip') {
                  return _TripCard(
                    trip: item['data'] as TraccarTrip,
                    onReplay: () => _replayTrip(item['data'] as TraccarTrip),
                  );
                }
                return _StopCard(stop: item['data'] as TraccarStop);
              }),

              if (_trips.isEmpty && _stops.isEmpty)
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                      color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: const EmptyState(
                      icon: Icons.history_rounded,
                      message: 'No trips found for this date'),
                ),
              const SizedBox(height: 24),
            ]),
          ),
        ])),
      ])),
    );
  }
}

// ── Playback bar (inside summary card, full-day mode) ─────────────────────
class _PlaybackBar extends StatelessWidget {
  final List<TraccarPosition> route;
  final int playIdx;
  final double prog;
  final bool playing;
  final int speed;
  final List<int> speeds;
  final TraccarPosition? curPos;
  final VoidCallback onTogglePlay;
  final void Function(double pct) onScrub;
  final VoidCallback onSpeedChange;

  const _PlaybackBar({
    required this.route, required this.playIdx, required this.prog,
    required this.playing, required this.speed, required this.speeds,
    required this.curPos, required this.onTogglePlay,
    required this.onScrub, required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      // Play/pause
      GestureDetector(
        onTap: route.isNotEmpty ? onTogglePlay : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: playing ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: playing ? Colors.white : (route.isNotEmpty ? AppColors.text1 : AppColors.text4),
            size: 24,
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Scrubber
      Expanded(child: _Scrubber(
        prog: prog, route: route, onScrub: onScrub)),
      const SizedBox(width: 10),
      // Speed
      GestureDetector(
        onTap: onSpeedChange,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Text('${speed}×',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text1)),
        ),
      ),
    ]),
    if (route.isNotEmpty && curPos != null)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '${playIdx + 1}/${route.length} · ${curPos!.speedKmh.round()} km/h · ${fmtTimeOnly(curPos!.fixTime)}',
          style: const TextStyle(fontSize: 11, color: AppColors.text3),
        ),
      ),
  ]);
}

// ── Playback overlay (floats at bottom of map in focus mode) ─────────────
class _PlaybackOverlay extends StatelessWidget {
  final List<TraccarPosition> route;
  final int playIdx;
  final double prog;
  final bool playing;
  final int speed;
  final List<int> speeds;
  final TraccarPosition? curPos;
  final VoidCallback onTogglePlay;
  final void Function(double pct) onScrub;
  final VoidCallback onSpeedChange;
  final VoidCallback onExit;

  const _PlaybackOverlay({
    required this.route, required this.playIdx, required this.prog,
    required this.playing, required this.speed, required this.speeds,
    required this.curPos, required this.onTogglePlay,
    required this.onScrub, required this.onSpeedChange, required this.onExit,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, -4))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Drag handle
      Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(2))),
      Row(children: [
        // Play/pause
        GestureDetector(
          onTap: onTogglePlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: playing ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: playing ? Colors.white : AppColors.text1, size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Scrubber
        Expanded(child: _Scrubber(prog: prog, route: route, onScrub: onScrub)),
        const SizedBox(width: 10),
        // Speed
        GestureDetector(
          onTap: onSpeedChange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Text('${speed}×',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text1)),
          ),
        ),
        const SizedBox(width: 8),
        // Close focus mode
        GestureDetector(
          onTap: onExit,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.red),
          ),
        ),
      ]),
    ]),
  );
}

// ── Reusable scrubber ──────────────────────────────────────────────────────
class _Scrubber extends StatelessWidget {
  final double prog;
  final List<TraccarPosition> route;
  final void Function(double pct) onScrub;
  const _Scrubber({required this.prog, required this.route, required this.onScrub});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, constraints) {
    final w = constraints.maxWidth;
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        if (route.isEmpty) return;
        onScrub((d.localPosition.dx / w).clamp(0.0, 1.0));
      },
      onTapDown: (d) {
        if (route.isEmpty) return;
        onScrub((d.localPosition.dx / w).clamp(0.0, 1.0));
      },
      child: Stack(alignment: Alignment.centerLeft, children: [
        Container(height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
        FractionallySizedBox(
          widthFactor: (prog / 100).clamp(0.0, 1.0),
          child: Container(height: 4,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        ),
        Positioned(
          left: ((prog / 100).clamp(0.0, 1.0) * w - 7).clamp(0.0, w - 14),
          child: Container(width: 14, height: 14, decoration: BoxDecoration(
            color: AppColors.surface, shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4)],
          )),
        ),
      ]),
    );
  });
}

// ── Trip card with Replay button ───────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final TraccarTrip trip;
  final VoidCallback onReplay;
  const _TripCard({required this.trip, required this.onReplay});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      // Header row
      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
            child: const Text('Trip',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669)))),
          const SizedBox(width: 8),
          Text(fmtKm(trip.distance),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text1)),
          const Spacer(),
          const Icon(Icons.speed_rounded, size: 14, color: AppColors.green),
          const SizedBox(width: 4),
          Text('${trip.maxSpeedKmh.round()} km/h',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
        ]),
      ),
      const Divider(height: 16, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),
      _Row(Icons.play_circle_outline_rounded, 'Start',
          trip.startTime != null ? fmtDateTime(trip.startTime) : '—'),
      const Divider(height: 1, indent: 46, color: Color(0xFFF1F5F9)),
      _Row(Icons.timer_outlined, 'Duration', trip.durationStr),
      const Divider(height: 1, indent: 46, color: Color(0xFFF1F5F9)),
      _Row(Icons.stop_circle_outlined, 'End',
          trip.endTime != null ? fmtDateTime(trip.endTime) : '—'),
      if (trip.startAddress != null || trip.endAddress != null) ...[
        const Divider(height: 1, indent: 46, color: Color(0xFFF1F5F9)),
        _Row(Icons.location_on_outlined, 'From', trip.startAddress ?? '—'),
        const Divider(height: 1, indent: 46, color: Color(0xFFF1F5F9)),
        _Row(Icons.flag_outlined,        'To',   trip.endAddress   ?? '—'),
      ],
      // Replay button
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onReplay,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
            label: const Text('Replay This Trip'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    ]),
  );
}

// ── Stop card ──────────────────────────────────────────────────────────────
class _StopCard extends StatelessWidget {
  final TraccarStop stop;
  const _StopCard({required this.stop});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
            child: const Text('Stop',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.red))),
          if (stop.address != null) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(stop.address!,
                style: const TextStyle(fontSize: 11, color: AppColors.text3),
                overflow: TextOverflow.ellipsis)),
          ],
        ]),
      ),
      const Divider(height: 16, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),
      _Row(Icons.play_circle_outline_rounded, 'Start',
          stop.startTime != null ? fmtDateTime(stop.startTime) : '—'),
      const Divider(height: 1, indent: 46, color: Color(0xFFF1F5F9)),
      _Row(Icons.timer_outlined, 'Duration', stop.durationStr),
      const Divider(height: 1, indent: 46, color: Color(0xFFF1F5F9)),
      _Row(Icons.stop_circle_outlined, 'End',
          stop.endTime != null ? fmtDateTime(stop.endTime) : '—'),
      const SizedBox(height: 4),
    ]),
  );
}

// ── Shared row widget ──────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.text4),
      const SizedBox(width: 10),
      Text('$label:', style: const TextStyle(fontSize: 13, color: AppColors.text3)),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1),
        overflow: TextOverflow.ellipsis)),
    ]),
  );
}
