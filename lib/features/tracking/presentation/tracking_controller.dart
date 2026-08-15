import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/field_api.dart';
import '../domain/tracking_repository.dart';

class TrackingController extends ChangeNotifier {
  TrackingController({
    required this.repository,
  });

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
    if (!active) {
      return 'Standby';
    }

    return moving
        ? 'Moving'
        : 'Watching';
  }

  Future<void> initialize({
    required String accessToken,
  }) async {
    _token = accessToken;

    await refresh();

    _poller ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        refresh();
      },
    );
  }

  Future<void> ensureAutomatic(
    String employeeId,
  ) async {
    /*
     * IMPORTANT:
     *
     * DO NOT skip native start simply because
     * snapshot.active says true.
     *
     * Android may have killed the process/service
     * while SharedPreferences still says active.
     *
     * ACTION_START is intentionally idempotent.
     *
     * Therefore every application/bootstrap launch
     * reasserts the desired state:
     *
     * "this employee requires the travel meter".
     */
    if (_autoStarting) {
      return;
    }

    _autoStarting = true;

    try {
      final granted =
          await repository.requestPermission();

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

      /*
       * ALWAYS reassert native service start.
       *
       * If it already exists, Android simply delivers
       * ACTION_START to the existing service.
       *
       * If Android previously killed it, this recreates it.
       */
      await repository.start(
        employeeId,
      );

      /*
       * Give Android a moment to create the service
       * and promote it to foreground.
       */
      await Future<void>.delayed(
        const Duration(
          milliseconds: 450,
        ),
      );

      await refresh();

    } catch (_) {
      /*
       * Don't make the whole employee application fail
       * because the native travel meter couldn't start.
       */
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

  Future<void> refresh() async {
    try {
      snapshot =
          await repository.status();

      notifyListeners();

      await flush();

    } catch (_) {
      /*
       * UI keeps its last known state.
       */
    }
  }

  Future<void> locateNow() async {
    await repository.locateNow();

    await Future<void>.delayed(
      const Duration(
        milliseconds: 500,
      ),
    );

    await refresh();
  }

  Future<CurrentLocationFix?>
      currentLocation() async {

    final granted =
        await repository.requestPermission();

    if (!granted) {
      return null;
    }

    await repository.locateNow();

    await Future<void>.delayed(
      const Duration(
        milliseconds: 900,
      ),
    );

    return repository.currentLocation();
  }

  Future<void> flush() async {
    final token = _token;

    if (
        token == null ||
        token.isEmpty
    ) {
      return;
    }

    final points =
        await repository.pending(
      limit: 80,
    );

    if (points.isEmpty) {
      return;
    }

    try {
      await FieldApi(
        accessToken: token,
      ).postJson(
        '/api/salesApp/location/points',
        {
          'points': points
              .map(
                (point) => {
                  'clientId':
                      point.id,

                  'latitude':
                      point.latitude,

                  'longitude':
                      point.longitude,

                  'accuracy':
                      point.accuracy,

                  'speed':
                      point.speed,

                  'recordedAt':
                      point.recordedAt
                          .toIso8601String(),

                  'totalDistanceTravelled':
                      point.totalDistanceM /
                          1000,
                },
              )
              .toList(),
        },
      );

      await repository.acknowledge(
        points
            .map(
              (point) => point.id,
            )
            .toList(),
      );

      if (
          points.length < 80
      ) {
        await repository.prune();
      }

    } catch (_) {
      /*
       * IMPORTANT:
       *
       * Do nothing.
       *
       * Native SQLite still owns every
       * unacknowledged point.
       */
    }
  }

  @override
  void dispose() {
    _poller?.cancel();

    super.dispose();
  }
}

class TrackingUiException
    implements Exception {

  const TrackingUiException(
    this.message,
  );

  final String message;

  @override
  String toString() =>
      message;
}