// lib/models/traccar_models.dart

class TraccarSession {
  final int id;
  final String name;
  final String email;
  final bool administrator;
  final String? phone;
  final String? map;
  final String distanceUnit;
  final String speedUnit;

  TraccarSession({
    required this.id,
    required this.name,
    required this.email,
    required this.administrator,
    this.phone,
    this.map,
    required this.distanceUnit,
    required this.speedUnit,
  });

  factory TraccarSession.fromJson(Map<String, dynamic> j) => TraccarSession(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        administrator: j['administrator'] ?? false,
        phone: j['phone'],
        map: j['map'],
        distanceUnit: j['attributes']?['distanceUnit'] ?? 'km',
        speedUnit: j['attributes']?['speedUnit'] ?? 'kmh',
      );
}

class TraccarDevice {
  final int id;
  final String name;
  final String uniqueId;
  final String status;
  final DateTime? lastUpdate;
  final int? groupId;
  final String? phone;
  final String? model;
  final String? contact;
  final String? category;
  final Map<String, dynamic> attributes;

  TraccarDevice({
    required this.id,
    required this.name,
    required this.uniqueId,
    required this.status,
    this.lastUpdate,
    this.groupId,
    this.phone,
    this.model,
    this.contact,
    this.category,
    required this.attributes,
  });

  factory TraccarDevice.fromJson(Map<String, dynamic> j) => TraccarDevice(
        id: j['id'] ?? 0,
        name: j['name'] ?? 'Unknown',
        uniqueId: j['uniqueId'] ?? '',
        status: j['status'] ?? 'offline',
        lastUpdate: j['lastUpdate'] != null ? DateTime.tryParse(j['lastUpdate']) : null,
        groupId: j['groupId'],
        phone: j['phone'],
        model: j['model'],
        contact: j['contact'],
        category: j['category'],
        attributes: Map<String, dynamic>.from(j['attributes'] ?? {}),
      );

  TraccarDevice copyWith({String? status}) => TraccarDevice(
        id: id, name: name, uniqueId: uniqueId,
        status: status ?? this.status,
        lastUpdate: lastUpdate, groupId: groupId,
        phone: phone, model: model, contact: contact,
        category: category, attributes: attributes,
      );
}

class TraccarPosition {
  final int id;
  final int deviceId;
  final DateTime? fixTime;
  final DateTime? serverTime;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed; // knots (Traccar REST API always sends speed in knots)
  final double course;
  final String? address;
  final bool valid;
  final Map<String, dynamic> attributes;

  TraccarPosition({
    required this.id,
    required this.deviceId,
    this.fixTime,
    this.serverTime,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.course,
    this.address,
    required this.valid,
    required this.attributes,
  });

  // Traccar sends speed in knots — multiply by 1.852 to get km/h
  // (NOT * 3.6 — that would be the m/s → km/h factor, which is wrong here)
  double get speedKmh => speed * 1.852;

  bool? get ignition => attributes['ignition'] as bool?;
  double? get fuel => (attributes['fuel'] as num?)?.toDouble();
  double? get batteryLevel => (attributes['batteryLevel'] ?? attributes['battery'] as num?)?.toDouble();
  double? get power => (attributes['power'] as num?)?.toDouble();
  int? get satellites => attributes['sat'] as int?;
  bool? get charging => attributes['charge'] as bool?;
  bool? get blocked => attributes['blocked'] as bool?;
  double? get odometer => (attributes['odometer'] as num?)?.toDouble();
  double? get totalDistance => (attributes['totalDistance'] as num?)?.toDouble();
  int? get rssi => (attributes['rssi'] as num?)?.toInt();
  double? get hours => (attributes['hours'] as num?)?.toDouble();
  String? get result => attributes['result'] as String?;

  factory TraccarPosition.fromJson(Map<String, dynamic> j) => TraccarPosition(
        id: j['id'] ?? 0,
        deviceId: j['deviceId'] ?? 0,
        fixTime: j['fixTime'] != null ? DateTime.tryParse(j['fixTime']) : null,
        serverTime: j['serverTime'] != null ? DateTime.tryParse(j['serverTime']) : null,
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        altitude: (j['altitude'] as num?)?.toDouble() ?? 0,
        speed: (j['speed'] as num?)?.toDouble() ?? 0,
        course: (j['course'] as num?)?.toDouble() ?? 0,
        address: j['address'],
        valid: j['valid'] ?? false,
        attributes: Map<String, dynamic>.from(j['attributes'] ?? {}),
      );
}

class TraccarEvent {
  final int id;
  final int deviceId;
  final String type;
  final DateTime? eventTime;
  final DateTime? serverTime;
  final int? geofenceId;
  final int? positionId;
  final Map<String, dynamic> attributes;

  // ── FIX: Non-final boolean so AppState can modify state directly ──
  bool read;

  TraccarEvent({
    required this.id,
    required this.deviceId,
    required this.type,
    this.eventTime,
    this.serverTime,
    this.geofenceId,
    this.positionId,
    required this.attributes,
    this.read = false, // Defaults to false (unread) for incoming objects
  });

  factory TraccarEvent.fromJson(Map<String, dynamic> j) => TraccarEvent(
        id: j['id'] ?? 0,
        deviceId: j['deviceId'] ?? 0,
        type: j['type'] ?? 'unknown',
        eventTime: j['eventTime'] != null ? DateTime.tryParse(j['eventTime']) : null,
        serverTime: j['serverTime'] != null ? DateTime.tryParse(j['serverTime']) : null,
        geofenceId: j['geofenceId'],
        positionId: j['positionId'],
        attributes: Map<String, dynamic>.from(j['attributes'] ?? {}),
        // Fallback context validation check
        read: j['read'] as bool? ?? false,
      );
}

class TraccarTrip {
  final int deviceId;
  final DateTime? startTime;
  final DateTime? endTime;
  final double distance; // meters
  final double maxSpeed;     // knots (Traccar Reports API sends knots)
  final double averageSpeed; // knots (Traccar Reports API sends knots)
  final int duration; // ms
  final String? startAddress;
  final String? endAddress;
  final double? startLat;
  final double? startLon;
  final double? endLat;
  final double? endLon;

  TraccarTrip({
    required this.deviceId,
    this.startTime,
    this.endTime,
    required this.distance,
    required this.maxSpeed,
    required this.averageSpeed,
    required this.duration,
    this.startAddress,
    this.endAddress,
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
  });

  double get distanceKm => distance / 1000;
  // Traccar sends trip speeds in knots — multiply by 1.852 to get km/h
  double get maxSpeedKmh     => maxSpeed     * 1.852;
  double get averageSpeedKmh => averageSpeed * 1.852;
  String get durationStr {
    final s = duration ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}min ${sec}s';
    if (m > 0) return '${m}min ${sec}s';
    return '${sec}s';
  }

  factory TraccarTrip.fromJson(Map<String, dynamic> j) => TraccarTrip(
        deviceId: j['deviceId'] ?? 0,
        startTime: j['startTime'] != null ? DateTime.tryParse(j['startTime']) : null,
        endTime: j['endTime'] != null ? DateTime.tryParse(j['endTime']) : null,
        distance: (j['distance'] as num?)?.toDouble() ?? 0,
        maxSpeed: (j['maxSpeed'] as num?)?.toDouble() ?? 0,
        averageSpeed: (j['averageSpeed'] as num?)?.toDouble() ?? 0,
        duration: (j['duration'] as num?)?.toInt() ?? 0,
        startAddress: j['startAddress'],
        endAddress: j['endAddress'],
        startLat: (j['startLat'] as num?)?.toDouble(),
        startLon: (j['startLon'] as num?)?.toDouble(),
        endLat: (j['endLat'] as num?)?.toDouble(),
        endLon: (j['endLon'] as num?)?.toDouble(),
      );
}

class TraccarStop {
  final int deviceId;
  final DateTime? startTime;
  final DateTime? endTime;
  final int duration;
  final double? lat;
  final double? lon;
  final String? address;

  TraccarStop({
    required this.deviceId,
    this.startTime,
    this.endTime,
    required this.duration,
    this.lat,
    this.lon,
    this.address,
  });

  String get durationStr {
    final s = duration ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}min ${sec}s';
    if (m > 0) return '${m}min ${sec}s';
    return '${sec}s';
  }

  factory TraccarStop.fromJson(Map<String, dynamic> j) => TraccarStop(
        deviceId: j['deviceId'] ?? 0,
        startTime: j['startTime'] != null ? DateTime.tryParse(j['startTime']) : null,
        endTime: j['endTime'] != null ? DateTime.tryParse(j['endTime']) : null,
        duration: (j['duration'] as num?)?.toInt() ?? 0,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        address: j['address'],
      );
}

class TraccarGeofence {
  final int id;
  final String name;
  final String area;
  final String? description;

  TraccarGeofence({required this.id, required this.name, required this.area, this.description});

  factory TraccarGeofence.fromJson(Map<String, dynamic> j) => TraccarGeofence(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        area: j['area'] ?? '',
        description: j['description'],
      );
}

// Device computed status
enum DeviceStatus { running, stopped, idle, offline, nodata, expired }

DeviceStatus computeStatus(TraccarDevice device, TraccarPosition? pos) {
  // Check if we have a recent position (within 10 minutes).
  // Traccar's device.status='offline' lags behind real position data — its
  // server-side timeout can mark a device offline even when we received a
  // packet seconds ago. If position is fresh, never trust the offline status.
  final posTimestamp = pos?.serverTime ?? pos?.fixTime;
  final hasRecentPos = posTimestamp != null &&
      DateTime.now().difference(posTimestamp.toLocal()).inMinutes < 10;

  // Unknown/no-data: no recent position AND Traccar says unknown
  if (device.status == 'unknown' && !hasRecentPos) return DeviceStatus.nodata;

  // Offline: no recent position AND Traccar confirms offline
  if (device.status == 'offline' && !hasRecentPos) return DeviceStatus.offline;

  // Device is online (or has a recent position — override stale offline status)
  if (pos == null) return DeviceStatus.stopped;

  if (pos.speedKmh > 2)        return DeviceStatus.running;
  if (pos.ignition == true)    return DeviceStatus.idle;    // engine on, not moving
  if (pos.ignition == false)   return DeviceStatus.stopped; // engine off
  return DeviceStatus.stopped; // no ignition data — default to stopped
}

String statusLabel(DeviceStatus s) {
  switch (s) {
    case DeviceStatus.running: return 'Running';
    case DeviceStatus.stopped: return 'Stopped';
    case DeviceStatus.idle:    return 'Idle';
    case DeviceStatus.offline: return 'Offline';
    case DeviceStatus.nodata:  return 'No Data';
    case DeviceStatus.expired: return 'Expired';
  }
}

class EventPref {
  bool showInApp;
  bool pushEnabled;

  EventPref({this.showInApp = true, this.pushEnabled = true});

  Map<String, dynamic> toJson() => {'showInApp': showInApp, 'pushEnabled': pushEnabled};
  factory EventPref.fromJson(Map<String, dynamic> json) => EventPref(
    showInApp: json['showInApp'] ?? true,
    pushEnabled: json['pushEnabled'] ?? true,
  );
}