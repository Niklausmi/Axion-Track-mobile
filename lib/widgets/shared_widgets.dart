// lib/widgets/shared_widgets.dart  — v2
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';

// ── Pulsing Dot ────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulseDot({required this.color, required this.pulse});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) return Container(width: 7, height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    return ScaleTransition(scale: _scale,
      child: Container(width: 7, height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)])));
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final DeviceStatus status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final col = AppColors.forStatus(status);
    final bg  = AppColors.bgForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _PulseDot(color: col, pulse: status == DeviceStatus.running),
        const SizedBox(width: 5),
        Text(statusLabel(status),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
      ]),
    );
  }
}

// ── Sensor Chip ────────────────────────────────────────────────────────────
class SensorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const SensorChip({super.key, required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: (color ?? AppColors.text3).withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? AppColors.text3),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AppColors.text3)),
    ]),
  );
}

// ── Section Header ─────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.text3, letterSpacing: 0.6)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
  );
}

// ── Last Updated Bar ───────────────────────────────────────────────────────
class LastUpdatedBar extends StatefulWidget {
  final DateTime? lastRefreshed;
  const LastUpdatedBar({super.key, this.lastRefreshed});
  @override
  State<LastUpdatedBar> createState() => _LastUpdatedBarState();
}
class _LastUpdatedBarState extends State<LastUpdatedBar> {
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _timer.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: AppColors.background,
    child: Row(children: [
      const Icon(Icons.sync_rounded, size: 12, color: AppColors.text4),
      const SizedBox(width: 5),
      Text(
        widget.lastRefreshed != null ? 'Updated ${timeAgo(widget.lastRefreshed)}' : 'Connecting…',
        style: const TextStyle(fontSize: 11, color: AppColors.text4),
      ),
    ]),
  );
}

// ── Vehicle Card ───────────────────────────────────────────────────────────
class VehicleCard extends StatelessWidget {
  final TraccarDevice device;
  final TraccarPosition? pos;
  final DeviceStatus status;
  final VoidCallback onTap;
  const VehicleCard({super.key, required this.device, required this.pos, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = AppColors.forStatus(status);
    final bg  = AppColors.bgForStatus(status);
    final spd = pos?.speedKmh.round() ?? 0;
    final stLabel = status == DeviceStatus.stopped && pos?.serverTime != null
        ? 'Stopped ${stoppedFor(pos!.serverTime)}'
        : statusLabel(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(child: Text(device.name,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: col),
                overflow: TextOverflow.ellipsis)),
              StatusBadge(status),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 72, height: 64,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.directions_car_rounded, size: 38, color: col)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row(Icons.bolt_rounded, 'Speed: ', '$spd km/h'),
                const SizedBox(height: 4),
                _statusRow(stLabel, col),
                const SizedBox(height: 4),
                _row(Icons.access_time_rounded, '',
                  pos?.serverTime != null ? fmtDateTime(pos!.serverTime)
                  : device.lastUpdate != null ? fmtDateTime(device.lastUpdate) : '—', small: true),
              ])),
            ]),
          ),
          if (pos != null) Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              SensorChip(icon: Icons.power_settings_new_rounded,
                label: pos!.ignition == true ? 'IGN On' : 'IGN Off',
                color: pos!.ignition == true ? AppColors.green : null),
              if (pos!.rssi != null)
                SensorChip(icon: Icons.signal_cellular_alt, label: '${pos!.rssi}%',
                  color: (pos!.rssi ?? 0) < 30 ? AppColors.red : null),
              SensorChip(icon: Icons.shield_rounded,
                label: pos!.blocked == true ? 'Blocked' : 'Active',
                color: pos!.blocked == true ? AppColors.red : AppColors.green),
              if (pos!.satellites != null)
                SensorChip(icon: Icons.satellite_alt, label: '${pos!.satellites} sat'),
              if (pos!.fuel != null)
                SensorChip(icon: Icons.local_gas_station, label: '${pos!.fuel!.round()}%',
                  color: (pos!.fuel ?? 100) < 20 ? AppColors.red : null),
              if (pos!.batteryLevel != null)
                SensorChip(icon: Icons.battery_4_bar_rounded, label: '${pos!.batteryLevel!.round()}%'),
            ]),
          ),
          if (pos?.address != null || pos?.latitude != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.text3),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  pos!.address ?? '${pos!.latitude.toStringAsFixed(5)}, ${pos!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.text3, height: 1.4),
                )),
              ]),
            )
          else const SizedBox(height: 14),
        ]),
      ),
    );
  }

  Widget _row(IconData ico, String label, String val, {bool small = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(ico, size: 14, color: AppColors.text3),
      const SizedBox(width: 6),
      Flexible(child: Text.rich(TextSpan(children: [
        if (label.isNotEmpty) TextSpan(text: label, style: TextStyle(fontSize: small ? 11 : 13, color: AppColors.text3)),
        TextSpan(text: val, style: TextStyle(fontSize: small ? 11 : 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
      ]), overflow: TextOverflow.ellipsis)),
    ],
  );

  Widget _statusRow(String label, Color col) => Row(children: [
    Icon(Icons.circle, size: 9, color: col),
    const SizedBox(width: 6),
    Flexible(child: Text.rich(TextSpan(children: [
      const TextSpan(text: 'Status: ', style: TextStyle(fontSize: 13, color: AppColors.text3)),
      TextSpan(text: label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col)),
    ]), overflow: TextOverflow.ellipsis)),
  ]);
}

// ── Event Card ─────────────────────────────────────────────────────────────
class EventCard extends StatelessWidget {
  final TraccarEvent event;
  final String deviceName;
  const EventCard({super.key, required this.event, required this.deviceName});
  @override
  Widget build(BuildContext context) {
    final meta = eventMeta(event.type);
    final col  = Color(meta['color'] as int);
    final bg   = Color(meta['bg']    as int);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(meta['icon'] as IconData, color: col, size: 21)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const SizedBox(height: 2),
          Text(meta['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
        ])),
        Text(event.serverTime != null ? timeAgo(event.serverTime) : '—',
          style: const TextStyle(fontSize: 10, color: AppColors.text4)),
      ]),
    );
  }
}

// ── Animated Speedometer ───────────────────────────────────────────────────
class Speedometer extends StatefulWidget {
  final double speedKmh;
  final double size;
  const Speedometer({super.key, required this.speedKmh, this.size = 100});
  @override
  State<Speedometer> createState() => _SpeedometerState();
}
class _SpeedometerState extends State<Speedometer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: widget.speedKmh).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }
  @override
  void didUpdateWidget(Speedometer old) {
    super.didUpdateWidget(old);
    if ((widget.speedKmh - old.speedKmh).abs() > 0.5) {
      _anim = Tween<double>(begin: _anim.value, end: widget.speedKmh).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl.forward(from: 0);
    }
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => CustomPaint(
      size: Size(widget.size, widget.size * 0.75),
      painter: _SpeedoPainter(_anim.value),
    ),
  );
}
class _SpeedoPainter extends CustomPainter {
  final double speed;
  _SpeedoPainter(this.speed);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height * 0.72;
    final r  = size.width * 0.38;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), startAngle, sweepAngle, false,
      Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
    final pct = (speed / 140).clamp(0.0, 1.0);
    final arcColor = speed > 100 ? const Color(0xFFEF4444) : speed > 60 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), startAngle, sweepAngle * pct, false,
      Paint()..color = arcColor..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [0, 40, 80, 120]) {
      final angle = startAngle + sweepAngle * (v / 140);
      final tx = cx + (r + 13) * math.cos(angle);
      final ty = cy + (r + 13) * math.sin(angle);
      labelPaint..text = TextSpan(text: '$v', style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)))..layout();
      labelPaint.paint(canvas, Offset(tx - labelPaint.width / 2, ty - labelPaint.height / 2));
    }
    final needleAngle = startAngle + sweepAngle * pct;
    canvas.drawLine(Offset(cx, cy),
      Offset(cx + r * 0.75 * math.cos(needleAngle), cy + r * 0.75 * math.sin(needleAngle)),
      Paint()..color = const Color(0xFFEF4444)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = const Color(0xFF1E293B));
    final sp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(text: '${speed.round()} km/h',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))
      ..layout();
    sp.paint(canvas, Offset(cx - sp.width / 2, cy + 10));
  }
  @override
  bool shouldRepaint(_SpeedoPainter old) => old.speed != speed;
}

// ── Shimmer Card ───────────────────────────────────────────────────────────
class ShimmerCard extends StatefulWidget {
  const ShimmerCard({super.key});
  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}
class _ShimmerCardState extends State<ShimmerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value, 0),
          colors: const [Color(0xFFE9EDF2), Color(0xFFF5F7FA), Color(0xFFE9EDF2)],
        ),
      ),
    ),
  );
}

// ── Empty State ────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 56, color: AppColors.text4),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(fontSize: 15, color: AppColors.text3)),
    ]),
  );
}

// ── Stat Tile ──────────────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ])),
    ]),
  );
}
