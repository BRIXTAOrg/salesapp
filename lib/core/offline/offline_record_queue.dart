import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../config/field_api.dart';
import '../database/app_database.dart';
import '../services/media/local_photo_store.dart';
import 'offline_sync_backoff.dart';

class OfflineRecordQueue {
  OfflineRecordQueue._();

  static const _legacyCacheKey = 'pending_responsibility_records_v1';

  static const localPhotoKey = '__localPhotoPath';

  static const _queueName = 'responsibility_records';

  static const _flushBatchSize = 100;

  static String _scope = 'anonymous';

  static final Set<String> _migratedScopes = {};

  static Future<int>? _flushInFlight;

  // BRIXTA_OFFLINE_RECORD_BACKOFF_V1
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

  static void useScope(String value) {
    final normalized = value.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_.:-]+'),
      '_',
    );

    _scope = normalized.isEmpty ? 'anonymous' : normalized;
  }

  static String get _cacheKey => 'pending_responsibility_records_v2:$_scope';

  static Future<void> migrateLegacyQueue() async {
    final scope = _scope;

    if (scope == 'anonymous' || _migratedScopes.contains(scope)) {
      return;
    }

    final database = AppDatabase.instance;

    final current = await database.getCache(_cacheKey);

    final legacy = await database.getCache(_legacyCacheKey);

    final List<dynamic> source;

    if (current is List && current.isNotEmpty) {
      source = current;
    } else if (legacy is List) {
      source = legacy;
    } else {
      source = const [];
    }

    for (final raw in source.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);

      final bodyRaw = item['body'];

      final path = item['path']?.toString();

      final method = item['method']?.toString();

      if (bodyRaw is! Map ||
          path == null ||
          path.isEmpty ||
          method == null ||
          method.isEmpty) {
        continue;
      }

      final body = Map<String, dynamic>.from(bodyRaw);

      await database.enqueueOfflineQueueItem(
        queueName: _queueName,
        scope: scope,
        method: method.toUpperCase(),
        path: path,
        payload: body,
        clientMutationId: body['clientMutationId']?.toString(),
        producesRecordKey: item['producesRecordKey']?.toString(),
        recordReferenceKey: item['recordReferenceKey']?.toString(),
        queuedAt: item['queuedAt']?.toString(),
      );
    }

    await database.removeCache(_cacheKey);
    await database.removeCache(_legacyCacheKey);

    _migratedScopes.add(scope);
  }

  static Future<void> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    String? producesRecordKey,
    String? recordReferenceKey,
  }) async {
    await migrateLegacyQueue();

    await AppDatabase.instance.enqueueOfflineQueueItem(
      queueName: _queueName,
      scope: _scope,
      method: method.toUpperCase(),
      path: path,
      payload: body,
      clientMutationId: body['clientMutationId']?.toString(),
      producesRecordKey: producesRecordKey,
      recordReferenceKey: recordReferenceKey,
    );
  }

  static Future<int> pendingCount() async {
    await migrateLegacyQueue();

    return AppDatabase.instance.offlineQueueCount(
      queueName: _queueName,
      scope: _scope,
    );
  }

  static Future<Map<String, dynamic>> prepareBodyForUpload(
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final api = FieldApi(accessToken: accessToken);

    final resolved = await _resolveValue(api, body);

    if (resolved is! Map) {
      throw const FieldApiException('Invalid queued Responsibility record.');
    }

    return Map<String, dynamic>.from(resolved);
  }

  // BRIXTA_OFFLINE_RECORD_SINGLE_FLIGHT_V1
  static Future<int> flush(String accessToken, {bool bypassBackoff = false}) {
    _lastAccessToken = accessToken;

    if (!bypassBackoff && !_backoff.canAttempt) {
      return pendingCount();
    }

    final running = _flushInFlight;

    if (running != null) {
      return running;
    }

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
    await migrateLegacyQueue();

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

      Map<String, dynamic> body;

      try {
        final decoded = jsonDecode(row['payload_json']?.toString() ?? '');

        if (decoded is! Map) {
          deleteIds.add(itemId);
          continue;
        }

        body = Map<String, dynamic>.from(decoded);
      } catch (_) {
        deleteIds.add(itemId);
        continue;
      }

      final path = row['path']?.toString();

      final method = row['method']?.toString().toUpperCase();

      if (path == null || path.isEmpty) {
        deleteIds.add(itemId);
        continue;
      }

      final referenceKey = row['record_reference_key']?.toString();

      if (referenceKey != null && referenceKey.isNotEmpty) {
        final recordId = await database.offlineQueueResolution(
          queueName: _queueName,
          scope: _scope,
          referenceKey: referenceKey,
        );

        if (recordId == null || recordId.isEmpty) {
          continue;
        }

        body['recordId'] = recordId;
      }

      final localPaths = _collectLocalPhotoPaths(body);

      try {
        final resolved = await _resolveValue(api, body);

        if (resolved is! Map) {
          throw const FieldApiException(
            'Invalid queued Responsibility record.',
          );
        }

        final prepared = Map<String, dynamic>.from(resolved);

        Map<String, dynamic> response;

        switch (method) {
          case 'PATCH':
            response = await api.patchJson(path, prepared);
            break;

          case 'DELETE':
            response = await api.deleteJson(path, prepared);
            break;

          case 'POST':
          default:
            response = await api.postJson(path, prepared);
            break;
        }

        final producerKey = row['produces_record_key']?.toString();

        if (producerKey != null && producerKey.isNotEmpty) {
          final recordRaw = response['record'];
          final runtimeRaw = response['runtime'];

          String? recordId;

          if (recordRaw is Map) {
            recordId = recordRaw['id']?.toString();
          }

          if ((recordId == null || recordId.isEmpty) && runtimeRaw is Map) {
            final worldRaw = runtimeRaw['world'];

            if (worldRaw is Map) {
              recordId = worldRaw['recordId']?.toString();
            }
          }

          if (recordId != null && recordId.isNotEmpty) {
            await database.putOfflineQueueResolution(
              queueName: _queueName,
              scope: _scope,
              referenceKey: producerKey,
              recordId: recordId,
            );
          }
        }

        for (final localPath in localPaths) {
          await LocalPhotoStore.delete(localPath);
        }

        _backoff.recordSuccess();

        deleteIds.add(itemId);
      } on FieldApiException catch (error) {
        final status = error.statusCode ?? 0;

        final permanent =
            status >= 400 && status < 500 && status != 408 && status != 429;

        if (permanent) {
          deleteIds.add(itemId);
          continue;
        }

        // BRIXTA_OFFLINE_FAIL_FAST_V1
        //
        // 408 / 429 / 5xx / transient API failure:
        // stop immediately instead of waiting on the
        // remaining rows.
        _backoff.recordTransientFailure();
        break;
      } catch (_) {
        // Socket, DNS or transport failure.
        //
        // Current + remaining rows stay untouched.
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
