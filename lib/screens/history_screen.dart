// lib/screens/history_screen.dart
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
  final bool embedded;
  const HistoryScreen({super.key, required this.device, this.embedded = false});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _startDate   = DateTime.now();
  DateTime _endDate     = DateTime.now();
  String   _range  = '7days';
  List<TraccarTrip>     _trips = [];
  List<TraccarStop>     _stops = [];
  List<TraccarPosition> _route = [];
  List<TraccarPosition> _fullRoute = [];
  TraccarTrip? _selectedTrip;
  bool   _loading = false;
  double _prog    = 0;
  bool   _playing = false;
  int    _playIdx = 0;
  final MapController _mapCtrl = MapController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _trips = []; _stops = []; _route = []; _fullRoute = []; _prog = 0; _playing = false; _playIdx = 0; _selectedTrip = null; });
    final svc = context.read<AppState>().svc;
    if (svc == null) { setState(() => _loading = false); return; }
    DateTime from, to = DateTime.now();
    if (_range == 'today')     { final n = DateTime.now(); from = DateTime(n.year, n.month, n.day); to = n; }
    else if (_range == '7days'){ from = to.subtract(const Duration(days: 7)); }
    else if (_range == 'month'){ from = to.subtract(const Duration(days: 30)); }
    else { from = DateTime(_startDate.year, _startDate.month, _startDate.day); to = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59); }
    try {
      final results = await Future.wait([
        svc.getTrips(deviceId: widget.device.id, from: from, to: to),
        svc.getStops(deviceId: widget.device.id, from: from, to: to),
        svc.getRoute(deviceId: widget.device.id, from: from, to: to),
      ]);
      setState(() {
        _trips = results[0] as List<TraccarTrip>;
        _stops = results[1] as List<TraccarStop>;
        _fullRoute = results[2] as List<TraccarPosition>;
        _route = _fullRoute;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final p = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AC.blue, surface: AC.surface)),
        child: child!));
    if (p != null) { setState(() { _startDate = p.start; _endDate = p.end; _range = 'custom'; }); _load(); }
  }

  void _focusTrip(TraccarTrip trip) {
    setState(() {
      _selectedTrip = trip;
      _route = _fullRoute.where((p) {
        if (p.fixTime == null || trip.startTime == null || trip.endTime == null) return false;
        return !p.fixTime!.isBefore(trip.startTime!) && !p.fixTime!.isAfter(trip.endTime!);
      }).toList();
      _playIdx = 0;
      _prog = 0;
      _playing = false;
    });
    Future.delayed(const Duration(milliseconds: 300), _togglePlay);
  }

  void _clearFocus() {
    setState(() {
      _selectedTrip = null;
      _route = _fullRoute;
      _playIdx = 0;
      _prog = 0;
      _playing = false;
    });
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) _playStep();
  }

  void _playStep() {
    if (!_playing || _route.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!mounted || !_playing) return;
      setState(() {
        _playIdx = (_playIdx + 1).clamp(0, _route.length - 1);
        _prog    = _playIdx / (_route.length - 1) * 100;
        final curPos = _route[_playIdx];
        _mapCtrl.move(LatLng(curPos.latitude, curPos.longitude), _mapCtrl.camera.zoom);
        if (_playIdx >= _route.length - 1) { _playing = false; return; }
      });
      if (_playing) _playStep();
    });
  }

  double get _totalDist => _trips.fold(0, (s, t) => s + t.distance);
  int    get _totalDur  => _trips.fold(0, (s, t) => s + t.duration);
  int    get _stopDur   => _stops.fold(0, (s, t) => s + t.duration);
  double get _maxSpd    => _trips.fold(0.0, (m, t) => t.maxSpeedKmh > m ? t.maxSpeedKmh : m);

  List<Map<String, dynamic>> get _timeline {
    final items = <Map<String, dynamic>>[
      ..._trips.map((t) => {'type': 'trip', 'data': t, 'time': t.startTime}),
      ..._stops.map((s) => {'type': 'stop', 'data': s, 'time': s.startTime}),
    ];
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
    final routePts = _route.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final curPos   = _route.isNotEmpty && _playIdx < _route.length ? _route[_playIdx] : null;
    final mapCenter = routePts.isNotEmpty ? routePts[routePts.length ~/ 2] : const LatLng(31.5, 74.3);

    final body = Column(children: [
      // ── Range selector ──
      Container(
        color: AC.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(children: [
          // Quick range buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _RBtn('today',   'Today',    _range, () { setState(() => _range = 'today');   _load(); }),
              const SizedBox(width: 6),
              _RBtn('7days',   'Last 7 Days', _range, () { setState(() => _range = '7days'); _load(); }),
              const SizedBox(width: 6),
              _RBtn('month',   '30 Days',  _range, () { setState(() => _range = 'month');  _load(); }),
              const SizedBox(width: 6),
              _RBtn('custom',  'Custom',   _range, _pickDate),
            ]),
          ),
          if (_range == 'custom') ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AC.text3),
              const SizedBox(width: 8),
              GestureDetector(onTap: _pickDate,
                child: Text(
                  '${_startDate.day.toString().padLeft(2,'0')}-${_startDate.month.toString().padLeft(2,'0')}-${_startDate.year} to ${_endDate.day.toString().padLeft(2,'0')}-${_endDate.month.toString().padLeft(2,'0')}-${_endDate.year}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.blue))),
            ]),
          ],
        ]),
      ),

      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.blue, strokeWidth: 2.5))
        : Stack(children: [
            // ── Full map ──
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(initialCenter: mapCenter, initialZoom: 12),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.axiontrack.app'),
                  if (routePts.length >= 2) PolylineLayer(polylines: [
                    Polyline(points: routePts, strokeWidth: 3, color: AC.blue.withOpacity(0.8)),
                  ]),
                  if (routePts.isNotEmpty) MarkerLayer(markers: [
                    Marker(point: routePts.first, width: 18, height: 18,
                      child: Container(decoration: const BoxDecoration(color: AC.green, shape: BoxShape.circle),
                        child: const Icon(Icons.circle, color: Colors.white, size: 8))),
                    Marker(point: routePts.last, width: 18, height: 18,
                      child: Container(decoration: const BoxDecoration(color: AC.red, shape: BoxShape.circle),
                        child: const Icon(Icons.circle, color: Colors.white, size: 8))),
                    if (curPos != null) Marker(
                      point: LatLng(curPos.latitude, curPos.longitude),
                      width: 28, height: 28,
                      child: Transform.rotate(
                        angle: curPos.course * 3.1415926535897932 / 180,
                        child: const Icon(Icons.navigation_rounded, color: AC.blue, size: 24))),
                  ]),
                ],
              ),
            ),
            
            // ── Draggable Bottom Sheet ──
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.1,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AC.bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -4))],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40, height: 5,
                          decoration: BoxDecoration(color: AC.surface3, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

            // ── Summary card ──
            if (_trips.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
                child: Column(children: [
                  // Header dot + dates
                  Row(children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(
                      color: AC.orange, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('From: ${_shortDate(_range == 'custom' ? _startDate : (_range == 'month' ? DateTime.now().subtract(const Duration(days: 30)) : (_range == 'today' ? DateTime.now() : DateTime.now().subtract(const Duration(days: 7)))))}',
                        style: const TextStyle(fontSize: 12, color: AC.text3)),
                      Text('To: ${_shortDate(_range == 'custom' ? _endDate : DateTime.now())}',
                        style: const TextStyle(fontSize: 12, color: AC.text3)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  // Stats line
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _StatPill(Icons.speed_rounded,           '${_maxSpd.round()} km/h'),
                    _StatPill(Icons.access_time_rounded,      _trips.isNotEmpty && _trips.first.startTime != null
                      ? fmtTimeOnly(_trips.first.startTime) : '—'),
                    _StatPill(Icons.directions_car_rounded,  fmtKmFull(_totalDist)),
                  ]),
                  const SizedBox(height: 14),
                  // Playback controls
                  Row(children: [
                    if (_selectedTrip != null) ...[
                      GestureDetector(
                        onTap: _clearFocus,
                        child: Container(
                          width: 44, height: 44, margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(color: AC.red.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.close_rounded, color: AC.red, size: 24))),
                    ],
                    GestureDetector(
                      onTap: _route.isNotEmpty ? _togglePlay : null,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(14)),
                        child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: _route.isNotEmpty ? AC.text1 : AC.text4, size: 24))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTapDown: (d) {
                        if (_route.isEmpty) return;
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final availW = box.size.width - 80;
                        final pct = (d.localPosition.dx / availW).clamp(0.0, 1.0);
                        setState(() {
                          _prog    = pct * 100;
                          _playIdx = (pct * (_route.length - 1)).round();
                        });
                      },
                      child: Stack(alignment: Alignment.centerLeft, children: [
                        Container(height: 4,
                          decoration: BoxDecoration(color: AC.surface3, borderRadius: BorderRadius.circular(2))),
                        FractionallySizedBox(
                          widthFactor: (_prog / 100).clamp(0.0, 1.0),
                          child: Container(height: 4,
                            decoration: BoxDecoration(color: AC.blue, borderRadius: BorderRadius.circular(2)))),
                        Positioned(
                          left: (_prog / 100).clamp(0.0, 0.98) * (MediaQuery.of(context).size.width - 120),
                          child: Container(width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: AC.surface, shape: BoxShape.circle,
                              border: Border.all(color: AC.blue, width: 2),
                              boxShadow: [BoxShadow(color: AC.blue.withOpacity(0.4), blurRadius: 4)]))),
                      ]))),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(10)),
                      child: const Text('1x', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text1))),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Distance: ', style: TextStyle(fontSize: 12, color: AC.text3)),
                    Text(fmtKmFull(_totalDist), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AC.text1)),
                    const Text('Max Speed: ', style: TextStyle(fontSize: 12, color: AC.text3)),
                    Text('${_maxSpd.round()} kph', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AC.text1)),
                  ]),
                  const SizedBox(height: 12),
                  // Travel / stop time
                  Row(children: [
                    Expanded(child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF0D2A1A), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('Travel Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AC.green)),
                          const SizedBox(width: 4),
                          Text('(Trips: ${_trips.length})', style: TextStyle(fontSize: 10, color: AC.green.withOpacity(0.6))),
                        ]),
                        const SizedBox(height: 6),
                        Container(height: 3, decoration: BoxDecoration(color: AC.green, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 6),
                        Text(fmtDuration(_totalDur),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AC.text1)),
                      ]))),
                    const SizedBox(width: 10),
                    Expanded(child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF2A0D0D), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('Stop Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AC.red)),
                          const SizedBox(width: 4),
                          Text('(Stops: ${_stops.length})', style: TextStyle(fontSize: 10, color: AC.red.withOpacity(0.6))),
                        ]),
                        const SizedBox(height: 6),
                        Container(height: 3, decoration: BoxDecoration(color: AC.red, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 6),
                        Text(fmtDuration(_stopDur),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AC.text1)),
                      ]))),
                  ]),
                ]),
              ),
            ),

            // ── Timeline ──
            const SizedBox(height: 12),
            ..._timeline.map((item) {
              if (item['type'] == 'trip') return _TripCard(trip: item['data'] as TraccarTrip, onReplay: () => _focusTrip(item['data'] as TraccarTrip));
              return _StopCard(stop: item['data'] as TraccarStop);
            }),

            if (!_loading && _timeline.isEmpty) const Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(icon: Icons.history_rounded, message: 'No trips found for this period')),
                    ],
                  ),
                );
              },
            ),
          ]),
      ),
    ]);

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AC.bg,
      appBar: AppBar(
        backgroundColor: AC.surface,
        title: Text(widget.device.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context))),
      body: body);
  }

  String _shortDate(DateTime d) =>
    '${_mon(d.month)} ${d.day.toString().padLeft(2,'0')}';
  String _mon(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

class _RBtn extends StatelessWidget {
  final String value, label, current;
  final VoidCallback onTap;
  const _RBtn(this.value, this.label, this.current, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: current == value ? AC.blue.withOpacity(0.2) : AC.surface2,
        borderRadius: BorderRadius.circular(10),
        border: current == value ? Border.all(color: AC.blue) : null),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: current == value ? AC.blue : AC.text3))));
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  const _StatPill(this.icon, this.value);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AC.text3),
    const SizedBox(width: 5),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text2)),
  ]);
}

class _TripCard extends StatelessWidget {
  final TraccarTrip trip;
  final VoidCallback onReplay;
  const _TripCard({required this.trip, required this.onReplay});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)]),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(children: [
          const Icon(Icons.route_rounded, size: 14, color: AC.text3),
          const SizedBox(width: 6),
          Text(fmtKmFull(trip.distance),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AC.text1)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AC.green.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Text('Trip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AC.green))),
          const Spacer(),
          const Icon(Icons.speed_rounded, size: 13, color: AC.green),
          const SizedBox(width: 4),
          Text('Speed 🔄 ${trip.maxSpeedKmh.round()} km/h',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.green)),
        ])),
      const Divider(height: 14, indent: 14, endIndent: 14, color: Color(0xFF1E2A40)),
      _Row(Icons.play_circle_outline_rounded, 'Start', trip.startTime != null ? fmtDateTime(trip.startTime) : 'null'),
      const Divider(height: 1, indent: 46, color: Color(0xFF1E2A40)),
      _Row(Icons.timer_outlined, 'Duration', trip.durationStr),
      const Divider(height: 1, indent: 46, color: Color(0xFF1E2A40)),
      _Row(Icons.stop_circle_outlined, 'End', trip.endTime != null ? fmtDateTime(trip.endTime) : 'null'),
      const SizedBox(height: 4),
      // Replay button
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: OutlinedButton.icon(
          onPressed: onReplay,
          icon: const Icon(Icons.play_circle_rounded, size: 16),
          label: const Text('Replay on Map', style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AC.blue, side: const BorderSide(color: AC.blue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 40)))),
    ]));

  Widget _Row(IconData ico, String lbl, String val) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(children: [
      Icon(ico, size: 16, color: AC.text4),
      const SizedBox(width: 10),
      Text('$lbl:', style: const TextStyle(fontSize: 13, color: AC.text3)),
      const Spacer(),
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text1)),
    ]));
}

class _StopCard extends StatelessWidget {
  final TraccarStop stop;
  const _StopCard({required this.stop});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)]),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AC.red.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Text('Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AC.red))),
          if (stop.address != null) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(stop.address!, style: const TextStyle(fontSize: 11, color: AC.text3),
              overflow: TextOverflow.ellipsis)),
          ],
        ])),
      const Divider(height: 14, indent: 14, endIndent: 14, color: Color(0xFF1E2A40)),
      _Row(Icons.play_circle_outline_rounded, 'Start', stop.startTime != null ? fmtDateTime(stop.startTime) : 'null'),
      const Divider(height: 1, indent: 46, color: Color(0xFF1E2A40)),
      _Row(Icons.timer_outlined, 'Duration', stop.durationStr),
      const Divider(height: 1, indent: 46, color: Color(0xFF1E2A40)),
      _Row(Icons.stop_circle_outlined, 'End', stop.endTime != null ? fmtDateTime(stop.endTime) : 'null'),
      const SizedBox(height: 8),
    ]));

  Widget _Row(IconData ico, String lbl, String val) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(children: [
      Icon(ico, size: 16, color: AC.text4),
      const SizedBox(width: 10),
      Text('$lbl:', style: const TextStyle(fontSize: 13, color: AC.text3)),
      const Spacer(),
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text1)),
    ]));
}
