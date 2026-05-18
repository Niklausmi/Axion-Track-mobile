// lib/screens/vehicle_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import 'history_screen.dart';
import 'sensors_screen.dart';
import 'live_tracking_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final TraccarDevice device;
  const VehicleDetailScreen({super.key, required this.device});
  @override State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final pos    = state.posFor(widget.device.id);
    final status = state.statusFor(widget.device);
    final col    = AC.forStatus(status);

    return Scaffold(
      backgroundColor: AC.bg,
      appBar: AppBar(
        backgroundColor: AC.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: Text(widget.device.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AC.blue,
          indicatorWeight: 3,
          labelColor: AC.blue,
          unselectedLabelColor: AC.text3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Dashboard'), Tab(text: 'Trips'),
            Tab(text: 'Alerts'),    Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _DashTab(device: widget.device, pos: pos, status: status, col: col),
        HistoryScreen(device: widget.device, embedded: true),
        _AlertsTab(device: widget.device),
        _ReportsTab(device: widget.device),
      ]),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────
class _DashTab extends StatefulWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final Color col;
  const _DashTab({required this.device, required this.pos, required this.status, required this.col});

  @override
  State<_DashTab> createState() => _DashTabState();
}

class _DashTabState extends State<_DashTab> {
  double? _todayDist;

  @override
  void initState() {
    super.initState();
    _fetchDist();
  }

  void _fetchDist() async {
    final svc = context.read<AppState>().svc;
    if (svc != null) {
      final d = await svc.getDailyDistance(deviceId: widget.device.id);
      if (mounted) setState(() => _todayDist = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spd  = widget.pos?.speedKmh ?? 0.0;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      // Live Telemetry card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Text('Live Telemetry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.text3)),
          const SizedBox(height: 16),
          SpeedBar(speedKmh: spd),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LiveTrackingScreen(device: widget.device))),
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Live Track Vehicle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
          ),
          const SizedBox(height: 12),
          Text(_todayDist != null ? "Today's Distance: ${_todayDist!.toStringAsFixed(1)} km" : "Today's Distance: Loading...",
            style: const TextStyle(fontSize: 13, color: AC.text3)),
        ]),
      ),
      const SizedBox(height: 12),

      // Status card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _Row('Status', statusLabel(widget.status), valueColor: widget.col),
          const Divider(color: AC.surface2, height: 16),
          _Row('Vehicle', widget.device.model ?? widget.device.uniqueId),
          const Divider(color: AC.surface2, height: 16),
          if (widget.pos != null) InkWell(
            onTap: () {},
            child: Row(children: [
              const Icon(Icons.location_on_rounded, color: AC.blue, size: 16),
              const SizedBox(width: 8),
              const Text('Last Known Location', style: TextStyle(color: AC.blue, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text(widget.pos!.address ?? '${widget.pos!.latitude.toStringAsFixed(6)}, ${widget.pos!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: AC.text3), overflow: TextOverflow.ellipsis),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new_rounded, color: AC.blue, size: 14),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Sensor chips
      if (widget.pos != null) ...[
        const Text("Today's Stats", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
          children: [
            InfoTile(label: 'Dist', value: _todayDist != null ? '${_todayDist!.toStringAsFixed(1)}km' : '—'),
            InfoTile(label: 'Max', value: '${widget.pos!.attributes['maxSpeed'] != null ? ((widget.pos!.attributes['maxSpeed'] as num) * 3.6).round() : 0} km/h'),
            const InfoTile(label: 'Avg', value: '—'),
            if (widget.pos!.fuel != null) InfoTile(label: 'Fuel', value: '${widget.pos!.fuel!.round()}%',
              valueColor: widget.pos!.fuel! < 25 ? AC.red : widget.pos!.fuel! < 50 ? AC.orange : AC.green),
            if (widget.pos!.batteryLevel != null) InfoTile(label: 'Battery', value: '${widget.pos!.batteryLevel!.round()}%'),
            if (widget.pos!.satellites != null) InfoTile(label: 'GPS Sats', value: '${widget.pos!.satellites}'),
          ],
        ),
        const SizedBox(height: 12),

        // Sensor chips row
        Wrap(spacing: 6, runSpacing: 6, children: [
          SChip(icon: Icons.power_settings_new_rounded,
            label: widget.pos!.ignition == true ? 'Ignition ON' : 'Ignition OFF',
            color: widget.pos!.ignition == true ? AC.green : AC.text3),
          SChip(icon: Icons.electric_bolt_rounded,
            label: widget.pos!.charging == true ? 'Charging' : 'Not Charging',
            color: widget.pos!.charging == true ? AC.green : AC.text3),
          SChip(icon: Icons.shield_rounded,
            label: widget.pos!.blocked == true ? 'Immobilized' : 'Active',
            color: widget.pos!.blocked == true ? AC.red : AC.text3),
          if (widget.pos!.rssi != null) SChip(icon: Icons.signal_cellular_alt_rounded, label: '${widget.pos!.rssi}% Signal'),
          if (widget.pos!.satellites != null) SChip(icon: Icons.satellite_alt_rounded, label: '${widget.pos!.satellites} Sats'),
        ]),
        const SizedBox(height: 16),
      ],

      // Action buttons
      Row(children: [
        Expanded(child: _ActionBtn(Icons.sensors_rounded, 'Sensors', AC.purple, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => SensorsScreen(device: widget.device))))),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(Icons.shield_rounded, 'Immobilizer',
          widget.pos?.blocked == true ? AC.green : AC.red,
          () => _sendCommand(context, widget.pos?.blocked == true ? 'engineResume' : 'engineStop'))),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(Icons.location_searching_rounded, 'Get Location', AC.blue,
          () => _sendCommand(context, 'positionSingle'))),
      ]),
    ]);
  }

  void _sendCommand(BuildContext ctx, String type) async {
    final state = ctx.read<AppState>();
    try {
      await state.svc!.sendCommand(deviceId: widget.device.id, type: type);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Command "$type" sent'), backgroundColor: AC.green));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AC.red));
      }
    }
  }

  Widget _Row(String label, String value, {Color? valueColor}) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 13, color: AC.text3)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? AC.text1)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Alerts Tab ────────────────────────────────────────────────────────────────
class _AlertsTab extends StatelessWidget {
  final TraccarDevice device;
  const _AlertsTab({required this.device});
  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final events = state.events.where((e) => e.deviceId == device.id).toList();
    if (events.isEmpty) return const EmptyState(icon: Icons.notifications_none_rounded, message: 'No alerts for this vehicle');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: events.length,
      itemBuilder: (_, i) => _AlertCard(event: events[i]));
  }
}

class _AlertCard extends StatelessWidget {
  final TraccarEvent event;
  const _AlertCard({required this.event});
  @override
  Widget build(BuildContext context) {
    final m   = eventMeta(event.type);
    final col = Color(m['color'] as int);
    final bg  = Color(m['bg']    as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AC.surface, borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: col, width: 4))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(m['icon'] as IconData, color: col, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m['label'] as String,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text1)),
            const SizedBox(height: 2),
            if (event.geofenceId != null) Text('Geofence #${event.geofenceId}',
              style: const TextStyle(fontSize: 11, color: AC.text3)),
            Text(event.serverTime != null
              ? '${(m['label'] as String)} at location' : '—',
              style: const TextStyle(fontSize: 11, color: AC.text3)),
            if (event.serverTime != null) Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 11, color: AC.text3),
                const SizedBox(width: 3),
                Text(event.attributes['address'] as String? ?? '—',
                  style: const TextStyle(fontSize: 11, color: AC.text3), overflow: TextOverflow.ellipsis),
              ])),
          ])),
          Text(event.serverTime != null ? _shortFmt(event.serverTime!) : '—',
            style: const TextStyle(fontSize: 11, color: AC.text3)),
        ]),
      ),
    );
  }

  String _shortFmt(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour, ap = h >= 12 ? 'PM' : 'AM', h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')} $ap';
  }
}

// ── Reports Tab ───────────────────────────────────────────────────────────────
class _ReportsTab extends StatefulWidget {
  final TraccarDevice device;
  const _ReportsTab({required this.device});
  @override State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to   = DateTime.now();
  String _range  = '7days';

  void _setRange(String r) {
    setState(() {
      _range = r;
      final now = DateTime.now();
      if (r == 'yesterday') { _from = now.subtract(const Duration(days: 1)); _to = now; }
      else if (r == '7days')  { _from = now.subtract(const Duration(days: 7));  _to = now; }
      else if (r == 'today')  { _from = DateTime(now.year, now.month, now.day); _to = now; }
      else if (r == 'month')  { _from = now.subtract(const Duration(days: 30)); _to = now; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = [
      ('Vehicle Master',  Icons.directions_car_rounded,  const Color(0xFF7C4DFF)),
      ('Fleet Summary',   Icons.bar_chart_rounded,        const Color(0xFF2196F3)),
      ('Daily Summary',   Icons.calendar_today_rounded,   const Color(0xFF00BCD4)),
      ('Trip Report',     Icons.route_rounded,            const Color(0xFF4CAF50)),
      ('Overspeed Report',Icons.speed_rounded,            const Color(0xFFFF5722)),
      ('Idle Report',     Icons.timer_off_rounded,        const Color(0xFFFFAB00)),
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      // Date range
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REPORT DATE RANGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.text3, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Row(children: [
            _RangeBtn('today',     'Today',    _range),
            const SizedBox(width: 6),
            _RangeBtn('yesterday', 'Yesterday', _range),
            const SizedBox(width: 6),
            _RangeBtn('7days',     'Last 7 Days', _range),
            const SizedBox(width: 6),
            _RangeBtn('month',     '30 Days',  _range),
          ].map((w) => w is _RangeBtn ? GestureDetector(onTap: () => _setRange(w.value), child: w) : w).toList()),
          const SizedBox(height: 12),
          Row(children: [
            _DateBox('START DATE', _from),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded, color: AC.text3, size: 18)),
            _DateBox('END DATE', _to),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('Functional Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.2,
        children: reports.map((r) => _ReportTile(label: r.$1, icon: r.$2, color: r.$3)).toList()),
    ]);
  }

  Widget _DateBox(String label, DateTime dt) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 9, color: AC.text3, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Icon(Icons.remove_circle_outline_rounded, color: AC.blue, size: 18),
        Text('${_mon(dt.month)} ${dt.day.toString().padLeft(2,'0')}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text1)),
        const Icon(Icons.add_circle_outline_rounded, color: AC.blue, size: 18),
      ])),
  ]));

  String _mon(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

class _RangeBtn extends StatelessWidget {
  final String value, label, current;
  const _RangeBtn(this.value, this.label, this.current);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: current == value ? AC.blue.withOpacity(0.2) : AC.surface2,
      borderRadius: BorderRadius.circular(8),
      border: current == value ? Border.all(color: AC.blue) : null),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: current == value ? AC.blue : AC.text3)));
}

class _ReportTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _ReportTile({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 26)),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.text1), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      const Text('View Report', style: TextStyle(fontSize: 11, color: AC.blue, fontWeight: FontWeight.w600)),
    ]),
  );
}
