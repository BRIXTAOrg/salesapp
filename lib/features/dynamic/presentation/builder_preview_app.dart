// BRIXTA_UNIVERSAL_INTEGRATION_V1
// Lightweight Flutter-Web host used only by the CMS live preview iframe.
// It renders the SAME BrixtaStacUi implementation as the employee app.

import 'package:flutter/material.dart';

import 'brixta_stac_ui.dart';
import 'builder_preview_bridge.dart';

class BrixtaBuilderPreviewApp extends StatelessWidget {
  const BrixtaBuilderPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const _BuilderPreviewScreen(),
    );
  }
}

class _BuilderPreviewScreen extends StatefulWidget {
  const _BuilderPreviewScreen();

  @override
  State<_BuilderPreviewScreen> createState() => _BuilderPreviewScreenState();
}

class _BuilderPreviewScreenState extends State<_BuilderPreviewScreen> {
  final BuilderPreviewBridge _bridge = BuilderPreviewBridge();
  Map<String, dynamic> _document = const {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': <String>[],
    'blocks': <Map<String, dynamic>>[],
  };
  Map<String, dynamic>? _record;
  String _stateId = 'draft';
  List<Map<String, dynamic>> _actions = const [];
  Map<String, Map<String, dynamic>> _captures = const {};
  final Map<String, dynamic> _values = {};

  @override
  void initState() {
    super.initState();
    _bridge.start(_receive);
  }

  void _receive(Map<String, dynamic> message) {
    if (message['type'] != 'brixta.preview.update') return;
    final rawPayload = message['payload'];
    if (rawPayload is! Map) return;
    final payload = Map<String, dynamic>.from(rawPayload);

    final rawDocument = payload['document'];
    final rawRecord = payload['record'];
    final rawActions = payload['actions'];
    final rawCaptures = payload['captures'];

    setState(() {
      if (rawDocument is Map) {
        _document = Map<String, dynamic>.from(rawDocument);
      }
      _record = rawRecord is Map ? Map<String, dynamic>.from(rawRecord) : null;
      _stateId = payload['stateId']?.toString() ?? 'draft';
      _actions = rawActions is List
          ? rawActions
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [];
      _captures = rawCaptures is Map
          ? rawCaptures.map(
              (key, value) => MapEntry(
                key.toString(),
                value is Map
                    ? Map<String, dynamic>.from(value)
                    : <String, dynamic>{},
              ),
            )
          : const {};
      _values.clear();
    });
  }

  Map<String, dynamic> _captureConfig(Map<String, dynamic> capture) {
    final raw = capture['config'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Widget _capture(String key, Map<String, dynamic> visualConfig) {
    final capture = _captures[key] ?? const <String, dynamic>{};
    final kind = capture['kind']?.toString() ?? 'short_text';
    final label = capture['label']?.toString() ?? key;
    final required = capture['required'] == true;
    final config = _captureConfig(capture);
    final decoration = InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    );

    if (kind == 'boolean') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _values[key] == true,
        onChanged: (value) => setState(() => _values[key] = value),
      );
    }

    if (kind == 'choice') {
      final options = config['options'] is List
          ? (config['options'] as List).map((item) => item.toString()).toList()
          : const <String>[];
      return DropdownButtonFormField<String>(
        decoration: decoration,
        initialValue: _values[key]?.toString(),
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) => setState(() => _values[key] = value),
      );
    }

    if ({
      'entity_reference',
      'person_reference',
      'responsibility_reference',
    }.contains(kind)) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _values[key] = 'preview-selection'),
        child: InputDecorator(
          decoration: decoration,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _values[key]?.toString() ?? 'Search and select…',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.search_rounded),
            ],
          ),
        ),
      );
    }

    if (kind == 'photo' ||
        kind == 'video' ||
        kind == 'file' ||
        kind == 'signature') {
      final captured = _values[key] != null;
      return OutlinedButton.icon(
        onPressed: () => setState(() => _values[key] = 'preview-captured'),
        icon: Icon(
          captured ? Icons.check_circle_outline : Icons.camera_alt_outlined,
        ),
        label: Text(captured ? '$label captured' : label),
      );
    }

    if (kind == 'gps' || kind == 'route') {
      final captured = _values[key] != null;
      return OutlinedButton.icon(
        onPressed: () =>
            setState(() => _values[key] = {'lat': 22.5726, 'lon': 88.3639}),
        icon: const Icon(Icons.location_on_outlined),
        label: Text(captured ? '$label · location ready' : label),
      );
    }

    if (kind == 'date' || kind == 'datetime') {
      return OutlinedButton.icon(
        onPressed: () =>
            setState(() => _values[key] = DateTime.now().toIso8601String()),
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(_values[key]?.toString() ?? label),
      );
    }

    return TextFormField(
      decoration: decoration,
      keyboardType: {'number', 'amount', 'rating'}.contains(kind)
          ? TextInputType.number
          : TextInputType.text,
      onChanged: (value) => _values[key] = value,
    );
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    final rawConfig = action['config'];
    final config = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};
    final next =
        config['resultingState']?.toString() ??
        action['status']?.toString() ??
        _stateId;

    setState(() {
      _stateId = next;
      _record = {
        'id': 'builder-preview',
        'status': next,
        'payload': {
          ..._values,
          '__state': {'process': next},
        },
      };
    });
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrixtaStacUi(
        document: _document,
        record: _record,
        stateId: _stateId,
        actions: _actions,
        submittingActionKey: null,
        onRunAction: _runAction,
        onBuildCapture: _capture,
        onSelectBlock: _bridge.selectBlock,
      ),
    );
  }
}
