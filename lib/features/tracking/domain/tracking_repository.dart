class TrackingSnapshot {
  const TrackingSnapshot({
    required this.active,
    required this.distanceM,
    required this.mode,
    required this.speedMps,
    required this.lastFixAt,
    required this.accuracyM,
    this.employeeId,
  });

  final bool active;
  final double distanceM;
  final String mode;
  final double speedMps;
  final DateTime? lastFixAt;
  final double accuracyM;
  final String? employeeId;

  double get distanceKm => distanceM / 1000;
  double get speedKmh => speedMps * 3.6;
  bool get moving => mode == 'moving';
}

class PendingLocationPoint {
  const PendingLocationPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.recordedAt,
    required this.totalDistanceM,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final DateTime recordedAt;
  final double totalDistanceM;
}

class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.recordedAt,
    required this.totalDistanceM,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final DateTime recordedAt;
  final double totalDistanceM;
}

class CurrentLocationFix {
  const CurrentLocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
}

abstract interface class TrackingRepository {
  Future<bool> requestPermission();
  Future<void> start(String employeeId);
  Future<void> stop();
  Future<void> locateNow();
  Future<TrackingSnapshot> status();
  Future<CurrentLocationFix?> currentLocation();

  Future<List<PendingLocationPoint>> pending({
    int limit = 100,
  });

  /// All route points retained for the current local work day, including
  /// already-synced points. Used as employee-visible evidence in TA/DA.
  Future<List<RoutePoint>> todayRoute();

  Future<void> acknowledge(List<String> ids);

  /// Prunes only old synced route points. Today's evidence must be retained.
  Future<void> prune();
}
