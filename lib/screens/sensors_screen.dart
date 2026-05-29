// lib/screens/sensors_screen.dart  — v2 (auto-refresh every 10s)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class SensorsScreen extends StatefulWidget {
  final TraccarDevice device;
  const SensorsScreen({super.key, required this.device});
  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      context.read<AppState>().refresh();
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pos   = state.posFor(widget.device.id);
    final attrs = pos?.attributes ?? {};

    final known = <_SensorDef>[
      _SensorDef('ignition',      'Ignition',        Icons.power_settings_new_rounded,    const Color(0xFFECFDF5), const Color(0xFF059669), (v) => v == true ? 'ON' : 'OFF'),
      _SensorDef('charge',        'Charging',        Icons.battery_charging_full_rounded, const Color(0xFFECFDF5), const Color(0xFF059669), (v) => v == true ? 'Yes' : 'No'),
      _SensorDef('blocked',       'Immobilizer',     Icons.shield_rounded,                const Color(0xFFFEF2F2), const Color(0xFFDC2626), (v) => v == true ? 'Blocked' : 'Active'),
      _SensorDef('motion',        'Motion',          Icons.directions_run_rounded,        const Color(0xFFEFF6FF), const Color(0xFF2563EB), (v) => v == true ? 'Moving' : 'Still'),
      _SensorDef('power',         'External Voltage', Icons.electric_bolt_rounded,        const Color(0xFFFFFBEB), const Color(0xFFD97706), (v) => '${(v as num).toStringAsFixed(2)} V'),
      _SensorDef('battery',       'Battery Voltage', Icons.battery_4_bar_rounded,         const Color(0xFFECFDF5), const Color(0xFF059669), (v) => '${(v as num).toStringAsFixed(2)} V'),
      _SensorDef('batteryLevel',  'Battery Level',   Icons.battery_4_bar_rounded,         const Color(0xFFECFDF5), const Color(0xFF059669), (v) => '${(v as num).round()} %'),
      _SensorDef('sat',           'GPS Satellites',  Icons.satellite_alt_rounded,         const Color(0xFFF5F3FF), const Color(0xFF7C3AED), (v) => '$v'),
      _SensorDef('rssi',          'Network Signal',  Icons.signal_cellular_alt_rounded,   const Color(0xFFEFF6FF), const Color(0xFF2563EB), (v) => '${(v as num).round()} %'),
      _SensorDef('odometer',      'Odometer',        Icons.speed_rounded,                 const Color(0xFFF3F4F6), const Color(0xFF6B7280), (v) => '${((v as num) / 1000).toStringAsFixed(0)} km'),
      _SensorDef('totalDistance', 'Total Distance',  Icons.route_rounded,                 const Color(0xFFEFF6FF), const Color(0xFF2563EB), (v) => '${((v as num) / 1000).toStringAsFixed(2)} km'),
      _SensorDef('distance',      'Trip Distance',   Icons.straighten_rounded,            const Color(0xFFF3F4F6), const Color(0xFF6B7280), (v) => '${((v as num) / 1000).toStringAsFixed(2)} km'),
      _SensorDef('hours',         'Engine Hours',    Icons.timer_rounded,                 const Color(0xFFEFF6FF), const Color(0xFF2563EB), (v) => '${(v as num).toStringAsFixed(1)} h'),
      _SensorDef('fuel',          'Fuel Level',      Icons.local_gas_station_rounded,     const Color(0xFFFFFBEB), const Color(0xFFD97706), (v) => '${(v as num).round()} %'),
      _SensorDef('rpm',           'RPM',             Icons.settings_rounded,              const Color(0xFFF3F4F6), const Color(0xFF6B7280), (v) => '$v'),
      _SensorDef('temp1',         'Temperature',     Icons.thermostat_rounded,            const Color(0xFFFEF2F2), const Color(0xFFDC2626), (v) => '$v °C'),
      _SensorDef('result',        'Command Result',  Icons.info_outline_rounded,          const Color(0xFFF3F4F6), const Color(0xFF6B7280), (v) => '$v'),
    ];

    final knownKeys = {for (final d in known) d.key};
    final present   = known.where((d) => attrs.containsKey(d.key)).toList();
    final extra     = attrs.entries
        .where((e) => !knownKeys.contains(e.key))
        .map((e) => _SensorDef(e.key,
              e.key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}').trim(),
              Icons.sensors_rounded, const Color(0xFFF3F4F6), const Color(0xFF6B7280), (v) => '$v'))
        .toList();
    final allSensors = [...present, ...extra];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.text1)),
            ),
            const Expanded(child: Text('Vehicle Sensors', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text1))),
            GestureDetector(
              onTap: () => context.read<AppState>().refresh(),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary)),
            ),
          ]),
        ),

        // Last updated
        LastUpdatedBar(lastRefreshed: state.lastRefreshed),

        Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
          // Device name + status
          Row(children: [
            Expanded(child: Text(widget.device.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary))),
            StatusBadge(state.statusFor(widget.device)),
          ]),
          const SizedBox(height: 2),
          Text(widget.device.uniqueId,
            style: const TextStyle(fontSize: 12, color: AppColors.text4, letterSpacing: 0.3)),
          const SizedBox(height: 14),

          // Quick stats grid
          if (pos != null) GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              StatTile(label: 'Speed',    value: '${pos.speedKmh.round()} km/h', icon: Icons.speed_rounded,       color: AppColors.primary),
              StatTile(label: 'Course',   value: '${pos.course.round()}°',       icon: Icons.navigation_rounded,  color: AppColors.orange),
              StatTile(label: 'Altitude', value: '${pos.altitude.round()} m',    icon: Icons.terrain_rounded,     color: AppColors.purple),
              StatTile(label: 'GPS Valid',value: pos.valid ? 'Yes' : 'No',       icon: Icons.gps_fixed_rounded,   color: pos.valid ? AppColors.green : AppColors.red),
            ],
          ),
          const SizedBox(height: 14),

          // Last update
          if (pos != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Row(children: [
              const Icon(Icons.access_time_rounded, size: 15, color: AppColors.text4),
              const SizedBox(width: 8),
              Text('Last update: ${fmtDateTime(pos.serverTime ?? pos.fixTime)}',
                style: const TextStyle(fontSize: 12, color: AppColors.text3, fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(height: 12),

          // Sensors card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: allSensors.isEmpty
              ? const Padding(padding: EdgeInsets.all(32),
                  child: EmptyState(icon: Icons.sensors_off_rounded, message: 'No sensor data available'))
              : Column(children: [
                  for (int i = 0; i < allSensors.length; i++) ...[
                    _SensorRow(def: allSensors[i], value: attrs[allSensors[i].key]),
                    if (i < allSensors.length - 1)
                      const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                  ],
                ]),
          ),
          const SizedBox(height: 24),
        ])),
      ])),
    );
  }
}

class _SensorDef {
  final String key, label;
  final IconData icon;
  final Color bg, color;
  final String Function(dynamic) format;
  const _SensorDef(this.key, this.label, this.icon, this.bg, this.color, this.format);
}

class _SensorRow extends StatelessWidget {
  final _SensorDef def;
  final dynamic value;
  const _SensorRow({super.key, required this.def, required this.value});
  @override
  Widget build(BuildContext context) {
    String formatted;
    try { formatted = def.format(value); } catch (_) { formatted = '$value'; }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: def.bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(def.icon, color: def.color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(def.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1))),
        Flexible(child: Text(formatted, textAlign: TextAlign.right,
          style: TextStyle(fontSize: 14, color: def.color, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
