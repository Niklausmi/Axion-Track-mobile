// lib/screens/history_screen.dart — v5 (Unified Date Routing Engine Fixed)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';

class HistoryScreen extends StatefulWidget {
  final TraccarDevice device;
  final TraccarTrip? jumpToTrip;
  final DateTime? initialDate; // ── FIX: Explicit incoming calendar range parameter hook ──

  const HistoryScreen({
    super.key, 
    required this.device, 
    this.jumpToTrip, 
    this.initialDate,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {

  // ── Data ──────────────────────────────────────────────────────────────────
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<TraccarTrip>     _trips     = [];
  List<TraccarStop>     _stops     = [];
  List<TraccarPosition> _fullRoute = [];
  bool    _loading = false;
  String? _error;

  // ── Playback state ────────────────────────────────────────────────────────
  TraccarTrip?          _playingTrip;      // null = full day
  List<TraccarPosition> _activeSlice = []; // current slice being played
  List<LatLng>          _fullDayPts  = []; // cached LatLng for full route (never changes per load)
  List<LatLng>          _activePts   = []; // cached LatLng for active slice
  List<LatLng>          _trailPts    = []; // played portion — updated inside timer ONLY
  int    _playIdx = 0;
  double _prog    = 0.0;
  bool   _playing = false;
  int    _speed   = 1;
  static const _speeds = [1, 2, 5, 10, 20];
  Timer? _timer;

  // ── Map ───────────────────────────────────────────────────────────────────
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    
    // ── FIX: Cascade structural fallbacks so initial date context matches chosen state parameters ──
    if (widget.initialDate != null) {
      _date = DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day);
    } else if (widget.jumpToTrip?.startTime != null) {
      final localStart = widget.jumpToTrip!.startTime!.toLocal();
      _date = DateTime(localStart.year, localStart.month, localStart.day);
    } else {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
    }
    _load();
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    _timer?.cancel();
    setState(() {
      _loading = true; _error = null;
      _playing = false; _playIdx = 0; _prog = 0;
      _trips = []; _stops = []; _fullRoute = [];
      _fullDayPts = []; _activePts = []; _trailPts = [];
      _activeSlice = []; _playingTrip = null;
    });

    final svc = context.read<AppState>().service;
    if (svc == null) {
      setState(() { _loading = false; _error = 'Not connected'; });
      return;
    }

    final from = DateTime.utc(_date.year, _date.month, _date.day, 0, 0, 0);
    final to   = DateTime.utc(_date.year, _date.month, _date.day, 23, 59, 59, 999);

    try {
      final res = await Future.wait([
        svc.getTrips(deviceId: widget.device.id, from: from, to: to),
        svc.getStops(deviceId: widget.device.id, from: from, to: to),
        svc.getRoute(deviceId: widget.device.id, from: from, to: to),
      ]);
      if (!mounted) return;

      final route = res[2] as List<TraccarPosition>;
      final pts   = route.map((p) => LatLng(p.latitude, p.longitude)).toList();

      setState(() {
        _trips      = res[0] as List<TraccarTrip>;
        _stops      = res[1] as List<TraccarStop>;
        _fullRoute  = route;
        _fullDayPts = pts;
      });

      // Maintain user trip selection if jumped from sub-card triggers
      final target = (widget.jumpToTrip != null && widget.jumpToTrip!.startTime != null)
          ? _trips.firstWhere(
              (t) => t.startTime == widget.jumpToTrip!.startTime,
              orElse: () => widget.jumpToTrip!)
          : null;
      _selectSlice(target);

    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Slice selection ───────────────────────────────────────────────────────
  void _selectSlice(TraccarTrip? trip) {
    _timer?.cancel();
    List<TraccarPosition> slice;

    if (trip?.startTime != null && trip?.endTime != null) {
      slice = _fullRoute.where((p) {
        final t = p.fixTime ?? p.serverTime;
        if (t == null) return false;
        return !t.isBefore(trip!.startTime!) && !t.isAfter(trip.endTime!);
      }).toList();
      if (slice.isEmpty) slice = List.from(_fullRoute);
    } else {
      slice = List.from(_fullRoute);
    }

    final pts = slice.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _playingTrip = trip;
      _activeSlice = slice;
      _activePts   = pts;
      _trailPts    = pts.isNotEmpty ? [pts.first] : [];
      _playIdx     = 0;
      _prog        = 0.0;
      _playing     = false;
    });

    _fitRoute(pts);
  }

  void _fitRoute(List<LatLng> pts) {
    if (pts.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final b = LatLngBounds.fromPoints(pts);
        _mapCtrl.fitCamera(CameraFit.bounds(bounds: b,
          padding: const EdgeInsets.fromLTRB(32, 100, 32, 310)));
      } catch (_) {}
    });
  }

  // ── Playback engine ───────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    if (_activePts.isEmpty || _playIdx >= _activePts.length - 1) {
      setState(() => _playing = false); return;
    }
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted) { t.cancel(); return; }
      final max = _activePts.length - 1;
      final next = (_playIdx + _speed).clamp(0, max);
      if (next == _playIdx) { t.cancel(); setState(() => _playing = false); return; }
      setState(() {
        _playIdx  = next;
        _prog     = (_playIdx / max) * 100;
        _trailPts = _activePts.sublist(0, _playIdx + 1); 
        try { _mapCtrl.move(_activePts[_playIdx], _mapCtrl.camera.zoom); } catch (_) {}
        if (_playIdx >= max) { _playing = false; t.cancel(); }
      });
    });
  }

  void _pauseTimer() { _timer?.cancel(); setState(() => _playing = false); }

  void _togglePlay() {
    if (_playing) { _pauseTimer(); return; }
    if (_playIdx >= _activePts.length - 1) {
      setState(() {
        _playIdx  = 0; _prog = 0;
        _trailPts = _activePts.isNotEmpty ? [_activePts.first] : [];
      });
    }
    _startTimer();
  }

  void _seekTo(double pct) {
    _timer?.cancel();
    final max = _activePts.length - 1;
    if (max <= 0) return;
    final idx = (pct * max).round().clamp(0, max);
    setState(() {
      _playing  = false;
      _playIdx  = idx;
      _prog     = pct * 100;
      _trailPts = _activePts.sublist(0, idx + 1);
    });
    try { _mapCtrl.move(_activePts[idx], _mapCtrl.camera.zoom); } catch (_) {}
  }

  void _restartPlay() {
    _timer?.cancel();
    setState(() {
      _playing  = false; _playIdx = 0; _prog = 0;
      _trailPts = _activePts.isNotEmpty ? [_activePts.first] : [];
    });
    if (_activePts.isNotEmpty) {
      try { _mapCtrl.move(_activePts.first, _mapCtrl.camera.zoom); } catch (_) {}
    }
  }

  void _cycleSpeed() {
    final i = _speeds.indexOf(_speed);
    setState(() => _speed = _speeds[(i + 1) % _speeds.length]);
    if (_playing) { _pauseTimer(); _startTimer(); }
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final maxLimit = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final p = await showDatePicker(
      context: context, 
      initialDate: _date,
      firstDate: maxLimit.subtract(const Duration(days: 365)),
      lastDate: maxLimit,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (p != null) { 
      setState(() => _date = DateTime(p.year, p.month, p.day)); 
      _load(); 
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _dateStr {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${_date.day} ${m[_date.month - 1]} ${_date.year}';
  }

  String _fmtT(DateTime? t) {
    if (t == null) return '--:--';
    final l = t.toLocal();
    final h  = l.hour.toString().padLeft(2,'0');
    final mi = l.minute.toString().padLeft(2,'0');
    final s  = l.second.toString().padLeft(2,'0');
    return '$h:$mi:$s';
  }

  List<Map<String, dynamic>> get _timeline {
    final items = <Map<String, dynamic>>[];
    for (final t in _trips) items.add({'type':'trip','data':t,'time':t.startTime});
    for (final s in _stops) items.add({'type':'stop','data':s,'time':s.startTime});
    items.sort((a, b) {
      final ta = a['time'] as DateTime?, tb = b['time'] as DateTime?;
      if (ta == null) return 1; if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    return items;
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final curPos = _activeSlice.isNotEmpty && _playIdx < _activeSlice.length
        ? _activeSlice[_playIdx] : null;
    final startT = _activeSlice.isNotEmpty ? (_activeSlice.first.fixTime ?? _activeSlice.first.serverTime) : null;
    final endT   = _activeSlice.isNotEmpty ? (_activeSlice.last.fixTime  ?? _activeSlice.last.serverTime)  : null;
    final curT   = curPos != null ? (curPos.fixTime ?? curPos.serverTime) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Stack(children: [

        // ── LAYER 1: Full-screen map ──────────────────────────────────────
        Positioned.fill(child: FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _fullDayPts.isNotEmpty ? _fullDayPts.first : const LatLng(31.5, 74.3),
            initialZoom: 13,
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.axiontrack.app'),

            if (_fullDayPts.length >= 2 && _playingTrip != null)
              PolylineLayer<Object>(polylines: [
                Polyline(points: _fullDayPts, strokeWidth: 3,
                  color: Colors.blueGrey.withOpacity(0.2)),
              ]),

            if (_activePts.length >= 2)
              PolylineLayer<Object>(polylines: [
                Polyline(points: _activePts, strokeWidth: 4.5,
                  color: AppColors.primary.withOpacity(0.55)),
              ]),

            if (_trailPts.length >= 2)
              PolylineLayer<Object>(polylines: [
                Polyline(points: _trailPts, strokeWidth: 5.5,
                  color: AppColors.green.withOpacity(0.9)),
              ]),

            if (_activePts.isNotEmpty)
              MarkerLayer(markers: [
                Marker(point: _activePts.first, width: 26, height: 26,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 12))),
                Marker(point: _activePts.last, width: 26, height: 26,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: const Icon(Icons.flag, color: Colors.white, size: 12))),
                if (curPos != null)
                  Marker(point: LatLng(curPos.latitude, curPos.longitude), width: 44, height: 44,
                    child: Transform.rotate(
                      angle: curPos.course * 3.14159265 / 180,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(Icons.navigation_rounded, color: AppColors.primary, size: 34,
                          shadows: const [Shadow(color: Colors.white70, blurRadius: 6)])))),
              ]),
          ],
        )),

        // ── LAYER 2: Floating header ───────────────────────────────────────
        Positioned(top: 12, left: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.text1, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(widget.device.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
                Text(_playingTrip == null ? 'Full Day · $_dateStr' : 'Trip ${_trips.indexOf(_playingTrip!) + 1} Replay',
                  style: const TextStyle(fontSize: 11, color: AppColors.text3)),
              ])),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_month_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(_dateStr, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              ),
              if (curPos != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider)),
                  child: Text('${curPos.speedKmh.round()} km/h',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text1))),
              ],
            ]),
          ),
        ),

        // ── LAYER 3: Map controls ───────────────────
        Positioned(right: 12, bottom: 302,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _MapBtn(icon: Icons.add,
              onTap: () { try { _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1); } catch(_){} }),
            const SizedBox(height: 8),
            _MapBtn(icon: Icons.remove,
              onTap: () { try { _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1); } catch(_){} }),
            const SizedBox(height: 8),
            _MapBtn(icon: Icons.fit_screen_rounded,
              onTap: () => _fitRoute(_activePts)),
          ]),
        ),

        // ── LAYER 4: Loading overlay ───────────────────────────────────────
        if (_loading)
          Positioned.fill(child: Container(
            color: Colors.white.withOpacity(0.6),
            child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)))),

        // ── LAYER 5: Error banner ──────────────────────────────────────────
        if (_error != null && !_loading)
          Positioned(top: 80, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red))),
                GestureDetector(onTap: _load,
                  child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.red))),
              ]),
            ),
          ),

        // ── LAYER 6: Bottom console ────────────────────────────────────────
        Positioned(bottom: 0, left: 0, right: 0,
          child: _BottomConsole(
            trips:       _trips,
            stops:       _stops,
            timeline:    _timeline,
            activeSlice: _activeSlice,
            playingTrip: _playingTrip,
            playIdx:     _playIdx,
            prog:        _prog,
            playing:     _playing,
            speed:       _speed,
            startT:      startT,
            endT:        endT,
            curT:        curT,
            totalDist:   _trips.fold(0.0, (s, t) => s + t.distance),
            totalDur:    _trips.fold(0, (s, t) => s + t.duration),
            onToggle:    _togglePlay,
            onRestart:   _restartPlay,
            onScrub:     _seekTo,
            onSpeed:     _cycleSpeed,
            onSelectSlice: _selectSlice,
            onResetToAllDay: () => _selectSlice(null),
            parentDateStr: _dateStr, 
          ),
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// BOTTOM CONSOLE
// ══════════════════════════════════════════════════════════════════════════
class _BottomConsole extends StatelessWidget {
  final List<TraccarTrip>           trips;
  final List<TraccarStop>           stops;
  final List<Map<String,dynamic>>   timeline;
  final List<TraccarPosition>       activeSlice;
  final TraccarTrip?                playingTrip;
  final int     playIdx, speed;
  final double  prog;
  final bool    playing;
  final DateTime? startT, endT, curT;
  final double totalDist;
  final int    totalDur;
  final String parentDateStr; 
  final VoidCallback onToggle, onRestart, onSpeed, onResetToAllDay;
  final void Function(double) onScrub;
  final void Function(TraccarTrip?) onSelectSlice;

  const _BottomConsole({
    required this.trips, required this.stops, required this.timeline,
    required this.activeSlice, required this.playingTrip,
    required this.playIdx, required this.speed, required this.prog,
    required this.playing, required this.startT, required this.endT,
    required this.curT, required this.totalDist, required this.totalDur,
    required this.onToggle, required this.onRestart, required this.onScrub,
    required this.onSpeed, required this.onSelectSlice, required this.onResetToAllDay,
    required this.parentDateStr,
  });

  String _t(DateTime? dt) {
    if (dt == null) return '--:--';
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}:${l.second.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.text4.withOpacity(0.35), borderRadius: BorderRadius.circular(2))),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_t(startT), style: const TextStyle(fontSize: 11, color: AppColors.text4)),
            Text(_t(curT),   style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text1)),
            Text(_t(endT),   style: const TextStyle(fontSize: 11, color: AppColors.text4)),
          ]),
          const SizedBox(height: 6),

          _Scrubber(prog: prog, enabled: activeSlice.isNotEmpty, onScrub: onScrub),
          const SizedBox(height: 12),

          Row(children: [
            _CtrlBtn(icon: Icons.skip_previous_rounded, onTap: onRestart),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: activeSlice.isNotEmpty ? onToggle : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: activeSlice.isNotEmpty ? AppColors.primary : AppColors.background,
                  shape: BoxShape.circle,
                  boxShadow: playing
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 1)]
                    : [],
                ),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 26)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider)),
                child: Text('${speed}×',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text1))),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(totalDist/1000).toStringAsFixed(1)} km  ·  ${_fmtDur(totalDur)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text2)),
              Text('${playIdx + 1} / ${activeSlice.length} pts · ${prog.round()}%',
                style: const TextStyle(fontSize: 10, color: AppColors.text4)),
            ]),
            if (playingTrip != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onResetToAllDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25))),
                  child: const Text('All Day',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)))),
            ],
          ]),
        ])),

        const Divider(height: 16, color: AppColors.divider),

        SizedBox(
          height: 90,
          child: timeline.isEmpty
            ? Center(child: Text(
                'No trips found for $parentDateStr', 
                style: const TextStyle(fontSize: 12, color: AppColors.text4)))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 4),
                itemCount: timeline.length,
                itemBuilder: (ctx, i) {
                  final item = timeline[i];
                  if (item['type'] == 'trip') {
                    final t = item['data'] as TraccarTrip;
                    return _TripChip(
                      trip: t,
                      index: trips.indexOf(t) + 1,
                      selected: playingTrip == t,
                      onTap: () => onSelectSlice(t),
                    );
                  }
                  return _StopChip(stop: item['data'] as TraccarStop);
                },
              ),
        ),
      ]),
    );
  }

  String _fmtDur(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SCRUBBER
// ══════════════════════════════════════════════════════════════════════════
class _Scrubber extends StatelessWidget {
  final double prog;
  final bool enabled;
  final void Function(double) onScrub;
  const _Scrubber({required this.prog, required this.enabled, required this.onScrub});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    final w   = c.maxWidth;
    final pct = (prog / 100).clamp(0.0, 1.0);
    final thumbL = (pct * w - 9).clamp(0.0, w - 18);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) { if (enabled) onScrub((d.localPosition.dx / w).clamp(0, 1)); },
      onTapDown: (d)           { if (enabled) onScrub((d.localPosition.dx / w).clamp(0, 1)); },
      child: SizedBox(height: 28, child: Stack(alignment: Alignment.center, children: [
        Container(height: 4,
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        Align(alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: pct,
            child: Container(height: 4,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))))),
        Positioned(left: thumbL,
          child: Container(width: 18, height: 18,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)]))),
      ])),
    );
  });
}

// ══════════════════════════════════════════════════════════════════════════
// TRIP CHIP
// ══════════════════════════════════════════════════════════════════════════
class _TripChip extends StatelessWidget {
  final TraccarTrip trip;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  const _TripChip({required this.trip, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.8 : 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text('Trip $index',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.text1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
              child: Text('${(trip.distance / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green))),
          ]),
          Text(trip.durationStr,
            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
          Text('${trip.maxSpeedKmh.round()} km/h max',
            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// STOP CHIP
// ══════════════════════════════════════════════════════════════════════════
class _StopChip extends StatelessWidget {
  final TraccarStop stop;
  const _StopChip({required this.stop});

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: AppColors.red.withOpacity(0.7), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Stop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text1)),
        ]),
        Text(stop.durationStr, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        Text(stop.address ?? 'Parked location',
          style: const TextStyle(fontSize: 10, color: AppColors.text4),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// SMALL REUSABLES
// ══════════════════════════════════════════════════════════════════════════
class _MapBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
      child: Icon(icon, color: AppColors.text2, size: 20)),
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppColors.background, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider)),
      child: Icon(icon, color: AppColors.text2, size: 22)),
  );
}