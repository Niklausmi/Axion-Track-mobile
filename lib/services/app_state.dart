// lib/services/app_state.dart — v6 (Clean Light Mode Setup + Sticky Session Fix)
import 'dart:convert';
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
  Map<String, EventPref> eventPrefs = {};
  bool isLoading = false;
  bool wsConnected = false;
  String? error;

  String? get serverUrl => _service?.serverUrl;

  // Expose last refresh time so screens can show "updated X ago"
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
      // Trim trailing slash before storing
      final url = serverUrl.trim().replaceAll(RegExp(r'/$'), '');
      final svc = TraccarService(serverUrl: url, email: email.trim(), password: password);
      final sess = await svc.login();
      _service = svc;
      session = sess;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server', url);
      await prefs.setString('email', email.trim());
      await prefs.setString('password', password);

      await _loadEventPrefs();
      _setupWsCallbacks();
      await _loadInitialData();
      _service!.connectWebSocket();
    } catch (e) {
      // Strip verbose exception prefix
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
      final svc = TraccarService(serverUrl: server, email: email, password: pass);
      
      // Step 1: Attempt to recover session directly using stored cookies
      TraccarSession? sess;
      try {
        sess = await svc.getSession();
      } catch (_) {
        // Step 2: Fallback if the cookie session has expired on the backend server.
        // Re-authenticate explicitly using the stored credential pair.
        sess = await svc.login();
      }
      
      _service = svc;
      session  = sess;
      await _loadEventPrefs();
      _setupWsCallbacks();
      await _loadInitialData();
      _service!.connectWebSocket();
      notifyListeners();
      return true;
    } catch (_) {
      // If network is completely unreachable, fall back to manual login window gracefully
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
      for (final p in pos) {
        // Retain previous ignition state if missing in new packet
        final oldPos = positions[p.deviceId];
        if (oldPos != null && p.ignition == null && oldPos.ignition != null) {
          p.attributes['ignition'] = oldPos.ignition;
        }
        posMap[p.deviceId] = p;
      }
      positions = posMap;

      // Load today's events in parallel, don't block if fails
      if (devices.isNotEmpty) {
        final now  = DateTime.now().toUtc();
        // FIX: Enforce standard UTC floor matching backend API parsing specs
        final from = DateTime.utc(now.year, now.month, now.day, 0, 0, 0);
        try {
          final evs = await _service!.getEvents(
            from: from, to: now,
            deviceIds: devices.map((d) => d.id).toList(),
          );
          evs.sort((a, b) {
            final ta = a.serverTime ?? a.eventTime ?? DateTime(0);
            final tb = b.serverTime ?? b.eventTime ?? DateTime(0);
            return tb.compareTo(ta);
          });
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

  // ── Event Prefs ──
  Future<void> _loadEventPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? prefsJson = prefs.getString('eventPrefs');
    
    // Initialize defaults from theme
    final Map<String, dynamic> defaultMeta = {'deviceOverspeed': null, 'geofenceEnter': null, 'geofenceExit': null, 'ignitionOn': null, 'ignitionOff': null, 'deviceOnline': null, 'deviceOffline': null, 'alarm': null, 'deviceStopped': null, 'deviceMoving': null, 'deviceInactive': null, 'hardBraking': null, 'hardAcceleration': null, 'hardCornering': null, 'lowBattery': null, 'powerCut': null};
    eventPrefs = {};
    for (final key in defaultMeta.keys) {
      eventPrefs[key] = EventPref();
    }

    if (prefsJson != null) {
      try {
        final decoded = jsonDecode(prefsJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          eventPrefs[entry.key] = EventPref.fromJson(entry.value);
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setEventPref(String type, {bool? showInApp, bool? pushEnabled}) async {
    if (!eventPrefs.containsKey(type)) {
      eventPrefs[type] = EventPref();
    }
    if (showInApp != null) eventPrefs[type]!.showInApp = showInApp;
    if (pushEnabled != null) eventPrefs[type]!.pushEnabled = pushEnabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final mapped = eventPrefs.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString('eventPrefs', jsonEncode(mapped));
  }

  // ── WS callbacks ──
  void _setupWsCallbacks() {
    _service!.onDevicesUpdate = (updated) {
      final map = {for (var d in devices) d.id: d};
      for (final d in updated) {
        map[d.id] = d;
      }
      devices = map.values.toList();
      lastRefreshed = DateTime.now();
      notifyListeners();
    };
    _service!.onPositionsUpdate = (updated) {
      for (final p in updated) {
        // Retain previous ignition state if missing in new packet
        final oldPos = positions[p.deviceId];
        if (oldPos != null && p.ignition == null && oldPos.ignition != null) {
          p.attributes['ignition'] = oldPos.ignition;
        }
        positions[p.deviceId] = p;
      }
      lastRefreshed = DateTime.now();
      notifyListeners();
    };
    _service!.onEventsUpdate = (newEvents) {
      // Cap at 500, de-duplicate by id
      final existing = {for (var e in events) e.id: e};
      for (final e in newEvents) {
        existing[e.id] = e;
      }
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

  // ── Read state handlers ──
  void markRead(int eventId) {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      events[index].read = true;
      notifyListeners();
    }
  }

  void markAllRead() {
    bool changed = false;
    for (var event in events) {
      if (!event.read) {
        event.read = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
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

  int get overspeedToday =>
      events.where((e) => e.type == 'deviceOverspeed').length;
}