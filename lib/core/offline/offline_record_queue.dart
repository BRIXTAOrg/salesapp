import 'dart:io';

import '../config/field_api.dart';
import '../database/app_database.dart';
import '../services/media/local_photo_store.dart';

/// Offline queue for the generic Responsibility CRUD API.
///
/// Queue items store the HTTP method + generic record path instead of a
/// business-specific submission type. Media values may contain a local file
/// marker and are uploaded immediately before the queued mutation is sent.
class OfflineRecordQueue {
  OfflineRecordQueue._();

  static const _cacheKey = 'pending_responsibility_records_v1';
  static const localPhotoKey = '__localPhotoPath';

  static Future<void> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
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
              (item['body'] as Map)['clientMutationId']?.toString() ==
                  mutationId,
        )) {
      return;
    }

    queue.add({
      'method': method.toUpperCase(),
      'path': path,
      'body': body,
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

  static Future<int> flush(String accessToken) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    if (existing is! List || existing.isEmpty) return 0;

    final queue = existing
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final remaining = <Map<String, dynamic>>[];
    final api = FieldApi(accessToken: accessToken);

    for (final item in queue) {
      final bodyRaw = item['body'];
      final path = item['path']?.toString();
      final method = item['method']?.toString().toUpperCase();

      if (bodyRaw is! Map || path == null || path.isEmpty) {
        continue;
      }

      final body = Map<String, dynamic>.from(bodyRaw);
      final localPaths = _collectLocalPhotoPaths(body);

      try {
        final prepared = await prepareBodyForUpload(accessToken, body);

        switch (method) {
          case 'PATCH':
            await api.patchJson(path, prepared);
            break;
          case 'POST':
          default:
            await api.postJson(path, prepared);
            break;
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
