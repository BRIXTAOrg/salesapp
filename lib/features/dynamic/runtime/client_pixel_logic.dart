class ClientPixelLogicResult {
  const ClientPixelLogicResult({
    required this.effects,
    required this.executedNodeIds,
  });

  final List<Map<String, dynamic>> effects;
  final List<String> executedNodeIds;
}

const _clientSafeEffects = {
  'effect.ui_animate',
  'effect.ui_show',
  'effect.ui_hide',
  'effect.ui_play',
  'effect.haptic',
  'effect.device_sound',
  'effect.device_ring',
  'effect.device_notification',
};

const _autoDeviceEffects = {
  'effect.ui_animate',
  'effect.ui_show',
  'effect.ui_hide',
  'effect.ui_play',
  'effect.haptic',
  'effect.device_sound',
};

Map<String, dynamic> _map(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

List<Map<String, dynamic>> _maps(dynamic value) {
  return value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];
}

dynamic _parseLiteral(dynamic value) {
  if (value is! String) {
    return value;
  }

  final text = value.trim();

  if (text.isEmpty) {
    return '';
  }

  if (text == 'true') {
    return true;
  }

  if (text == 'false') {
    return false;
  }

  if (text == 'null') {
    return null;
  }

  final number = num.tryParse(text);

  return number ?? value;
}

dynamic _path(dynamic value, String? path) {
  if (path == null || path.trim().isEmpty) {
    return value;
  }

  dynamic current = value;

  for (final part in path.split('.').where((item) => item.isNotEmpty)) {
    if (current is Map && current.containsKey(part)) {
      current = current[part];
    } else {
      return null;
    }
  }

  return current;
}

num _number(dynamic value) {
  return value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(dynamic value) {
  if (value == null || value == false || value == 0 || value == '') {
    return false;
  }

  if (value is Iterable) {
    return value.isNotEmpty;
  }

  return true;
}

ClientPixelLogicResult runClientPixelLogic({
  required dynamic rawProgram,
  required String actionId,
  required Map<String, dynamic> captures,
  required String? stateId,
  Map<String, dynamic> context = const {},
}) {
  final program = _map(rawProgram);

  if (program.isEmpty || program['enabled'] == false) {
    return const ClientPixelLogicResult(effects: [], executedNodeIds: []);
  }

  final nodes = _maps(program['nodes']);

  final edges = _maps(program['edges']);

  final byId = <String, Map<String, dynamic>>{
    for (final node in nodes)
      if ((node['id']?.toString() ?? '').isNotEmpty)
        node['id'].toString(): node,
  };

  final incomingData = <String, List<Map<String, dynamic>>>{};

  final outgoingFlow = <String, List<Map<String, dynamic>>>{};

  for (final edge in edges) {
    final kind = edge['kind']?.toString();

    final fromId = edge['fromNodeId']?.toString() ?? '';

    final toId = edge['toNodeId']?.toString() ?? '';

    if (kind == 'data') {
      incomingData.putIfAbsent(toId, () => []).add(edge);
    } else if (kind == 'flow') {
      outgoingFlow.putIfAbsent(fromId, () => []).add(edge);
    }
  }

  final values = <String, dynamic>{
    'capture': captures,

    'state': {'process': stateId},

    'context': {
      'current_time': DateTime.now().toUtc().toIso8601String(),

      ...context,
    },

    'variable': {
      for (final variable in _maps(program['variables']))
        if ((variable['key']?.toString() ?? '').isNotEmpty)
          variable['key'].toString(): variable['initialValue'],
    },
  };

  final cache = <String, Map<String, dynamic>>{};

  final evaluating = <String>{};

  Map<String, dynamic> evaluate(String nodeId) {
    final cached = cache[nodeId];

    if (cached != null) {
      return cached;
    }

    if (!evaluating.add(nodeId)) {
      return <String, dynamic>{};
    }

    final node = byId[nodeId];

    if (node == null) {
      evaluating.remove(nodeId);

      return <String, dynamic>{};
    }

    final inputs = <String, dynamic>{};

    for (final edge in incomingData[nodeId] ?? const []) {
      final source = evaluate(edge['fromNodeId']?.toString() ?? '');

      final fromPort = edge['fromPort']?.toString() ?? '';

      final toPort = edge['toPort']?.toString() ?? '';

      final value = source[fromPort];

      if (inputs.containsKey(toPort)) {
        final existing = inputs[toPort];

        inputs[toPort] = existing is List
            ? [...existing, value]
            : [existing, value];
      } else {
        inputs[toPort] = value;
      }
    }

    final type = node['type']?.toString() ?? '';

    final config = _map(node['config']);

    final outputs = <String, dynamic>{};

    if (type.startsWith('event.')) {
      outputs['flow'] = true;
    } else if (type == 'value.literal') {
      outputs['value'] = _parseLiteral(config['value']);
    } else if (type == 'value.ref') {
      final scope = config['scope']?.toString() ?? 'context';

      final key = config['key']?.toString() ?? '';

      final bucket = _map(values[scope]);

      final root = key.isEmpty ? bucket : bucket[key];

      outputs['value'] = _path(root, config['path']?.toString());
    } else if (type == 'math.add') {
      outputs['value'] = _number(inputs['a']) + _number(inputs['b']);
    } else if (type == 'math.subtract') {
      outputs['value'] = _number(inputs['a']) - _number(inputs['b']);
    } else if (type == 'math.multiply') {
      outputs['value'] = _number(inputs['a']) * _number(inputs['b']);
    } else if (type == 'math.divide') {
      final divisor = _number(inputs['b']);

      outputs['value'] = divisor == 0 ? 0 : _number(inputs['a']) / divisor;
    } else if (type == 'math.min') {
      final a = _number(inputs['a']);

      final b = _number(inputs['b']);

      outputs['value'] = a < b ? a : b;
    } else if (type == 'math.max') {
      final a = _number(inputs['a']);

      final b = _number(inputs['b']);

      outputs['value'] = a > b ? a : b;
    } else if (type == 'math.round') {
      outputs['value'] = _number(inputs['value']).round();
    } else if (type == 'logic.and') {
      outputs['value'] = _bool(inputs['a']) && _bool(inputs['b']);
    } else if (type == 'logic.or') {
      outputs['value'] = _bool(inputs['a']) || _bool(inputs['b']);
    } else if (type == 'logic.not') {
      outputs['value'] = !_bool(inputs['value']);
    } else if (type == 'logic.compare') {
      final left = inputs['left'];

      final right = inputs['right'];

      final operator = config['operator']?.toString() ?? 'eq';

      outputs['value'] = switch (operator) {
        'neq' => left != right,

        'gt' => _number(left) > _number(right),

        'gte' => _number(left) >= _number(right),

        'lt' => _number(left) < _number(right),

        'lte' => _number(left) <= _number(right),

        'exists' => left != null,

        'not_exists' => left == null,

        'contains' =>
          left is String
              ? left.contains(right?.toString() ?? '')
              : left is List
              ? left.contains(right)
              : false,

        _ => left == right,
      };
    } else if (type == 'control.if') {
      final condition = _bool(inputs['condition']);

      outputs['true'] = condition;

      outputs['false'] = !condition;
    } else if (type == 'time.difference_minutes') {
      final start = DateTime.tryParse(inputs['start']?.toString() ?? '');

      final end = DateTime.tryParse(inputs['end']?.toString() ?? '');

      outputs['value'] = start != null && end != null
          ? end.difference(start).inMilliseconds / 60000
          : 0;
    } else if (type == 'time.add_minutes') {
      final time = DateTime.tryParse(inputs['time']?.toString() ?? '');

      outputs['value'] = time
          ?.add(
            Duration(
              milliseconds: (_number(inputs['minutes']) * 60000).round(),
            ),
          )
          .toUtc()
          .toIso8601String();
    } else if (type == 'data.coalesce') {
      outputs['value'] = inputs['a'] ?? inputs['b'];
    } else {
      outputs.addAll(inputs);
    }

    cache[nodeId] = outputs;

    evaluating.remove(nodeId);

    return outputs;
  }

  bool eventMatches(Map<String, dynamic> node) {
    final type = node['type']?.toString() ?? '';

    final config = _map(node['config']);

    if (type == 'event.any') {
      return true;
    }

    if (type == 'event.responsibility.action') {
      final target = config['actionId']?.toString() ?? '';

      return target.isEmpty || target == actionId;
    }

    return false;
  }

  final effects = <Map<String, dynamic>>[];

  final executedNodeIds = <String>[];

  final visitedFlowEdges = <String>{};

  void walk(String nodeId) {
    final node = byId[nodeId];

    if (node == null) {
      return;
    }

    final outputs = evaluate(nodeId);

    final type = node['type']?.toString() ?? '';

    final config = _map(node['config']);

    final execution = _map(node['execution']);

    final placement = execution['placement']?.toString() ?? 'auto';

    final canExecuteEffect =
        _clientSafeEffects.contains(type) &&
        (placement == 'device' ||
            (placement == 'auto' && _autoDeviceEffects.contains(type)));

    if (canExecuteEffect) {
      final effect = <String, dynamic>{
        'nodeId': nodeId,

        'kind': type.substring('effect.'.length),

        ...config,
      };

      for (final edge in incomingData[nodeId] ?? const []) {
        final source = evaluate(edge['fromNodeId']?.toString() ?? '');

        final fromPort = edge['fromPort']?.toString() ?? '';

        final toPort = edge['toPort']?.toString() ?? '';

        if (toPort.isNotEmpty) {
          effect[toPort] = source[fromPort];
        }
      }

      effects.add(effect);

      executedNodeIds.add(nodeId);
    }

    for (final edge in outgoingFlow[nodeId] ?? const []) {
      final edgeId = edge['id']?.toString() ?? '';

      if (!visitedFlowEdges.add(edgeId)) {
        continue;
      }

      final shouldFollow = type == 'control.if'
          ? outputs[edge['fromPort']?.toString()] == true
          : true;

      if (shouldFollow) {
        walk(edge['toNodeId']?.toString() ?? '');
      }
    }
  }

  for (final node in nodes.where(eventMatches)) {
    walk(node['id']?.toString() ?? '');
  }

  return ClientPixelLogicResult(
    effects: effects,

    executedNodeIds: executedNodeIds,
  );
}
