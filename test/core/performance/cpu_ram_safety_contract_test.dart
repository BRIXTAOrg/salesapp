import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('offline queues no longer rewrite whole JSON queue', () {
    final database = source('lib/core/database/app_database.dart');

    final records = source('lib/core/offline/offline_record_queue.dart');

    final submissions = source(
      'lib/core/offline/offline_submission_queue.dart',
    );

    expect(database, contains('BRIXTA_ROW_OFFLINE_QUEUE_V1'));

    expect(database, contains('offline_queue_items'));

    expect(records, contains('enqueueOfflineQueueItem'));

    expect(submissions, contains('enqueueOfflineQueueItem'));

    expect(records, isNot(contains('putCache(_cacheKey, queue)')));

    expect(submissions, isNot(contains('putCache(_cacheKey, queue)')));

    expect(records, contains('_flushBatchSize = 100'));

    expect(submissions, contains('_flushBatchSize = 100'));
  });

  test('GPS network synchronization is bounded', () {
    final tracking = source(
      'lib/core/services/location/field_tracking_service.dart',
    );

    expect(tracking, contains('BRIXTA_TRACKING_SINGLE_FLIGHT_V1'));

    expect(tracking, contains('Duration(seconds: 30)'));

    expect(tracking, contains('Future<void>? _flushInFlight'));

    expect(tracking, contains('limit: 50'));
  });

  test('GPS acknowledgements are one SQL statement', () {
    final database = source('lib/core/database/app_database.dart');

    expect(database, contains('BRIXTA_TRACKING_BATCH_ACK_V1'));

    expect(database, contains('id IN (\$placeholders)'));
  });

  test('HTTP requests have timeout protection', () {
    final api = source('lib/core/config/field_api.dart');

    expect(api, contains('BRIXTA_REQUEST_TIMEOUT_V1'));

    expect(api, contains('Duration(seconds: 20)'));

    expect(api, contains('REQUEST_TIMEOUT'));
  });
}
