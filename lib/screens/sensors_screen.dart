// lib/screens/sensors_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class SensorsScreen extends StatelessWidget {
  final TraccarDevice device;
  const SensorsScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pos   = state.posFor(device.id);
    final attrs = pos?.attributes ?? {};
    final status = state.statusFor(device);

    final defs = <_SDef>[
      _SDef('charge',       'Charging',        Icons.battery_charging_full_rounded, const Color(0xFF0D2A1A), AC.green,   (v) => v == true ? 'On' : 'Off'),
      _SDef('hours',        'Engine Hours',    Icons.timer_rounded,                 const Color(0xFF0D1A2A), AC.blue,    (v) => '${(v as num).toStringAsFixed(2)} h'),
      _SDef('power',        'External Volts',  Icons.electric_bolt_rounded,         const Color(0xFF2A1A0D), AC.orange,  (v) => '${(v as num).toStringAsFixed(1)} V'),
      _SDef('sat',          'GPS Satellites',  Icons.satellite_alt_rounded,         const Color(0xFF1A0D2A), AC.purple,  (v) => '$v'),
      _SDef('ignition',     'Ignition',        Icons.power_settings_new_rounded,    const Color(0xFF0D2A1A), AC.green,   (v) => v == true ? 'On' : 'Off'),
      _SDef('blocked',      'Immobilizer',     Icons.shield_rounded,                const Color(0xFF2A0D0D), AC.red,     (v) => v == true ? 'On' : 'Off'),
      _SDef('rssi',         'Network Signal',  Icons.signal_cellular_alt_rounded,   const Color(0xFF0D1A2A), AC.blue,    (v) => '${(v as num).round()} %'),
      _SDef('odometer',     'Odometer',        Icons.speed_rounded,                 const Color(0xFF1A1A1A), AC.text2,   (v) => '${((v as num) / 1000).toStringAsFixed(0)} KMs'),
      _SDef('result',       'Result',          Icons.info_outline_rounded,          const Color(0xFF1A1A1A), AC.text2,   (v) => '$v'),
      _SDef('battery',      'Battery',         Icons.battery_4_bar_rounded,         const Color(0xFF0D2A1A), AC.green,   (v) => '${(v as num).round()} %'),
      _SDef('batteryLevel', 'Battery Level',   Icons.battery_4_bar_rounded,         const Color(0xFF0D2A1A), AC.green,   (v) => '${(v as num).round()} %'),
      _SDef('fuel',         'Fuel Level',      Icons.local_gas_station_rounded,     const Color(0xFF2A1A0D), AC.orange,  (v) => '${(v as num).round()} %'),
      _SDef('motion',       'Motion',          Icons.directions_run_rounded,        const Color(0xFF0D1A2A), AC.blue,    (v) => v == true ? 'Yes' : 'No'),
      _SDef('rpm',          'RPM',             Icons.settings_rounded,              const Color(0xFF1A1A1A), AC.text2,   (v) => '$v'),
      _SDef('temp1',        'Temperature',     Icons.thermostat_rounded,            const Color(0xFF2A0D0D), AC.red,     (v) => '$v °C'),
      _SDef('distance',     'Distance',        Icons.straighten_rounded,            const Color(0xFF1A1A1A), AC.text2,   (v) => fmtKm(v as double)),
      _SDef('totalDistance','Total Distance',  Icons.route_rounded,                 const Color(0xFF0D1A2A), AC.blue,    (v) => fmtKmFull(v as double)),
    ];

    final knownKeys = {for (final d in defs) d.key};
    final present   = defs.where((d) => attrs.containsKey(d.key)).toList();
    final extra     = attrs.entries
      .where((e) => !knownKeys.contains(e.key))
      .map((e) => _SDef(e.key,
        e.key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}').trim(),
        Icons.sensors_rounded, const Color(0xFF1A1A1A), AC.text2, (v) => '$v'))
      .toList();
    final all = [...present, ...extra];

    return Scaffold(
      backgroundColor: AC.bg,
      appBar: AppBar(
        backgroundColor: AC.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Vehicle Sensors')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        // Device header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(device.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AC.blue)),
            const SizedBox(height: 3),
            Text(device.model ?? device.uniqueId,
              style: const TextStyle(fontSize: 12, color: AC.text4, letterSpacing: 0.3)),
          ])),
          StatusBadge(status),
        ]),
        const SizedBox(height: 12),

        // Last update
        if (pos != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.access_time_rounded, size: 14, color: AC.text3),
            const SizedBox(width: 8),
            Text('Last updated: ${fmtDateTime(pos.serverTime ?? pos.fixTime)}',
              style: const TextStyle(fontSize: 12, color: AC.text3, fontWeight: FontWeight.w500)),
          ])),
        const SizedBox(height: 12),

        // Quick stats grid
        if (pos != null) GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
          children: [
            _QStat('Speed',    '${pos.speedKmh.round()} km/h', Icons.speed_rounded,         AC.blue),
            _QStat('Heading',  '${pos.course.round()}°',       Icons.navigation_rounded,    AC.orange),
            _QStat('Altitude', '${pos.altitude.round()} m',    Icons.terrain_rounded,       AC.purple),
            _QStat('GPS Valid',pos.valid ? 'Yes' : 'No',       Icons.gps_fixed_rounded,     pos.valid ? AC.green : AC.red),
          ]),
        const SizedBox(height: 12),

        // All sensors card
        Container(
          decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
          child: all.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: EmptyState(icon: Icons.sensors_off_rounded, message: 'No sensor data available'))
            : Column(children: [
                for (int i = 0; i < all.length; i++) ...[
                  _SRow(def: all[i], value: attrs[all[i].key]),
                  if (i < all.length - 1)
                    const Divider(height: 1, indent: 64, color: Color(0xFF1A2235)),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _SDef {
  final String key, label;
  final IconData icon;
  final Color bg, color;
  final String Function(dynamic) fmt;
  const _SDef(this.key, this.label, this.icon, this.bg, this.color, this.fmt);
}

class _SRow extends StatelessWidget {
  final _SDef def;
  final dynamic value;
  const _SRow({required this.def, required this.value});
  @override
  Widget build(BuildContext context) {
    String fmted;
    try { fmted = def.fmt(value); } catch (_) { fmted = '$value'; }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: def.bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(def.icon, color: def.color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(def.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AC.text1))),
        Flexible(child: Text(fmted,
          style: const TextStyle(fontSize: 14, color: AC.text2, fontWeight: FontWeight.w500),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ]));
  }
}

class _QStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _QStat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ])),
    ]));
}
