import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/tracking_repository.dart';

class NativeTrackingRepository implements TrackingRepository {
  static const _channel = MethodChannel('salesapp/native_tracking');

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> start(String employeeId) async {
    await _channel.invokeMethod<void>(
      'start',
      {'employeeId': employeeId},
    );
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> locateNow() async {
    await _channel.invokeMethod<void>('locateNow');
  }

  @override
  Future<TrackingSnapshot> status() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('status') ?? {};

    final lastFixMs = (raw['lastFixAt'] as num?)?.toInt() ?? 0;

    return TrackingSnapshot(
      active: raw['active'] == true,
      distanceM: (raw['distanceM'] as num?)?.toDouble() ?? 0,
      employeeId: raw['employeeId']?.toString(),
      mode: raw['mode']?.toString() ?? 'idle',
      speedMps: (raw['speedMps'] as num?)?.toDouble() ?? 0,
      lastFixAt: lastFixMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastFixMs, isUtc: true)
          : null,
      accuracyM: (raw['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<CurrentLocationFix?> currentLocation() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'currentLocation',
      );

      if (raw == null) return null;

      return CurrentLocationFix(
        latitude: (raw['latitude'] as num).toDouble(),
        longitude: (raw['longitude'] as num).toDouble(),
        accuracy: (raw['accuracy'] as num).toDouble(),
      );
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<List<PendingLocationPoint>> pending({int limit = 100}) async {
    final text = await _channel.invokeMethod<String>(
      'pending',
      {'limit': limit},
    );

    if (text == null || text.isEmpty) return const [];
    final decoded = jsonDecode(text);
    if (decoded is! List) return const [];

    return decoded.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return PendingLocationPoint(
        id: map['id'].toString(),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        speed: (map['speed'] as num).toDouble(),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['recordedAtMs'] as num).toInt(),
          isUtc: true,
        ),
        totalDistanceM: (map['totalDistanceM'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<List<RoutePoint>> todayRoute() async {
    final text = await _channel.invokeMethod<String>('todayRoute');
    if (text == null || text.isEmpty) return const [];

    final decoded = jsonDecode(text);
    if (decoded is! List) return const [];

    return decoded.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return RoutePoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        speed: (map['speed'] as num).toDouble(),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['recordedAtMs'] as num).toInt(),
          isUtc: true,
        ),
        totalDistanceM: (map['totalDistanceM'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<void> acknowledge(List<String> ids) async {
    await _channel.invokeMethod<void>('acknowledge', {'ids': ids});
  }

  @override
  Future<void> prune() async {
    await _channel.invokeMethod<void>('prune');
  }
}
