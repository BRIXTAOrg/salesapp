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
import '../../../core/services/runtime/responsibility_runtime_api.dart';
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
    this.initialRecordId,
    this.workflowInstanceId,
  });

  final AppSessionController controller;
  final MobileCapability capability;

  /// Concrete Responsibility record supplied by My Work / actor delegation.
  final String? initialRecordId;

  /// Preserved when the Responsibility is participating in a workflow.
  final String? workflowInstanceId;

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

  // BRIXTA_PIXEL_REALITY_ACTOR_PROJECTION
  //
  // These are calculated by the Kernel for:
  //
  // current user + current Responsibility + current record + current state.
  //
  // They are authoritative while online.
  List<Map<String, dynamic>> _runtimeActions = const [];
  List<Map<String, dynamic>> _runtimeOutputs = const [];

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

  // BRIXTA_RESPONSIBILITY_INSTANCE_MODE_V1
  //
  // continuing:
  //   operate the current/latest business record.
  //
  // repeatable:
  //   opening the Responsibility represents a NEW instance even when
  //   historical records already exist.
  //
  // A concrete initialRecordId always wins. That is how manager/reviewer
  // delegation and returned-record editing remain record-specific.
  String get _instanceMode {
    final rawConfig = _capability.appDefinition['config'];

    final config = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};

    final value = config['instanceMode']?.toString().trim().toLowerCase();

    return value == 'repeatable' ? 'repeatable' : 'continuing';
  }

  bool get _hasConcreteRecordContext =>
      widget.initialRecordId != null &&
      widget.initialRecordId!.trim().isNotEmpty;

  bool get _isRepeatableRootContext =>
      !_hasConcreteRecordContext && _instanceMode == 'repeatable';

  String? get _initialState {
    final rawConfig = _capability.appDefinition['config'];

    final config = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};

    final value = config['initialState']?.toString().trim();

    return value == null || value.isEmpty ? null : value;
  }

  /*
   * Action visibility is NOT necessarily the same thing as historical
   * latest-record status.
   *
   * For a repeatable Responsibility, the root screen represents a fresh
   * instance, so actions evaluate from the initial state even though
   * RECENT/history can contain pending/approved/rejected records.
   */
  String? get _actionStatus =>
      _isRepeatableRootContext ? _initialState : latestStatus;

  Map<String, dynamic> _runtimeActionToAppAction(Map<String, dynamic> action) {
    final kind = (action['kind'] ?? 'update').toString();

    final configRaw = action['config'];
    final config = configRaw is Map
        ? Map<String, dynamic>.from(configRaw)
        : <String, dynamic>{};

    final captureIds = action['captureIds'] is List
        ? (action['captureIds'] as List).map((item) => item.toString()).toList()
        : <String>[];

    // Kernel capture IDs are semantic IDs. Flutter form actions operate
    // on the compiled field key, so map the two properly.
    final fieldKeys = captureIds.map((captureId) {
      for (final field in fields) {
        final fieldConfig = _config(field);

        if (_fieldKey(field) == captureId ||
            fieldConfig['kernelPossibilityId']?.toString() == captureId) {
          return _fieldKey(field);
        }
      }

      return captureId;
    }).toList();

    final requiredFieldKeys = fieldKeys.where((fieldKey) {
      for (final field in fields) {
        if (_fieldKey(field) == fieldKey) {
          return field['required'] == true;
        }
      }
      return false;
    }).toList();

    final explicitResult = config['resultingState']?.toString();

    final createKind = kind == 'create' || kind == 'submit' || kind == 'start';

    /*
     * Record existence alone must NEVER decide whether a business action
     * creates a new instance.
     *
     * repeatable root:
     *   historical records may exist, but submit/start/create means NEW.
     *
     * concrete delegated/history record:
     *   submit/start may represent resubmit/restart of THAT record.
     *
     * continuing root:
     *   preserve the previous latest-record behaviour.
     */
    final operation = createKind
        ? (_hasConcreteRecordContext ||
                  (!_isRepeatableRootContext && _records.isNotEmpty)
              ? 'update'
              : 'create')
        : 'update';

    return {
      'key': (action['id'] ?? action['key'] ?? kind).toString(),

      'label': (action['label'] ?? kind).toString(),

      'operation': operation,

      'status': explicitResult ?? kind,

      'style': const {'reject', 'cancel', 'delete'}.contains(kind)
          ? 'danger'
          : const {'approve', 'submit', 'start', 'complete'}.contains(kind)
          ? 'primary'
          : 'secondary',

      'fieldKeys': fieldKeys,

      'requiredFieldKeys': requiredFieldKeys,

      // Kernel has ALREADY evaluated actor/state/condition visibility.
      'visibility': {'mode': 'always'},

      if (operation == 'update') 'target': {'strategy': 'latest_record'},

      'successMessage':
          config['successMessage']?.toString() ??
          '${action['label'] ?? kind} completed.',
    };
  }

  List<Map<String, dynamic>> get actions {
    if (_runtimeActions.isNotEmpty) {
      return _runtimeActions.map(_runtimeActionToAppAction).toList();
    }

    /*
     * A delegated participant MUST NOT fall back to the employee's
     * static/global action list. If Kernel runtime isn't available,
     * delegated work becomes read-only instead of leaking authority.
     */
    if (widget.initialRecordId != null && widget.initialRecordId!.isNotEmpty) {
      return const [];
    }

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

  bool get employeeOwnHistoryVisible {
    final rawConfig = _capability.appDefinition['config'];
    final config = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};

    return config['employeeOwnHistoryVisible'] != false;
  }

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
    _autoPopulateFields();
  }

  /// Location and date/time are things the device already knows -- a
  /// person shouldn't have to tap "Use current location" or type a
  /// timestamp by hand before every check-in. Pre-fill both the moment
  /// the screen opens. (Some actions separately re-sample location fresh
  /// at submit time via `action.capture.location` -- unrelated to this,
  /// that path already worked; this covers plain `location_point` /
  /// `date` / `datetime` fields that had no auto-fill at all.)
  void _autoPopulateFields() {
    for (final field in fields) {
      final type = _fieldType(field);
      final key = _fieldKey(field);

      if (type == 'location_point' || type == 'gps') {
        unawaited(_captureManualLocation(key));
      } else if (type == 'date' || type == 'datetime') {
        _controllerFor(key).text = _formatIstNow(withTime: type == 'datetime');
      }
    }
  }

  /// India runs one fixed UTC+5:30 offset year-round (no DST), so a plain
  /// offset add is correct here without pulling in the `timezone` package.
  static String _formatIstNow({required bool withTime}) {
    final ist = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final datePart =
        '${ist.year.toString().padLeft(4, '0')}-'
        '${ist.month.toString().padLeft(2, '0')}-'
        '${ist.day.toString().padLeft(2, '0')}';
    if (!withTime) return datePart;

    final hour12 = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final period = ist.hour < 12 ? 'AM' : 'PM';
    return '$datePart $hour12:$minute $period';
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

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      if (widget.controller.isOnline) {
        await OfflineRecordQueue.flush(session.accessToken);

        final runtimeApi = ResponsibilityRuntimeApi(
          accessToken: session.accessToken,
        );

        /*
         * BRIXTA_PIXEL_REALITY_RUNTIME_LOAD
         *
         * DYNAMIC PARTICIPANT PATH
         *
         * Manager / reviewer / other actor opens one concrete record.
         * Do NOT use /records because that legacy endpoint is "my own records".
         */
        if (widget.initialRecordId != null &&
            widget.initialRecordId!.isNotEmpty) {
          final runtime = await runtimeApi.runtime(
            _capability.key,
            recordId: widget.initialRecordId,
          );

          final recordRaw = runtime['record'];

          final record = recordRaw is Map
              ? Map<String, dynamic>.from(recordRaw)
              : <String, dynamic>{};

          final possibilitiesRaw = runtime['possibilities'];

          final possibilities = possibilitiesRaw is Map
              ? Map<String, dynamic>.from(possibilitiesRaw)
              : <String, dynamic>{};

          final actionRaw = possibilities['actions'];

          final outputRaw = possibilities['outputs'];

          final runtimeActions = actionRaw is List
              ? actionRaw
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : <Map<String, dynamic>>[];

          final runtimeOutputs = outputRaw is List
              ? outputRaw
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : <Map<String, dynamic>>[];

          final records = record.isEmpty ? <Map<String, dynamic>>[] : [record];

          await AppDatabase.instance.putCache(_cacheKey, records);

          if (mounted) {
            setState(() {
              _records = records;
              _runtimeActions = runtimeActions;
              _runtimeOutputs = runtimeOutputs;
            });
          }

          return;
        }

        /*
         * NORMAL ASSIGNED EMPLOYEE PATH
         *
         * Keep existing own-record history for compatibility,
         * but get AVAILABLE ACTIONS + OUTPUTS from Kernel.
         */
        final body = await FieldApi(accessToken: session.accessToken).getJson(
          '/api/salesApp/records/'
          '${Uri.encodeComponent(_capability.key)}'
          '?limit=50',
        );

        final raw = body['records'];

        final records = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];

        List<Map<String, dynamic>> runtimeActions = const [];

        List<Map<String, dynamic>> runtimeOutputs = const [];

        try {
          /*
           * A repeatable Responsibility's root screen is a NEW-instance
           * projection. Historical records remain loaded below for history,
           * but must not become the Kernel action context.
           *
           * Continuing Responsibilities preserve latest-record semantics.
           */
          final runtime = await runtimeApi.runtime(
            _capability.key,
            recordId: _isRepeatableRootContext
                ? null
                : records.isNotEmpty
                ? records.first['id']?.toString()
                : null,
          );

          final possibilitiesRaw = runtime['possibilities'];

          final possibilities = possibilitiesRaw is Map
              ? Map<String, dynamic>.from(possibilitiesRaw)
              : <String, dynamic>{};

          final actionRaw = possibilities['actions'];

          final outputRaw = possibilities['outputs'];

          runtimeActions = actionRaw is List
              ? actionRaw
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : const [];

          runtimeOutputs = outputRaw is List
              ? outputRaw
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : const [];
        } catch (_) {
          /*
           * Legacy Responsibilities can still use their compiled static
           * action contract while migration is in progress.
           */
        }

        await AppDatabase.instance.putCache(_cacheKey, records);

        if (mounted) {
          setState(() {
            _records = records;
            _runtimeActions = runtimeActions;
            _runtimeOutputs = runtimeOutputs;
          });
        }
      } else {
        await _loadCachedRecords();
      }
    } catch (error) {
      /*
       * Delegated authority is online/Kernel-authoritative.
       * Never invent manager actions from stale/static UI while offline.
       */
      if (widget.initialRecordId != null &&
          widget.initialRecordId!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _runtimeActions = const [];
            _runtimeOutputs = const [];
          });
        }
      }

      await _loadCachedRecords();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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

  /// Same interaction pattern already used elsewhere in the app
  /// (kernel_responsibility_screen.dart's _pickDate) -- a native picker
  /// instead of asking someone to type a date by hand. Writes into the
  /// field's own text controller so _valueForField's existing fallback
  /// keeps working unchanged.
  Future<void> _pickDate(String key, {required bool withTime}) async {
    final controller = _controllerFor(key);
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();

    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (day == null || !mounted) return;

    DateTime value = day;
    if (withTime) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;
      value = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }

    final datePart =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    if (!withTime) {
      setState(() => controller.text = datePart);
      return;
    }

    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    setState(() => controller.text = '$datePart $hour12:$minute $period');
  }

  bool _actionVisible(Map<String, dynamic> action) {
    final visibilityRaw = action['visibility'];
    final visibility = visibilityRaw is Map
        ? Map<String, dynamic>.from(visibilityRaw)
        : <String, dynamic>{};

    final mode = (visibility['mode'] ?? 'always').toString();
    final expected = visibility['status']?.toString();

    /*
     * For repeatable root screens, the actionable state is the initial
     * state of a NEW instance, not the status of the newest history row.
     */
    final latest = _actionStatus;

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

      // BRIXTA_KERNEL_ACTION_API_V1
      //
      // Generated Responsibility actions must execute through the
      // canonical Kernel endpoint. Pixel Logic is attached to the
      // exact same action execution lifecycle.
      final target = operation == 'update' ? _targetRecord(action) : null;

      if (operation == 'update' && (target == null || target['id'] == null)) {
        _message('There is no matching record to update yet.');
        return;
      }

      final method = 'POST';

      final path =
          '/api/salesApp/responsibilities/'
          '${Uri.encodeComponent(_capability.key)}'
          '/actions/'
          '${Uri.encodeComponent(actionKey)}';

      final body = <String, dynamic>{
        'recordId': target?['id']?.toString(),

        'workflowInstanceId': widget.workflowInstanceId,

        'clientMutationId': operation == 'update'
            ? null
            : AppDatabase.instance.newId(),

        'clientCreatedAt': now,

        'payload': payload,

        // These remain useful to the optimistic/offline
        // mobile renderer. Server Kernel state is authoritative.
        'status': status,

        'appActionKey': actionKey,
      }..removeWhere((_, value) => value == null);

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
        } on FieldApiException catch (error) {
          // BRIXTA_SHOW_SERVER_VALIDATION_DETAILS
          // A 4xx/409 is a real server decision. Surface the backend's
          // validation details instead of hiding them behind the generic
          // "Record payload does not match..." wrapper.
          final rawDetails = error.details;
          String detailText = '';

          if (rawDetails is List) {
            detailText = rawDetails.map((item) => item.toString()).join('\n');
          } else if (rawDetails != null) {
            detailText = rawDetails.toString();
          }

          final message = detailText.trim().isEmpty
              ? error.message
              : '${error.message}\n$detailText';

          if (mounted) _message(message);
          return;
        } catch (error) {
          // Transport/unknown failures can be queued. CREATE is idempotent via
          // clientMutationId and UPDATE targets a known cached server record.
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

      // BRIXTA_RUNTIME_EFFECT_MESSAGES_V1
      final runtimeMessages = <String>[];

      final rawEffects = response == null ? null : response['effects'];

      if (rawEffects is List) {
        for (final raw in rawEffects.whereType<Map>()) {
          final effect = Map<String, dynamic>.from(raw);

          if (effect['kind']?.toString() != 'notify_actor') {
            continue;
          }

          final message = effect['message']?.toString().trim();

          if (message != null && message.isNotEmpty) {
            runtimeMessages.add(message);
          }
        }
      }

      _clearActionFields(selectedKeys);
      await AppDatabase.instance.putCache(_cacheKey, _records);

      await HapticFeedback.lightImpact();
      if (!mounted) return;

      // BRIXTA_PIXEL_MESSAGE_PRIORITY_V1
      if (runtimeMessages.isNotEmpty) {
        _message(runtimeMessages.join('\n'));
      } else {
        _message(
          (action['successMessage'] ??
                  (widget.controller.isOffline
                      ? 'Safe on this phone. It will sync automatically.'
                      : 'Recorded.'))
              .toString(),
        );
      }

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
            if (_runtimeOutputs.isNotEmpty) ...[
              const SizedBox(height: 40),
              for (var i = 0; i < _runtimeOutputs.length; i++) ...[
                _buildRuntimeOutput(_runtimeOutputs[i]),
                if (i != _runtimeOutputs.length - 1) const SizedBox(height: 28),
              ],
            ],

            if (_runtimeOutputs.isEmpty &&
                employeeOwnHistoryVisible &&
                _records.isNotEmpty) ...[
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

  String _runtimeDisplayValue(dynamic value) {
    if (value == null || value == '') {
      return '—';
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }

    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(' · ');
    }

    return value.toString();
  }

  Widget _buildRuntimeOutput(Map<String, dynamic> output) {
    final label = output['label']?.toString() ?? 'Output';

    final kind = output['kind']?.toString() ?? 'detail';

    final stateRaw = output['stateIds'];

    final stateIds = stateRaw is List
        ? stateRaw.map((item) => item.toString()).toSet()
        : <String>{};

    final keysRaw = output['visibleKeys'];

    final visibleKeys = keysRaw is List
        ? keysRaw.map((item) => item.toString()).toSet()
        : <String>{};

    final matchingRecords = _records
        .where(
          (record) =>
              stateIds.isEmpty ||
              stateIds.contains(record['status']?.toString()),
        )
        .toList();

    if (matchingRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final outputFields = visibleKeys.isEmpty
        ? visibleFields
        : visibleFields
              .where((field) => visibleKeys.contains(_fieldKey(field)))
              .toList();

    if (kind == 'metric') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label.toUpperCase()),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppDesign.surface,
              border: Border.all(color: AppDesign.line),
              borderRadius: BorderRadius.circular(AppDesign.radius),
            ),
            child: Text(
              matchingRecords.length.toString(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label.toUpperCase()),
        const SizedBox(height: 12),
        for (final record in matchingRecords.take(20))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesign.surface,
              border: Border.all(color: AppDesign.line),
              borderRadius: BorderRadius.circular(AppDesign.radius),
            ),
            child: Builder(
              builder: (context) {
                final rawPayload = record['payload'];

                final payload = rawPayload is Map
                    ? Map<String, dynamic>.from(rawPayload)
                    : <String, dynamic>{};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record['status']?.toString() ?? 'Record',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          kind.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppDesign.muted,
                          ),
                        ),
                      ],
                    ),
                    if (outputFields.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final field in outputFields) ...[
                        Text(
                          _fieldLabel(field),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppDesign.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(_runtimeDisplayValue(payload[_fieldKey(field)])),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
      ],
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
            // The app theme sets canvasColor to transparent (the
            // EditorialBackdrop paints scaffold backgrounds), and this
            // widget's popup menu falls back to canvasColor when
            // dropdownColor isn't set -- so without this it renders with
            // no background at all. Set it explicitly instead of
            // touching the global theme.
            dropdownColor: Colors.white,
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
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

    if (type == 'date' || type == 'datetime') {
      final withTime = type == 'datetime';
      final current = _controllerFor(key).text.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickDate(key, withTime: withTime),
            icon: Icon(
              withTime
                  ? Icons.event_available_outlined
                  : Icons.calendar_today_outlined,
              size: 18,
            ),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                current.isEmpty
                    ? (withTime ? 'Choose date & time' : 'Choose date')
                    : current,
              ),
            ),
          ),
          if (helpText != null) ...[
            const SizedBox(height: 6),
            Text(helpText, style: Theme.of(context).textTheme.bodySmall),
          ],
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
