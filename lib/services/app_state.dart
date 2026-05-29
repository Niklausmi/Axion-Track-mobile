// lib/services/app_state.dart  — v2
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/traccar_models.dart';
import 'traccar_service.dart';

class AppState extends ChangeNotifier {
  TraccarService? _service;
  TraccarSession? session;
  List<TraccarDevice> devices = [];
  Map<int, TraccarPosition> positions = {};
  List<TraccarEvent> events = [];
  bool isLoading = false;
  bool wsConnected = false;
  String? error;

  // FIX: expose last refresh time so screens can show "updated X ago"
  DateTime? lastRefreshed;

  bool get isLoggedIn => session != null && _service != null;
  TraccarService? get service => _service;

  // ── Login ──
  Future<void> login({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      // FIX: trim trailing slash before storing
      final url = serverUrl.trim().replaceAll(RegExp(r'/$'), '');
      final svc = TraccarService(serverUrl: url, email: email.trim(), password: password);
      final sess = await svc.login();
      _service = svc;
      session = sess;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server', url);
      await prefs.setString('email', email.trim());
      await prefs.setString('password', password);

      _setupWsCallbacks();
      await _loadInitialData();
      _service!.connectWebSocket();
    } catch (e) {
      // FIX: strip verbose exception prefix
      error = e.toString().replaceAll('Exception: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  // ── Auto-login ──
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('server');
    final email  = prefs.getString('email');
    final pass   = prefs.getString('password');
    if (server == null || email == null || pass == null) return false;
    try {
      final svc  = TraccarService(serverUrl: server, email: email, password: pass);
      final sess = await svc.getSession();
      _service = svc;
      session  = sess;
      _setupWsCallbacks();
      await _loadInitialData();
      _service!.connectWebSocket();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Logout ──
  Future<void> logout() async {
    try { await _service?.logout(); } catch (_) {}
    _service?.dispose();
    _service = null;
    session = null;
    devices = [];
    positions = {};
    events = [];
    wsConnected = false;
    lastRefreshed = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // ── Load data ──
  Future<void> _loadInitialData() async {
    if (_service == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service!.getDevices(),
        _service!.getPositions(),
      ]);
      devices = results[0] as List<TraccarDevice>;
      final pos = results[1] as List<TraccarPosition>;
      final posMap = <int, TraccarPosition>{};
      for (final p in pos) posMap[p.deviceId] = p;
      positions = posMap;

      // FIX: load today's events in parallel, don't block if fails
      if (devices.isNotEmpty) {
        final now  = DateTime.now();
        final from = DateTime(now.year, now.month, now.day);
        try {
          final evs = await _service!.getEvents(
            from: from, to: now,
            deviceIds: devices.map((d) => d.id).toList(),
          );
          events = evs;
        } catch (_) {}
      }
      lastRefreshed = DateTime.now();
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _loadInitialData();

  // ── WS callbacks ──
  void _setupWsCallbacks() {
    _service!.onDevicesUpdate = (updated) {
      final map = {for (var d in devices) d.id: d};
      for (final d in updated) map[d.id] = d;
      devices = map.values.toList();
      lastRefreshed = DateTime.now();
      notifyListeners();
    };
    _service!.onPositionsUpdate = (updated) {
      for (final p in updated) positions[p.deviceId] = p;
      lastRefreshed = DateTime.now();
      notifyListeners();
    };
    _service!.onEventsUpdate = (newEvents) {
      // FIX: cap at 500, de-duplicate by id
      final existing = {for (var e in events) e.id: e};
      for (final e in newEvents) existing[e.id] = e;
      final list = existing.values.toList()
        ..sort((a, b) {
          final ta = a.serverTime ?? DateTime(0);
          final tb = b.serverTime ?? DateTime(0);
          return tb.compareTo(ta);
        });
      events = list.take(500).toList();
      notifyListeners();
    };
    _service!.onWsConnectionChange = (connected) {
      wsConnected = connected;
      notifyListeners();
    };
  }

  // ── Computed helpers ──
  TraccarPosition? posFor(int deviceId) => positions[deviceId];

  DeviceStatus statusFor(TraccarDevice d) => computeStatus(d, posFor(d.id));

  Map<DeviceStatus, int> get statusCounts {
    final counts = <DeviceStatus, int>{};
    for (final d in devices) {
      final s = statusFor(d);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  int get criticalEventCount =>
      events.where((e) => ['alarm', 'deviceOffline'].contains(e.type)).length;
}
