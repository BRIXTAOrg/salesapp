import 'dart:io';

import '../config/field_api.dart';
import '../database/app_database.dart';
import '../services/media/local_photo_store.dart';

class OfflineSubmissionQueue {
  OfflineSubmissionQueue._();

  static const _cacheKey = 'pending_dynamic_submissions';
  static const localPhotoKey = '__localPhotoPath';

  static Future<void> enqueue(Map<String, dynamic> submission) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);

    final queue = <Map<String, dynamic>>[
      if (existing is List)
        ...existing.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
    ];

    final id = submission['clientMutationId']?.toString();
    if (id != null &&
        queue.any((item) => item['clientMutationId']?.toString() == id)) {
      return;
    }

    queue.add(submission);
    await AppDatabase.instance.putCache(_cacheKey, queue);
  }

  static Future<int> pendingCount() async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    return existing is List ? existing.length : 0;
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

  static Future<int> flush(String accessToken) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    if (existing is! List || existing.isEmpty) return 0;

    final queue = existing
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final remaining = <Map<String, dynamic>>[];
    final api = FieldApi(accessToken: accessToken);

    for (final original in queue) {
      final localPaths = _collectLocalPhotoPaths(original);

      try {
        final prepared = await prepareForUpload(
          accessToken,
          original,
        );

        await api.postJson('/api/salesApp/submissions', prepared);

        for (final path in localPaths) {
          await LocalPhotoStore.delete(path);
        }
      } catch (_) {
        remaining.add(original);
      }
    }

    await AppDatabase.instance.putCache(_cacheKey, remaining);
    return remaining.length;
  }

  static Future<dynamic> _resolveValue(
    FieldApi api,
    dynamic value,
  ) async {
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

        if (path != null && path.isNotEmpty) {
          paths.add(path);
        }

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
