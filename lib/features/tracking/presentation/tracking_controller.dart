import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/field_api.dart';
import '../domain/tracking_repository.dart';

class TrackingController extends ChangeNotifier {
  TrackingController({required this.repository});

  final TrackingRepository repository;

  TrackingSnapshot snapshot = const TrackingSnapshot(
    active: false,
    distanceM: 0,
    mode: 'idle',
    speedMps: 0,
    lastFixAt: null,
    accuracyM: 0,
  );

  Timer? _poller;
  String? _token;
  bool _autoStarting = false;

  bool get active => snapshot.active;
  bool get moving => snapshot.moving;
  double get distanceKm => snapshot.distanceKm;
  double get speedKmh => snapshot.speedKmh;

  String get meterState {
    if (!active) return 'Standby';
    return moving ? 'Moving' : 'Watching';
  }

  Future<void> initialize({required String accessToken}) async {
    _token = accessToken;
    await refresh();

    _poller ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => refresh(),
    );
  }

  Future<void> ensureAutomatic(String employeeId) async {
    if (_autoStarting) return;
    _autoStarting = true;

    try {
      final granted = await repository.requestPermission();
      if (!granted) {
        snapshot = TrackingSnapshot(
          active: false,
          distanceM: snapshot.distanceM,
          mode: 'idle',
          speedMps: 0,
          lastFixAt: snapshot.lastFixAt,
          accuracyM: snapshot.accuracyM,
          employeeId: snapshot.employeeId,
        );
        notifyListeners();
        return;
      }

      // ACTION_START is idempotent. Reasserting it repairs a service that was
      // killed while SharedPreferences still said the meter was desired.
      await repository.start(employeeId);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await refresh();
    } catch (_) {
      snapshot = TrackingSnapshot(
        active: false,
        distanceM: snapshot.distanceM,
        mode: 'idle',
        speedMps: 0,
        lastFixAt: snapshot.lastFixAt,
        accuracyM: snapshot.accuracyM,
        employeeId: snapshot.employeeId,
      );
      notifyListeners();
    } finally {
      _autoStarting = false;
    }
  }

  Future<void> stop() async {
    try {
      await repository.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await refresh();
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      snapshot = await repository.status();
      notifyListeners();
      await flush();
    } catch (_) {}
  }

  Future<List<RoutePoint>> todayRoute() async {
    try {
      return await repository.todayRoute();
    } catch (_) {
      return const [];
    }
  }

  Future<void> locateNow() async {
    await repository.locateNow();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  Future<CurrentLocationFix?> currentLocation() async {
    final granted = await repository.requestPermission();
    if (!granted) return null;

    await repository.locateNow();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return repository.currentLocation();
  }

  Future<void> flush() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final points = await repository.pending(limit: 80);
    if (points.isEmpty) return;

    try {
      await FieldApi(accessToken: token).postJson(
        '/api/salesApp/location/points',
        {
          'points': points
              .map(
                (point) => {
                  'clientId': point.id,
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                  'accuracy': point.accuracy,
                  'speed': point.speed,
                  'recordedAt': point.recordedAt.toIso8601String(),
                  'totalDistanceTravelled': point.totalDistanceM / 1000,
                },
              )
              .toList(),
        },
      );

      await repository.acknowledge(points.map((point) => point.id).toList());

      if (points.length < 80) {
        await repository.prune();
      }
    } catch (_) {
      // Native SQLite keeps every unacknowledged point.
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }
}

class TrackingUiException implements Exception {
  const TrackingUiException(this.message);

  final String message;

  @override
  String toString() => message;
}
