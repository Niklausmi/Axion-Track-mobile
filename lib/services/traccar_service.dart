// lib/services/traccar_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/traccar_models.dart';

class TraccarService {
  final String serverUrl;
  final String email;
  final String password;
  late final String _auth;
  late final String _base;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _wsTimer;
  int _wsRetries = 0;

  Function(List<TraccarDevice>)?  onDevices;
  Function(List<TraccarPosition>)? onPositions;
  Function(List<TraccarEvent>)?   onEvents;
  Function(bool)?                 onWsChange;

  TraccarService({required this.serverUrl, required this.email, required this.password}) {
    _base = '${serverUrl.replaceAll(RegExp(r'/$'), '')}/api';
    _auth = 'Basic ${base64Encode(utf8.encode('$email:$password'))}';
  }

  Map<String, String> get _h => {'Authorization': _auth, 'Accept': 'application/json'};

  Future<dynamic> _get(String path) async {
    final r = await http.get(Uri.parse('$_base$path'), headers: _h).timeout(const Duration(seconds: 30));
    if (r.statusCode == 200) return json.decode(utf8.decode(r.bodyBytes));
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<dynamic> _post(String path, Map<String, String> form) async {
    final r = await http.post(Uri.parse('$_base$path'),
      headers: {..._h, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: form).timeout(const Duration(seconds: 30));
    if (r.statusCode == 200) return json.decode(utf8.decode(r.bodyBytes));
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<dynamic> _postJson(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$_base$path'),
      headers: {..._h, 'Content-Type': 'application/json'},
      body: json.encode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return {};
      return json.decode(utf8.decode(r.bodyBytes));
    }
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }

  // FIX: Explicitly cast the dynamic map to Map<String, dynamic>
  Future<TraccarSession> login()      => _post('/session', {'email': email, 'password': password}).then((d) => TraccarSession.fromJson(d as Map<String, dynamic>));
  Future<TraccarSession> getSession() => _get('/session').then((d) => TraccarSession.fromJson(d as Map<String, dynamic>));
  Future<void>           logout()     => http.delete(Uri.parse('$_base/session'), headers: _h).then((_) {});

  // FIX: Use .cast<Map<String, dynamic>>() or explicit mapping to ensure List<Model>
  Future<List<TraccarDevice>>   getDevices()   => _get('/devices').then((d)   => (d as List).map((e) => TraccarDevice.fromJson(e as Map<String, dynamic>)).toList());
  Future<List<TraccarPosition>> getPositions() => _get('/positions').then((d) => (d as List).map((e) => TraccarPosition.fromJson(e as Map<String, dynamic>)).toList());
  Future<List<TraccarGeofence>> getGeofences() => _get('/geofences').then((d) => (d as List).map((e) => TraccarGeofence.fromJson(e as Map<String, dynamic>)).toList());
  Future<List<TraccarGroup>>    getGroups()    => _get('/groups').then((d)    => (d as List).map((e) => TraccarGroup.fromJson(e as Map<String, dynamic>)).toList());

  Future<List<TraccarEvent>> getEvents({required DateTime from, required DateTime to, required List<int> ids}) async {
    if (ids.isEmpty) return [];
    final p = StringBuffer('/reports/events?from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
    for (final id in ids.take(20)) {
      p.write('&deviceId=$id');
    }
    try { 
      final d = await _get(p.toString());
      return (d as List).map((e) => TraccarEvent.fromJson(e as Map<String, dynamic>)).toList(); 
    } catch (_) { return []; }
  }

  Future<List<TraccarTrip>> getTrips({required int deviceId, required DateTime from, required DateTime to}) async {
    try {
      final d = await _get('/reports/trips?deviceId=$deviceId&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
      return (d as List).map((e) => TraccarTrip.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<TraccarStop>> getStops({required int deviceId, required DateTime from, required DateTime to}) async {
    try {
      final d = await _get('/reports/stops?deviceId=$deviceId&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
      return (d as List).map((e) => TraccarStop.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<TraccarPosition>> getRoute({required int deviceId, required DateTime from, required DateTime to}) async {
    try {
      final d = await _get('/reports/route?deviceId=$deviceId&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
      return (d as List).map((e) => TraccarPosition.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<double> getDailyDistance({required int deviceId}) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    try {
      final d = await _get('/reports/summary?deviceId=$deviceId&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
      if (d is List && d.isNotEmpty) {
        return ((d.first['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      }
    } catch (_) {}
    return 0.0;
  }

  // FIX: Added cast to Map<String, dynamic>
  Future<Map<String,dynamic>> sendCommand({required int deviceId, required String type}) async {
    final res = await _postJson('/commands/send', {'deviceId': deviceId, 'type': type});
    return res as Map<String, dynamic>;
  }

  String get wsUrl => '${_base.replaceFirst('http', 'ws').replaceAll('/api', '')}/api/socket';

  void connectWS() {
    _wsTimer?.cancel();
    _wsSub?.cancel(); // Close existing subscription
    _ws?.sink.close(); // Close existing socket
    
    try {
      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      _ws!.ready.catchError((_) {});
      onWsChange?.call(true);
      _wsRetries = 0;
      _wsSub = _ws!.stream.listen(
        (data) {
          try {
            final msg = json.decode(data.toString()) as Map<String, dynamic>;
            // FIX: Explicitly map the lists inside the WebSocket message
            if (msg['devices']   != null) onDevices?.call((msg['devices']   as List).map((e) => TraccarDevice.fromJson(e as Map<String, dynamic>)).toList());
            if (msg['positions'] != null) onPositions?.call((msg['positions'] as List).map((e) => TraccarPosition.fromJson(e as Map<String, dynamic>)).toList());
            if (msg['events']    != null) onEvents?.call((msg['events']    as List).map((e) => TraccarEvent.fromJson(e as Map<String, dynamic>)).toList());
          } catch (_) {}
        },
        onError: (_) => _reconnect(),
        onDone:  ()  => _reconnect(),
      );
    } catch (_) { _reconnect(); }
  }

  void _reconnect() {
    onWsChange?.call(false);
    _wsRetries++;
    _wsTimer = Timer(Duration(seconds: (_wsRetries * 2).clamp(2, 30)), connectWS);
  }

  void dispose() { _wsTimer?.cancel(); _wsSub?.cancel(); _ws?.sink.close(); }
}