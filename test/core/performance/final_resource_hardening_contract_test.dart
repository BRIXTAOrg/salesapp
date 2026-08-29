import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('animation soft and hard budgets exist', () {
    final renderer = source(
      'lib/features/dynamic/presentation/brixta_stac_ui.dart',
    );

    expect(renderer, contains('_recommendedAnimatedNodes = 512'));

    expect(renderer, contains('_maxAnimatedNodes = 1024'));

    expect(renderer, contains('suppressAnimations'));
  });

  test('raw STAC is sandboxed', () {
    final renderer = source(
      'lib/features/dynamic/presentation/brixta_stac_ui.dart',
    );

    for (final marker in [
      'BRIXTA_RAW_STAC_PREFLIGHT_V1',
      '_maxRawStacNodes = 2048',
      '_maxExpandedRawStacNodes = 4096',
      '_maxRawStacDepth = 32',
      '_maxRawStacDirectChildren = 256',
      '_maxRawStacBytes = 512 * 1024',
    ]) {
      expect(renderer, contains(marker));
    }
  });

  test('offline queues fail fast', () {
    final record = source('lib/core/offline/offline_record_queue.dart');

    final submission = source('lib/core/offline/offline_submission_queue.dart');

    expect(record, contains('BRIXTA_OFFLINE_FAIL_FAST_V1'));

    expect(submission, contains('BRIXTA_OFFLINE_SUBMISSION_FAIL_FAST_V1'));

    expect(record, contains('recordTransientFailure'));

    expect(submission, contains('recordTransientFailure'));
  });

  test('backoff ceiling is 15 minutes', () {
    final backoff = source('lib/core/offline/offline_sync_backoff.dart');

    for (final value in [
      'Duration(seconds: 30)',
      'Duration(minutes: 1)',
      'Duration(minutes: 2)',
      'Duration(minutes: 5)',
      'Duration(minutes: 15)',
    ]) {
      expect(backoff, contains(value));
    }

    expect(backoff, contains('BRIXTA_CONNECTIVITY_RESTORE_RETRY_V1'));
  });

  test('only old synced GPS points are pruned', () {
    final database = source('lib/core/database/app_database.dart');

    final tracking = source(
      'lib/core/services/location/field_tracking_service.dart',
    );

    expect(database, contains('BRIXTA_TRACKING_RETENTION_V1'));

    expect(database, contains('Duration(days: 30)'));

    expect(database, contains("'synced = 1 '"));

    expect(database, contains("'AND recorded_at < ?'"));

    expect(tracking, contains('BRIXTA_TRACKING_PRUNE_ON_START_V1'));
  });
}
