// lib/services/app_state.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/traccar_models.dart';
import 'traccar_service.dart';

enum ThemeMode2 { auto, light, dark }

class NotifPref {
  bool push;
  bool email;
  NotifPref({this.push = true, this.email = false});
}

class AppState extends ChangeNotifier {
  TraccarService? _svc;
  TraccarSession? session;
  List<TraccarDevice>   devices    = [];
  Map<int,TraccarPosition> positions = {};
  List<TraccarEvent>    events     = [];
  List<TraccarGeofence> geofences  = [];
  List<TraccarGroup>    groups     = [];
  bool isLoading  = false;
  bool wsConnected= false;
  String? error;
  DateTime? lastRefresh;

  // Settings
  ThemeMode2 themeMode = ThemeMode2.dark;
  Map<String, NotifPref> notifPrefs = {
    'Overspeed': NotifPref(push: true),
    'Idle':      NotifPref(push: true),
    'Geofence':  NotifPref(push: true),
    'Ignition':  NotifPref(push: false),
    'Offline':   NotifPref(push: true),
  };

  bool get isLoggedIn => session != null && _svc != null;
  TraccarService? get svc => _svc;
  String? get serverUrl => _svc?.serverUrl;

  // ── Computed ──────────────────────────────────────────────────────────────
  TraccarPosition? posFor(int id) => positions[id];
  DeviceStatus statusFor(TraccarDevice d) => computeStatus(d, posFor(d.id));

  Map<DeviceStatus, int> get statusCounts {
    final c = <DeviceStatus, int>{};
    for (final d in devices) { final s = statusFor(d); c[s] = (c[s] ?? 0) + 1; }
    return c;
  }

  int get unreadEvents  => events.where((e) => !e.read).length;
  int get criticalEvents=> events.where((e) => ['alarm','deviceOffline','deviceOverspeed'].contains(e.type)).length;
  int get overspeedToday=> events.where((e) => e.type == 'deviceOverspeed').length;

  double get fleetHealthScore {
    if (devices.isEmpty) return 100;
    final online = devices.where((d) => d.status == 'online').length;
    final noAlerts = criticalEvents == 0 ? 1.0 : (1.0 - (criticalEvents / devices.length).clamp(0.0, 1.0));
    return ((online / devices.length) * 70 + noAlerts * 30).clamp(0, 100);
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> login({required String serverUrl, required String email, required String password}) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final svc  = TraccarService(serverUrl: serverUrl, email: email, password: password);
      final sess = await svc.login();
      _svc = svc; session = sess;
      final p = await SharedPreferences.getInstance();
      await p.setString('sv', serverUrl); await p.setString('em', email); await p.setString('pw', password);
      _setupWS(); await _loadAll(); _svc!.connectWS();
    } catch (e) { error = e.toString().replaceAll('Exception: ', ''); }
    isLoading = false; notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final p = await SharedPreferences.getInstance();
    final sv = p.getString('sv'), em = p.getString('em'), pw = p.getString('pw');
    if (sv == null || em == null || pw == null) return false;
    try {
      final svc  = TraccarService(serverUrl: sv, email: em, password: pw);
      final sess = await svc.getSession();
      _svc = svc; session = sess;
      _setupWS(); await _loadAll(); _svc!.connectWS();
      notifyListeners(); return true;
    } catch (_) { return false; }
  }

  Future<void> logout() async {
    try { await _svc?.logout(); } catch (_) {}
    _svc?.dispose(); _svc = null; session = null;
    devices = []; positions = {}; events = []; geofences = []; groups = [];
    wsConnected = false;
    final p = await SharedPreferences.getInstance(); await p.clear();
    notifyListeners();
  }

  Future<void> _loadAll() async {
    isLoading = true; notifyListeners();
    try {
      final results = await Future.wait([
        _svc!.getDevices(), _svc!.getPositions(),
        _svc!.getGeofences().catchError((_) => <TraccarGeofence>[]),
        _svc!.getGroups().catchError((_) => <TraccarGroup>[]),
      ]);
      devices   = results[0] as List<TraccarDevice>;
      final pm  = <int, TraccarPosition>{};
      for (final pos in results[1] as List<TraccarPosition>) {
        pm[pos.deviceId] = pos;
      }
      positions = pm;
      geofences = results[2] as List<TraccarGeofence>;
      groups    = results[3] as List<TraccarGroup>;
      lastRefresh = DateTime.now();
      // Load today's events
      if (devices.isNotEmpty) {
        final now = DateTime.now(), from = DateTime(now.year, now.month, now.day);
        final evs = await _svc!.getEvents(from: from, to: now, ids: devices.map((d) => d.id).toList());
        events = evs;
      }
    } catch (e) { error = e.toString(); }
    isLoading = false; notifyListeners();
  }

  Future<void> refresh() => _loadAll();

  void markAllRead() {
    for (final e in events) {
      e.read = true;
    }
    notifyListeners();
  }

  void markRead(int eventId) {
    final e = events.where((e) => e.id == eventId).firstOrNull;
    if (e != null) { e.read = true; notifyListeners(); }
  }

  void setTheme(ThemeMode2 t) { themeMode = t; notifyListeners(); }

  void setNotifPref(String key, {bool? push, bool? email}) {
    final p = notifPrefs[key];
    if (p == null) return;
    if (push  != null) p.push  = push;
    if (email != null) p.email = email;
    notifyListeners();
  }

  void _setupWS() {
    _svc!.onDevices = (updated) {
      final m = {for (var d in devices) d.id: d};
      for (final d in updated) {
        m[d.id] = d;
      }
      devices = m.values.toList();
      notifyListeners();
    };
    _svc!.onPositions = (updated) {
      for (final p in updated) {
        positions[p.deviceId] = p;
      }
      notifyListeners();
    };
    _svc!.onEvents = (newEvs) {
      events = [...newEvs, ...events].take(1000).toList();
      notifyListeners();
    };
    _svc!.onWsChange = (c) { wsConnected = c; notifyListeners(); };
  }
}
