// lib/widgets/shared_widgets.dart
import 'package:flutter/material.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import 'dart:math' as math;

// ── Status badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final DeviceStatus status;
  final double fontSize;
  const StatusBadge(this.status, {super.key, this.fontSize = 11});
  @override
  Widget build(BuildContext context) {
    final col = AC.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(statusLabel(status).toUpperCase(),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.5)));
  }
}

// ── Circular speedometer ──────────────────────────────────────────────────────
class Speedometer extends StatelessWidget {
  final double speedKmh;
  final double size;
  const Speedometer({super.key, required this.speedKmh, this.size = 100});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 0.78), painter: _SpeedoPainter(speedKmh));
}

class _SpeedoPainter extends CustomPainter {
  final double spd;
  _SpeedoPainter(this.spd);
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height * 0.7, r = s.width * 0.40;
    const sa = math.pi * 0.75, sw = math.pi * 1.5;
    final pct = (spd / 200).clamp(0.0, 1.0);
    final col = spd > 120 ? AC.red : spd > 80 ? AC.orange : AC.green;
    // Track
    c.drawArc(Rect.fromCircle(center: Offset(cx,cy), radius: r), sa, sw, false,
      Paint()..color = const Color(0xFF1E2A40)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    // Fill
    if (pct > 0) {
      c.drawArc(Rect.fromCircle(center: Offset(cx,cy), radius: r), sa, sw * pct, false,
      Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    }
    // Tick labels
    for (final v in [0, 50, 100, 150, 200]) {
      final a = sa + sw * (v / 200);
      final tx = cx + (r + 14) * math.cos(a), ty = cy + (r + 14) * math.sin(a);
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(text: '$v', style: const TextStyle(fontSize: 7, color: AC.text3))
        ..layout();
      tp.paint(c, Offset(tx - tp.width/2, ty - tp.height/2));
    }
    // Needle
    final na = sa + sw * pct;
    c.drawLine(Offset(cx,cy), Offset(cx + r*0.72*math.cos(na), cy + r*0.72*math.sin(na)),
      Paint()..color = col..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    c.drawCircle(Offset(cx,cy), 5, Paint()..color = AC.surface2);
    // Speed text
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(children: [
        TextSpan(text: '${spd.round()}', style: TextStyle(fontSize: s.width * 0.18, fontWeight: FontWeight.w800, color: AC.text1)),
        const TextSpan(text: '\nkm/h', style: TextStyle(fontSize: 9, color: AC.text3)),
      ], style: const TextStyle(fontFamily: 'Inter'))
      ..textAlign = TextAlign.center..layout(maxWidth: s.width);
    tp.paint(c, Offset(cx - tp.width/2, cy + 8));
  }
  @override bool shouldRepaint(_SpeedoPainter o) => o.spd != spd;
}

// ── Horizontal speed bar (like original app) ──────────────────────────────────
class SpeedBar extends StatelessWidget {
  final double speedKmh;
  final double maxKmh;
  const SpeedBar({super.key, required this.speedKmh, this.maxKmh = 200});
  @override
  Widget build(BuildContext context) {
    final pct = (speedKmh / maxKmh).clamp(0.0, 1.0);
    final col = speedKmh > 120 ? AC.red : speedKmh > 80 ? AC.orange : AC.blue;
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('${speedKmh.round()}', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: AC.text1, height: 1)),
      const Text('km/h', style: TextStyle(fontSize: 14, color: AC.text3)),
      const SizedBox(height: 12),
      Stack(children: [
        Container(height: 6, decoration: BoxDecoration(color: AC.surface3, borderRadius: BorderRadius.circular(3))),
        FractionallySizedBox(widthFactor: pct,
          child: Container(height: 6, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)))),
        Positioned(left: pct * (double.infinity == pct ? 0 : 1) - 6, top: -3,
          child: Container(width: 12, height: 12,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: col, width: 2)))),
      ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('0', style: TextStyle(fontSize: 11, color: AC.text3)),
        Text('${maxKmh.round()}', style: const TextStyle(fontSize: 11, color: AC.text3)),
      ]),
    ]);
  }
}

// ── Sensor chip ───────────────────────────────────────────────────────────────
class SChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const SChip({super.key, required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? AC.text3),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AC.text3)),
    ]),
  );
}

// ── Info tile ─────────────────────────────────────────────────────────────────
class InfoTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const InfoTile({super.key, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AC.text3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: valueColor ?? AC.text1)),
    ]),
  );
}

// ── Section header ────────────────────────────────────────────────────────────
class SecHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SecHeader(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Row(children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1)),
      const Spacer(),
      if (action != null) action!,
    ]),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 52, color: AC.text4),
      const SizedBox(height: 14),
      Text(message, style: const TextStyle(fontSize: 15, color: AC.text3, fontWeight: FontWeight.w500)),
    ]));
}

// ── Shimmer card ──────────────────────────────────────────────────────────────
class ShimmerCard extends StatefulWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 140});
  @override State<ShimmerCard> createState() => _ShimmerCardState();
}
class _ShimmerCardState extends State<ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      height: widget.height, margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: const [AC.surface2, AC.surface3, AC.surface2],
          stops: [0, _a.value, 1]),
        borderRadius: BorderRadius.circular(16))));
}

// ── Custom toggle ─────────────────────────────────────────────────────────────
class AToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AToggle({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46, height: 26,
      decoration: BoxDecoration(
        color: value ? AC.blue : AC.surface3,
        borderRadius: BorderRadius.circular(13)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 20, height: 20,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))));
}
