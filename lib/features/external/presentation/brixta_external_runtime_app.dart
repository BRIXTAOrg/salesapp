import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../dynamic/presentation/brixta_stac_ui.dart';

class BrixtaExternalRuntimeRoute {
  const BrixtaExternalRuntimeRoute._();

  static bool matches(Uri uri) {
    final segments = uri.pathSegments;

    return segments.length >= 3 &&
        (segments.first == 'r' || segments.first == 'x');
  }
}

class BrixtaExternalRuntimeApp extends StatelessWidget {
  const BrixtaExternalRuntimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BRIXTA',
      home: _ExternalRuntimeScreen(),
    );
  }
}

class _ExternalRuntimeScreen extends StatefulWidget {
  const _ExternalRuntimeScreen();

  @override
  State<_ExternalRuntimeScreen> createState() => _ExternalRuntimeScreenState();
}

class _ExternalRuntimeScreenState extends State<_ExternalRuntimeScreen> {
  static const _configuredBackendOrigin = String.fromEnvironment(
    'BRIXTA_BACKEND_ORIGIN',
    defaultValue: '',
  );

  final Map<String, TextEditingController> _controllers = {};

  final Map<String, dynamic> _values = {};

  final Map<String, int> _effectNonces = {};

  final Map<String, String> _effectAnimationPresets = {};

  final Map<String, int> _effectAnimationDurations = {};

  final Set<String> _forceVisible = {};

  final Set<String> _forceHidden = {};

  bool _loading = true;

  String? _error;

  String? _tenant;

  String? _token;

  String? _responsibilityKey;

  String? _externalSessionToken;

  String? _submittingActionKey;

  Map<String, dynamic>? _runtime;

  Map<String, dynamic>? _record;

  Map<String, dynamic>? _reward;

  Map<String, Map<String, dynamic>> _captures = {};

  List<Map<String, dynamic>> _actions = [];

  bool get _isQrRoute => _token != null;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Uri _apiUri(String path, {Map<String, dynamic>? query}) {
    final origin = _configuredBackendOrigin.trim().isEmpty
        ? Uri.base.origin
        : _configuredBackendOrigin.trim().replaceFirst(RegExp(r'/$'), '');

    final base = Uri.parse('$origin$path');

    return query == null
        ? base
        : base.replace(
            queryParameters: query.map(
              (key, value) => MapEntry(key, value?.toString()),
            ),
          );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    bool includeExternalSession = false,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};

    if (includeExternalSession && _externalSessionToken != null) {
      headers['x-brixta-external-session'] = _externalSessionToken!;
    }

    final response = await http.get(_apiUri(path), headers: headers);

    final body = jsonDecode(response.body);

    if (body is! Map) {
      throw StateError('BRIXTA returned an invalid response.');
    }

    final result = Map<String, dynamic>.from(body);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] == false) {
      throw StateError(
        result['error']?.toString() ??
            'BRIXTA request failed (${response.statusCode}).',
      );
    }

    return result;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    bool includeExternalSession = false,
  }) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json',
    };

    if (includeExternalSession && _externalSessionToken != null) {
      headers['x-brixta-external-session'] = _externalSessionToken!;
    }

    final response = await http.post(
      _apiUri(path),
      headers: headers,
      body: jsonEncode(payload),
    );

    final raw = jsonDecode(response.body);

    if (raw is! Map) {
      throw StateError('BRIXTA returned an invalid response.');
    }

    final result = Map<String, dynamic>.from(raw);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] == false) {
      throw StateError(
        result['error']?.toString() ??
            'BRIXTA request failed (${response.statusCode}).',
      );
    }

    return result;
  }

  String _mutationId() {
    final random = Random.secure();

    return [
      DateTime.now().microsecondsSinceEpoch,
      random.nextInt(1 << 32),
    ].join('_');
  }

  String _initialState(List<Map<String, dynamic>> actions) {
    for (final action in actions) {
      final config = _asMap(action['config']);

      final available = config['availableState']?.toString().trim();

      if (available != null && available.isNotEmpty) {
        return available;
      }
    }

    return 'draft';
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final uri = Uri.base;
      final segments = uri.pathSegments;

      if (segments.length < 3) {
        throw StateError('Invalid BRIXTA public route.');
      }

      final routeKind = segments[0];

      final tenant = segments[1];

      final routeValue = Uri.decodeComponent(segments.sublist(2).join('/'));

      String responsibilityKey;

      Map<String, dynamic>? reward;

      if (routeKind == 'r') {
        final qr = await _get(
          '/api/public/qr-rewards/'
          '${Uri.encodeComponent(tenant)}/'
          '${Uri.encodeComponent(routeValue)}',
        );

        reward = _asMap(qr['reward']);

        final mapping = _asMap(qr['runtime']);

        responsibilityKey = mapping['responsibilityKey']?.toString() ?? '';

        if (responsibilityKey.isEmpty) {
          throw StateError(
            'This QR is not bound to a published BRIXTA External Responsibility.',
          );
        }
      } else if (routeKind == 'x') {
        responsibilityKey = routeValue;
      } else {
        throw StateError('Unsupported BRIXTA public route.');
      }

      _tenant = tenant;
      _token = routeKind == 'r' ? routeValue : null;
      _responsibilityKey = responsibilityKey;

      final envelope = await _get(
        '/api/public/runtime/'
        '${Uri.encodeComponent(tenant)}/'
        '${Uri.encodeComponent(responsibilityKey)}',
        includeExternalSession: true,
      );

      final runtime = _asMap(envelope['runtime']);

      final session = _asMap(envelope['session']);

      final sessionToken = session['token']?.toString();

      if (sessionToken == null || sessionToken.isEmpty) {
        throw StateError('BRIXTA did not create an External Runtime session.');
      }

      final captures = _asMapList(runtime['captures']);

      final actions = _asMapList(runtime['actions']);

      final captureMap = <String, Map<String, dynamic>>{};

      for (final capture in captures) {
        final id = capture['id']?.toString();

        final storeAs = capture['storeAs']?.toString();

        if (id != null && id.isNotEmpty) {
          captureMap[id] = capture;
        }

        if (storeAs != null && storeAs.isNotEmpty) {
          captureMap[storeAs] = capture;
        }
      }

      final initialPayload = <String, dynamic>{};

      if (reward != null) {
        initialPayload.addAll(reward);

        initialPayload['qrReward'] = reward;
      }

      final stateId = _initialState(actions);

      initialPayload['__state'] = {'process': stateId};

      if (!mounted) {
        return;
      }

      setState(() {
        _runtime = runtime;
        _externalSessionToken = sessionToken;
        _reward = reward;
        _captures = captureMap;
        _actions = actions;

        _record = {'id': null, 'status': stateId, 'payload': initialPayload};

        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  dynamic _captureValue(String key) {
    return _values[key] ?? _asMap(_record?['payload'])[key];
  }

  Widget _buildCapture(String captureKey, Map<String, dynamic> visualConfig) {
    final capture =
        _captures[captureKey] ??
        <String, dynamic>{
          'id': captureKey,
          'label': captureKey,
          'kind': 'short_text',
          'config': <String, dynamic>{},
        };

    final id = capture['id']?.toString() ?? captureKey;

    final label = capture['label']?.toString() ?? captureKey;

    final kind = capture['kind']?.toString() ?? 'short_text';

    final config = _asMap(capture['config']);

    final required = capture['required'] == true;

    final effectiveLabel = required ? '$label *' : label;

    if (kind == 'boolean') {
      final current = _captureValue(captureKey) == true;

      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(effectiveLabel),
        value: current,
        onChanged: (value) {
          setState(() {
            _values[captureKey] = value;
            _values[id] = value;
          });
        },
      );
    }

    if (kind == 'choice') {
      final rawOptions = config['options'];

      final options = rawOptions is List
          ? rawOptions.map((item) => item.toString()).toList()
          : <String>[];

      final current = _captureValue(captureKey)?.toString();

      return DropdownButtonFormField<String>(
        value: options.contains(current) ? current : null,
        decoration: InputDecoration(
          labelText: effectiveLabel,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _values[captureKey] = value;
            _values[id] = value;
          });
        },
      );
    }

    if (kind == 'entity_reference') {
      final entities = _reward?['entities'];

      if (entities is List && entities.isNotEmpty) {
        final rows = entities
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        final current = _captureValue(captureKey)?.toString();

        return DropdownButtonFormField<String>(
          value: rows.any((row) => row['id']?.toString() == current)
              ? current
              : null,
          decoration: InputDecoration(
            labelText: effectiveLabel,
            border: const OutlineInputBorder(),
          ),
          items: rows
              .map(
                (row) => DropdownMenuItem(
                  value: row['id']?.toString(),
                  child: Text(
                    row['label']?.toString() ??
                        row['id']?.toString() ??
                        'Entity',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _values[captureKey] = value;
              _values[id] = value;
              _values['entityRecordId'] = value;
            });
          },
        );
      }
    }

    final controller = _controllers.putIfAbsent(
      captureKey,
      () => TextEditingController(
        text: _captureValue(captureKey)?.toString() ?? '',
      ),
    );

    final numeric = kind == 'number' || kind == 'amount';

    final upiLike =
        id.toLowerCase().contains('upi') ||
        captureKey.toLowerCase().contains('upi');

    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : upiLike
          ? TextInputType.emailAddress
          : TextInputType.text,
      maxLines: kind == 'long_text' ? 4 : 1,
      decoration: InputDecoration(
        labelText: effectiveLabel,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        dynamic stored = value;

        if (numeric) {
          stored = num.tryParse(value) ?? value;
        }

        _values[captureKey] = stored;
        _values[id] = stored;
      },
    );
  }

  String? _upiForAction(Map<String, dynamic> action) {
    final config = _asMap(action['config']);

    final configured = config['upiCaptureKey']?.toString();

    if (configured != null && configured.isNotEmpty) {
      final value = _values[configured]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    for (final entry in _values.entries) {
      if (entry.key.toLowerCase().contains('upi')) {
        final value = entry.value?.toString().trim();

        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }

    return _values['upi']?.toString().trim();
  }

  String? _entityForAction(Map<String, dynamic> action) {
    final config = _asMap(action['config']);

    final configured = config['entityRecordIdCaptureKey']?.toString();

    if (configured != null && configured.isNotEmpty) {
      final value = _values[configured]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return _values['entityRecordId']?.toString().trim();
  }

  bool _isQrClaimAction(Map<String, dynamic> action) {
    if (!_isQrRoute) {
      return false;
    }

    final config = _asMap(action['config']);

    if (config['publicCapability'] == 'voucher.claimPublic') {
      return true;
    }

    final identity = [action['id'], action['label']]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();

    return identity.contains('claim') || identity.contains('redeem');
  }

  void _applyClientEffects(dynamic rawEffects) {
    if (rawEffects is! List) {
      return;
    }

    for (final raw in rawEffects) {
      if (raw is! Map) {
        continue;
      }

      final effect = Map<String, dynamic>.from(raw);

      final kind = effect['kind']?.toString();

      final target = effect['targetKey']?.toString();

      final config = _asMap(effect['config']);

      if (target == null || target.isEmpty) {
        continue;
      }

      if (kind == 'ui_show') {
        _forceHidden.remove(target);
        _forceVisible.add(target);
      }

      if (kind == 'ui_hide') {
        _forceVisible.remove(target);
        _forceHidden.add(target);
      }

      if (kind == 'ui_animate' || kind == 'ui_play') {
        _effectNonces[target] = (_effectNonces[target] ?? 0) + 1;

        final preset = config['preset']?.toString();

        final duration = int.tryParse(config['durationMs']?.toString() ?? '');

        if (preset != null && preset.isNotEmpty) {
          _effectAnimationPresets[target] = preset;
        }

        if (duration != null) {
          _effectAnimationDurations[target] = duration;
        }
      }
    }
  }

  bool _isUpiVerificationAction(Map<String, dynamic> action) {
    final config = _asMap(action['config']);

    if (config['publicCapability'] == 'upi.validate' ||
        config['capability'] == 'upi.validate') {
      return true;
    }

    final identity = [action['id'], action['label']]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();

    return identity.contains('upi') &&
        (identity.contains('verify') || identity.contains('validate'));
  }

  /*
   * Deliberately contains the literal /actions/ route so the
   * public-host contract is explicit and auditable.
   */
  String _publicActionPath(
    String tenant,
    String responsibilityKey,
    String actionId,
  ) {
    return '/api/public/runtime/'
        '${Uri.encodeComponent(tenant)}/'
        '${Uri.encodeComponent(responsibilityKey)}'
        '/actions/'
        '${Uri.encodeComponent(actionId)}';
  }

  List<String> _serviceRequestIds(Map<String, dynamic> envelope) {
    final effects = envelope['effects'];

    if (effects is! List) {
      return <String>[];
    }

    final ids = <String>[];

    for (final raw in effects) {
      if (raw is! Map) {
        continue;
      }

      final effect = Map<String, dynamic>.from(raw);

      final serviceRequest = _asMap(effect['serviceRequest']);

      final id = serviceRequest['id']?.toString().trim();

      if (id != null && id.isNotEmpty) {
        ids.add(id);
      }
    }

    return ids;
  }

  Future<Map<String, dynamic>> _waitForServiceRequest(String requestId) async {
    final tenant = _tenant;

    final responsibilityKey = _responsibilityKey;

    if (tenant == null || responsibilityKey == null) {
      throw StateError('External Runtime route is unavailable.');
    }

    /*
     * Worker normally starts in <1 second and then ticks every 3s.
     * Poll only long enough to resolve interactive UPI verification.
     */
    for (var attempt = 0; attempt < 30; attempt += 1) {
      final envelope = await _get(
        '/api/public/runtime/'
        '${Uri.encodeComponent(tenant)}/'
        '${Uri.encodeComponent(responsibilityKey)}'
        '/service-requests/'
        '${Uri.encodeComponent(requestId)}',
        includeExternalSession: true,
      );

      final service = _asMap(envelope['service']);

      final outcome = service['outcome']?.toString();

      if (outcome == 'succeeded' || outcome == 'failed') {
        return service;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return <String, dynamic>{
      'outcome': 'failed',

      'status': 'timeout',

      'code': 'VERIFICATION_STATUS_TIMEOUT',

      'message':
          'UPI verification could not be confirmed. Your reward has not been claimed.',
    };
  }

  void _setVerificationState(String stateId, {String? message}) {
    if (!mounted) {
      return;
    }

    final current = _record == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_record!);

    final payload = _asMap(current['payload']);

    final state = _asMap(payload['__state']);

    state['process'] = stateId;

    payload['__state'] = state;

    payload['upiVerification'] = <String, dynamic>{
      'status': stateId,

      if (message != null) 'message': message,
    };

    setState(() {
      _record = {...current, 'status': stateId, 'payload': payload};

      _error = message;
    });
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    final tenant = _tenant;
    final responsibilityKey = _responsibilityKey;

    if (tenant == null || responsibilityKey == null) {
      return;
    }

    final actionId = action['id']?.toString();

    if (actionId == null || actionId.isEmpty) {
      return;
    }

    final mutationId = _mutationId();

    setState(() {
      _submittingActionKey = actionId;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{..._values};

      /*
       * QR CLAIM IS A DEDICATED AUTHORITATIVE BUSINESS COMMAND.
       *
       * Pixel may react to the action afterward, but it never gets
       * authority to choose payout amount or reopen the voucher.
       */
      if (_isQrClaimAction(action)) {
        final upi = _upiForAction(action);

        if (upi == null || upi.isEmpty) {
          throw StateError('Enter your UPI ID before claiming.');
        }

        final claimEnvelope = await _post(
          '/api/public/qr-rewards/'
          '${Uri.encodeComponent(tenant)}/'
          '${Uri.encodeComponent(_token!)}/claim',
          {
            'requestId': mutationId,

            'upi': upi,

            'entityRecordId': _entityForAction(action),
          },
        );

        final claimReward = _asMap(claimEnvelope['reward']);

        final outcome = claimReward['outcome']?.toString();

        if (outcome != 'claimed' && outcome != 'already_claimed') {
          throw StateError(
            'Reward claim was not accepted: ${outcome ?? "unknown"}',
          );
        }

        payload['qrClaim'] = claimReward;

        payload['claimOutcome'] = outcome;

        _reward = {...?_reward, ...claimReward};
      }

      final currentRecordId = _record?['id']?.toString();

      final actionEnvelope = await _post(
        _publicActionPath(tenant, responsibilityKey, actionId),
        {
          'clientMutationId': mutationId,

          'recordId': currentRecordId == null || currentRecordId == 'null'
              ? null
              : currentRecordId,

          'payload': payload,

          'device': {
            'platform': 'web',

            'route': Uri.base.path,

            'metadata': {'browserExternalRuntime': true},
          },
        },
        includeExternalSession: true,
      );

      final record = _asMap(actionEnvelope['record']);

      if (record.isNotEmpty) {
        _record = record;
      }

      _applyClientEffects(actionEnvelope['effects']);

      /*
       * BRIXTA_UPI_PROVIDER_BOUNDARY_V1
       *
       * VERIFY UPI is NOT the QR claim command.
       *
       * Therefore:
       * provider failure -> verification_unavailable
       * voucher          -> still AVAILABLE
       */
      if (_isUpiVerificationAction(action)) {
        final requestIds = _serviceRequestIds(actionEnvelope);

        if (requestIds.isEmpty) {
          throw StateError(
            'UPI verification did not create a provider service request.',
          );
        }

        final service = await _waitForServiceRequest(requestIds.first);

        final outcome = service['outcome']?.toString();

        if (outcome == 'failed') {
          final message =
              service['message']?.toString() ??
              'UPI verification is unavailable because the payment provider could not complete the request. Your reward has not been claimed.';

          _setVerificationState('verification_unavailable', message: message);

          if (mounted) {
            setState(() {
              _submittingActionKey = null;
            });
          }

          return;
        }

        if (outcome == 'succeeded') {
          _setVerificationState('upi_verified');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _submittingActionKey = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submittingActionKey = null;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && _runtime == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 38),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final runtime = _runtime ?? <String, dynamic>{};

    final document = _asMap(runtime['uiDocument']);

    final stateId =
        _record?['status']?.toString() ??
        _asMap(_record?['payload'])['__state']?.toString();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                    },
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            Expanded(
              child: BrixtaStacUi(
                document: document,
                record: _record,
                stateId: stateId,
                actions: _actions,
                submittingActionKey: _submittingActionKey,
                onRunAction: _runAction,
                onBuildCapture: _buildCapture,
                onRefresh: _load,
                effectNonces: _effectNonces,
                effectAnimationPresets: _effectAnimationPresets,
                effectAnimationDurations: _effectAnimationDurations,
                forceVisibleBlockIds: _forceVisible,
                forceHiddenBlockIds: _forceHidden,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
