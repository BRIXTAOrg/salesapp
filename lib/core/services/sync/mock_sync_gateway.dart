import 'dart:async';

import 'sync_gateway.dart';

class MockSyncGateway implements SyncGateway {
  final StreamController<SyncSnapshot> _controller =
      StreamController<SyncSnapshot>.broadcast();

  SyncSnapshot _current = const SyncSnapshot(
    pendingCount: 3,
    isSyncing: false,
    conflictCount: 0,
  );

  @override
  SyncSnapshot get current => _current;

  @override
  Stream<SyncSnapshot> get changes => _controller.stream;

  @override
  Future<void> syncNow() async {
    _current = SyncSnapshot(
      pendingCount: _current.pendingCount,
      isSyncing: true,
      conflictCount: _current.conflictCount,
    );
    _controller.add(_current);

    await Future<void>.delayed(const Duration(milliseconds: 900));

    _current = SyncSnapshot.clean;
    _controller.add(_current);
  }
}
