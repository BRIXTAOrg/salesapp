import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/device/device_identity.dart';
import '../../../core/models/mobile_capability.dart';
import '../../../core/offline/offline_record_queue.dart';
import '../../../core/services/media/local_photo_store.dart';
import '../../../core/services/runtime/local_kernel_simulator.dart';
import '../../../core/services/runtime/responsibility_runtime_api.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/runtime_connection_banner.dart';
import '../../tracking/presentation/tracking_controller.dart';

/// Kernel-aware renderer for Responsibilities published by the CMS Studio.
///
/// No Attendance/Leave/Inspection/etc. behavior is hardcoded here. The server
/// returns the current world + possibilities; this screen renders the captures,
/// actions and outputs the current actor is allowed to use right now.
class KernelResponsibilityScreen extends StatefulWidget {
  const KernelResponsibilityScreen({
    super.key,
    required this.controller,
    required this.capability,
    this.trackingController,
    this.workflowInstanceId,
    this.initialRecordId,
  });

  final AppSessionController controller;
  final MobileCapability capability;
  final TrackingController? trackingController;
  final String? workflowInstanceId;
  final String? initialRecordId;

  @override
  State<KernelResponsibilityScreen> createState() =>
      _KernelResponsibilityScreenState();
}

class _KernelResponsibilityScreenState extends State<KernelResponsibilityScreen>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _values = {};
  final Map<String, String> _photos = {};

  Map<String, dynamic>? _runtime;
  bool _loading = true;
  String? _busyActionId;
  String? _recordId;
  String? _localRecordKey;
  String _manifestHash = '';
  bool _wasOnline = false;

  MobileCapability get _capability {
    final modules =
        widget.controller.session?.modules ?? const <MobileCapability>[];
    for (final item in modules) {
      if (item.key == widget.capability.key) return item;
    }
    return widget.capability;
  }

  ResponsibilityRuntimeApi get _api => ResponsibilityRuntimeApi(
    accessToken: widget.controller.session!.accessToken,
  );

  String get _scope =>
      '${widget.controller.session!.tenant.code}:${widget.controller.session!.user.id}:${_capability.key}';
  String get _runtimeCacheKey => 'kernel_runtime:$_scope';
  String get _recordCacheKey => 'kernel_runtime_record:$_scope';
  String get _localRecordCacheKey => 'kernel_runtime_local_record:$_scope';

  Map<String, dynamic> get _world => _map(_runtime?['world']);
  Map<String, dynamic> get _possibilities => _map(_runtime?['possibilities']);
  List<Map<String, dynamic>> get _captures =>
      _mapList(_possibilities['captures']);
  List<Map<String, dynamic>> get _actions =>
      _mapList(_possibilities['actions']);
  List<Map<String, dynamic>> get _outputs =>
      _mapList(_possibilities['outputs']);

  /// Exact phone order authored by the CMS App Builder. Runtime availability
  /// still comes from the server; the layout only controls presentation.
  List<Map<String, dynamic>> get _layoutItems {
    final kernel = _capability.kernelDefinition;
    final metadata = _map(kernel['metadata']);
    final ui = _map(metadata['ui']);
    final layout = _strings(ui['layout']);
    if (layout.isEmpty) return const [];

    final full = _mapList(kernel['possibilities']);
    final byPossibilityId = <String, Map<String, dynamic>>{
      for (final item in full)
        if (item['id'] != null) item['id'].toString(): item,
    };
    final allowedCaptureIds = _captures
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();
    final allowedActionIds = _actions
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();

    final items = <Map<String, dynamic>>[];
    for (final possibilityId in layout) {
      final possibility = byPossibilityId[possibilityId];
      if (possibility == null) continue;
      final type = possibility['type']?.toString();
      if (type == 'capture') {
        final capture = _map(possibility['capture']);
        if (allowedCaptureIds.contains(capture['id']?.toString())) {
          items.add({'type': 'capture', 'value': capture});
        }
      } else if (type == 'action') {
        final action = _map(possibility['action']);
        if (allowedActionIds.contains(action['id']?.toString())) {
          items.add({'type': 'action', 'value': action});
        }
      }
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _manifestHash = _capability.manifestHash;
    _recordId = widget.initialRecordId?.trim();
    if (_recordId?.isEmpty == true) _recordId = null;
    _wasOnline = widget.controller.isOnline;
    unawaited(_loadRuntime());
    unawaited(
      _api.usage(
        'responsibility.open',
        entityType: 'responsibility',
        entityId: _capability.key,
        metadata: {'manifestVersion': _capability.manifestVersion},
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.controller.isOnline) {
      unawaited(_loadRuntime());
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final liveHash = _capability.manifestHash;
    final online = widget.controller.isOnline;

    if (liveHash.isNotEmpty && liveHash != _manifestHash) {
      _manifestHash = liveHash;
      unawaited(_loadRuntime(forceNewDefinition: true));
    } else if (!_wasOnline && online) {
      unawaited(_loadRuntime());
    }

    _wasOnline = online;
    setState(() {});
  }

  Future<void> _loadRuntime({bool forceNewDefinition = false}) async {
    final session = widget.controller.session;
    if (session == null) return;
    if (mounted) setState(() => _loading = true);

    try {
      if (forceNewDefinition) {
        _runtime = null;
        _values.clear();
        for (final controller in _text.values) {
          controller.clear();
        }
      }

      if (_recordId == null) {
        final cachedRecord = await AppDatabase.instance.getCache(
          _recordCacheKey,
        );
        _recordId = cachedRecord?.toString().trim();
        if (_recordId?.isEmpty == true) _recordId = null;
      }
      if (_recordId == null && _localRecordKey == null) {
        final cachedLocal = await AppDatabase.instance.getCache(
          _localRecordCacheKey,
        );
        _localRecordKey = cachedLocal?.toString().trim();
        if (_localRecordKey?.isEmpty == true) _localRecordKey = null;
      }

      if (widget.controller.isOnline) {
        await OfflineRecordQueue.flush(session.accessToken);
        await widget.controller.markLocalMutationQueued();

        _recordId ??= await _api.latestRecordId(_capability.key);

        Map<String, dynamic> fresh;
        try {
          fresh = await _api.runtime(_capability.key, recordId: _recordId);
        } on FieldApiException catch (error) {
          if (_recordId != null &&
              (error.statusCode == 404 ||
                  error.code == 'KERNEL_RECORD_NOT_VISIBLE')) {
            _recordId = null;
            await AppDatabase.instance.removeCache(_recordCacheKey);
            fresh = await _api.runtime(_capability.key);
          } else {
            rethrow;
          }
        }

        _acceptRuntime(fresh);
      } else {
        final cached = await AppDatabase.instance.getCache(_runtimeCacheKey);
        if (cached is Map) {
          _runtime = Map<String, dynamic>.from(cached);
        } else {
          _runtime = LocalKernelSimulator.initialRuntime(
            capability: _capability,
            currentUser: {
              'id': session.user.id,
              'employeeCode': session.user.employeeCode,
              'name': session.user.name,
              'designation': session.user.designation,
              'department': session.user.department,
            },
            device: {
              ...AppDeviceIdentity.instance.registrationPayload,
              'online': false,
            },
          );
          if (_runtime != null) {
            await AppDatabase.instance.putCache(_runtimeCacheKey, _runtime);
          }
        }
      }
    } catch (error) {
      final cached = await AppDatabase.instance.getCache(_runtimeCacheKey);
      if (cached is Map) {
        _runtime = Map<String, dynamic>.from(cached);
        _message('Using the last safe copy on this phone.');
      } else {
        _message(error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _acceptRuntime(Map<String, dynamic> body) {
    final nested = body['runtime'];
    final runtime = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(body);
    _runtime = runtime;

    final record = _map(body['record']).isNotEmpty
        ? _map(body['record'])
        : _map(runtime['record']);
    final id =
        record['id']?.toString() ??
        _map(runtime['world'])['recordId']?.toString();
    if (id != null && id.isNotEmpty) {
      _recordId = id;
      _localRecordKey = null;
      unawaited(AppDatabase.instance.removeCache(_localRecordCacheKey));
    }

    unawaited(AppDatabase.instance.putCache(_runtimeCacheKey, runtime));
    if (_recordId != null) {
      unawaited(AppDatabase.instance.putCache(_recordCacheKey, _recordId));
    }
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    final actionId = action['id']?.toString() ?? '';
    if (actionId.isEmpty || _busyActionId != null) return;

    setState(() => _busyActionId = actionId);

    try {
      final captureIds = _strings(action['captureIds']);
      final payload = <String, dynamic>{};

      for (final captureId in captureIds) {
        Map<String, dynamic>? capture;
        for (final candidate in _captures) {
          if (candidate['id']?.toString() == captureId) {
            capture = candidate;
            break;
          }
        }
        if (capture == null) continue;

        final key = capture['storeAs']?.toString().trim().isNotEmpty == true
            ? capture['storeAs'].toString()
            : captureId;
        final value = await _captureValue(capture);
        final required = capture['required'] == true;

        if (_empty(value)) {
          if (required) {
            _message('${capture['label'] ?? 'This field'} is required.');
            return;
          }
          continue;
        }
        payload[key] = value;
      }

      final actionKind = action['kind']?.toString().toLowerCase() ?? '';
      if (actionKind == 'start' && widget.trackingController != null) {
        await widget.trackingController!.ensureAutomatic(
          widget.controller.session!.user.id,
        );
      }

      if (widget.controller.isOffline) {
        final mutationId = AppDatabase.instance.newId();
        final path =
            '/api/salesApp/responsibilities/${Uri.encodeComponent(_capability.key)}/actions/${Uri.encodeComponent(actionId)}';
        final alreadyStartedLocally = _runtime?['_localRecordStarted'] == true;

        if (_recordId == null) {
          _localRecordKey ??= AppDatabase.instance.newId();
          await AppDatabase.instance.putCache(
            _localRecordCacheKey,
            _localRecordKey,
          );
        }

        await OfflineRecordQueue.enqueue(
          method: 'POST',
          path: path,
          body: {
            'recordId': _recordId,
            'payload': payload,
            'clientMutationId': mutationId,
            'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
            'workflowInstanceId': widget.workflowInstanceId,
            ...AppDeviceIdentity.instance.registrationPayload,
          },
          producesRecordKey: _recordId == null && !alreadyStartedLocally
              ? _localRecordKey
              : null,
          recordReferenceKey: _recordId == null && alreadyStartedLocally
              ? _localRecordKey
              : null,
        );

        if (_runtime != null) {
          _runtime = LocalKernelSimulator.simulateAction(
            capability: _capability,
            runtime: _runtime!,
            actionId: actionId,
            captures: payload,
          );
          _runtime!['_localRecordStarted'] = true;
          _runtime!['_localRecordKey'] = _localRecordKey;
          await AppDatabase.instance.putCache(_runtimeCacheKey, _runtime);
        }

        await widget.controller.markLocalMutationQueued();
        _message('Saved on this phone. It will sync automatically.');
      } else {
        final preparedBody = await OfflineRecordQueue.prepareBodyForUpload(
          widget.controller.session!.accessToken,
          {'payload': payload},
        );
        final preparedPayload = _map(preparedBody['payload']);

        final response = await _api.runAction(
          responsibilityKey: _capability.key,
          actionId: actionId,
          payload: preparedPayload,
          recordId: _recordId,
          workflowInstanceId: widget.workflowInstanceId,
        );

        _acceptRuntime(response);
        await widget.controller.syncNow();
        _message(
          (action['config'] is Map
                      ? (action['config'] as Map)['successMessage']
                      : null)
                  ?.toString() ??
              '${action['label'] ?? 'Action'} completed.',
        );
      }

      if ((actionKind == 'stop' || actionKind == 'complete') &&
          widget.trackingController?.active == true) {
        await widget.trackingController!.stop();
      }

      _clearActionInputs(captureIds);
      await HapticFeedback.lightImpact();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _busyActionId = null);
    }
  }

  Future<dynamic> _captureValue(Map<String, dynamic> capture) async {
    final id = capture['id']?.toString() ?? '';
    final kind = capture['kind']?.toString().toLowerCase() ?? 'text';

    if (kind == 'photo' || kind == 'image' || kind == 'camera') {
      final path = _photos[id];
      return path == null ? null : {OfflineRecordQueue.localPhotoKey: path};
    }

    if (kind == 'gps' || kind == 'location' || kind == 'location_point') {
      return _values[id];
    }

    if (kind == 'route' ||
        kind == 'route_movement' ||
        kind == 'location_route') {
      final tracker = widget.trackingController;
      if (tracker == null) return _values[id];
      final points = await tracker.todayRoute();
      return points
          .map(
            (point) => {
              'lat': point.latitude,
              'lng': point.longitude,
              'accuracy': point.accuracy,
              'speed': point.speed,
              'recordedAt': point.recordedAt.toUtc().toIso8601String(),
              'totalDistanceM': point.totalDistanceM,
            },
          )
          .toList();
    }

    if (kind == 'distance' || kind == 'distance_travelled') {
      return widget.trackingController?.distanceKm ?? _values[id];
    }

    if (_values.containsKey(id)) return _values[id];

    final raw = _text[id]?.text.trim();
    if (raw == null || raw.isEmpty) return null;
    if (kind == 'number' || kind == 'amount' || kind == 'currency') {
      return double.tryParse(raw);
    }
    if (kind == 'integer') return int.tryParse(raw);
    return raw;
  }

  Future<void> _takePhoto(String id) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1440,
    );
    if (picked == null) return;

    final persisted = await LocalPhotoStore.persist(
      picked,
      prefix: '${_capability.key}-$id',
    );
    await LocalPhotoStore.delete(_photos[id]);
    if (mounted) setState(() => _photos[id] = persisted);
  }

  Future<void> _captureLocation(String id) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _message('Turn on location services to continue.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _message('Location permission is required.');
      return;
    }

    final fix = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (mounted) {
      setState(() {
        _values[id] = {
          'lat': fix.latitude,
          'lng': fix.longitude,
          'accuracy': fix.accuracy,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
        };
      });
    }
  }

  Future<void> _pickReference(Map<String, dynamic> capture) async {
    final id = capture['id']?.toString() ?? '';
    final config = _map(capture['config']);
    final sourceKey =
        (capture['sourceKey'] ?? config['sourceKey'] ?? config['dataSourceKey'])
            ?.toString()
            .trim();

    if (sourceKey == null || sourceKey.isEmpty) {
      _message('This picker is not connected to a Data Source yet.');
      return;
    }

    final referenceCacheKey = 'data_source_cache:$_scope:$sourceKey';
    final cached = await AppDatabase.instance.getCache(referenceCacheKey);

    if (!mounted) return;
    final cachedRows = cached is List
        ? _mapList(cached)
        : _mapList(config['offlineRows']);

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReferencePickerSheet(
        title: capture['label']?.toString() ?? 'Choose',
        api: _api,
        sourceKey: sourceKey,
        offlineRows: cachedRows,
        offline: widget.controller.isOffline,
        cacheKey: referenceCacheKey,
      ),
    );

    if (selected != null && mounted) {
      setState(() => _values[id] = selected);
    }
  }

  Future<void> _pickDate(
    Map<String, dynamic> capture, {
    required bool withTime,
  }) async {
    final id = capture['id']?.toString() ?? '';
    final initial =
        DateTime.tryParse(_values[id]?.toString() ?? '') ?? DateTime.now();
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
      if (time == null) return;
      value = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }

    setState(
      () => _values[id] = withTime
          ? value.toUtc().toIso8601String()
          : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
    );
  }

  void _clearActionInputs(List<String> captureIds) {
    setState(() {
      for (final id in captureIds) {
        _text[id]?.clear();
        _values.remove(id);
        _photos.remove(id);
      }
    });
  }

  Future<void> _startNewRun() async {
    _recordId = null;
    _localRecordKey = null;
    await AppDatabase.instance.removeCache(_recordCacheKey);
    await AppDatabase.instance.removeCache(_localRecordCacheKey);
    await AppDatabase.instance.removeCache(_runtimeCacheKey);
    _values.clear();
    for (final controller in _text.values) {
      controller.clear();
    }
    await _loadRuntime();
  }

  @override
  Widget build(BuildContext context) {
    final state = _map(_world['state']);
    final stateLabel = _stateLabel(state['process']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: Text(_capability.title),
        actions: [
          if (_capability.manifestVersion > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppDesign.softGreen,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'LIVE v${_capability.manifestVersion}',
                  style: const TextStyle(
                    color: AppDesign.greenDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh from company',
            onPressed: _loading ? null : () => _loadRuntime(),
            icon: Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRuntime,
        child: ListView(
          padding: AppDesign.pageInset,
          children: [
            RuntimeConnectionBanner(controller: widget.controller),
            const SizedBox(height: 18),
            _RuntimeHeader(
              capability: _capability,
              stateLabel: stateLabel,
              recordId: _recordId,
              offlineLocal: _runtime?['_offlineLocal'] == true,
            ),
            const SizedBox(height: 24),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2)
            else if (_runtime == null)
              _EmptyRuntime(onRetry: _loadRuntime)
            else ...[
              if (_layoutItems.isNotEmpty)
                _PublishedAppSurface(
                  title:
                      _map(
                        _map(_capability.kernelDefinition['metadata'])['ui'],
                      )['title']?.toString() ??
                      _capability.title,
                  items: _layoutItems,
                  busyActionId: _busyActionId,
                  buildCapture: _buildCapture,
                  onAction: _runAction,
                )
              else if (_actions.isEmpty)
                _NoActions(onNewRun: _recordId == null ? null : _startNewRun)
              else
                for (var i = 0; i < _actions.length; i++) ...[
                  _ActionCard(
                    action: _actions[i],
                    captures: _captures,
                    busy: _busyActionId == _actions[i]['id']?.toString(),
                    buildCapture: _buildCapture,
                    onRun: () => _runAction(_actions[i]),
                  ),
                  if (i != _actions.length - 1) const SizedBox(height: 16),
                ],
              if (_outputs.isNotEmpty) ...[
                const SizedBox(height: 24),
                _OutputSection(outputs: _outputs, world: _world),
              ],
              finalHistorySection(_world),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapture(Map<String, dynamic> capture) {
    final id = capture['id']?.toString() ?? '';
    final label = capture['label']?.toString() ?? 'Field';
    final kind = capture['kind']?.toString().toLowerCase() ?? 'text';
    final config = _map(capture['config']);
    final required = capture['required'] == true;
    final help = config['helpText']?.toString();

    Widget field;

    if (kind == 'choice' || kind == 'select' || kind == 'dropdown') {
      final options = _optionValues(config['options']);
      field = DropdownButtonFormField<String>(
        initialValue: _values[id]?.toString(),
        isExpanded: true,
        hint: Text(config['placeholder']?.toString() ?? 'Choose one'),
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) => setState(() => _values[id] = value),
      );
    } else if (kind == 'yes_no' ||
        kind == 'boolean' ||
        kind == 'toggle' ||
        kind == 'checkbox') {
      field = SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _values[id] == true,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onChanged: (value) => setState(() => _values[id] = value),
      );
      return field;
    } else if (kind == 'date' || kind == 'datetime' || kind == 'date_time') {
      final withTime = kind != 'date';
      field = OutlinedButton.icon(
        onPressed: () => _pickDate(capture, withTime: withTime),
        icon: Icon(
          withTime
              ? Icons.event_available_outlined
              : Icons.calendar_today_outlined,
          size: 18,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _values[id]?.toString() ??
                (withTime ? 'Choose date & time' : 'Choose date'),
          ),
        ),
      );
    } else if (kind == 'photo' || kind == 'image' || kind == 'camera') {
      final path = _photos[id];
      field = OutlinedButton.icon(
        onPressed: () => _takePhoto(id),
        icon: Icon(path == null ? AppIcons.camera : AppIcons.check, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(path == null ? 'Take photo' : 'Photo ready'),
        ),
      );
    } else if (kind == 'gps' ||
        kind == 'location' ||
        kind == 'location_point') {
      final value = _map(_values[id]);
      field = OutlinedButton.icon(
        onPressed: () => _captureLocation(id),
        icon: Icon(
          value.isEmpty ? AppIcons.location : AppIcons.check,
          size: 18,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value.isEmpty
                ? 'Use current location'
                : 'Location captured · ±${(value['accuracy'] as num?)?.toStringAsFixed(0) ?? '?'} m',
          ),
        ),
      );
    } else if (kind.contains('person') ||
        kind.contains('employee') ||
        kind.contains('entity_reference') ||
        kind.contains('record_reference') ||
        kind.contains('responsibility_reference')) {
      final selected = _map(_values[id]);
      field = OutlinedButton.icon(
        onPressed: () => _pickReference(capture),
        icon: const Icon(Icons.manage_search_outlined, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            selected.isEmpty
                ? 'Search and choose'
                : selected['label']?.toString() ??
                      selected['id']?.toString() ??
                      'Selected',
          ),
        ),
      );
    } else if (kind.contains('route') ||
        kind.contains('movement') ||
        kind.contains('distance')) {
      field = AnimatedBuilder(
        animation: widget.trackingController ?? _NeverListenable.instance,
        builder: (_, _) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppDesign.greenWash,
            border: Border.all(color: AppDesign.line),
            borderRadius: BorderRadius.circular(AppDesign.controlRadius),
          ),
          child: Row(
            children: [
              Icon(AppIcons.journey, color: AppDesign.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.trackingController == null
                      ? 'Route capture will be attached by the device.'
                      : '${widget.trackingController!.distanceKm.toStringAsFixed(2)} km · ${widget.trackingController!.meterState}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final long = kind == 'long_text' || kind == 'textarea' || kind == 'notes';
      final numeric =
          kind == 'number' ||
          kind == 'amount' ||
          kind == 'currency' ||
          kind == 'integer';
      field = TextField(
        controller: _text.putIfAbsent(id, TextEditingController.new),
        maxLines: long ? 4 : 1,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: config['placeholder']?.toString() ?? 'Enter $label',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (required)
              const Text(
                'REQUIRED',
                style: TextStyle(
                  color: AppDesign.greenDark,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        field,
        if (help != null && help.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(help, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  String _stateLabel(String? stateId) {
    if (stateId == null || stateId.isEmpty) return 'Ready';
    final states = _mapList(
      _map(_capability.kernelDefinition['runtimeWorld'])['states'],
    );
    for (final state in states) {
      if (state['id']?.toString() == stateId) {
        return state['label']?.toString() ?? _humanize(stateId);
      }
    }
    return _humanize(stateId);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static bool _empty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }
}

class _PublishedAppSurface extends StatelessWidget {
  const _PublishedAppSurface({
    required this.title,
    required this.items,
    required this.busyActionId,
    required this.buildCapture,
    required this.onAction,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final String? busyActionId;
  final Widget Function(Map<String, dynamic>) buildCapture;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const _SmallPill(label: 'COMPANY APP', tone: AppDesign.green),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i++) ...[
            if (items[i]['type'] == 'capture')
              buildCapture(_map(items[i]['value']))
            else if (items[i]['type'] == 'action')
              _PublishedActionButton(
                action: _map(items[i]['value']),
                busy: busyActionId == _map(items[i]['value'])['id']?.toString(),
                onPressed: () => onAction(_map(items[i]['value'])),
              ),
            if (i != items.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _PublishedActionButton extends StatelessWidget {
  const _PublishedActionButton({
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final Map<String, dynamic> action;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = action['label']?.toString() ?? 'Continue';
    final kind = action['kind']?.toString().toLowerCase() ?? '';
    final destructive =
        kind == 'delete' || kind == 'reject' || kind == 'cancel';
    final secondary =
        kind == 'return' ||
        kind == 'pause' ||
        kind == 'comment' ||
        kind == 'acknowledge';

    if (secondary) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: destructive
            ? FilledButton.styleFrom(backgroundColor: AppDesign.red)
            : null,
        onPressed: busy ? null : onPressed,
        child: busy ? const _ButtonSpinner() : Text(label),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.captures,
    required this.busy,
    required this.buildCapture,
    required this.onRun,
  });

  final Map<String, dynamic> action;
  final List<Map<String, dynamic>> captures;
  final bool busy;
  final Widget Function(Map<String, dynamic>) buildCapture;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final captureIds = _strings(action['captureIds']).toSet();
    final selected = captures
        .where((capture) => captureIds.contains(capture['id']?.toString()))
        .toList();
    final label = action['label']?.toString() ?? 'Continue';
    final kind = action['kind']?.toString() ?? '';
    final destructive =
        kind == 'delete' || kind == 'reject' || kind == 'cancel';

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: destructive ? AppDesign.softRed : AppDesign.softGreen,
                  borderRadius: BorderRadius.circular(AppDesign.controlRadius),
                ),
                child: Icon(
                  destructive ? Icons.close_rounded : Icons.play_arrow_rounded,
                  color: destructive ? AppDesign.red : AppDesign.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (var i = 0; i < selected.length; i++) ...[
              buildCapture(selected[i]),
              if (i != selected.length - 1) const SizedBox(height: 18),
            ],
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: destructive
                ? OutlinedButton(
                    onPressed: busy ? null : onRun,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesign.red,
                    ),
                    child: busy ? const _ButtonSpinner() : Text(label),
                  )
                : FilledButton(
                    onPressed: busy ? null : onRun,
                    child: busy ? const _ButtonSpinner() : Text(label),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeHeader extends StatelessWidget {
  const _RuntimeHeader({
    required this.capability,
    required this.stateLabel,
    required this.recordId,
    required this.offlineLocal,
  });

  final MobileCapability capability;
  final String stateLabel;
  final String? recordId;
  final bool offlineLocal;

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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppDesign.softGreen,
              borderRadius: BorderRadius.circular(AppDesign.radius),
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.forCapability(capability),
              color: AppDesign.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capability.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (capability.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    capability.description!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallPill(label: stateLabel, tone: AppDesign.green),
                    if (recordId != null)
                      const _SmallPill(
                        label: 'IN PROGRESS',
                        tone: AppDesign.muted,
                      ),
                    if (offlineLocal)
                      const _SmallPill(
                        label: 'LOCAL COPY',
                        tone: AppDesign.amber,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection({required this.outputs, required this.world});

  final List<Map<String, dynamic>> outputs;
  final Map<String, dynamic> world;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('NOW'),
        const SizedBox(height: 10),
        for (var i = 0; i < outputs.length; i++) ...[
          _OutputCard(output: outputs[i], world: world),
          if (i != outputs.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({required this.output, required this.world});

  final Map<String, dynamic> output;
  final Map<String, dynamic> world;

  @override
  Widget build(BuildContext context) {
    final label = output['label']?.toString() ?? 'Current status';
    final kind = output['kind']?.toString() ?? 'detail';
    final visibleKeys = _strings(output['visibleKeys']);
    final captures = _map(world['captures']);
    final computed = _map(world['computed']);
    final contextValues = _map(world['context']);
    final state = _map(world['state']);

    final rows = <MapEntry<String, dynamic>>[];
    for (final key in visibleKeys) {
      final value =
          captures[key] ?? computed[key] ?? contextValues[key] ?? state[key];
      if (value != null) rows.add(MapEntry(key, value));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.greenWash,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                kind == 'timeline'
                    ? Icons.timeline_rounded
                    : Icons.visibility_outlined,
                color: AppDesign.green,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final row in rows.take(8))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _humanize(row.key),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesign.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _displayValue(row.value),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Widget finalHistorySection(Map<String, dynamic> world) {
  final history = world['history'];
  if (history is! List || history.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('HISTORY'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppDesign.surface,
            border: Border.all(color: AppDesign.line),
            borderRadius: BorderRadius.circular(AppDesign.radius),
          ),
          child: Column(
            children: [
              for (var i = 0; i < history.length && i < 8; i++) ...[
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 17,
                        color: AppDesign.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _historyLabel(history[history.length - 1 - i]),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != history.length - 1 && i != 7)
                  const Divider(indent: 42),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReferencePickerSheet extends StatefulWidget {
  const _ReferencePickerSheet({
    required this.title,
    required this.api,
    required this.sourceKey,
    required this.offlineRows,
    required this.offline,
    required this.cacheKey,
  });

  final String title;
  final ResponsibilityRuntimeApi api;
  final String sourceKey;
  final List<Map<String, dynamic>> offlineRows;
  final bool offline;
  final String cacheKey;

  @override
  State<_ReferencePickerSheet> createState() => _ReferencePickerSheetState();
}

class _ReferencePickerSheetState extends State<_ReferencePickerSheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.offline) {
      setState(() {
        _rows = widget.offlineRows;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final body = await widget.api.dataSource(
        widget.sourceKey,
        query: _search.text.trim(),
      );
      final raw = body['rows'];
      if (mounted) {
        final rows = _mapList(raw);
        setState(() => _rows = rows);
        unawaited(AppDatabase.instance.putCache(widget.cacheKey, rows));
      }
    } catch (_) {
      if (mounted) setState(() => _rows = widget.offlineRows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                autofocus: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search',
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _load);
                },
              ),
              if (widget.offline) ...[
                const SizedBox(height: 8),
                const Text(
                  'Offline results are from the last cached reference set.',
                  style: TextStyle(color: AppDesign.amber, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              row['label']?.toString() ??
                                  row['id']?.toString() ??
                                  'Record',
                            ),
                            subtitle: row['data'] is Map
                                ? Text(
                                    _compactData(row['data']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: Icon(AppIcons.chevronRight, size: 18),
                            onTap: () => Navigator.pop(context, row),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoActions extends StatelessWidget {
  const _NoActions({this.onNewRun});
  final VoidCallback? onNewRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        children: [
          Icon(AppIcons.check, color: AppDesign.green, size: 26),
          const SizedBox(height: 10),
          const Text(
            'Nothing else is required right now.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (onNewRun != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onNewRun,
              child: const Text('Start a new run'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyRuntime extends StatelessWidget {
  const _EmptyRuntime({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        children: [
          Icon(AppIcons.alert, color: AppDesign.amber),
          const SizedBox(height: 10),
          const Text('This Responsibility is not available on this phone yet.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: tone,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .35,
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    );
  }
}

class _NeverListenable extends ChangeNotifier {
  _NeverListenable._();
  static final _NeverListenable instance = _NeverListenable._();
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];

List<String> _strings(dynamic value) =>
    value is List ? value.map((item) => item.toString()).toList() : <String>[];

List<String> _optionValues(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return (item['label'] ?? item['value'] ?? '').toString();
        }
        return item.toString();
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

String _humanize(String value) {
  final words = value.replaceAll(RegExp(r'[_-]+'), ' ').trim().split(' ');
  return words
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

String _displayValue(dynamic value) {
  if (value is Map) {
    return (value['label'] ??
            value['name'] ??
            value['title'] ??
            value['id'] ??
            'Selected')
        .toString();
  }
  if (value is List) {
    return '${value.length} item${value.length == 1 ? '' : 's'}';
  }
  return value.toString();
}

String _historyLabel(dynamic value) {
  if (value is Map) {
    return (value['label'] ??
            value['message'] ??
            value['event'] ??
            value['actionId'] ??
            'Updated')
        .toString();
  }
  return value.toString();
}

String _compactData(dynamic value) {
  if (value is! Map) return value.toString();
  final items = value.entries
      .where(
        (entry) =>
            entry.value != null && entry.value.toString().trim().isNotEmpty,
      )
      .take(3)
      .map((entry) => entry.value.toString())
      .join(' · ');
  return items;
}
