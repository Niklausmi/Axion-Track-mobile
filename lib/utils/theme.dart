// lib/utils/theme.dart — v3
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/traccar_models.dart';

class AppColors {
  // Core
  static const primary     = Color(0xFF1A73E8);
  static const primaryDark = Color(0xFF1558B0);
  static const accent      = Color(0xFF0EA5E9);
  static const surface     = Color(0xFFFFFFFF);
  static const background  = Color(0xFFF4F6FA);
  static const card        = Color(0xFFFFFFFF);

  // Status
  static const running = Color(0xFF16A34A);
  static const stopped = Color(0xFFDC2626);
  static const idle    = Color(0xFFD97706);
  static const offline = Color(0xFF64748B);
  static const nodata  = Color(0xFF94A3B8);
  static const expired = Color(0xFF7C3AED);

  // Text
  static const text1 = Color(0xFF0F172A);
  static const text2 = Color(0xFF1E293B);
  static const text3 = Color(0xFF475569);
  static const text4 = Color(0xFF94A3B8);

  // Utility
  static const green  = Color(0xFF16A34A);
  static const red    = Color(0xFFDC2626);
  static const orange = Color(0xFFD97706);
  static const blue   = Color(0xFF1A73E8);
  static const purple = Color(0xFF7C3AED);
  static const teal   = Color(0xFF0891B2);
  static const divider = Color(0xFFE8EDF4);

  static Color forStatus(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.running: return running;
      case DeviceStatus.stopped: return stopped;
      case DeviceStatus.idle:    return idle;
      case DeviceStatus.offline: return offline;
      case DeviceStatus.nodata:  return nodata;
      case DeviceStatus.expired: return expired;
    }
  }

  static Color bgForStatus(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.running: return const Color(0xFFDCFCE7);
      case DeviceStatus.stopped: return const Color(0xFFFEE2E2);
      case DeviceStatus.idle:    return const Color(0xFFFEF3C7);
      case DeviceStatus.offline: return const Color(0xFFF1F5F9);
      case DeviceStatus.nodata:  return const Color(0xFFF8FAFC);
      case DeviceStatus.expired: return const Color(0xFFF5F3FF);
    }
  }
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text1,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800,
        color: AppColors.text1, fontFamily: 'Inter',
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        elevation: 0,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
    }),
  );
}

// ── Formatters ──────────────────────────────────────────────────────────────
String fmtDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final l = dt.toLocal();
  final d  = l.day.toString().padLeft(2,'0');
  final mo = l.month.toString().padLeft(2,'0');
  final h  = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final mi = l.minute.toString().padLeft(2,'0');
  final s  = l.second.toString().padLeft(2,'0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${l.year}/$mo/$d ${h.toString().padLeft(2,'0')}:$mi:$s $ap';
}

String fmtDateShort(DateTime? dt) {
  if (dt == null) return '—';
  final l = dt.toLocal();
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${l.day} ${months[l.month-1]} ${l.year}';
}

String fmtTimeOnly(DateTime? dt) {
  if (dt == null) return '—';
  final l = dt.toLocal();
  final h  = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final mi = l.minute.toString().padLeft(2,'0');
  final s  = l.second.toString().padLeft(2,'0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${h.toString().padLeft(2,'0')}:$mi:$s $ap';
}

String timeAgo(DateTime? dt) {
  if (dt == null) return '—';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
  if (diff.inHours < 24)    return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String stoppedFor(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  final s = diff.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String fmtDuration(int ms) {
  final s   = ms ~/ 1000;
  final h   = s ~/ 3600;
  final min = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0)   return '${h}h ${min}m ${sec}s';
  if (min > 0) return '${min}m ${sec}s';
  return '${sec}s';
}

String fmtKm(double meters) => '${(meters / 1000).toStringAsFixed(1)} km';

Map<String, dynamic> eventMeta(String type) {
  const map = {
    'deviceOverspeed':  {'icon': Icons.speed,                  'color': 0xFFD97706, 'bg': 0xFFFEF3C7, 'label': 'Overspeed'},
    'geofenceEnter':    {'icon': Icons.location_on,            'color': 0xFF7C3AED, 'bg': 0xFFF5F3FF, 'label': 'Zone Entry'},
    'geofenceExit':     {'icon': Icons.logout,                 'color': 0xFF7C3AED, 'bg': 0xFFF5F3FF, 'label': 'Zone Exit'},
    'ignitionOn':       {'icon': Icons.vpn_key_rounded,        'color': 0xFF16A34A, 'bg': 0xFFDCFCE7, 'label': 'Engine ON'},
    'ignitionOff':      {'icon': Icons.vpn_key_off_rounded,    'color': 0xFF64748B, 'bg': 0xFFF1F5F9, 'label': 'Engine OFF'},
    'deviceOnline':     {'icon': Icons.wifi,                   'color': 0xFF16A34A, 'bg': 0xFFDCFCE7, 'label': 'Online'},
    'deviceOffline':    {'icon': Icons.wifi_off,               'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'label': 'Offline'},
    'alarm':            {'icon': Icons.warning_amber_rounded,  'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'label': 'Alarm'},
    'deviceStopped':    {'icon': Icons.stop_circle_outlined,   'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'label': 'Vehicle Stopped'},
    'deviceMoving':     {'icon': Icons.directions_car_rounded, 'color': 0xFF1A73E8, 'bg': 0xFFDBEAFE, 'label': 'Vehicle Moving'},
    'deviceInactive':   {'icon': Icons.bedtime_rounded,        'color': 0xFF64748B, 'bg': 0xFFF1F5F9, 'label': 'Inactive'},
    'hardBraking':      {'icon': Icons.pan_tool_rounded,       'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'label': 'Hard Braking'},
    'hardAcceleration': {'icon': Icons.flash_on_rounded,       'color': 0xFFD97706, 'bg': 0xFFFEF3C7, 'label': 'Hard Acceleration'},
    'hardCornering':    {'icon': Icons.rotate_right_rounded,   'color': 0xFFD97706, 'bg': 0xFFFEF3C7, 'label': 'Hard Cornering'},
    'lowBattery':       {'icon': Icons.battery_alert_rounded,  'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'label': 'Low Battery'},
    'powerCut':         {'icon': Icons.power_off_rounded,      'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'label': 'Power Cut'},
  };
  return map[type] ?? {'icon': Icons.notifications_rounded, 'color': 0xFFD97706, 'bg': 0xFFFEF3C7, 'label': type};
}
