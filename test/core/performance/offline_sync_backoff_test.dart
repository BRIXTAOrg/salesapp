import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:salesapp/core/offline/offline_sync_backoff.dart';

void main() {
  test('failure blocks immediate retry', () async {
    var retries = 0;

    final policy = OfflineSyncBackoff(
      watchConnectivity: false,
      retryDelays: const [
        Duration(milliseconds: 20),
        Duration(milliseconds: 40),
      ],
      onRetry: () async {
        retries += 1;
      },
    );

    expect(policy.canAttempt, isTrue);

    policy.recordTransientFailure();

    expect(policy.failureCount, 1);

    expect(policy.canAttempt, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(retries, 1);

    expect(policy.canAttempt, isTrue);

    await policy.dispose();
  });

  test('reconnect retries immediately', () async {
    final retried = Completer<void>();

    var retries = 0;

    final policy = OfflineSyncBackoff(
      watchConnectivity: false,
      retryDelays: const [Duration(minutes: 5)],
      onRetry: () async {
        retries += 1;

        if (!retried.isCompleted) {
          retried.complete();
        }
      },
    );

    policy.noteConnectivity(false);

    policy.recordTransientFailure();

    expect(policy.canAttempt, isFalse);

    policy.noteConnectivity(true);

    await retried.future.timeout(const Duration(seconds: 1));

    expect(retries, 1);

    expect(policy.canAttempt, isTrue);

    expect(policy.failureCount, 0);

    await policy.dispose();
  });

  test('success resets failure state', () async {
    final policy = OfflineSyncBackoff(
      watchConnectivity: false,
      retryDelays: const [Duration(minutes: 1), Duration(minutes: 2)],
      onRetry: () async {},
    );

    policy.recordTransientFailure();

    expect(policy.failureCount, 1);

    policy.recordSuccess();

    expect(policy.failureCount, 0);

    expect(policy.canAttempt, isTrue);

    await policy.dispose();
  });
}
