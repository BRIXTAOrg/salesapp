import 'dart:io';

import '../config/field_api.dart';
import '../database/app_database.dart';
import '../services/media/local_photo_store.dart';

/// Tenant/user-scoped offline queue for generic Responsibility mutations.
class OfflineRecordQueue {
  OfflineRecordQueue._();

  static const _legacyCacheKey = 'pending_responsibility_records_v1';
  static const localPhotoKey = '__localPhotoPath';

  static String _scope = 'anonymous';

  static void useScope(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_.:-]+'), '_');
    _scope = normalized.isEmpty ? 'anonymous' : normalized;
  }

  static String get _cacheKey => 'pending_responsibility_records_v2:$_scope';

  static Future<void> migrateLegacyQueue() async {
    if (_scope == 'anonymous') return;
    final current = await AppDatabase.instance.getCache(_cacheKey);
    if (current is List && current.isNotEmpty) return;

    final legacy = await AppDatabase.instance.getCache(_legacyCacheKey);
    if (legacy is List && legacy.isNotEmpty) {
      await AppDatabase.instance.putCache(_cacheKey, legacy);
      await AppDatabase.instance.removeCache(_legacyCacheKey);
    }
  }

  static Future<void> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    String? producesRecordKey,
    String? recordReferenceKey,
  }) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);

    final queue = <Map<String, dynamic>>[
      if (existing is List)
        ...existing.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
    ];

    final mutationId = body['clientMutationId']?.toString();
    if (mutationId != null &&
        mutationId.isNotEmpty &&
        queue.any(
          (item) =>
              (item['body'] is Map) &&
              (item['body'] as Map)['clientMutationId']?.toString() == mutationId,
        )) {
      return;
    }

    queue.add({
      'method': method.toUpperCase(),
      'path': path,
      'body': body,
      if (producesRecordKey != null && producesRecordKey.isNotEmpty)
        'producesRecordKey': producesRecordKey,
      if (recordReferenceKey != null && recordReferenceKey.isNotEmpty)
        'recordReferenceKey': recordReferenceKey,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
    });

    await AppDatabase.instance.putCache(_cacheKey, queue);
  }

  static Future<int> pendingCount() async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    return existing is List ? existing.length : 0;
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

  /// Returns the number of mutations still waiting after the flush.
  static Future<int> flush(String accessToken) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    if (existing is! List || existing.isEmpty) return 0;

    final queue = existing
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final remaining = <Map<String, dynamic>>[];
    final resolvedRecordIds = <String, String>{};
    final api = FieldApi(accessToken: accessToken);

    for (final original in queue) {
      final item = Map<String, dynamic>.from(original);
      final bodyRaw = item['body'];
      final path = item['path']?.toString();
      final method = item['method']?.toString().toUpperCase();

      if (bodyRaw is! Map || path == null || path.isEmpty) continue;

      final body = Map<String, dynamic>.from(bodyRaw);
      final recordReferenceKey = item['recordReferenceKey']?.toString();

      if (recordReferenceKey != null && recordReferenceKey.isNotEmpty) {
        final resolvedId = resolvedRecordIds[recordReferenceKey];
        if (resolvedId == null || resolvedId.isEmpty) {
          // The mutation that creates the server record is still ahead of us
          // (or failed). Keep this dependent action safely queued.
          remaining.add(item);
          continue;
        }

        body['recordId'] = resolvedId;
        item['body'] = body;
        item.remove('recordReferenceKey');
      }

      final localPaths = _collectLocalPhotoPaths(body);

      try {
        final prepared = await prepareBodyForUpload(accessToken, body);
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

        final producesRecordKey = item['producesRecordKey']?.toString();
        if (producesRecordKey != null && producesRecordKey.isNotEmpty) {
          final recordRaw = response['record'];
          final runtimeRaw = response['runtime'];
          String? recordId;

          if (recordRaw is Map) {
            recordId = recordRaw['id']?.toString();
          }
          if ((recordId == null || recordId.isEmpty) && runtimeRaw is Map) {
            final worldRaw = runtimeRaw['world'];
            if (worldRaw is Map) recordId = worldRaw['recordId']?.toString();
          }

          if (recordId != null && recordId.isNotEmpty) {
            resolvedRecordIds[producesRecordKey] = recordId;
          }
        }

        for (final localPath in localPaths) {
          await LocalPhotoStore.delete(localPath);
        }
      } catch (_) {
        remaining.add(item);
      }
    }

    await AppDatabase.instance.putCache(_cacheKey, remaining);
    return remaining.length;
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
      final resolved = <dynamic>[];
      for (final item in value) {
        resolved.add(await _resolveValue(api, item));
      }
      return resolved;
    }

    return value;
  }

  static List<String> _collectLocalPhotoPaths(dynamic value) {
    final paths = <String>[];

    void walk(dynamic current) {
      if (current is Map) {
        final map = Map<String, dynamic>.from(current);
        final path = map[localPhotoKey]?.toString();
        if (path != null && path.isNotEmpty) paths.add(path);
        for (final entry in map.entries) {
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
