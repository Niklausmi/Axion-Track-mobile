// lib/screens/dashboard_screen.dart — v3
// Matches: Hello Admin, Total Fleet Size card, Live Status 2x2 grid, Today's Activity
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import 'secondary_screens.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final sess   = state.session;
    final counts = state.statusCounts;
    final total  = state.devices.length;
    final moving = counts[DeviceStatus.running] ?? 0;
    final idle   = counts[DeviceStatus.idle]    ?? 0;
    final stopped= counts[DeviceStatus.stopped] ?? 0;
    final inactive= (counts[DeviceStatus.offline] ?? 0) + (counts[DeviceStatus.nodata] ?? 0);
    final overspeed = state.events.where((e) => e.type == 'deviceOverspeed').length;
    final alerts7d  = state.events.length;

    // Day name
    final now = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dayStr = '${days[now.weekday-1]}, ${months[now.month-1]} ${now.day}';

    return RefreshIndicator(
      onRefresh: state.refresh,
      color: AppColors.primary,
      child: CustomScrollView(slivers: [
        // ── App bar ──
        SliverToBoxAdapter(child: Container(
          color: AppColors.surface,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayStr, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
              const SizedBox(height: 2),
              Text('Hello, ${sess?.name ?? "Admin"}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text1)),
            ])),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
              ),
            ),
          ]),
        )),

        // ── Fleet size card ──
        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A73E8), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Fleet Size',
                style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('$total',
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
              const SizedBox(height: 4),
              Text('${state.wsConnected ? "● Live" : "○ Connecting"}',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
            ])),
            Icon(Icons.directions_car_rounded,
              size: 80, color: Colors.white.withOpacity(0.2)),
          ]),
        )),

        // ── Live Status ──
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Row(children: [
            const Text('Live Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                // Switch to map tab
                final nav = context.findAncestorStateOfType<State>();
              },
              child: const Text('See Map',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ]),
        )),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              _StatusCard(count: moving,   label: 'Moving',   icon: Icons.navigation_rounded,    color: AppColors.primary, bg: const Color(0xFFDBEAFE)),
              _StatusCard(count: idle,     label: 'Idle',     icon: Icons.hourglass_empty_rounded,color: AppColors.orange,  bg: const Color(0xFFFEF3C7)),
              _StatusCard(count: stopped,  label: 'Stopped',  icon: Icons.stop_circle_rounded,   color: AppColors.red,     bg: const Color(0xFFFEE2E2)),
              _StatusCard(count: inactive, label: 'Inactive', icon: Icons.power_settings_new_rounded, color: AppColors.offline, bg: const Color(0xFFF1F5F9)),
            ],
          ),
        )),

        // ── Today's Activity ──
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Row(children: [
            const Text("Today's Activity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const Spacer(),
            const Text('See All',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
        )),

        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Expanded(child: _ActivityStat(label: 'Alerts',    value: '$alerts7d', color: AppColors.text1)),
            Container(width: 1, height: 40, color: AppColors.divider),
            Expanded(child: _ActivityStat(label: 'Overspeed', value: '$overspeed', color: AppColors.red)),
            Container(width: 1, height: 40, color: AppColors.divider),
            Expanded(child: _ActivityStat(label: '7 Days',    value: '${(total * 243)}', color: AppColors.primary)),
          ]),
        )),

        // ── Recent Alerts ──
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(children: [
            const Text('Recent Alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const Spacer(),
            const Text('See All',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
        )),

        SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
          if (i >= state.events.take(5).length) return null;
          final e = state.events[i];
          final dev = state.devices.firstWhere((d) => d.id == e.deviceId,
            orElse: () => TraccarDevice(id: 0, name: 'Unknown', uniqueId: '', status: '', attributes: {}));
          final meta = eventMeta(e.type);
          final col  = Color(meta['color'] as int);
          final bg   = Color(meta['bg'] as int);
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(meta['icon'] as IconData, color: col, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta['label'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
                Text(dev.name, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
              ])),
              Text(timeAgo(e.serverTime),
                style: const TextStyle(fontSize: 11, color: AppColors.text4)),
            ]),
          );
        }, childCount: state.events.take(5).length)),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color, bg;
  const _StatusCard({required this.count, required this.label, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      const SizedBox(width: 14),
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22)),
      const SizedBox(width: 12),
      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color, height: 1.1)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text3, fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

class _ActivityStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ActivityStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
  ]);
}
