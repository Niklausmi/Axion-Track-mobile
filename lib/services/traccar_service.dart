// lib/services/traccar_service.dart — v4 (Extended Network Timeout Engine)
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/traccar_models.dart';

class TraccarService {
  final String serverUrl;
  final String email;
  final String password;
  late final String _authHeader;
  late final String _baseUrl;

  // ── FIX: Maintain a single client session engine to persist cookies natively ──
  final http.Client _client = http.Client();

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  Timer? _wsReconnectTimer;
  Timer? _pollTimer;               // Polling fallback when WS is down
  int _wsRetries = 0;
  bool _disposed = false;

  // Callbacks for live updates
  Function(List<TraccarDevice>)? onDevicesUpdate;
  Function(List<TraccarPosition>)? onPositionsUpdate;
  Function(List<TraccarEvent>)? onEventsUpdate;
  Function(bool)? onWsConnectionChange;

  TraccarService({
    required this.serverUrl,
    required this.email,
    required this.password,
  }) {
    _baseUrl = '${serverUrl.replaceAll(RegExp(r'/$'), '')}/api';
    _authHeader = 'Basic ${base64Encode(utf8.encode('$email:$password'))}';
  }

  // Fallback authorization payload if server drops cookie context caches
  Map<String, String> get _headers => {
    'Authorization': _authHeader,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ── REFACTOR: All requests route through the persistent shared _client ──
  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body, bool form = false}) async {
    final uri = Uri.parse('$_baseUrl$path');
    http.Response res;
    final headers = Map<String, String>.from(_headers);
    if (form) headers['Content-Type'] = 'application/x-www-form-urlencoded';

    try {
      switch (method) {
        case 'GET':
          // ── FIX: Increased timeout from 20s to 60s to support heavy tracking queries ──
          res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 60));
          break;
        case 'POST':
          final b = form && body != null
              ? body.map((k, v) => MapEntry(k, v.toString()))
              : null;
          // ── FIX: Increased timeout from 20s to 60s to support heavy tracking queries ──
          res = await _client.post(
            uri,
            headers: headers,
            body: form ? b : (body != null ? json.encode(body) : null),
          ).timeout(const Duration(seconds: 60));
          break;
        case 'DELETE':
          // ── FIX: Increased timeout from 20s to 60s to support heavy tracking queries ──
          res = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 60));
          break;
        default:
          throw Exception('Unsupported method: $method');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. The server is taking too long to compile logs.');
    } on Exception catch (e) {
      throw Exception('Network error: $e');
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      if (res.body.isEmpty) return null;
      return json.decode(res.body);
    }
    if (res.statusCode == 204) return null;
    if (res.statusCode == 401) throw Exception('Invalid credentials');
    if (res.statusCode == 404) throw Exception('Server not found. Check URL.');
    throw Exception('Server error ${res.statusCode}: ${res.body}');
  }

  // ── Auth ──
  Future<TraccarSession> login() async {
    final data = await _request('POST', '/session',
        body: {'email': email, 'password': password}, form: true);
    return TraccarSession.fromJson(data);
  }

  Future<TraccarSession> getSession() async {
    final data = await _request('GET', '/session');
    return TraccarSession.fromJson(data);
  }

  Future<void> logout() async => _request('DELETE', '/session');

  Future<bool> updateNotificationToken(int userId, String token) async {
    try {
      final userRes = await _request('GET', '/users/$userId');
      if (userRes != null) {
        final Map<String, dynamic> user = Map<String, dynamic>.from(userRes);
        final attributes = Map<String, dynamic>.from(user['attributes'] ?? {});
        // Traccar commonly expects the token in attributes.notificationTokens
        attributes['notificationTokens'] = token;
        user['attributes'] = attributes;
        
        await _request('PUT', '/users/$userId', body: user);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Data ──
  Future<List<TraccarDevice>> getDevices() async {
    final data = await _request('GET', '/devices');
    return (data as List).map((e) => TraccarDevice.fromJson(e)).toList();
  }

  Future<List<TraccarPosition>> getPositions({int? id}) async {
    final path = id != null ? '/positions?id=$id' : '/positions';
    final data = await _request('GET', path);
    return (data as List).map((e) => TraccarPosition.fromJson(e)).toList();
  }

  Future<List<TraccarGeofence>> getGeofences() async {
    final data = await _request('GET', '/geofences');
    return (data as List).map((e) => TraccarGeofence.fromJson(e)).toList();
  }

  Future<List<TraccarEvent>> getEvents({
    required DateTime from,
    required DateTime to,
    required List<int> deviceIds,
  }) async {
    if (deviceIds.isEmpty) return [];
    final params = StringBuffer('/reports/events?')
      ..write('from=${Uri.encodeComponent(from.toUtc().toIso8601String())}')
      ..write('&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
    for (final id in deviceIds) {
      params.write('&deviceId=$id');
    }
    try {
      final data = await _request('GET', params.toString());
      if (data == null) return [];
      return (data as List).map((e) => TraccarEvent.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TraccarTrip>> getTrips({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final path = '/reports/trips?deviceId=$deviceId'
        '&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}'
        '&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}';
    final data = await _request('GET', path);
    if (data == null) return [];
    return (data as List).map((e) => TraccarTrip.fromJson(e)).toList();
  }

  Future<List<TraccarStop>> getStops({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final path = '/reports/stops?deviceId=$deviceId'
        '&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}'
        '&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}';
    try {
      final data = await _request('GET', path);
      if (data == null) return [];
      return (data as List).map((e) => TraccarStop.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TraccarPosition>> getRoute({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final path = '/reports/route?deviceId=$deviceId'
        '&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}'
        '&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}';
    try {
      final data = await _request('GET', path);
      if (data == null) return [];
      return (data as List).map((e) => TraccarPosition.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> sendCommand({
    required int deviceId,
    required String type,
    Map<String, dynamic>? attributes,
  }) async {
    final body = <String, dynamic>{
      'deviceId': deviceId,
      'type': type,
      'attributes': attributes ?? {},
    };
    try {
      final data = await _request('POST', '/commands/send', body: body);
      return data as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<List<String>> getCommandTypes(int deviceId) async {
    try {
      final data = await _request('GET', '/commands/types?deviceId=$deviceId');
      if (data == null) return [];
      return (data as List).map((e) => e['type'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  // ── WebSocket ──
  void connectWebSocket() {
    if (_disposed) return;
    _wsReconnectTimer?.cancel();
    try {
      final wsUrl = '${serverUrl.replaceAll(RegExp(r'/$'), '').replaceFirst(RegExp(r'^https'), 'wss').replaceFirst(RegExp(r'^http'), 'ws')}/api/socket';
      
      // OPTIMIZATION: Explicitly hook into JSON serialization protocols on proxy handshakes
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['json'],
      );
      _wsRetries = 0;

      _wsSub = _wsChannel!.stream.listen(
        (data) {
          if (_disposed) return;
          try {
            final msg = json.decode(data.toString());
            if (msg['devices'] != null) {
              final devices = (msg['devices'] as List).map((e) => TraccarDevice.fromJson(e)).toList();
              onDevicesUpdate?.call(devices);
            }
            if (msg['positions'] != null) {
              final positions = (msg['positions'] as List).map((e) => TraccarPosition.fromJson(e)).toList();
              onPositionsUpdate?.call(positions);
              onWsConnectionChange?.call(true);
            }
            if (msg['events'] != null) {
              final events = (msg['events'] as List).map((e) => TraccarEvent.fromJson(e)).toList();
              onEventsUpdate?.call(events);
            }
          } catch (_) {}
        },
        onError: (_) {
          onWsConnectionChange?.call(false);
          _startPolling(); 
          _scheduleReconnect();
        },
        onDone: () {
          onWsConnectionChange?.call(false);
          _startPolling();
          _scheduleReconnect();
        },
      );
      onWsConnectionChange?.call(true);
    } catch (_) {
      onWsConnectionChange?.call(false);
      _startPolling();
      _scheduleReconnect();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async { // 30s not 15s — halves mobile data/battery drain
      if (_disposed) return;
      try {
        final devs = await getDevices();
        final pos  = await getPositions();
        if (devs.isNotEmpty) onDevicesUpdate?.call(devs);
        if (pos.isNotEmpty)  onPositionsUpdate?.call(pos);
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _wsRetries++;
    final delay = Duration(seconds: (_wsRetries * 3).clamp(3, 60));
    _wsReconnectTimer = Timer(delay, () {
      _stopPolling(); 
      connectWebSocket();
    });
  }

  // ── FIX: Clean up the persistent client session along with timers to avoid memory leak ports ──
  void dispose() {
    _disposed = true;
    _wsReconnectTimer?.cancel();
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _client.close(); 
  }
}