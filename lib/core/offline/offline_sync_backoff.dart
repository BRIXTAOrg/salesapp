import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

typedef OfflineRetryCallback = Future<void> Function();

/// BRIXTA_OFFLINE_SYNC_BACKOFF_V1
///
/// Retry sequence:
///
/// 30 sec
/// 1 min
/// 2 min
/// 5 min
/// 15 min
/// 15 min...
///
/// A real offline -> online transition cancels the old delay
/// and immediately asks the queue to retry.
class OfflineSyncBackoff {
  OfflineSyncBackoff({
    required this.onRetry,
    List<Duration>? retryDelays,
    bool watchConnectivity = true,
  }) : _retryDelays =
           retryDelays ??
           const [
             Duration(seconds: 30),
             Duration(minutes: 1),
             Duration(minutes: 2),
             Duration(minutes: 5),
             Duration(minutes: 15),
           ] {
    if (_retryDelays.isEmpty) {
      throw ArgumentError('At least one retry delay is required.');
    }

    if (watchConnectivity) {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        results,
      ) {
        noteConnectivity(
          results.any((result) => result != ConnectivityResult.none),
        );
      });
    }
  }

  final OfflineRetryCallback onRetry;

  final List<Duration> _retryDelays;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Timer? _timer;

  DateTime? _notBefore;

  bool? _online;

  bool _retryRunning = false;

  int _failureCount = 0;

  int get failureCount => _failureCount;

  DateTime? get notBefore => _notBefore;

  bool get canAttempt {
    final boundary = _notBefore;

    return boundary == null || !DateTime.now().isBefore(boundary);
  }

  Duration get _nextDelay {
    final index = _failureCount < _retryDelays.length
        ? _failureCount
        : _retryDelays.length - 1;

    return _retryDelays[index];
  }

  void recordTransientFailure() {
    final delay = _nextDelay;

    _failureCount += 1;

    _timer?.cancel();

    _notBefore = DateTime.now().add(delay);

    _timer = Timer(delay, () {
      _timer = null;
      _notBefore = null;

      unawaited(_triggerRetry());
    });
  }

  void recordSuccess() {
    _failureCount = 0;
    _notBefore = null;

    _timer?.cancel();
    _timer = null;
  }

  /// Public so deterministic tests can simulate connectivity
  /// transitions without mocking platform channels.
  void noteConnectivity(bool online) {
    final previous = _online;

    _online = online;

    if (online && previous == false) {
      // BRIXTA_CONNECTIVITY_RESTORE_RETRY_V1

      _failureCount = 0;
      _notBefore = null;

      _timer?.cancel();
      _timer = null;

      unawaited(_triggerRetry());
    }
  }

  Future<void> _triggerRetry() async {
    if (_retryRunning) {
      return;
    }

    _retryRunning = true;

    try {
      await onRetry();
    } finally {
      _retryRunning = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;

    await _connectivitySubscription?.cancel();

    _connectivitySubscription = null;
  }
}
