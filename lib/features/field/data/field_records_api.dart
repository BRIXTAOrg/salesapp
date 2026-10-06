import 'dart:convert';
import 'dart:io';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/services/media/local_photo_store.dart';
import 'field_logic.dart';

export 'field_logic.dart';

// BRIXTA_FIELD_APP_V1
//
// Field work on imported lists (Sites, Dealers, ...). Everything the screens
// show comes from the list's field-app config, which the CMS writes. Nothing
// here knows about construction sites.

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

List<String> _strings(Object? value) => value is List
    ? value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
    : <String>[];

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class FieldStage {
  const FieldStage({
    required this.key,
    required this.label,
    required this.tone,
    required this.closed,
  });

  factory FieldStage.fromJson(Map<String, dynamic> json) => FieldStage(
    key: json['key']?.toString() ?? 'new',
    label: json['label']?.toString() ?? 'Not visited',
    tone: json['tone']?.toString() ?? 'neutral',
    closed: json['closed'] == true,
  );

  final String key;
  final String label;
  final String tone;
  final bool closed;
}

/// Input types this app version can draw (BRIXTA_FIELD_APP_CONTRACT_V2).
const fieldInputTypes = {
  'text',
  'long_text',
  'number',
  'currency',
  'phone',
  'email',
  'date',
  'time',
  'choice',
  'multi_choice',
  'yes_no',
  'checkbox',
  'rating',
  'photos',
  'signature',
  'gps',
  'calculated',
  'note',
};

/// Inputs whose answer is a file on the phone until it is uploaded.
const fieldMediaTypes = {'photos', 'signature'};

class FieldInput {
  const FieldInput({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
    this.placeholder,
    this.unit,
    this.help,
    this.min,
    this.max,
    this.maxPhotos = 10,
    this.formula,
    this.decimals = 2,
    this.showWhen,
  });

  factory FieldInput.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'text';
    final maxPhotos = (json['maxPhotos'] as num?)?.toInt() ?? 0;
    return FieldInput(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      // A newer CMS may send a type this app doesn't know yet.
      type: fieldInputTypes.contains(type) ? type : 'text',
      required: json['required'] == true,
      options: _strings(json['options']),
      placeholder: json['placeholder']?.toString(),
      unit: json['unit']?.toString(),
      help: json['help']?.toString(),
      min: _double(json['min']),
      max: _double(json['max']),
      maxPhotos: maxPhotos > 0 ? maxPhotos : 10,
      formula: json['formula']?.toString(),
      decimals: (json['decimals'] as num?)?.toInt() ?? 2,
      showWhen: FieldCondition.fromJson(json['showWhen']),
    );
  }

  final String key;
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final String? placeholder;
  final String? unit;
  final String? help;
  final double? min;
  final double? max;
  final int maxPhotos;
  final String? formula;
  final int decimals;
  final FieldCondition? showWhen;

  bool get collects => type != 'note';
  bool get isMedia => fieldMediaTypes.contains(type);
  int get stars {
    final count = (max ?? 5).round();
    return count < 3 ? 3 : (count > 10 ? 10 : count);
  }
}

class FieldSection {
  const FieldSection({
    required this.key,
    required this.title,
    required this.requires,
    required this.fields,
    this.hint,
  });

  factory FieldSection.fromJson(Map<String, dynamic> json) => FieldSection(
    key: json['key']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    hint: json['hint']?.toString(),
    requires: _strings(json['requires']),
    fields: _maps(json['fields']).map(FieldInput.fromJson).toList(),
  );

  final String key;
  final String title;
  final String? hint;
  final List<String> requires;
  final List<FieldInput> fields;
}

class FieldListConfig {
  const FieldListConfig({
    required this.title,
    required this.stages,
    required this.sections,
    this.locationField,
  });

  factory FieldListConfig.fromJson(Map<String, dynamic> json) =>
      FieldListConfig(
        title: json['title']?.toString() ?? 'Field',
        locationField: json['locationField']?.toString(),
        stages: _maps(json['stages']).map(FieldStage.fromJson).toList(),
        sections: _maps(json['sections']).map(FieldSection.fromJson).toList(),
      );

  final String title;
  final String? locationField;
  final List<FieldStage> stages;
  final List<FieldSection> sections;

  FieldSection? section(String key) {
    for (final section in sections) {
      if (section.key == key) return section;
    }
    return null;
  }
}

class FieldList {
  const FieldList({
    required this.id,
    required this.key,
    required this.title,
    required this.config,
    required this.counts,
    required this.total,
  });

  factory FieldList.fromJson(Map<String, dynamic> json) => FieldList(
    id: (json['id'] as num?)?.toInt() ?? 0,
    key: json['key']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Field',
    config: FieldListConfig.fromJson(_map(json['config'])),
    counts: _map(
      json['counts'],
    ).map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
    total: (json['total'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String key;
  final String title;
  final FieldListConfig config;
  final Map<String, int> counts;
  final int total;
}

class FieldPoint {
  const FieldPoint(this.lat, this.lng);

  static FieldPoint? fromJson(Object? value) {
    final map = _map(value);
    final lat = _double(map['lat']);
    final lng = _double(map['lng']);
    if (lat == null || lng == null) return null;
    return FieldPoint(lat, lng);
  }

  final double lat;
  final double lng;
}

class FieldRecordSummary {
  const FieldRecordSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.stage,
    required this.stageLabel,
    required this.stageTone,
    required this.closed,
    this.key,
    this.priority,
    this.location,
    this.distanceM,
    this.followUpAt,
    this.lastVisitAt,
    this.lastVisitBy,
    this.assigneeName,
    this.assignedToMe = false,
  });

  factory FieldRecordSummary.fromJson(Map<String, dynamic> json) =>
      FieldRecordSummary(
        id: json['id']?.toString() ?? '',
        key: json['key']?.toString(),
        title: json['title']?.toString() ?? 'Untitled',
        subtitle: _strings(json['subtitle']),
        priority: _double(json['priority']),
        location: FieldPoint.fromJson(json['location']),
        distanceM: _double(json['distanceM']),
        stage: json['stage']?.toString() ?? 'new',
        stageLabel: json['stageLabel']?.toString() ?? 'Not visited',
        stageTone: json['stageTone']?.toString() ?? 'neutral',
        closed: json['closed'] == true,
        followUpAt: json['followUpAt']?.toString(),
        lastVisitAt: json['lastVisitAt']?.toString(),
        lastVisitBy: json['lastVisitBy']?.toString(),
        assigneeName: json['assigneeName']?.toString(),
        assignedToMe: json['assignedToMe'] == true,
      );

  final String id;
  final String? key;
  final String title;
  final List<String> subtitle;
  final double? priority;
  final FieldPoint? location;
  final double? distanceM;
  final String stage;
  final String stageLabel;
  final String stageTone;
  final bool closed;
  final String? followUpAt;
  final String? lastVisitAt;
  final String? lastVisitBy;
  final String? assigneeName;
  final bool assignedToMe;
}

class FieldSectionDone {
  const FieldSectionDone({required this.completedAt, this.byName});

  final String completedAt;
  final String? byName;
}

class FieldInfoItem {
  const FieldInfoItem(this.label, this.value);

  final String label;
  final String value;
}

class FieldRecordDetail {
  const FieldRecordDetail({
    required this.summary,
    required this.sections,
    required this.values,
    required this.info,
  });

  factory FieldRecordDetail.fromJson(Map<String, dynamic> json) {
    final sections = <String, FieldSectionDone>{};
    _map(json['sections']).forEach((key, value) {
      final item = _map(value);
      final at = item['completedAt']?.toString();
      if (at != null) {
        sections[key] = FieldSectionDone(
          completedAt: at,
          byName: item['byName']?.toString(),
        );
      }
    });
    return FieldRecordDetail(
      summary: FieldRecordSummary.fromJson(json),
      sections: sections,
      values: _map(json['values']),
      info: _maps(json['info'])
          .map(
            (item) => FieldInfoItem(
              item['label']?.toString() ?? '',
              item['value']?.toString() ?? '',
            ),
          )
          .where((item) => item.value.isNotEmpty)
          .toList(),
    );
  }

  final FieldRecordSummary summary;
  final Map<String, FieldSectionDone> sections;
  final Map<String, dynamic> values;
  final List<FieldInfoItem> info;
}

class FieldTimelineItem {
  const FieldTimelineItem({
    required this.at,
    required this.title,
    required this.detail,
    this.by,
  });

  factory FieldTimelineItem.fromJson(Map<String, dynamic> json) =>
      FieldTimelineItem(
        at: json['at']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
        by: json['by']?.toString(),
      );

  final String at;
  final String title;
  final String detail;
  final String? by;
}

class FieldRecordBundle {
  const FieldRecordBundle({
    required this.list,
    required this.record,
    required this.timeline,
  });

  factory FieldRecordBundle.fromJson(Map<String, dynamic> json) {
    final list = _map(json['list']);
    return FieldRecordBundle(
      list: FieldList.fromJson({...list, 'counts': const {}, 'total': 0}),
      record: FieldRecordDetail.fromJson(_map(json['record'])),
      timeline: _maps(json['timeline']).map(FieldTimelineItem.fromJson).toList(),
    );
  }

  final FieldList list;
  final FieldRecordDetail record;
  final List<FieldTimelineItem> timeline;
}

class FieldRecordPage {
  const FieldRecordPage({
    required this.items,
    required this.counts,
    required this.sortedBy,
  });

  factory FieldRecordPage.fromJson(Map<String, dynamic> json) =>
      FieldRecordPage(
        items: _maps(json['items']).map(FieldRecordSummary.fromJson).toList(),
        counts: _map(
          json['counts'],
        ).map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
        sortedBy: json['sortedBy']?.toString() ?? 'priority',
      );

  final List<FieldRecordSummary> items;
  final Map<String, int> counts;
  final String sortedBy;
}

/// Thin client + phone cache for the field endpoints.
class FieldRecordsApi {
  FieldRecordsApi(String accessToken) : _api = FieldApi(accessToken: accessToken);

  final FieldApi _api;

  static const _listsCache = 'field:lists';

  static String _pageCache(String listKey, String lens) =>
      'field:records:$listKey:$lens';

  static String _recordCache(String id) => 'field:record:$id';

  Future<List<FieldList>> lists() async {
    final body = await _api.getJson('/api/salesApp/field/lists');
    final raw = _maps(body['lists']);
    await AppDatabase.instance.putCache(_listsCache, raw);
    return raw.map(FieldList.fromJson).toList();
  }

  static Future<List<FieldList>> cachedLists() async {
    final cached = await AppDatabase.instance.getCache(_listsCache);
    return _maps(cached).map(FieldList.fromJson).toList();
  }

  Future<FieldRecordPage> records(
    String listKey, {
    required String lens,
    FieldPoint? origin,
    String query = '',
    int limit = 80,
  }) async {
    final params = <String, String>{
      'lens': lens,
      'limit': '$limit',
      if (origin != null) 'lat': origin.lat.toStringAsFixed(6),
      if (origin != null) 'lng': origin.lng.toStringAsFixed(6),
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final body = await _api.getJson(
      '/api/salesApp/field/lists/${Uri.encodeComponent(listKey)}/records?$qs',
    );
    if (query.trim().isEmpty) {
      await AppDatabase.instance.putCache(_pageCache(listKey, lens), body);
    }
    return FieldRecordPage.fromJson(body);
  }

  static Future<FieldRecordPage?> cachedRecords(
    String listKey,
    String lens,
  ) async {
    final cached = await AppDatabase.instance.getCache(
      _pageCache(listKey, lens),
    );
    if (cached is! Map) return null;
    return FieldRecordPage.fromJson(Map<String, dynamic>.from(cached));
  }

  Future<FieldRecordBundle> record(String id) async {
    final body = await _api.getJson(
      '/api/salesApp/field/records/${Uri.encodeComponent(id)}',
    );
    await AppDatabase.instance.putCache(_recordCache(id), body);
    return FieldRecordBundle.fromJson(body);
  }

  static Future<FieldRecordBundle?> cachedRecord(String id) async {
    final cached = await AppDatabase.instance.getCache(_recordCache(id));
    if (cached is! Map) return null;
    return FieldRecordBundle.fromJson(Map<String, dynamic>.from(cached));
  }

  Future<void> saveSection({
    required String recordId,
    required String sectionKey,
    required Map<String, dynamic> values,
    required String clientMutationId,
    Set<String>? mediaKeys,
  }) async {
    final ready = await uploadLocalMedia(values, mediaKeys: mediaKeys);
    await _api.postJson(
      '/api/salesApp/field/records/${Uri.encodeComponent(recordId)}'
      '/sections/${Uri.encodeComponent(sectionKey)}',
      {'values': ready, 'clientMutationId': clientMutationId},
    );
    await deleteLocalMedia(values, mediaKeys: mediaKeys);
  }

  /// Photo and signature answers hold uploaded URLs and/or files on the
  /// phone. Uploads the files and returns the values with URLs only.
  ///
  /// Only [mediaKeys] are looked at when given, so a multiple-choice answer
  /// is never mistaken for a file. Older offline saves have no list; for
  /// those only absolute paths of files that exist count.
  Future<Map<String, dynamic>> uploadLocalMedia(
    Map<String, dynamic> values, {
    Set<String>? mediaKeys,
  }) async {
    final ready = <String, dynamic>{};
    for (final entry in values.entries) {
      final value = entry.value;
      final isMedia = mediaKeys == null || mediaKeys.contains(entry.key);
      if (isMedia && value is List && value.any(isLocalFile)) {
        final urls = <String>[];
        for (final item in value) {
          final path = item.toString();
          if (isLocalFile(path)) {
            if (!await File(path).exists()) continue;
            final media = await _api.uploadMedia(path);
            urls.add(media['url'].toString());
          } else {
            urls.add(path);
          }
        }
        ready[entry.key] = urls;
      } else if (isMedia && value is String && isLocalFile(value)) {
        ready[entry.key] = await File(value).exists()
            ? (await _api.uploadMedia(value))['url'].toString()
            : null;
      } else {
        ready[entry.key] = value;
      }
    }
    return ready;
  }

  /// Files saved by this app live under an absolute app folder path.
  static bool isLocalFile(Object? value) {
    final text = value?.toString() ?? '';
    return text.startsWith('/') || text.startsWith('file://');
  }

  static Future<void> deleteLocalMedia(
    Map<String, dynamic> values, {
    Set<String>? mediaKeys,
  }) async {
    for (final entry in values.entries) {
      if (mediaKeys != null && !mediaKeys.contains(entry.key)) continue;
      final value = entry.value;
      final items = value is List ? value : [value];
      for (final item in items) {
        if (isLocalFile(item)) await LocalPhotoStore.delete(item.toString());
      }
    }
  }
}

/// Saves made without signal wait here and are sent when the phone is back
/// online. Each save carries a clientMutationId, so a retry never applies
/// twice on the server.
abstract final class FieldSectionQueue {
  static const queueName = 'field_sections';

  static String scopeFor(AuthSession session) =>
      '${session.tenant.code}:${session.user.id}';

  static Future<void> enqueue({
    required AuthSession session,
    required String recordId,
    required String sectionKey,
    required Map<String, dynamic> values,
    required String clientMutationId,
    Set<String> mediaKeys = const {},
  }) async {
    await AppDatabase.instance.enqueueOfflineQueueItem(
      queueName: queueName,
      scope: scopeFor(session),
      method: 'POST',
      path: '/api/salesApp/field/records/$recordId/sections/$sectionKey',
      payload: {
        'recordId': recordId,
        'sectionKey': sectionKey,
        'values': values,
        'clientMutationId': clientMutationId,
        'mediaKeys': mediaKeys.toList(),
      },
      clientMutationId: clientMutationId,
    );
  }

  static Future<int> pending(AuthSession session) =>
      AppDatabase.instance.offlineQueueCount(
        queueName: queueName,
        scope: scopeFor(session),
      );

  /// Returns how many saves are still waiting.
  static Future<int> flush(AuthSession session) async {
    final scope = scopeFor(session);
    final rows = await AppDatabase.instance.offlineQueueBatch(
      queueName: queueName,
      scope: scope,
      limit: 50,
    );
    final api = FieldRecordsApi(session.accessToken);
    final done = <String>[];

    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null) continue;

      Map<String, dynamic> payload;
      try {
        payload = Map<String, dynamic>.from(
          jsonDecode(row['payload_json']?.toString() ?? '{}') as Map,
        );
      } catch (_) {
        done.add(id);
        continue;
      }

      final values = _map(payload['values']);
      final mediaKeys = payload['mediaKeys'] is List
          ? _strings(payload['mediaKeys']).toSet()
          : null;

      try {
        await api.saveSection(
          recordId: payload['recordId'].toString(),
          sectionKey: payload['sectionKey'].toString(),
          values: values,
          clientMutationId: payload['clientMutationId'].toString(),
          mediaKeys: mediaKeys,
        );
        done.add(id);
      } on FieldApiException catch (error) {
        if (error.isSignInProblem) {
          // Signed out or switched off: keep the saves for the next sign-in.
          break;
        }
        final status = error.statusCode ?? 0;
        if (status >= 400 && status < 500 && status != 408 && status != 429) {
          // The server refused this save (record removed, step locked,
          // invalid value). Retrying will never succeed, so drop it and
          // free the photos it was holding on the phone.
          done.add(id);
          await FieldRecordsApi.deleteLocalMedia(values, mediaKeys: mediaKeys);
          continue;
        }
        break;
      } catch (_) {
        // No signal or server down: keep the rest for the next try.
        break;
      }
    }

    await AppDatabase.instance.deleteOfflineQueueItems(done);
    return AppDatabase.instance.offlineQueueCount(
      queueName: queueName,
      scope: scope,
    );
  }
}
