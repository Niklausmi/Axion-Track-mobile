// lib/utils/theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/traccar_models.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
class AC {
  // Brand
  static const blue     = Color(0xFF2196F3);
  static const blueDark = Color(0xFF1565C0);
  static const cyan     = Color(0xFF00B4D8);

  // Status
  static const moving   = Color(0xFF00C853);
  static const idle     = Color(0xFFFFAB00);
  static const stopped  = Color(0xFFFF1744);
  static const inactive = Color(0xFF90A4AE);
  static const offline  = Color(0xFF607D8B);
  static const nodata   = Color(0xFF78909C);

  // Dark surfaces
  static const bg       = Color(0xFF0A0E1A);
  static const surface  = Color(0xFF111827);
  static const surface2 = Color(0xFF1A2235);
  static const surface3 = Color(0xFF1E2A40);
  static const card     = Color(0xFF162032);

  // Text
  static const text1  = Color(0xFFFFFFFF);
  static const text2  = Color(0xFFB0BEC5);
  static const text3  = Color(0xFF607D8B);
  static const text4  = Color(0xFF37474F);

  // Misc
  static const red    = Color(0xFFFF1744);
  static const green  = Color(0xFF00C853);
  static const orange = Color(0xFFFFAB00);
  static const purple = Color(0xFF7C4DFF);

  static Color forStatus(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.moving:   return moving;
      case DeviceStatus.idle:     return idle;
      case DeviceStatus.stopped:  return stopped;
      case DeviceStatus.inactive: return inactive;
      case DeviceStatus.offline:  return offline;
      case DeviceStatus.nodata:   return nodata;
    }
  }

  static Color bgForStatus(DeviceStatus s) =>
    forStatus(s).withOpacity(0.15);
}

// ── Theme ─────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AC.bg,
    colorScheme: const ColorScheme.dark(
      primary: AC.blue, secondary: AC.cyan,
      surface: AC.surface, error: AC.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AC.surface,
      foregroundColor: AC.text1,
      elevation: 0, scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
        color: AC.text1, fontFamily: 'Inter'),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light),
    ),
    cardTheme: CardThemeData(
      color: AC.card, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF1E2A40), thickness: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AC.surface,
      selectedItemColor: AC.blue,
      unselectedItemColor: AC.text3,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AC.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AC.blue, width: 1.5)),
      hintStyle: const TextStyle(color: AC.text3, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AC.blue, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.blue : AC.text3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.blue.withOpacity(0.4) : AC.surface3),
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true, brightness: Brightness.light, fontFamily: 'Inter',
    scaffoldBackgroundColor: const Color(0xFFF4F6FA),
    colorScheme: const ColorScheme.light(primary: AC.blue, secondary: AC.cyan),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white, foregroundColor: Color(0xFF0F172A),
      elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A), fontFamily: 'Inter'),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white, selectedItemColor: AC.blue,
      unselectedItemColor: Color(0xFF94A3B8), type: BottomNavigationBarType.fixed, elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AC.blue, width: 1.5)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AC.blue, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), elevation: 0,
      ),
    ),
  );
}

// ── Formatters ────────────────────────────────────────────────────────────────
String fmtDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final l = dt.toLocal();
  final h = l.hour, ap = h >= 12 ? 'PM' : 'AM', h12 = h % 12 == 0 ? 12 : h % 12;
  return '${l.day.toString().padLeft(2,'0')}-${l.month.toString().padLeft(2,'0')}-${l.year} '
    '${h12.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}:${l.second.toString().padLeft(2,'0')} $ap';
}

String fmtTimeOnly(DateTime? dt) {
  if (dt == null) return '—';
  final l = dt.toLocal();
  final h = l.hour, ap = h >= 12 ? 'PM' : 'AM', h12 = h % 12 == 0 ? 12 : h % 12;
  return '${h12.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}:${l.second.toString().padLeft(2,'0')} $ap';
}

String timeAgo(DateTime? dt) {
  if (dt == null) return '—';
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60)  return '${d.inSeconds}s ago';
  if (d.inMinutes < 60)  return '${d.inMinutes}m ago';
  if (d.inHours < 24)    return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

String stoppedFor(DateTime? dt) {
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  return '${d.inHours} hr ${d.inMinutes % 60} min ${d.inSeconds % 60} sec';
}

String fmtDuration(int ms) {
  final s = ms ~/ 1000, h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  if (h > 0) return '${h}h ${m}min ${sec}s';
  if (m > 0) return '${m}min ${sec}s';
  return '${sec}s';
}

String fmtKm(double m) => '${(m / 1000).toStringAsFixed(1)} km';
String fmtKmFull(double m) => '${(m / 1000).toStringAsFixed(2)} km';

Map<String, dynamic> eventMeta(String type) {
  const m = {
    'deviceOverspeed':  {'icon': Icons.speed,              'color': 0xFFFF1744, 'bg': 0x22FF1744, 'label': 'Overspeed'},
    'geofenceEnter':    {'icon': Icons.login,              'color': 0xFF00C853, 'bg': 0x2200C853, 'label': 'Entered Zone'},
    'geofenceExit':     {'icon': Icons.logout,             'color': 0xFFFFAB00, 'bg': 0x22FFAB00, 'label': 'Exited Zone'},
    'geofenceStay':     {'icon': Icons.location_on,        'color': 0xFFFFAB00, 'bg': 0x22FFAB00, 'label': 'Zone Stay'},
    'ignitionOn':       {'icon': Icons.power,              'color': 0xFF00C853, 'bg': 0x2200C853, 'label': 'Ignition ON'},
    'ignitionOff':      {'icon': Icons.power_off,          'color': 0xFF607D8B, 'bg': 0x22607D8B, 'label': 'Ignition OFF'},
    'deviceOnline':     {'icon': Icons.wifi,               'color': 0xFF00C853, 'bg': 0x2200C853, 'label': 'Device Online'},
    'deviceOffline':    {'icon': Icons.wifi_off,           'color': 0xFFFF1744, 'bg': 0x22FF1744, 'label': 'Device Offline'},
    'alarm':            {'icon': Icons.warning_amber,      'color': 0xFFFF1744, 'bg': 0x22FF1744, 'label': 'Alarm'},
    'deviceStopped':    {'icon': Icons.stop_circle,        'color': 0xFFFF1744, 'bg': 0x22FF1744, 'label': 'Vehicle Stopped'},
    'deviceMoving':     {'icon': Icons.directions_car,     'color': 0xFF00C853, 'bg': 0x2200C853, 'label': 'Vehicle Moving'},
    'deviceInactive':   {'icon': Icons.bedtime,            'color': 0xFF607D8B, 'bg': 0x22607D8B, 'label': 'Inactive'},
    'driverChanged':    {'icon': Icons.person,             'color': 0xFF2196F3, 'bg': 0x222196F3, 'label': 'Driver Changed'},
    'deviceOverspeedEnd':{'icon': Icons.check_circle,      'color': 0xFF00C853, 'bg': 0x2200C853, 'label': 'Speed Normal'},
    'deviceExcessIdle': {'icon': Icons.timer_off,          'color': 0xFFFFAB00, 'bg': 0x22FFAB00, 'label': 'Excess Idle'},
  };
  return (m[type] as Map<String, dynamic>?) ??
    {'icon': Icons.info_outline, 'color': 0xFF607D8B, 'bg': 0x22607D8B,
     'label': type.replaceAllMapped(RegExp(r'([A-Z])'), (x) => ' ${x[0]}').trim()};
}
