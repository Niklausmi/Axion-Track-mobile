// lib/screens/status_screen.dart  — v2 (animated list + live counter)
import 'dart:async';
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

class _StatusScreenState extends State<StatusScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DeviceStatus? _filter;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _showMenu(BuildContext ctx, TraccarDevice device) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ActionSheet(
        device: device,
        onTrack:   () { Navigator.pop(ctx); Navigator.push(ctx, _slide(LiveTrackingScreen(device: device))); },
        onHistory: () { Navigator.pop(ctx); Navigator.push(ctx, _slide(HistoryScreen(device: device))); },
        onSensors: () { Navigator.pop(ctx); Navigator.push(ctx, _slide(SensorsScreen(device: device))); },
      ),
    );
  }

  Route _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<AppState>();
    final counts = state.statusCounts;
    final total  = state.devices.length;

    final filtered = state.devices.where((d) {
      final s = state.statusFor(d);
      if (_filter != null && s != _filter) return false;
      if (_query.isNotEmpty &&
          !d.name.toLowerCase().contains(_query.toLowerCase()) &&
          !d.uniqueId.contains(_query)) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: state.refresh,
      color: AppColors.primary,
      child: CustomScrollView(slivers: [
        // ── Status summary bar ──
        SliverToBoxAdapter(child: _SummaryBar(counts: counts, total: total)),

        // ── Filter pills + search ──
        SliverToBoxAdapter(child: Container(
          color: AppColors.surface,
          child: Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(children: [
                _Pill(label: 'All', count: total, color: const Color(0xFF334155),
                  bg: const Color(0xFFF1F5F9), selected: _filter == null,
                  onTap: () => setState(() => _filter = null)),
                _statusPill(DeviceStatus.running, counts, 'Running'),
                _statusPill(DeviceStatus.stopped, counts, 'Stopped'),
                _statusPill(DeviceStatus.idle,    counts, 'Idle'),
                _statusPill(DeviceStatus.offline, counts, 'Offline'),
                _statusPill(DeviceStatus.nodata,  counts, 'No Data'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by vehicle name or IMEI…',
                  prefixIcon: const Icon(Icons.search, color: AppColors.text4, size: 20),
                  suffixIcon: _query.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.text4),
                    onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                  ) : null,
                ),
              ),
            ),
          ]),
        )),

        // ── Last updated bar ──
        SliverToBoxAdapter(child: LastUpdatedBar(lastRefreshed: state.lastRefreshed)),

        // ── Loading skeletons ──
        if (state.isLoading && state.devices.isEmpty)
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => const ShimmerCard(), childCount: 5)),

        // ── Empty ──
        if (!state.isLoading && filtered.isEmpty) const SliverFillRemaining(
          child: EmptyState(icon: Icons.directions_car_outlined, message: 'No vehicles found')),

        // ── Animated vehicle cards ──
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final d = filtered[i];
              final p = state.posFor(d.id);
              final s = state.statusFor(d);
              return _AnimatedCard(
                key: ValueKey(d.id),
                index: i,
                child: VehicleCard(
                  device: d, pos: p, status: s,
                  onTap: () => _showMenu(ctx, d),
                ),
              );
            },
            childCount: filtered.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }

  Widget _statusPill(DeviceStatus s, Map<DeviceStatus, int> counts, String label) =>
    _Pill(
      label: label,
      count: counts[s] ?? 0,
      color: AppColors.forStatus(s),
      bg: AppColors.bgForStatus(s),
      selected: _filter == s,
      onTap: () => setState(() => _filter = _filter == s ? null : s),
    );
}

// ── Summary bar ─────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final Map<DeviceStatus, int> counts;
  final int total;
  const _SummaryBar({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final running = counts[DeviceStatus.running] ?? 0;
    final stopped = counts[DeviceStatus.stopped] ?? 0;
    final offline = counts[DeviceStatus.offline] ?? 0;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        _SumStat(value: '$total',    label: 'Total',   color: AppColors.primary),
        _divider(),
        _SumStat(value: '$running',  label: 'Running', color: AppColors.green),
        _divider(),
        _SumStat(value: '$stopped',  label: 'Stopped', color: AppColors.red),
        _divider(),
        _SumStat(value: '$offline',  label: 'Offline', color: AppColors.offline),
      ]),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: const Color(0xFFF1F5F9),
    margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _SumStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _SumStat({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.text3)),
  ]));
}

// ── Animated card staggered entry ──────────────────────────────────────────
class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({super.key, required this.index, required this.child});
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}
class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Filter pill ────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.count, required this.color,
    required this.bg, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? bg : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: selected ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? color : AppColors.text3)),
        const SizedBox(width: 5),
        Text('($count)', style: TextStyle(fontSize: 11, color: selected ? color : AppColors.text4)),
      ]),
    ),
  );
}

// ── Action sheet ───────────────────────────────────────────────────────────
class _ActionSheet extends StatelessWidget {
  final TraccarDevice device;
  final VoidCallback onTrack, onHistory, onSensors;
  const _ActionSheet({required this.device, required this.onTrack, required this.onHistory, required this.onSensors});

  @override
  Widget build(BuildContext context) {
    final state  = context.read<AppState>();
    final status = state.statusFor(device);
    final col    = AppColors.forStatus(status);
    final pos    = state.posFor(device.id);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(
              color: AppColors.bgForStatus(status), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.directions_car_rounded, color: col, size: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(device.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
              Text(device.uniqueId, style: const TextStyle(fontSize: 11, color: AppColors.text4)),
              if (pos?.address != null)
                Text(pos!.address!, style: const TextStyle(fontSize: 11, color: AppColors.text3),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            StatusBadge(status),
          ]),
        ),
        const Divider(height: 20, color: AppColors.background),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            _Action(ico: Icons.map_outlined,     bg: const Color(0xFFEFF6FF), label: 'Live Track',  onTap: onTrack),
            _Action(ico: Icons.history,           bg: const Color(0xFFECFDF5), label: 'History',     onTap: onHistory),
            _Action(ico: Icons.sensors,           bg: const Color(0xFFF5F3FF), label: 'Sensors',     onTap: onSensors),
            _Action(ico: Icons.bar_chart_rounded, bg: const Color(0xFFFFF7ED), label: 'Reports',     onTap: () => Navigator.pop(context)),
            _Action(ico: Icons.shield_outlined,   bg: const Color(0xFFFEF2F2), label: 'Immobilizer', onTap: () => Navigator.pop(context)),
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
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Icon(ico, color: AppColors.text2, size: 24)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text2),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}
