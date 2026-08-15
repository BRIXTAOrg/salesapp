import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_gateway.dart';

class DeviceConnectivityGateway implements ConnectivityGateway {
  DeviceConnectivityGateway._(this._current) {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final next = _fromResults(results);
      if (next == _current) return;
      _current = next;
      _controller.add(next);
    });
  }

  ConnectivityStateValue _current;
  final _controller =
      StreamController<ConnectivityStateValue>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  static Future<DeviceConnectivityGateway> create() async {
    final results = await Connectivity().checkConnectivity();
    return DeviceConnectivityGateway._(_fromResults(results));
  }

  static ConnectivityStateValue _fromResults(
    List<ConnectivityResult> results,
  ) {
    final connected = results.any(
      (result) => result != ConnectivityResult.none,
    );
    return connected
        ? ConnectivityStateValue.online
        : ConnectivityStateValue.offline;
  }

  @override
  ConnectivityStateValue get current => _current;

  @override
  Stream<ConnectivityStateValue> get changes => _controller.stream;

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
