import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/models/mobile_capability.dart';
import '../../../core/offline/offline_record_queue.dart';
import '../../../core/services/media/local_photo_store.dart';
import '../../../core/session/app_session_controller.dart';

/// Generic Responsibility app renderer.
///
/// The CMS defines:
///   definition.input.fields  -> data schema / primitive renderers
///   definition.app.actions   -> employee buttons + visibility + CRUD operation
///   definition.output        -> office-side projection
///
/// No business name (Attendance, Visit, Inspection, etc.) is special here.
class DynamicCapabilityScreen extends StatefulWidget {
  const DynamicCapabilityScreen({
    super.key,
    required this.controller,
    required this.capability,
  });

  final AppSessionController controller;
  final MobileCapability capability;

  @override
  State<DynamicCapabilityScreen> createState() =>
      _DynamicCapabilityScreenState();
}

class _DynamicCapabilityScreenState extends State<DynamicCapabilityScreen> {
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checks = {};
  final Map<String, String> _photos = {};
  final Map<String, String> _selects = {};
  final Map<String, Set<String>> _multiSelects = {};
  final Map<String, Map<String, dynamic>> _manualLocations = {};

  List<Map<String, dynamic>> _records = const [];
  bool _loading = true;
  String? _submittingActionKey;
  String _lastWorkspaceRevision = '';

  /// Resolve the live Responsibility from the refreshed workspace so an
  /// administrator can publish a changed app definition without requiring an
  /// APK release or a new login. The screen updates after the normal workspace
  /// refresh (or the refresh button) and falls back to the object it opened with.
  MobileCapability get _capability {
    final modules =
        widget.controller.session?.modules ?? const <MobileCapability>[];

    for (final item in modules) {
      if (item.key == widget.capability.key) return item;
    }

    return widget.capability;
  }

  String get _cacheKey =>
      'responsibility_records:${widget.controller.session!.user.id}:${_capability.key}';

  List<Map<String, dynamic>> get fields => _capability.fields;

  List<Map<String, dynamic>> get actions {
    final app = _capability.appDefinition;
    final raw = app['actions'];

    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    // Backward-compatible default: an old Responsibility with fields but no
    // app definition behaves like one simple Create form.
    return [
      {
        'key': 'submit',
        'label': 'Record',
        'operation': 'create',
        'status': 'submitted',
        'style': 'primary',
        'fieldKeys': visibleFields.map(_fieldKey).toList(),
        'requiredFieldKeys': visibleFields
            .where((field) => field['required'] == true)
            .map(_fieldKey)
            .toList(),
        'visibility': {'mode': 'always'},
        'successMessage': 'Recorded.',
      },
    ];
  }

  List<Map<String, dynamic>> get visibleFields => fields.where((field) {
    final config = _config(field);
    return config['hidden'] != true;
  }).toList();

  String? get latestStatus {
    /*
     * The absence of a record does NOT mean the Responsibility has
     * no state.
     *
     * Before the first employee action, the current state is the
     * initial state authored in the CMS Kernel.
     *
     * This keeps the installed Flutter runtime consistent with the
     * CMS Play App simulator.
     */
    if (_records.isNotEmpty) {
      return _records.first['status']?.toString();
    }

    final app = _capability.appDefinition;

    final configRaw = app['config'];

    final config = configRaw is Map
        ? Map<String, dynamic>.from(configRaw)
        : <String, dynamic>{};

    final initial = config['initialState']?.toString();

    if (initial == null || initial.trim().isEmpty) {
      return null;
    }

    return initial;
  }

  @override
  void initState() {
    super.initState();

    _lastWorkspaceRevision = widget.controller.workspaceRevision;

    widget.controller.addListener(_onWorkspaceChanged);

    _loadRecords();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onWorkspaceChanged);

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  void _onWorkspaceChanged() {
    if (!mounted) return;

    final revision = widget.controller.workspaceRevision;

    if (revision.isEmpty || revision == _lastWorkspaceRevision) {
      return;
    }

    _lastWorkspaceRevision = revision;

    // _capability resolves against the refreshed session.modules,
    // so the currently-open screen immediately sees the CMS definition.
    setState(() {});

    unawaited(_loadRecords());
  }

  Future<void> _loadRecords() async {
    final session = widget.controller.session;
    if (session == null) return;

    if (mounted) setState(() => _loading = true);

    try {
      if (widget.controller.isOnline) {
        await OfflineRecordQueue.flush(session.accessToken);

        final body = await FieldApi(accessToken: session.accessToken).getJson(
          '/api/salesApp/records/${Uri.encodeComponent(_capability.key)}?limit=50',
        );

        final raw = body['records'];
        final records = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];

        await AppDatabase.instance.putCache(_cacheKey, records);
        if (mounted) setState(() => _records = records);
      } else {
        await _loadCachedRecords();
      }
    } catch (_) {
      await _loadCachedRecords();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCachedRecords() async {
    final cached = await AppDatabase.instance.getCache(_cacheKey);
    if (cached is List && mounted) {
      setState(() {
        _records = cached
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    }
  }

  Future<void> _capturePhoto(String key) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 76,
        maxWidth: 1440,
      );

      if (picked == null) return;

      final persisted = await LocalPhotoStore.persist(
        picked,
        prefix: '${_capability.key}-$key',
      );

      await LocalPhotoStore.delete(_photos[key]);
      if (mounted) setState(() => _photos[key] = persisted);
    } catch (error) {
      if (mounted) _message('Could not open camera: $error');
    }
  }

  Future<Map<String, dynamic>?> _currentLocation({
    bool required = false,
  }) async {
    try {
      final services = await Geolocator.isLocationServiceEnabled();
      if (!services) {
        if (required) _message('Turn on location services to continue.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (required) {
          _message('Location permission is required for this action.');
        }
        return null;
      }

      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return {
        'lat': fix.latitude,
        'lng': fix.longitude,
        'accuracy': fix.accuracy,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
      };
    } catch (error) {
      if (required) _message('Could not capture location: $error');
      return null;
    }
  }

  Future<void> _captureManualLocation(String key) async {
    final value = await _currentLocation(required: true);
    if (value != null && mounted) {
      setState(() => _manualLocations[key] = value);
    }
  }

  bool _actionVisible(Map<String, dynamic> action) {
    final visibilityRaw = action['visibility'];
    final visibility = visibilityRaw is Map
        ? Map<String, dynamic>.from(visibilityRaw)
        : <String, dynamic>{};

    final mode = (visibility['mode'] ?? 'always').toString();
    final expected = visibility['status']?.toString();
    final latest = latestStatus;

    switch (mode) {
      case 'no_record':
        return _records.isEmpty;
      case 'latest_status_is':
        return expected != null && latest == expected;
      case 'latest_status_is_not':
        return expected != null && latest != expected;
      default:
        return true;
    }
  }

  Map<String, dynamic>? _targetRecord(Map<String, dynamic> action) {
    final targetRaw = action['target'];
    final target = targetRaw is Map
        ? Map<String, dynamic>.from(targetRaw)
        : <String, dynamic>{};

    final expectedStatus = target['status']?.toString();
    if (expectedStatus != null && expectedStatus.isNotEmpty) {
      for (final record in _records) {
        if (record['status']?.toString() == expectedStatus) return record;
      }
      return null;
    }

    return _records.isEmpty ? null : _records.first;
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    final actionKey = (action['key'] ?? 'action').toString();
    if (_submittingActionKey != null) return;

    setState(() => _submittingActionKey = actionKey);

    try {
      final selectedKeys = _stringList(action['fieldKeys']);
      final requiredKeys = _stringList(action['requiredFieldKeys']).toSet();
      final selectedFields = fields.where(
        (field) => selectedKeys.contains(_fieldKey(field)),
      );

      final payload = <String, dynamic>{};
      final localPhotoPaths = <String>[];

      for (final field in selectedFields) {
        final key = _fieldKey(field);
        final type = _fieldType(field);
        final required =
            requiredKeys.contains(key) || field['required'] == true;
        final value = _valueForField(field);

        if (_isEmptyValue(value)) {
          if (required) {
            _message('${_fieldLabel(field)} is required.');
            return;
          }
          continue;
        }

        if (_isPhotoType(type) && value is Map) {
          final path = value[OfflineRecordQueue.localPhotoKey]?.toString();
          if (path != null && path.isNotEmpty) localPhotoPaths.add(path);
        }

        payload[key] = value;
      }

      final captureRaw = action['capture'];
      final capture = captureRaw is Map
          ? Map<String, dynamic>.from(captureRaw)
          : <String, dynamic>{};
      final locationRaw = capture['location'];

      if (locationRaw is Map) {
        final location = Map<String, dynamic>.from(locationRaw);
        final fieldKey = location['fieldKey']?.toString();
        final required = location['required'] == true;

        if (fieldKey != null && fieldKey.isNotEmpty) {
          final fix = await _currentLocation(required: required);
          if (fix == null && required) return;
          if (fix != null) payload[fieldKey] = fix;
        }
      }

      final operation = (action['operation'] ?? 'create').toString();
      final status = (action['status'] ?? 'submitted').toString();
      final now = DateTime.now().toUtc().toIso8601String();
      final api = FieldApi(accessToken: widget.controller.session!.accessToken);

      String method;
      String path;
      Map<String, dynamic> body;

      if (operation == 'update') {
        final target = _targetRecord(action);
        if (target == null || target['id'] == null) {
          _message('There is no matching record to update yet.');
          return;
        }

        method = 'PATCH';
        path =
            '/api/salesApp/records/${Uri.encodeComponent(_capability.key)}/${Uri.encodeComponent(target['id'].toString())}';
        body = {
          'payload': payload,
          'status': status,
          'appActionKey': actionKey,
        };
      } else {
        method = 'POST';
        path = '/api/salesApp/records/${Uri.encodeComponent(_capability.key)}';
        body = {
          'clientMutationId': AppDatabase.instance.newId(),
          'clientCreatedAt': now,
          'payload': payload,
          'status': status,
          'appActionKey': actionKey,
        };
      }

      Map<String, dynamic>? response;

      if (widget.controller.isOffline) {
        await OfflineRecordQueue.enqueue(
          method: method,
          path: path,
          body: body,
        );
        _applyOptimisticRecord(
          operation: operation,
          target: operation == 'update' ? _targetRecord(action) : null,
          body: body,
          now: now,
        );
      } else {
        try {
          final prepared = await OfflineRecordQueue.prepareBodyForUpload(
            widget.controller.session!.accessToken,
            body,
          );
          response = method == 'PATCH'
              ? await api.patchJson(path, prepared)
              : await api.postJson(path, prepared);

          for (final localPath in localPhotoPaths) {
            await LocalPhotoStore.delete(localPath);
          }
        } catch (error) {
          // CREATE mutations are safe to queue because clientMutationId makes
          // them idempotent. UPDATE is also queued when it targets a known
          // server record ID from the local record cache.
          await OfflineRecordQueue.enqueue(
            method: method,
            path: path,
            body: body,
          );
          _applyOptimisticRecord(
            operation: operation,
            target: operation == 'update' ? _targetRecord(action) : null,
            body: body,
            now: now,
          );
        }
      }

      if (response != null && response['record'] is Map) {
        final record = Map<String, dynamic>.from(response['record'] as Map);
        _mergeServerRecord(record);
      }

      _clearActionFields(selectedKeys);
      await AppDatabase.instance.putCache(_cacheKey, _records);

      await HapticFeedback.lightImpact();
      if (!mounted) return;

      _message(
        (action['successMessage'] ??
                (widget.controller.isOffline
                    ? 'Safe on this phone. It will sync automatically.'
                    : 'Recorded.'))
            .toString(),
      );

      if (widget.controller.isOnline) {
        await _loadRecords();
      }
    } finally {
      if (mounted) setState(() => _submittingActionKey = null);
    }
  }

  void _applyOptimisticRecord({
    required String operation,
    required Map<String, dynamic>? target,
    required Map<String, dynamic> body,
    required String now,
  }) {
    final payload = body['payload'] is Map
        ? Map<String, dynamic>.from(body['payload'] as Map)
        : <String, dynamic>{};
    final status = body['status']?.toString() ?? 'submitted';

    setState(() {
      if (operation == 'update' && target != null) {
        final id = target['id']?.toString();
        _records = _records.map((record) {
          if (record['id']?.toString() != id) return record;
          final existingPayload = record['payload'] is Map
              ? Map<String, dynamic>.from(record['payload'] as Map)
              : <String, dynamic>{};
          return {
            ...record,
            'status': status,
            'payload': {...existingPayload, ...payload},
            'updatedAt': now,
          };
        }).toList();
      } else {
        _records = [
          {
            'id': body['clientMutationId'] ?? AppDatabase.instance.newId(),
            'status': status,
            'payload': payload,
            'createdAt': now,
            'updatedAt': now,
            '_optimistic': true,
          },
          ..._records,
        ];
      }
    });
  }

  void _mergeServerRecord(Map<String, dynamic> record) {
    final id = record['id']?.toString();
    if (id == null) return;

    setState(() {
      final withoutSame = _records
          .where((item) => item['id']?.toString() != id)
          .toList();
      _records = [record, ...withoutSame];
    });
  }

  void _clearActionFields(List<String> fieldKeys) {
    setState(() {
      for (final key in fieldKeys) {
        _controllers[key]?.clear();
        _checks.remove(key);
        _selects.remove(key);
        _multiSelects.remove(key);
        _manualLocations.remove(key);
        _photos.remove(key);
      }
    });
  }

  dynamic _valueForField(Map<String, dynamic> field) {
    final key = _fieldKey(field);
    final type = _fieldType(field);

    if (_isPhotoType(type)) {
      final path = _photos[key];
      return path == null || path.isEmpty
          ? null
          : {OfflineRecordQueue.localPhotoKey: path};
    }

    if (type == 'checkbox' || type == 'toggle' || type == 'boolean') {
      return _checks[key] ?? false;
    }

    if (type == 'select' || type == 'choice' || type == 'dropdown') {
      return _selects[key];
    }

    if (type == 'multi_select') {
      return (_multiSelects[key] ?? <String>{}).toList();
    }

    if (type == 'location_point') {
      return _manualLocations[key];
    }

    final text = _controllerFor(key).text.trim();
    if (text.isEmpty) return null;

    if (type == 'number' || type == 'currency') {
      return double.tryParse(text);
    }
    if (type == 'integer') {
      return int.tryParse(text);
    }

    return text;
  }

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final capability = _capability;
    final visibleActions = actions.where(_actionVisible).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(capability.title),
        actions: [
          IconButton(
            tooltip: 'Refresh app definition and records',
            onPressed: _loading
                ? null
                : () async {
                    await widget.controller.refreshWorkspace();
                    await _loadRecords();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.controller.refreshWorkspace();
          await _loadRecords();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            _ResponsibilityIntro(
              capability: capability,
              actionCount: actions.length,
              latestStatus: latestStatus,
            ),
            const SizedBox(height: 32),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2)
            else if (visibleActions.isEmpty)
              const _QuietState()
            else
              for (var i = 0; i < visibleActions.length; i++) ...[
                _ActionCard(
                  action: visibleActions[i],
                  fields: fields,
                  submitting:
                      _submittingActionKey ==
                      visibleActions[i]['key']?.toString(),
                  buildField: _buildField,
                  onRun: () => _runAction(visibleActions[i]),
                ),
                if (i != visibleActions.length - 1) const SizedBox(height: 20),
              ],
            if (_records.isNotEmpty) ...[
              const SizedBox(height: 40),
              const _SectionLabel('RECENT'),
              const SizedBox(height: 12),
              for (final record in _records.take(5)) _RecordRow(record: record),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final label = _fieldLabel(field);
    final key = _fieldKey(field);
    final type = _fieldType(field);
    final config = _config(field);
    final helpText = config['helpText']?.toString();

    if (_isPhotoType(type)) {
      return _PhotoField(
        label: label,
        path: _photos[key],
        helpText: helpText,
        onTap: () => _capturePhoto(key),
      );
    }

    if (type == 'checkbox' || type == 'toggle' || type == 'boolean') {
      return Container(
        decoration: BoxDecoration(
          color: AppDesign.surface,
          border: Border.all(color: AppDesign.line),
          borderRadius: BorderRadius.circular(AppDesign.radius),
        ),
        child: CheckboxListTile(
          value: _checks[key] ?? false,
          onChanged: (value) {
            setState(() => _checks[key] = value ?? false);
          },
          title: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: helpText == null ? null : Text(helpText),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
        ),
      );
    }

    if (type == 'select' || type == 'choice' || type == 'dropdown') {
      final options = _stringList(config['options']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selects[key],
            isExpanded: true,
            hint: Text(config['placeholder']?.toString() ?? 'Choose one'),
            items: options
                .map(
                  (option) =>
                      DropdownMenuItem(value: option, child: Text(option)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selects[key] = value);
            },
          ),
          if (helpText != null) ...[
            const SizedBox(height: 6),
            Text(helpText, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
    }

    if (type == 'multi_select') {
      final options = _stringList(config['options']);
      final selected = _multiSelects.putIfAbsent(key, () => <String>{});
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => FilterChip(
                    label: Text(option),
                    selected: selected.contains(option),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selected.add(option);
                        } else {
                          selected.remove(option);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    if (type == 'location_point') {
      final location = _manualLocations[key];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _captureManualLocation(key),
            icon: const Icon(Icons.location_on_outlined),
            label: Text(
              location == null
                  ? 'Use current location'
                  : '${location['lat']}, ${location['lng']}',
            ),
          ),
        ],
      );
    }

    final isLongText =
        type == 'textarea' || type == 'multiline' || type == 'notes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 8),
        TextField(
          controller: _controllerFor(key),
          maxLines: isLongText ? 4 : 1,
          keyboardType:
              type == 'number' || type == 'currency' || type == 'integer'
              ? const TextInputType.numberWithOptions(decimal: true)
              : type == 'date' || type == 'datetime'
              ? TextInputType.datetime
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: config['placeholder']?.toString() ?? 'Enter $label',
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 6),
          Text(helpText, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  static Map<String, dynamic> _config(Map<String, dynamic> field) {
    final raw = field['config'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static String _fieldKey(Map<String, dynamic> field) =>
      (field['key'] ?? field['name'] ?? field['label'] ?? 'field').toString();

  static String _fieldLabel(Map<String, dynamic> field) =>
      (field['label'] ?? _fieldKey(field)).toString();

  static String _fieldType(Map<String, dynamic> field) =>
      (field['inputType'] ?? field['type'] ?? 'text').toString().toLowerCase();

  static bool _isPhotoType(String type) =>
      type == 'photo' ||
      type == 'image' ||
      type == 'camera' ||
      type == 'upload_photo';

  static List<String> _stringList(dynamic value) => value is List
      ? value.map((item) => item.toString()).toList()
      : <String>[];
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.fields,
    required this.submitting,
    required this.buildField,
    required this.onRun,
  });

  final Map<String, dynamic> action;
  final List<Map<String, dynamic>> fields;
  final bool submitting;
  final Widget Function(Map<String, dynamic>) buildField;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final fieldKeys = action['fieldKeys'] is List
        ? (action['fieldKeys'] as List).map((item) => item.toString()).toSet()
        : <String>{};
    final selected = fields.where(
      (field) => fieldKeys.contains(
        (field['key'] ?? field['name'] ?? field['label']).toString(),
      ),
    );
    final label = (action['label'] ?? 'Record').toString();
    final style = (action['style'] ?? 'primary').toString();
    final capture = action['capture'];
    final hasAutoLocation = capture is Map && capture['location'] is Map;

    final ButtonStyle? buttonStyle = style == 'danger'
        ? FilledButton.styleFrom(backgroundColor: AppDesign.red)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final field in selected) ...[
              buildField(field),
              const SizedBox(height: 18),
            ],
          ],
          if (hasAutoLocation) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppDesign.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current location will be attached automatically',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: style == 'secondary'
                ? OutlinedButton(
                    onPressed: submitting ? null : onRun,
                    child: submitting ? _spinner() : Text(label),
                  )
                : FilledButton(
                    style: buttonStyle,
                    onPressed: submitting ? null : onRun,
                    child: submitting ? _spinner() : Text(label),
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _spinner() => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

class _ResponsibilityIntro extends StatelessWidget {
  const _ResponsibilityIntro({
    required this.capability,
    required this.actionCount,
    required this.latestStatus,
  });

  final MobileCapability capability;
  final int actionCount;
  final String? latestStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppDesign.softGray,
            borderRadius: BorderRadius.circular(AppDesign.radius),
            border: Border.all(color: AppDesign.line),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.forCapability(capability),
            size: 20,
            color: AppDesign.ink,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                capability.description?.trim().isNotEmpty == true
                    ? capability.description!.trim()
                    : 'Complete the actions configured by your administrator.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '$actionCount ${actionCount == 1 ? 'action' : 'actions'}'
                '${latestStatus == null ? '' : ' · latest: $latestStatus'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuietState extends StatelessWidget {
  const _QuietState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AppDesign.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'There is no action available in the current record state.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final status = record['status']?.toString() ?? 'recorded';
    final when = record['updatedAt'] ?? record['createdAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_outlined, size: 16, color: AppDesign.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.replaceAll('_', ' '),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (when != null)
            Text(
              _shortTime(when.toString()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  static String _shortTime(String raw) {
    final value = DateTime.tryParse(raw)?.toLocal();
    if (value == null) return '';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.path,
    required this.onTap,
    this.helpText,
  });

  final String label;
  final String? path;
  final VoidCallback onTap;
  final String? helpText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(helpText!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Material(
          color: AppDesign.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radius),
            side: const BorderSide(color: AppDesign.line),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDesign.radius),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: path != null && path!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppDesign.radius - 1),
                      child: Image.file(File(path!), fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 28,
                          color: AppDesign.ink,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Take photo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppDesign.ink,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppDesign.ink,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppDesign.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
