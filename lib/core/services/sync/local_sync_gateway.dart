import 'dart:async';

import '../../database/app_database.dart';
import '../connectivity/connectivity_gateway.dart';
import 'sync_gateway.dart';
import 'sync_transport.dart';

class LocalSyncGateway implements SyncGateway {
  LocalSyncGateway({
    required this.database,
    required this.connectivityGateway,
    required this.transport,
    required this.employeeIdProvider,
  });

  final AppDatabase database;
  final ConnectivityGateway connectivityGateway;
  final SyncTransport transport;
  final String? Function() employeeIdProvider;

  final _controller = StreamController<SyncSnapshot>.broadcast();
  StreamSubscription<int>? _pendingSubscription;
  StreamSubscription<ConnectivityStateValue>? _connectivitySubscription;

  SyncSnapshot _current = SyncSnapshot.clean;

  Future<void> initialize() async {
    _current = SyncSnapshot(
      pendingCount: await database.pendingCount(),
      isSyncing: false,
      conflictCount: 0,
    );

    _pendingSubscription = database.pendingCountChanges.listen((count) {
      _current = SyncSnapshot(
        pendingCount: count,
        isSyncing: _current.isSyncing,
        conflictCount: _current.conflictCount,
      );
      _controller.add(_current);
    });

    _connectivitySubscription =
        connectivityGateway.changes.listen((state) {
      if (state == ConnectivityStateValue.online) {
        unawaited(syncNow());
      }
    });
  }

  @override
  SyncSnapshot get current => _current;

  @override
  Stream<SyncSnapshot> get changes => _controller.stream;

  @override
  Future<void> syncNow() async {
    if (_current.isSyncing) return;
    if (connectivityGateway.current != ConnectivityStateValue.online) return;

    final employeeId = employeeIdProvider();
    if (employeeId == null || employeeId.isEmpty) return;

    final events = await database.pendingBatch();
    if (events.isEmpty) return;

    _setSyncing(true);

    try {
      final result = await transport.push(
        employeeId: employeeId,
        events: events,
      );
      await database.markAcknowledged(result.acknowledgedEventIds);
    } catch (_) {
      // Critical rule: never delete local events on network/backend failure.
    } finally {
      _setSyncing(false);
    }
  }

  void _setSyncing(bool value) {
    _current = SyncSnapshot(
      pendingCount: _current.pendingCount,
      isSyncing: value,
      conflictCount: _current.conflictCount,
    );
    _controller.add(_current);
  }

  Future<void> dispose() async {
    await _pendingSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _controller.close();
  }
}
