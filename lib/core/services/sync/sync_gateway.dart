class SyncSnapshot {
  const SyncSnapshot({
    required this.pendingCount,
    required this.isSyncing,
    required this.conflictCount,
  });

  final int pendingCount;
  final bool isSyncing;
  final int conflictCount;

  static const clean = SyncSnapshot(
    pendingCount: 0,
    isSyncing: false,
    conflictCount: 0,
  );
}

abstract interface class SyncGateway {
  SyncSnapshot get current;
  Stream<SyncSnapshot> get changes;
  Future<void> syncNow();
}
