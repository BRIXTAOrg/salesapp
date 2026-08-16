import '../config/field_api.dart';
import '../database/app_database.dart';
import '../services/media/local_photo_store.dart';

class OfflineAttendanceQueue {
  OfflineAttendanceQueue._();

  static const _cacheKey = 'pending_attendance_events';

  static Future<void> enqueue(Map<String, dynamic> event) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    final queue = <Map<String, dynamic>>[
      if (existing is List)
        ...existing.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
    ];

    queue.add(Map<String, dynamic>.from(event));
    await AppDatabase.instance.putCache(_cacheKey, queue);
  }

  static Future<int> pendingCount() async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    return existing is List ? existing.length : 0;
  }

  static Future<int> flush(String accessToken) async {
    final existing = await AppDatabase.instance.getCache(_cacheKey);
    if (existing is! List || existing.isEmpty) return 0;

    final api = FieldApi(accessToken: accessToken);
    final queue = existing
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final remaining = <Map<String, dynamic>>[];

    for (final original in queue) {
      final event = Map<String, dynamic>.from(original);

      try {
        var photoUrl = event['photoUrl']?.toString();
        final photoPath = event['photoPath']?.toString();

        if ((photoUrl == null || photoUrl.isEmpty) &&
            photoPath != null &&
            photoPath.isNotEmpty) {
          photoUrl = await api.uploadPhoto(photoPath);
          event['photoUrl'] = photoUrl;
        }

        final kind = event['kind']?.toString();
        final attendanceId = event['attendanceId']?.toString();
        final latitude = event['latitude'];
        final longitude = event['longitude'];

        if (kind == 'in') {
          await api.postJson('/api/salesApp/attendance/in', {
            if (attendanceId != null && attendanceId.isNotEmpty)
              'id': attendanceId,
            'locationName':
                event['locationName']?.toString() ?? 'Field work',
            'inTimeLatitude': latitude,
            'inTimeLongitude': longitude,
            'inTimeImageUrl': photoUrl,
            'inTimeImageCaptured': photoUrl != null && photoUrl.isNotEmpty,
          });
        } else if (kind == 'out') {
          await api.patchJson('/api/salesApp/attendance/out', {
            if (attendanceId != null && attendanceId.isNotEmpty)
              'id': attendanceId,
            'outTimeLatitude': latitude,
            'outTimeLongitude': longitude,
            'outTimeImageUrl': photoUrl,
            'outTimeImageCaptured': photoUrl != null && photoUrl.isNotEmpty,
          });
        } else {
          continue;
        }

        await LocalPhotoStore.delete(photoPath);
      } catch (_) {
        remaining.add(event);
      }
    }

    await AppDatabase.instance.putCache(_cacheKey, remaining);
    return remaining.length;
  }
}
