// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final counts = state.statusCounts;
    final total  = state.devices.length;
    final health = state.fleetHealthScore;

    return RefreshIndicator(
      onRefresh: state.refresh,
      color: AC.blue,
      backgroundColor: AC.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Greeting ──
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: const TextStyle(fontSize: 13, color: AC.text3, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('Hello, ${state.session?.name ?? "Admin"}',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AC.text1)),
            ])),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1565C0), AC.blue]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AC.blue.withOpacity(0.4), blurRadius: 12, offset: const Offset(0,4))]),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 22)),
          ]),
          const SizedBox(height: 16),

          // ── Fleet size card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF2196F3), Color(0xFF00B4D8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AC.blue.withOpacity(0.35), blurRadius: 20, offset: const Offset(0,8))]),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Fleet Size', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('$total', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text('Health ${health.round()}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                  const SizedBox(width: 8),
                  if (state.lastRefresh != null) Text(
                    'Updated ${timeAgo(state.lastRefresh)}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                ]),
              ])),
              const Icon(Icons.directions_car_rounded, size: 72, color: Colors.white24),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Live Status ──
          Row(children: [
            const Text('Live Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
            const Spacer(),
            GestureDetector(
              onTap: () => DefaultTabController.of(context).animateTo(2),
              child: const Text('See Map', style: TextStyle(fontSize: 13, color: AC.blue, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
            children: [
              _StatusTile(DeviceStatus.moving,   counts[DeviceStatus.moving]   ?? 0),
              _StatusTile(DeviceStatus.idle,     counts[DeviceStatus.idle]     ?? 0),
              _StatusTile(DeviceStatus.stopped,  counts[DeviceStatus.stopped]  ?? 0),
              _StatusTile(DeviceStatus.inactive, counts[DeviceStatus.inactive] ?? 0),
            ],
          ),
          const SizedBox(height: 20),

          // ── Today's Activity ──
          const Row(children: [
            Text("Today's Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
            Spacer(),
            Text('See All', style: TextStyle(fontSize: 13, color: AC.blue, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              _ActivityStat('Alerts', '${state.events.length}', AC.text1),
              _divider(),
              _ActivityStat('Overspeed', '${state.overspeedToday}', state.overspeedToday > 0 ? AC.red : AC.text1),
              _divider(),
              _ActivityStat('7 Days', '${_sevenDayTrips(state)}', AC.blue),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Quick stats row ──
          Row(children: [
            _QuickStat(Icons.directions_car_rounded, 'Online', '${counts[DeviceStatus.moving] ?? 0}/$total', AC.green),
            const SizedBox(width: 10),
            _QuickStat(Icons.notifications_rounded, 'Unread Alerts', '${state.unreadEvents}', AC.orange),
            const SizedBox(width: 10),
            _QuickStat(Icons.shield_rounded, 'Geofences', '${state.geofences.length}', AC.purple),
          ]),
          const SizedBox(height: 20),

          // ── Offline vehicles ──
          if ((counts[DeviceStatus.offline] ?? 0) > 0) ...[
            const Text('Offline Vehicles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
            const SizedBox(height: 12),
            ...state.devices.where((d) => state.statusFor(d) == DeviceStatus.offline).take(3).map((d) => _OfflineCard(d, state)),
            const SizedBox(height: 8),
          ],

          // ── WS status ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: state.wsConnected ? AC.green : AC.text3, shape: BoxShape.circle,
                boxShadow: state.wsConnected ? [BoxShadow(color: AC.green.withOpacity(0.5), blurRadius: 6)] : null)),
              const SizedBox(width: 10),
              Text(state.wsConnected ? 'Live updates active' : 'Connecting…',
                style: TextStyle(fontSize: 12, color: state.wsConnected ? AC.green : AC.text3, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(state.serverUrl ?? '', style: const TextStyle(fontSize: 11, color: AC.text3),
                overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  int _sevenDayTrips(AppState s) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return s.events.where((e) => e.type == 'deviceMoving' && (e.serverTime?.isAfter(cutoff) ?? false)).length;
  }

  Widget _divider() => Container(width: 1, height: 36, color: AC.surface2, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _StatusTile extends StatelessWidget {
  final DeviceStatus status;
  final int count;
  const _StatusTile(this.status, this.count);
  @override
  Widget build(BuildContext context) {
    final col = AC.forStatus(status);
    final icons = {
      DeviceStatus.moving:   Icons.navigation_rounded,
      DeviceStatus.idle:     Icons.timer_outlined,
      DeviceStatus.stopped:  Icons.stop_circle_outlined,
      DeviceStatus.inactive: Icons.power_settings_new_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icons[status] ?? Icons.circle, color: col, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: col, height: 1)),
          Text(statusLabel(status), style: const TextStyle(fontSize: 12, color: AC.text3, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _ActivityStat(this.label, this.value, this.valueColor);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: const TextStyle(fontSize: 12, color: AC.text3)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: valueColor)),
  ]));
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _QuickStat(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AC.text3, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    ]),
  ));
}

class _OfflineCard extends StatelessWidget {
  final TraccarDevice device;
  final AppState state;
  const _OfflineCard(this.device, this.state);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(width: 8, decoration: BoxDecoration(color: AC.offline, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 12),
      const Icon(Icons.directions_car_rounded, color: AC.offline, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AC.text1)),
        Text(device.lastUpdate != null ? 'Last seen ${timeAgo(device.lastUpdate)}' : 'Never connected',
          style: const TextStyle(fontSize: 11, color: AC.text3)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: AC.text4),
    ]),
  );
}
