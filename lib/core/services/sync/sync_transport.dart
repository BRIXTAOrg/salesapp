class SyncPushResult {
  const SyncPushResult({required this.acknowledgedEventIds});

  final List<String> acknowledgedEventIds;
}

abstract interface class SyncTransport {
  Future<SyncPushResult> push({
    required String employeeId,
    required List<Map<String, Object?>> events,
  });
}

class UnconfiguredSyncTransport implements SyncTransport {
  const UnconfiguredSyncTransport();

  @override
  Future<SyncPushResult> push({
    required String employeeId,
    required List<Map<String, Object?>> events,
  }) {
    throw StateError(
      'Backend sync transport is not configured yet. '
      'Local data remains safely queued.',
    );
  }
}
