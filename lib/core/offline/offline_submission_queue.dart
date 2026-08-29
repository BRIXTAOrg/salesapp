import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../config/field_api.dart';
import '../database/app_database.dart';
import '../services/media/local_photo_store.dart';
import 'offline_sync_backoff.dart';

class OfflineSubmissionQueue {
  OfflineSubmissionQueue._();

  static const _cacheKey = 'pending_dynamic_submissions';

  static const localPhotoKey = '__localPhotoPath';

  static const _queueName = 'dynamic_submissions';

  static const _scope = 'global';

  static const _flushBatchSize = 100;

  static bool _migrationComplete = false;

  static Future<int>? _flushInFlight;

  // BRIXTA_OFFLINE_SUBMISSION_BACKOFF_V1
  static String? _lastAccessToken;

  static OfflineSyncBackoff? _backoffInstance;

  static OfflineSyncBackoff get _backoff {
    return _backoffInstance ??= OfflineSyncBackoff(
      onRetry: () async {
        final token = _lastAccessToken;

        if (token == null || token.isEmpty) {
          return;
        }

        await flush(token, bypassBackoff: true);
      },
    );
  }

  static Future<void> _ensureMigrated() async {
    if (_migrationComplete) return;

    final database = AppDatabase.instance;

    final existing = await database.getCache(_cacheKey);

    if (existing is List) {
      for (final raw in existing.whereType<Map>()) {
        final submission = Map<String, dynamic>.from(raw);

        await database.enqueueOfflineQueueItem(
          queueName: _queueName,
          scope: _scope,
          payload: submission,
          clientMutationId: submission['clientMutationId']?.toString(),
        );
      }
    }

    await database.removeCache(_cacheKey);

    _migrationComplete = true;
  }

  static Future<void> enqueue(Map<String, dynamic> submission) async {
    await _ensureMigrated();

    await AppDatabase.instance.enqueueOfflineQueueItem(
      queueName: _queueName,
      scope: _scope,
      payload: submission,
      clientMutationId: submission['clientMutationId']?.toString(),
    );
  }

  static Future<int> pendingCount() async {
    await _ensureMigrated();

    return AppDatabase.instance.offlineQueueCount(
      queueName: _queueName,
      scope: _scope,
    );
  }

  static Future<Map<String, dynamic>> prepareForUpload(
    String accessToken,
    Map<String, dynamic> submission,
  ) async {
    final api = FieldApi(accessToken: accessToken);

    final resolved = await _resolveValue(api, submission);

    if (resolved is! Map) {
      throw const FieldApiException('Invalid queued submission.');
    }

    return Map<String, dynamic>.from(resolved);
  }

  // BRIXTA_OFFLINE_SUBMISSION_SINGLE_FLIGHT_V1
  static Future<int> flush(String accessToken, {bool bypassBackoff = false}) {
    _lastAccessToken = accessToken;

    if (!bypassBackoff && !_backoff.canAttempt) {
      return pendingCount();
    }

    final running = _flushInFlight;

    if (running != null) return running;

    late final Future<int> future;

    future = _flushOnce(accessToken).whenComplete(() {
      if (identical(_flushInFlight, future)) {
        _flushInFlight = null;
      }
    });

    _flushInFlight = future;

    return future;
  }

  static Future<int> _flushOnce(String accessToken) async {
    await _ensureMigrated();

    final database = AppDatabase.instance;

    final rows = await database.offlineQueueBatch(
      queueName: _queueName,
      scope: _scope,
      limit: _flushBatchSize,
    );

    if (rows.isEmpty) return 0;

    final api = FieldApi(accessToken: accessToken);

    final deleteIds = <String>[];

    for (final row in rows) {
      final itemId = row['id']?.toString();

      if (itemId == null || itemId.isEmpty) {
        continue;
      }

      Map<String, dynamic> submission;

      try {
        final decoded = jsonDecode(row['payload_json']?.toString() ?? '');

        if (decoded is! Map) {
          deleteIds.add(itemId);
          continue;
        }

        submission = Map<String, dynamic>.from(decoded);
      } catch (_) {
        deleteIds.add(itemId);
        continue;
      }

      final localPaths = _collectLocalPhotoPaths(submission);

      try {
        final resolved = await _resolveValue(api, submission);

        if (resolved is! Map) {
          throw const FieldApiException('Invalid queued submission.');
        }

        await api.postJson(
          '/api/salesApp/submissions',
          Map<String, dynamic>.from(resolved),
        );

        for (final path in localPaths) {
          await LocalPhotoStore.delete(path);
        }

        _backoff.recordSuccess();

        deleteIds.add(itemId);
      } catch (_) {
        // BRIXTA_OFFLINE_SUBMISSION_FAIL_FAST_V1
        //
        // Do not repeat a dead request for every queued row.
        _backoff.recordTransientFailure();
        break;
      }
    }

    await database.deleteOfflineQueueItems(deleteIds);

    return database.offlineQueueCount(queueName: _queueName, scope: _scope);
  }

  static Future<dynamic> _resolveValue(FieldApi api, dynamic value) async {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      final localPath = map[localPhotoKey]?.toString();

      if (localPath != null && localPath.isNotEmpty) {
        if (!await File(localPath).exists()) {
          throw const FieldApiException(
            'An offline photo is no longer available on this phone.',
          );
        }

        return api.uploadPhoto(localPath);
      }

      final resolved = <String, dynamic>{};

      for (final entry in map.entries) {
        resolved[entry.key] = await _resolveValue(api, entry.value);
      }

      return resolved;
    }

    if (value is List) {
      final result = <dynamic>[];

      for (final item in value) {
        result.add(await _resolveValue(api, item));
      }

      return result;
    }

    return value;
  }

  static List<String> _collectLocalPhotoPaths(dynamic value) {
    final paths = <String>[];

    void walk(dynamic current) {
      if (current is Map) {
        final path = current[localPhotoKey]?.toString();

        if (path != null && path.isNotEmpty) {
          paths.add(path);
        }

        for (final entry in current.entries) {
          walk(entry.value);
        }
      } else if (current is List) {
        for (final item in current) {
          walk(item);
        }
      }
    }

    walk(value);

    return paths;
  }
}
