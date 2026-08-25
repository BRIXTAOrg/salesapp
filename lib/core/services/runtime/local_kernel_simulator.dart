import '../../models/mobile_capability.dart';

/// Small offline evaluator for the subset that changes what the employee sees
/// immediately: state/context/computed/history + possibility conditions.
/// Server execution remains authoritative when connectivity returns.
abstract final class LocalKernelSimulator {
  static Map<String, dynamic>? initialRuntime({
    required MobileCapability capability,
    required Map<String, dynamic> currentUser,
    required Map<String, dynamic> device,
  }) {
    final kernel = capability.kernelDefinition;
    if (kernel.isEmpty) return null;

    final runtimeWorld = _map(kernel['runtimeWorld']);
    final state = <String, dynamic>{};
    for (final item in _mapList(runtimeWorld['states'])) {
      final dimension = item['dimension']?.toString() ?? 'process';
      if (item['initial'] == true && !state.containsKey(dimension)) {
        state[dimension] = item['id']?.toString();
      }
    }
    state.putIfAbsent('process', () => 'draft');

    final world = <String, dynamic>{
      'actorUserId': int.tryParse(currentUser['id']?.toString() ?? ''),
      'subjectUserId': int.tryParse(currentUser['id']?.toString() ?? ''),
      'responsibilityId': capability.id,
      'responsibilityKey': capability.key,
      'recordId': null,
      'state': state,
      'captures': <String, dynamic>{},
      'context': {
        'current_employee': currentUser,
        'current_user': currentUser,
        'current_device': device,
        'current_time': DateTime.now().toUtc().toIso8601String(),
        'history': <dynamic>[],
      },
      'objects': <String, dynamic>{'current_record': null},
      'actors': <String, dynamic>{
        'current_employee': currentUser,
        'current_user': currentUser,
        'system': {'system': true},
      },
      'queries': <String, dynamic>{},
      'computed': <String, dynamic>{},
      'history': <dynamic>[],
      'device': device,
      'now': DateTime.now().toUtc().toIso8601String(),
    };

    return {
      'responsibility': {
        'id': capability.id,
        'key': capability.key,
        'title': capability.title,
      },
      'manifest': {
        'version': capability.manifestVersion,
        'hash': capability.manifestHash,
        'source': capability.manifestSource,
      },
      'kernelVersion': kernel['kernelVersion'] ?? 3,
      'world': world,
      'possibilities': _availablePossibilities(kernel, world),
      'record': null,
      '_offlineLocal': true,
    };
  }

  static Map<String, dynamic> simulateAction({
    required MobileCapability capability,
    required Map<String, dynamic> runtime,
    required String actionId,
    required Map<String, dynamic> captures,
  }) {
    final kernel = capability.kernelDefinition;
    if (kernel.isEmpty) return runtime;

    final next = _deepMap(runtime);
    final world = _map(next['world']);
    final state = _map(world['state']);
    final worldCaptures = _map(world['captures'])..addAll(captures);
    final context = _map(world['context']);
    final computed = _map(world['computed']);
    final history = List<dynamic>.from(world['history'] is List ? world['history'] as List : const []);

    world['state'] = state;
    world['captures'] = worldCaptures;
    world['context'] = context;
    world['computed'] = computed;
    world['history'] = history;
    world['now'] = DateTime.now().toUtc().toIso8601String();

    final eventIds = _mapList(kernel['events'])
        .where((event) =>
            event['actionId']?.toString() == actionId ||
            (event['actionId'] == null &&
                event['kind']?.toString() == 'action' &&
                event['sourceKey']?.toString() == actionId))
        .map((event) => event['id']?.toString())
        .whereType<String>()
        .toSet();

    final rules = _mapList(kernel['rules'])
        .where((rule) =>
            rule['enabled'] != false &&
            (rule['eventId'] == null || eventIds.contains(rule['eventId']?.toString())) &&
            _conditionGroup(world, rule['when']))
        .toList()
      ..sort((a, b) =>
          (int.tryParse(a['priority']?.toString() ?? '') ?? 100)
              .compareTo(int.tryParse(b['priority']?.toString() ?? '') ?? 100));

    for (final rule in rules) {
      for (final effect in _mapList(rule['effects'])) {
        final kind = effect['kind']?.toString();
        final config = _map(effect['config']);
        switch (kind) {
          case 'change_state':
            final dimension = effect['targetKey']?.toString().isNotEmpty == true
                ? effect['targetKey'].toString()
                : 'process';
            final value = _resolveValue(world, effect['value']) ??
                config['stateId'] ??
                config['value'];
            if (value != null) state[dimension] = value.toString();
            break;
          case 'set_context':
            final key = effect['targetKey']?.toString() ?? config['key']?.toString();
            if (key != null && key.isNotEmpty) {
              context[key] = _resolveValue(world, effect['value']) ?? config['value'];
            }
            break;
          case 'remove_context':
            final key = effect['targetKey']?.toString() ?? config['key']?.toString();
            if (key != null && key.isNotEmpty) context.remove(key);
            break;
          case 'set_computed':
            final key = effect['targetKey']?.toString() ?? config['key']?.toString();
            if (key != null && key.isNotEmpty) {
              computed[key] = _resolveValue(world, effect['value']) ?? config['value'];
            }
            break;
          case 'append_history':
            history.add({
              'at': DateTime.now().toUtc().toIso8601String(),
              'label': config['message'] ?? config['label'] ?? rule['label'] ?? 'Updated',
              'actionId': actionId,
              'offline': true,
            });
            break;
        }
      }
    }

    next['world'] = world;
    next['possibilities'] = _availablePossibilities(kernel, world);
    next['_offlineLocal'] = true;
    return next;
  }

  static Map<String, dynamic> _availablePossibilities(
    Map<String, dynamic> kernel,
    Map<String, dynamic> world,
  ) {
    final captures = <Map<String, dynamic>>[];
    final actions = <Map<String, dynamic>>[];
    final outputs = <Map<String, dynamic>>[];

    for (final possibility in _mapList(kernel['possibilities'])) {
      if (!_conditionGroup(world, possibility['when'])) continue;
      final type = possibility['type']?.toString();

      if (type == 'capture') {
        captures.add(_map(possibility['capture']));
      } else if (type == 'action') {
        final action = _map(possibility['action']);
        if (!_conditionGroup(world, action['requires'])) continue;
        final actor = action['actorId']?.toString();
        if (actor == null ||
            actor.isEmpty ||
            actor == 'current_employee' ||
            actor == 'current_user') {
          actions.add(action);
        }
      } else if (type == 'output') {
        final output = _map(possibility['output']);
        final states = _strings(output['stateIds']);
        final currentStates = _map(world['state']).values.map((e) => e.toString()).toSet();
        if (states.isEmpty || states.any(currentStates.contains)) outputs.add(output);
      }
    }

    return {'captures': captures, 'actions': actions, 'outputs': outputs};
  }

  static bool _conditionGroup(Map<String, dynamic> world, dynamic raw) {
    if (raw is! Map) return true;
    final group = Map<String, dynamic>.from(raw);
    final conditions = _mapList(group['conditions']);
    if (conditions.isEmpty) return true;

    final values = conditions.map((condition) {
      final left = _resolveValue(world, condition['left']);
      final right = _resolveValue(world, condition['right']);
      switch (condition['operator']?.toString() ?? 'eq') {
        case 'neq':
          return left != right;
        case 'exists':
          return left != null && left.toString().isNotEmpty;
        case 'not_exists':
          return left == null || left.toString().isEmpty;
        case 'contains':
          return left is List
              ? left.contains(right)
              : left.toString().toLowerCase().contains(right.toString().toLowerCase());
        case 'in':
          return right is List && right.contains(left);
        case 'gt':
          return (num.tryParse(left.toString()) ?? 0) > (num.tryParse(right.toString()) ?? 0);
        case 'gte':
          return (num.tryParse(left.toString()) ?? 0) >= (num.tryParse(right.toString()) ?? 0);
        case 'lt':
          return (num.tryParse(left.toString()) ?? 0) < (num.tryParse(right.toString()) ?? 0);
        case 'lte':
          return (num.tryParse(left.toString()) ?? 0) <= (num.tryParse(right.toString()) ?? 0);
        default:
          return left == right;
      }
    }).toList();

    return group['mode']?.toString() == 'any'
        ? values.any((value) => value)
        : values.every((value) => value);
  }

  static dynamic _resolveValue(Map<String, dynamic> world, dynamic raw) {
    if (raw is! Map) return null;
    final ref = Map<String, dynamic>.from(raw);
    final kind = ref['kind']?.toString();
    final key = ref['key']?.toString() ?? '';
    dynamic value;

    switch (kind) {
      case 'literal':
        return ref['value'];
      case 'state':
        value = _map(world['state'])[key];
        break;
      case 'context':
        value = _map(world['context'])[key];
        break;
      case 'capture':
        value = _map(world['captures'])[key];
        break;
      case 'computed':
        value = _map(world['computed'])[key];
        break;
      case 'object':
        value = _map(world['objects'])[key];
        break;
      case 'actor':
        value = _map(world['actors'])[key];
        break;
      case 'query':
        value = _map(world['queries'])[key];
        break;
      default:
        return null;
    }

    final path = ref['path']?.toString();
    if (path == null || path.isEmpty) return value;
    for (final segment in path.split('.')) {
      if (value is Map) {
        value = value[segment];
      } else {
        return null;
      }
    }
    return value;
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  static List<String> _strings(dynamic value) => value is List
      ? value.map((item) => item.toString()).toList()
      : <String>[];

  static Map<String, dynamic> _deepMap(Map<String, dynamic> value) {
    dynamic clone(dynamic current) {
      if (current is Map) {
        return current.map((key, value) => MapEntry(key.toString(), clone(value)));
      }
      if (current is List) return current.map(clone).toList();
      return current;
    }

    return Map<String, dynamic>.from(clone(value) as Map);
  }
}
