import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../database/app_database.dart';
import '../../config/field_api.dart';

class FieldTrackingService extends ChangeNotifier {
  FieldTrackingService._();

  static final FieldTrackingService instance = FieldTrackingService._();

  StreamSubscription<Position>? _subscription;
  String? _employeeId;
  String? _accessToken;
  Position? _lastAccepted;
  double _distanceM = 0;
  String? _message;

  // BRIXTA_TRACKING_SINGLE_FLIGHT_V1
  static const Duration _minimumFlushInterval = Duration(seconds: 30);

  Future<void>? _flushInFlight;
  Timer? _flushTimer;
  DateTime? _lastFlushStartedAt;

  bool get isTracking => _subscription != null;
  double get distanceKm => _distanceM / 1000;
  String? get message => _message;

  Future<LocationPermission> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const TrackingException(
        'Location is switched off. Turn it on to start field tracking.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const TrackingException(
        'Location permission is required for attendance and travel distance.',
      );
    }

    return permission;
  }

  Future<Position> currentPosition() async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> start({
    required String employeeId,
    required String accessToken,
  }) async {
    if (isTracking && _employeeId == employeeId) return;

    await stop();
    final permission = await ensurePermission();

    _employeeId = employeeId;
    _accessToken = accessToken;

    // BRIXTA_TRACKING_PRUNE_ON_START_V1
    //
    // Deletes ONLY:
    //
    //     synced = 1
    //     recorded_at < 30 days
    //
    // Unsynced route evidence survives indefinitely.
    await AppDatabase.instance.pruneSyncedTrackingPoints();

    _distanceM = await AppDatabase.instance.todayDistanceKm(employeeId) * 1000;

    final last = await AppDatabase.instance.lastTrackingPoint(employeeId);
    if (last != null) {
      _lastAccepted = _positionFromLocal(last);
    }

    _message = permission == LocationPermission.always
        ? 'Tracking is on, including while the app is in the background.'
        : 'Tracking is on. For reliable background tracking, allow location all the time.';
    notifyListeners();

    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 15),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Field tracking is on',
              notificationText:
                  'Salesapp is recording your work route and travel distance.',
              enableWakeLock: true,
            ),
          )
        : defaultTargetPlatform == TargetPlatform.iOS
        ? AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.automotiveNavigation,
            distanceFilter: 15,
            pauseLocationUpdatesAutomatically: true,
            showBackgroundLocationIndicator: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
          );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          _handlePosition,
          onError: (Object error) {
            _message = 'Tracking needs attention: $error';
            notifyListeners();
          },
        );

    await _requestFlush(force: true);
  }

  Future<void> _handlePosition(Position p) async {
    if (_employeeId == null) return;

    // Reject low-quality points. GPS drift while stationary is the biggest
    // source of inflated TA/DA distance.
    if (p.accuracy > 50) return;

    double segment = 0;
    final previous = _lastAccepted;
    if (previous != null) {
      segment = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        p.latitude,
        p.longitude,
      );

      final seconds =
          p.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
      final impliedSpeed = seconds > 0 ? segment / seconds : 0;

      // Ignore tiny GPS jitter and implausible jumps.
      if (segment < 8 || impliedSpeed > 55) return;
    }

    _distanceM += segment;
    _lastAccepted = p;

    await AppDatabase.instance.saveTrackingPoint(
      employeeId: _employeeId!,
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      recordedAt: p.timestamp,
      segmentDistanceM: segment,
      totalDistanceM: _distanceM,
    );

    notifyListeners();

    // GPS persistence stays immediate.
    // Network work is detached and coalesced.
    unawaited(_requestFlush());
  }

  Future<void> _requestFlush({bool force = false}) async {
    if (_accessToken == null) return;

    final active = _flushInFlight;

    if (active != null) {
      await active;
      return;
    }

    final now = DateTime.now();
    final previous = _lastFlushStartedAt;

    if (!force && previous != null) {
      final elapsed = now.difference(previous);

      if (elapsed < _minimumFlushInterval) {
        final remaining = _minimumFlushInterval - elapsed;

        _flushTimer ??= Timer(remaining, () {
          _flushTimer = null;
          unawaited(_requestFlush(force: true));
        });

        return;
      }
    }

    _flushTimer?.cancel();
    _flushTimer = null;

    _lastFlushStartedAt = now;

    late final Future<void> future;

    future = _flushOnce().whenComplete(() {
      if (identical(_flushInFlight, future)) {
        _flushInFlight = null;
      }
    });

    _flushInFlight = future;

    await future;
  }

  Future<void> _flushOnce() async {
    final token = _accessToken;

    if (token == null) return;

    // BRIXTA_TRACKING_MEMORY_BUDGET_V1
    final rows = await AppDatabase.instance.unsyncedTrackingPoints(limit: 50);

    if (rows.isEmpty) return;

    try {
      await FieldApi(accessToken: token).postJson(
        '/api/salesApp/location/points',
        {
          'points': rows
              .map(
                (row) => {
                  'clientId': row['id'],
                  'latitude': row['latitude'],
                  'longitude': row['longitude'],
                  'accuracy': row['accuracy'],
                  'speed': row['speed'],
                  'recordedAt': row['recorded_at'],
                  'totalDistanceTravelled':
                      (row['total_distance_m'] as num) / 1000,
                },
              )
              .toList(growable: false),
        },
      );

      await AppDatabase.instance.markTrackingPointsSynced(
        rows.map((row) => row['id'] as String),
      );
    } catch (_) {
      // Remains offline-safe in SQLite.
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;

    _flushTimer?.cancel();
    _flushTimer = null;
    _lastFlushStartedAt = null;

    _lastAccepted = null;
    _message = null;
    notifyListeners();
  }

  Position _positionFromLocal(Map<String, Object?> row) {
    return Position(
      longitude: (row['longitude'] as num).toDouble(),
      latitude: (row['latitude'] as num).toDouble(),
      timestamp: DateTime.parse(row['recorded_at'] as String),
      accuracy: (row['accuracy'] as num?)?.toDouble() ?? 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: (row['speed'] as num?)?.toDouble() ?? 0,
      speedAccuracy: 0,
    );
  }
}

class TrackingException implements Exception {
  const TrackingException(this.message);
  final String message;

  @override
  String toString() => message;
}
