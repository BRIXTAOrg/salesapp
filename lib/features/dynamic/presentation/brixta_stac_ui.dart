import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:stac/stac.dart';

import '../../../core/design/responsibility_theme.dart';

typedef BrixtaUiRunAction = Future<void> Function(Map<String, dynamic> action);

// BRIXTA_VISUAL_CAPTURE_BRIDGE_V11
//
// The visual layer does NOT manufacture another form state.
//
// DynamicCapabilityScreen remains the owner of:
//   TextEditingControllers
//   selected values
//   photo paths
//   GPS values
//   submission payload state
typedef BrixtaUiCaptureBuilder =
    Widget Function(String captureKey, Map<String, dynamic> visualConfig);

class BrixtaUiRuntime {
  const BrixtaUiRuntime({
    required this.record,
    required this.stateId,
    required this.actions,
    required this.submittingActionKey,
    required this.onRunAction,
    this.onBuildCapture,
    this.onRefresh,
    this.effectNonces = const {},
    this.effectAnimationPresets = const {},
    this.effectAnimationDurations = const {},
    this.forceVisibleBlockIds = const {},
    this.forceHiddenBlockIds = const {},
  });

  final Map<String, dynamic>? record;
  final String? stateId;
  final List<Map<String, dynamic>> actions;
  final String? submittingActionKey;
  final BrixtaUiRunAction onRunAction;
  final BrixtaUiCaptureBuilder? onBuildCapture;
  final Future<void> Function()? onRefresh;

  final Map<String, int> effectNonces;
  final Map<String, String> effectAnimationPresets;
  final Map<String, int> effectAnimationDurations;
  final Set<String> forceVisibleBlockIds;
  final Set<String> forceHiddenBlockIds;

  Map<String, dynamic> get payload {
    final raw = record?['payload'];

    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic> get computed {
    final raw = payload['__computed'];

    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic> get contextValues {
    final raw = payload['__context'];

    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic> get stateValues {
    final raw = payload['__state'];

    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  dynamic resolveBinding(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final binding = Map<String, dynamic>.from(raw);

    final scope = binding['scope']?.toString();

    final key = binding['key']?.toString();

    switch (scope) {
      case 'literal':
        return binding['value'];

      case 'capture':
        return key == null ? null : payload[key];

      case 'computed':
        if (key == null) {
          return null;
        }

        return computed[key] ?? payload[key];

      case 'context':
        return key == null ? null : contextValues[key];

      case 'state':
        if (key == null || key == 'process') {
          return stateId;
        }

        return stateValues[key];

      case 'record':
        if (key == null) {
          return record;
        }

        return record?[key];

      case 'actor':
        return key == null ? null : contextValues[key];

      default:
        return null;
    }
  }

  bool declarativeVisible(dynamic raw) {
    if (raw == null) {
      return true;
    }

    if (raw is! Map) {
      return true;
    }

    final visibility = Map<String, dynamic>.from(raw);

    final left = resolveBinding(visibility['binding']);

    final operator = visibility['operator']?.toString() ?? 'eq';

    final right = visibility['value'];

    switch (operator) {
      case 'exists':
        return left != null && left != '';

      case 'not_exists':
        return left == null || left == '';

      case 'neq':
        return left != right;

      case 'gt':
        return _number(left) > _number(right);

      case 'gte':
        return _number(left) >= _number(right);

      case 'lt':
        return _number(left) < _number(right);

      case 'lte':
        return _number(left) <= _number(right);

      case 'eq':
      default:
        return left == right;
    }
  }

  bool blockVisible(Map<String, dynamic> block) {
    final id = block['id']?.toString();

    if (id != null && forceHiddenBlockIds.contains(id)) {
      return false;
    }

    if (id != null && forceVisibleBlockIds.contains(id)) {
      return true;
    }

    return declarativeVisible(block['visibility']);
  }

  int effectNonce(String blockId) {
    return effectNonces[blockId] ?? 0;
  }

  String? effectAnimationPreset(String blockId) {
    return effectAnimationPresets[blockId];
  }

  int? effectAnimationDuration(String blockId) {
    return effectAnimationDurations[blockId];
  }

  Widget buildCapture(String captureKey, Map<String, dynamic> visualConfig) {
    final builder = onBuildCapture;

    if (builder == null) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Text(
          'Input "$captureKey" is not connected to the host capture runtime.',
        ),
      );
    }

    return builder(captureKey, visualConfig);
  }

  static double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BrixtaUiRuntimeScope extends InheritedWidget {
  const BrixtaUiRuntimeScope({
    super.key,
    required this.runtime,
    required super.child,
  });

  final BrixtaUiRuntime runtime;

  static BrixtaUiRuntime of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BrixtaUiRuntimeScope>();

    assert(scope != null, 'BrixtaUiRuntimeScope missing.');

    return scope!.runtime;
  }

  @override
  bool updateShouldNotify(BrixtaUiRuntimeScope oldWidget) {
    return true;
  }
}

/// Stac is the JSON -> Flutter entry point.
/// BRIXTA provides installed binding/action/presentation semantics.
class BrixtaScreenParser extends StacParser<Map<String, dynamic>> {
  const BrixtaScreenParser();

  @override
  String get type => 'brixtaScreen';

  @override
  Map<String, dynamic> getModel(Map<String, dynamic> json) {
    return json;
  }

  @override
  Widget parse(BuildContext context, Map<String, dynamic> model) {
    final runtime = BrixtaUiRuntimeScope.of(context);

    final raw = model['document'];

    final document = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    return _BrixtaDocumentView(document: document, runtime: runtime);
  }
}

class BrixtaStacUi extends StatelessWidget {
  const BrixtaStacUi({
    super.key,
    required this.document,
    required this.record,
    required this.stateId,
    required this.actions,
    required this.submittingActionKey,
    required this.onRunAction,
    this.onBuildCapture,
    this.onRefresh,
    this.effectNonces = const {},
    this.effectAnimationPresets = const {},
    this.effectAnimationDurations = const {},
    this.forceVisibleBlockIds = const {},
    this.forceHiddenBlockIds = const {},
  });

  final Map<String, dynamic> document;
  final Map<String, dynamic>? record;
  final String? stateId;
  final List<Map<String, dynamic>> actions;
  final String? submittingActionKey;
  final BrixtaUiRunAction onRunAction;
  final BrixtaUiCaptureBuilder? onBuildCapture;
  final Future<void> Function()? onRefresh;

  final Map<String, int> effectNonces;
  final Map<String, String> effectAnimationPresets;
  final Map<String, int> effectAnimationDurations;
  final Set<String> forceVisibleBlockIds;
  final Set<String> forceHiddenBlockIds;

  @override
  Widget build(BuildContext context) {
    // BRIXTA_PRE_STAC_SERIALIZED_GUARD_V1
    //
    // Reject pathological CMS payloads BEFORE:
    //
    //   BrixtaUiRuntime
    //   ResponsibilityTheme
    //   Stac.fromJson
    //   BrixtaScreenParser
    //   _BrixtaDocumentView
    //   byId materialization
    //
    // List.length is O(1), so a two-million-entry serialized
    // document is rejected without walking those entries.
    final rawBlocks = document['blocks'];

    if (rawBlocks is List && rawBlocks.length > 10000) {
      return const _BrixtaPreStacResourceLimitView();
    }

    /*
     * Root count is cheap to validate here for the same reason.
     */
    final rawRoots = document['rootIds'];

    if (rawRoots is List && rawRoots.length > 256) {
      return const _BrixtaPreStacResourceLimitView();
    }

    final runtime = BrixtaUiRuntime(
      record: record,
      stateId: stateId,
      actions: actions,
      submittingActionKey: submittingActionKey,
      onRunAction: onRunAction,
      onBuildCapture: onBuildCapture,
      onRefresh: onRefresh,
      effectNonces: effectNonces,
      effectAnimationPresets: effectAnimationPresets,
      effectAnimationDurations: effectAnimationDurations,
      forceVisibleBlockIds: forceVisibleBlockIds,
      forceHiddenBlockIds: forceHiddenBlockIds,
    );

    final theme = ResponsibilityTheme.resolve(context, document);

    final background = ResponsibilityTheme.background(context, document);

    return Theme(
      data: theme,

      child: ColoredBox(
        color: background,

        child: BrixtaUiRuntimeScope(
          runtime: runtime,

          child: Builder(
            builder: (innerContext) {
              return Stac.fromJson({
                    'type': 'brixtaScreen',

                    'document': document,
                  }, innerContext) ??
                  const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _BrixtaPreStacResourceLimitView extends StatelessWidget {
  const _BrixtaPreStacResourceLimitView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                'This Responsibility cannot be displayed safely.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Its published interface exceeds the device render safety limit.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrixtaFullscreenHost extends StatefulWidget {
  const _BrixtaFullscreenHost({required this.overlays, required this.child});

  final List<Widget> overlays;
  final Widget child;

  @override
  State<_BrixtaFullscreenHost> createState() => _BrixtaFullscreenHostState();
}

class _BrixtaFullscreenHostState extends State<_BrixtaFullscreenHost> {
  OverlayEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(_BrixtaFullscreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sync();
      }
    });
  }

  void _sync() {
    if (widget.overlays.isEmpty) {
      _entry?.remove();
      _entry = null;
      return;
    }

    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (context) =>
            Stack(fit: StackFit.expand, children: widget.overlays),
      );

      Overlay.of(context, rootOverlay: true).insert(_entry!);

      return;
    }

    _entry!.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _BrixtaRenderGraphCheck {
  const _BrixtaRenderGraphCheck._({
    required this.allowed,
    required this.reason,
    required this.expandedNodes,
    required this.animatedNodes,
  });

  const _BrixtaRenderGraphCheck.allowed(
    int expandedNodes, {
    int animatedNodes = 0,
  }) : this._(
         allowed: true,
         reason: '',
         expandedNodes: expandedNodes,
         animatedNodes: animatedNodes,
       );

  const _BrixtaRenderGraphCheck.rejected(
    String reason,
    int expandedNodes, {
    int animatedNodes = 0,
  }) : this._(
         allowed: false,
         reason: reason,
         expandedNodes: expandedNodes,
         animatedNodes: animatedNodes,
       );

  final bool allowed;
  final String reason;
  final int expandedNodes;
  final int animatedNodes;
}

class _BrixtaRenderQueueEntry {
  const _BrixtaRenderQueueEntry({required this.id, required this.depth});

  final String id;
  final int depth;
}

class _BrixtaRawStacCheck {
  const _BrixtaRawStacCheck._({
    required this.allowed,
    required this.reason,
    required this.nodes,
  });

  const _BrixtaRawStacCheck.allowed(int nodes)
    : this._(allowed: true, reason: '', nodes: nodes);

  const _BrixtaRawStacCheck.rejected(String reason, int nodes)
    : this._(allowed: false, reason: reason, nodes: nodes);

  final bool allowed;
  final String reason;
  final int nodes;
}

class _BrixtaRawStacQueueEntry {
  const _BrixtaRawStacQueueEntry({required this.value, required this.depth});

  final dynamic value;
  final int depth;
}

class _BrixtaDocumentView extends StatelessWidget {
  const _BrixtaDocumentView({required this.document, required this.runtime});

  // BRIXTA_RENDER_GRAPH_GUARD_V1
  //
  // CMS-authored UI is untrusted declarative input.
  // A malformed graph must never be able to recurse until the
  // employee application exhausts its Dart stack.
  // BRIXTA_RENDER_RESOURCE_BUDGET_V1
  //
  // These limits apply to the EXPANDED graph, not merely
  // the number of serialized blocks. Repeated references
  // therefore cannot amplify a tiny CMS document without
  // bound.
  static const int _maxRenderDepth = 64;
  static const int _maxRenderRoots = 256;
  static const int _maxDirectChildren = 2048;
  static const int _maxExpandedRenderNodes = 4096;

  // BRIXTA_ANIMATION_RESOURCE_BUDGET_V1
  //
  // <= 512:
  //     authored/runtime animations remain enabled.
  //
  // 513..1024:
  //     business UI remains visible, but motion is disabled globally
  //     for this Responsibility.
  //
  // > 1024:
  //     fail closed before constructing animation controllers.
  static const int _recommendedAnimatedNodes = 512;
  static const int _maxAnimatedNodes = 1024;

  // BRIXTA_RAW_STAC_RESOURCE_BUDGET_V1
  //
  // stac.raw bypasses the normal BRIXTA block graph, so it receives
  // an independent structural envelope BEFORE Stac.fromJson().
  static const int _maxRawStacNodes = 2048;
  static const int _maxExpandedRawStacNodes = 4096;
  static const int _maxRawStacDepth = 32;
  static const int _maxRawStacDirectChildren = 256;
  static const int _maxRawStacBytes = 512 * 1024;

  // These cheap character limits execute BEFORE jsonEncode/utf8.encode
  // so a single absurd String cannot itself become the preflight DoS.
  static const int _maxRawStacStringChars = 128 * 1024;
  static const int _maxRawStacAggregateChars = 256 * 1024;

  // BRIXTA_SERIALIZED_DOCUMENT_ENVELOPE_V1
  //
  // IMPORTANT:
  //
  // This budget applies to the RAW serialized CMS document BEFORE
  // we copy block Maps or manufacture the byId index.
  //
  // Without this preflight, millions of unreachable blocks can still
  // cause seconds of allocation/GC work even though the reachable
  // render graph is tiny.
  static const int _maxSerializedBlocks = 10000;

  final Map<String, dynamic> document;
  final BrixtaUiRuntime runtime;

  Map<String, Map<String, dynamic>> get byId {
    final raw = document['blocks'];

    if (raw is! List) {
      return const <String, Map<String, dynamic>>{};
    }

    final result = <String, Map<String, dynamic>>{};

    /*
     * Single-pass materialization.
     *
     * We intentionally do NOT manufacture an intermediate
     * List<Map<String, dynamic>>.
     */
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      final id = item['id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      result[id] = Map<String, dynamic>.from(item);
    }

    return result;
  }

  List<String> get rootIds {
    final raw = document['rootIds'];

    if (raw is! List) {
      return const [];
    }

    return raw.map((item) => item.toString()).toList();
  }

  _BrixtaRenderGraphCheck? _validateSerializedEnvelope() {
    /*
     * O(1) REJECTION PATH.
     *
     * List.length does not iterate or copy the two-million-block
     * document.
     *
     * This check MUST execute before `byId`.
     */
    final rawBlocks = document['blocks'];

    if (rawBlocks is List && rawBlocks.length > _maxSerializedBlocks) {
      return _BrixtaRenderGraphCheck.rejected(
        'serialized_block_budget',
        rawBlocks.length,
      );
    }

    /*
     * Root count receives the same treatment. Do not convert an
     * attacker-controlled million-element rootIds list first.
     */
    final rawRoots = document['rootIds'];

    if (rawRoots is List && rawRoots.length > _maxRenderRoots) {
      return _BrixtaRenderGraphCheck.rejected('root_budget', rawRoots.length);
    }

    return null;
  }

  bool _blockUsesAnimation(Map<String, dynamic> block) {
    final blockId = block['id']?.toString() ?? '';

    final type = block['type']?.toString() ?? '';

    /*
     * Lottie is animation even when no generic animation preset exists.
     */
    if (type == 'animation.lottie') {
      return true;
    }

    final runtimePreset = blockId.isEmpty
        ? null
        : runtime.effectAnimationPreset(blockId);

    if (runtimePreset != null && runtimePreset != 'none') {
      return true;
    }

    final raw = block['animation'];

    if (raw is! Map) {
      return false;
    }

    final preset = raw['preset']?.toString() ?? 'none';

    return preset != 'none';
  }

  _BrixtaRawStacCheck _validateRawStac(Map<String, dynamic> raw) {
    /*
     * BRIXTA_RAW_STAC_PREFLIGHT_V1
     *
     * IMPORTANT:
     *
     * This is ITERATIVE rather than recursive.
     *
     * A hostile raw STAC tree therefore cannot overflow the validator
     * stack while we are trying to protect the Flutter renderer.
     */
    final queue = <_BrixtaRawStacQueueEntry>[
      _BrixtaRawStacQueueEntry(value: raw, depth: 0),
    ];

    var cursor = 0;
    var nodes = 0;
    var aggregateChars = 0;

    while (cursor < queue.length) {
      final entry = queue[cursor];
      cursor += 1;

      if (entry.depth > _maxRawStacDepth) {
        return _BrixtaRawStacCheck.rejected('depth_budget', nodes);
      }

      nodes += 1;

      if (nodes > _maxRawStacNodes) {
        return _BrixtaRawStacCheck.rejected('node_budget', nodes);
      }

      final value = entry.value;

      if (value is Map) {
        if (value.length > _maxRawStacDirectChildren) {
          return _BrixtaRawStacCheck.rejected('fanout_budget', nodes);
        }

        for (final mapEntry in value.entries) {
          final key = mapEntry.key.toString();

          if (key.length > _maxRawStacStringChars) {
            return _BrixtaRawStacCheck.rejected('string_budget', nodes);
          }

          aggregateChars += key.length;

          if (aggregateChars > _maxRawStacAggregateChars) {
            return _BrixtaRawStacCheck.rejected('character_budget', nodes);
          }

          queue.add(
            _BrixtaRawStacQueueEntry(
              value: mapEntry.value,
              depth: entry.depth + 1,
            ),
          );
        }

        continue;
      }

      if (value is List) {
        if (value.length > _maxRawStacDirectChildren) {
          return _BrixtaRawStacCheck.rejected('fanout_budget', nodes);
        }

        for (final child in value) {
          queue.add(
            _BrixtaRawStacQueueEntry(value: child, depth: entry.depth + 1),
          );
        }

        continue;
      }

      if (value is String) {
        if (value.length > _maxRawStacStringChars) {
          return _BrixtaRawStacCheck.rejected('string_budget', nodes);
        }

        aggregateChars += value.length;

        if (aggregateChars > _maxRawStacAggregateChars) {
          return _BrixtaRawStacCheck.rejected('character_budget', nodes);
        }
      }
    }

    /*
     * Only after structural and String limits are proven safe do we
     * calculate the exact UTF-8 serialized size.
     */
    try {
      final bytes = utf8.encode(jsonEncode(raw)).length;

      if (bytes > _maxRawStacBytes) {
        return _BrixtaRawStacCheck.rejected('byte_budget', nodes);
      }
    } catch (_) {
      return _BrixtaRawStacCheck.rejected('invalid_json', nodes);
    }

    return _BrixtaRawStacCheck.allowed(nodes);
  }

  _BrixtaRenderGraphCheck _validateExpandedRenderGraph(
    Map<String, Map<String, dynamic>> map,
    List<String> roots,
  ) {
    if (roots.length > _maxRenderRoots) {
      return _BrixtaRenderGraphCheck.rejected('root_budget', roots.length);
    }

    final queue = <_BrixtaRenderQueueEntry>[
      for (final id in roots) _BrixtaRenderQueueEntry(id: id, depth: 0),
    ];

    /*
     * "scheduled" counts render OCCURRENCES.
     *
     * This distinction is important:
     *
     * 2 serialized blocks may still describe:
     *
     * root.children =
     *   [leaf, leaf, leaf ... 10,000 times]
     *
     * A serialized block-count limit alone cannot protect Flutter.
     */
    var scheduled = queue.length;
    var cursor = 0;

    var animatedNodes = 0;
    var expandedRawStacNodes = 0;

    if (scheduled > _maxExpandedRenderNodes) {
      return _BrixtaRenderGraphCheck.rejected(
        'expanded_node_budget',
        scheduled,
      );
    }

    while (cursor < queue.length) {
      final entry = queue[cursor];
      cursor += 1;

      if (entry.depth >= _maxRenderDepth) {
        return _BrixtaRenderGraphCheck.rejected('depth_budget', scheduled);
      }

      final block = map[entry.id];

      /*
       * Unknown references do not create a Flutter block.
       */
      if (block == null) {
        continue;
      }

      /*
       * BRIXTA_ANIMATION_PREFLIGHT_V1
       *
       * Count EXPANDED animation occurrences rather than serialized
       * block definitions. Repeated references therefore cannot turn
       * one animated leaf into thousands of controllers.
       */
      if (_blockUsesAnimation(block)) {
        animatedNodes += 1;

        if (animatedNodes > _maxAnimatedNodes) {
          return _BrixtaRenderGraphCheck.rejected(
            'animation_budget',
            scheduled,
            animatedNodes: animatedNodes,
          );
        }
      }

      /*
       * BRIXTA_RAW_STAC_EXPANDED_PREFLIGHT_V1
       *
       * stac.raw is validated here, BEFORE _renderBlock() can call
       * Stac.fromJson().
       *
       * We also account repeated references to the same raw subtree.
       */
      if (block['type']?.toString() == 'stac.raw') {
        final rawConfig = block['config'];

        final rawJson = rawConfig is Map ? rawConfig['json'] : null;

        if (rawJson is Map) {
          final rawCheck = _validateRawStac(Map<String, dynamic>.from(rawJson));

          if (!rawCheck.allowed) {
            return _BrixtaRenderGraphCheck.rejected(
              'raw_stac_${rawCheck.reason}',
              scheduled,
              animatedNodes: animatedNodes,
            );
          }

          expandedRawStacNodes += rawCheck.nodes;

          if (expandedRawStacNodes > _maxExpandedRawStacNodes) {
            return _BrixtaRenderGraphCheck.rejected(
              'raw_stac_expanded_node_budget',
              scheduled,
              animatedNodes: animatedNodes,
            );
          }
        }
      }

      final rawChildren = block['children'];

      if (rawChildren is! List) {
        continue;
      }

      final childIds = rawChildren
          .map((value) => value.toString())
          .toList(growable: false);

      if (childIds.length > _maxDirectChildren) {
        return _BrixtaRenderGraphCheck.rejected(
          'fanout_budget',
          scheduled + childIds.length,
        );
      }

      /*
       * Reject BEFORE enqueuing an oversized generation.
       *
       * This prevents the validator itself from becoming the
       * memory-amplification surface.
       */
      if (scheduled + childIds.length > _maxExpandedRenderNodes) {
        return _BrixtaRenderGraphCheck.rejected(
          'expanded_node_budget',
          scheduled + childIds.length,
        );
      }

      scheduled += childIds.length;

      for (final childId in childIds) {
        queue.add(_BrixtaRenderQueueEntry(id: childId, depth: entry.depth + 1));
      }
    }

    return _BrixtaRenderGraphCheck.allowed(
      scheduled,
      animatedNodes: animatedNodes,
    );
  }

  Widget _resourceLimitView(
    BuildContext context,
    _BrixtaRenderGraphCheck check,
  ) {
    /*
     * Fail CLOSED rather than rendering a partial business UI.
     *
     * Silent truncation could hide:
     * - mandatory captures
     * - approval actions
     * - warnings
     * - submission buttons
     *
     * A complete safe rejection is preferable.
     */
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                'This Responsibility cannot be displayed safely.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Its published interface exceeds the device render safety limit.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /*
     * BRIXTA_SERIALIZED_PREFLIGHT_V1
     *
     * Never materialize/index an absurd CMS document merely to
     * discover later that it is unsafe.
     */
    final serializedCheck = _validateSerializedEnvelope();

    if (serializedCheck != null) {
      return _resourceLimitView(context, serializedCheck);
    }

    final map = byId;

    // BRIXTA_EXPANDED_GRAPH_PREFLIGHT_V1
    //
    // Validate the complete expanded reference graph BEFORE
    // recursively constructing Flutter widgets.
    final graphCheck = _validateExpandedRenderGraph(map, rootIds);

    if (!graphCheck.allowed) {
      return _resourceLimitView(context, graphCheck);
    }

    /*
     * BRIXTA_ANIMATION_SOFT_LIMIT_V1
     *
     * Do NOT hide the business UI when we merely exceed the recommended
     * motion budget.
     *
     * 513..1024 animated occurrences render statically.
     */
    final suppressAnimations =
        graphCheck.animatedNodes > _recommendedAnimatedNodes;

    final normal = <Widget>[];

    final overlays = <Widget>[];

    for (final id in rootIds) {
      final block = map[id];

      if (block == null || !runtime.blockVisible(block)) {
        continue;
      }

      final type = block['type']?.toString() ?? '';

      final widget = _renderBlock(
        context,
        block,
        map,
        suppressAnimations: suppressAnimations,
      );

      if (type == 'overlay.fullscreen') {
        overlays.add(Positioned.fill(child: widget));
      } else {
        normal.add(widget);
      }
    }

    final scroll = ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),

      children: [
        ...normal,

        if (normal.isEmpty)
          const SizedBox(
            height: 420,

            child: Center(
              child: Text('This app has no visible UI blocks yet.'),
            ),
          ),
      ],
    );

    final content = runtime.onRefresh == null
        ? scroll
        : RefreshIndicator(onRefresh: runtime.onRefresh!, child: scroll);

    return _BrixtaFullscreenHost(overlays: overlays, child: content);
  }

  Widget _renderBlock(
    BuildContext context,
    Map<String, dynamic> block,
    Map<String, Map<String, dynamic>> blockMap, {
    Set<String> ancestry = const <String>{},
    int depth = 0,
    bool suppressAnimations = false,
  }) {
    final type = block['type']?.toString() ?? '';

    final blockId = block['id']?.toString() ?? '';

    /*
     * Never trust the CMS graph to be acyclic.
     *
     * Examples that must terminate safely:
     *
     *   A -> A
     *
     *   A -> B -> A
     *
     * A repeated block ID is allowed elsewhere in the document;
     * it is rejected only when it already exists in THIS render path.
     */
    if (depth >= _maxRenderDepth) {
      return const SizedBox.shrink();
    }

    if (blockId.isNotEmpty && ancestry.contains(blockId)) {
      return const SizedBox.shrink();
    }

    final nextAncestry = blockId.isEmpty
        ? ancestry
        : <String>{...ancestry, blockId};

    final config = block['config'] is Map
        ? Map<String, dynamic>.from(block['config'] as Map)
        : <String, dynamic>{};

    final childIds = block['children'] is List
        ? (block['children'] as List).map((child) => child.toString()).toList()
        : const <String>[];

    Widget rendered;

    switch (type) {
      case 'layout.column':
        rendered = Column(
          crossAxisAlignment: _crossAxis(config['alignment']),

          children: _children(
            context,
            childIds,
            blockMap,
            ancestry: nextAncestry,
            depth: depth + 1,
            suppressAnimations: suppressAnimations,

            vertical: true,
            gap: _double(config['gap'], 16),
          ),
        );
        break;

      case 'layout.row':
        rendered = Row(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: _children(
            context,
            childIds,
            blockMap,
            ancestry: nextAncestry,
            depth: depth + 1,
            suppressAnimations: suppressAnimations,

            vertical: false,
            gap: _double(config['gap'], 12),
          ),
        );
        break;

      case 'layout.stack':
        rendered = Stack(
          children: childIds.map((id) {
            final child = blockMap[id];

            if (child == null || !runtime.blockVisible(child)) {
              return const SizedBox.shrink();
            }

            return _renderBlock(
              context,
              child,
              blockMap,
              ancestry: nextAncestry,
              depth: depth + 1,
              suppressAnimations: suppressAnimations,
            );
          }).toList(),
        );
        break;

      case 'layout.wrap':
        rendered = Wrap(
          spacing: _double(config['gap'], 10),
          runSpacing: _double(config['runGap'], 10),
          alignment: config['alignment']?.toString() == 'center'
              ? WrapAlignment.center
              : config['alignment']?.toString() == 'end'
              ? WrapAlignment.end
              : WrapAlignment.start,
          children: childIds.map((id) {
            final child = blockMap[id];
            if (child == null || !runtime.blockVisible(child)) {
              return const SizedBox.shrink();
            }
            return _renderBlock(
              context,
              child,
              blockMap,
              ancestry: nextAncestry,
              depth: depth + 1,
              suppressAnimations: suppressAnimations,
            );
          }).toList(),
        );
        break;

      case 'layout.grid':
        final columns = _double(config['columns'], 2).round().clamp(1, 6);
        final gap = _double(config['gap'], 12);
        rendered = GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: _double(config['childAspectRatio'], 1.15),
          children: childIds.map((id) {
            final child = blockMap[id];
            if (child == null || !runtime.blockVisible(child)) {
              return const SizedBox.shrink();
            }
            return _renderBlock(
              context,
              child,
              blockMap,
              ancestry: nextAncestry,
              depth: depth + 1,
              suppressAnimations: suppressAnimations,
            );
          }).toList(),
        );
        break;

      case 'container.card':
      case 'container.surface':
        final children = _children(
          context,
          childIds,
          blockMap,
          ancestry: nextAncestry,
          depth: depth + 1,
          suppressAnimations: suppressAnimations,
          vertical: true,
          gap: _double(config['gap'], 12),
        );
        final padding = EdgeInsets.all(_double(config['padding'], 16));
        final radius = BorderRadius.circular(_double(config['radius'], 16));
        final content = Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
        if (type == 'container.card') {
          rendered = Card(
            elevation: _double(config['elevation'], 0),
            shape: RoundedRectangleBorder(borderRadius: radius),
            clipBehavior: Clip.antiAlias,
            child: content,
          );
        } else {
          final scheme = Theme.of(context).colorScheme;
          rendered = Container(
            decoration: BoxDecoration(
              color: _hexColor(config['background']?.toString()) ??
                  scheme.surfaceContainerLow,
              borderRadius: radius,
              border: config['border'] == false
                  ? null
                  : Border.all(color: scheme.outlineVariant),
            ),
            child: content,
          );
        }
        break;

      case 'display.text':
        rendered = _textWidget(
          context,
          config['text']?.toString() ?? '',
          config,
        );
        break;

      case 'display.value':
      case 'display.counter':
      case 'display.metric':
        final value = runtime.resolveBinding(block['binding']);

        final prefix = config['prefix']?.toString() ?? '';

        final suffix = config['suffix']?.toString() ?? '';

        rendered = _textWidget(context, '$prefix${_display(value)}$suffix', {
          ...config,

          if (type == 'display.counter') 'size': config['size'] ?? 'hero',

          if (type == 'display.metric') 'size': config['size'] ?? 'large',
        });
        break;

      case 'display.progress':
        final value = _double(runtime.resolveBinding(block['binding']), 0);

        final min = _double(config['min'], 0);

        final max = _double(config['max'], 100);

        final normalized = max <= min
            ? 0.0
            : ((value - min) / (max - min)).clamp(0.0, 1.0);

        rendered = LinearProgressIndicator(
          value: normalized,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
        );
        break;

      case 'display.badge':
        final value = runtime.resolveBinding(block['binding']);

        rendered = Align(
          alignment: Alignment.centerLeft,

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(999),
            ),

            child: Text(_display(value)),
          ),
        );
        break;

      case 'display.icon':
        final alignment = config['alignment']?.toString();
        rendered = Align(
          alignment: alignment == 'center'
              ? Alignment.center
              : alignment == 'right'
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Icon(
            _iconData(config['name']?.toString()),
            size: _double(config['size'], 28),
            color: _hexColor(config['color']?.toString()),
          ),
        );
        break;

      case 'feedback.empty':
        rendered = Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconData(config['icon']?.toString() ?? 'inbox'),
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                config['title']?.toString() ?? 'Nothing here yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((config['message']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  config['message'].toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
        break;

      case 'feedback.loading':
        rendered = Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(config['text']?.toString() ?? 'Loading…'),
            ],
          ),
        );
        break;

      case 'interaction.capture':
        final rawBinding = block['binding'];

        final binding = rawBinding is Map
            ? Map<String, dynamic>.from(rawBinding)
            : <String, dynamic>{};

        final scope = binding['scope']?.toString();

        final captureKey = binding['key']?.toString();

        if (scope != 'capture' || captureKey == null || captureKey.isEmpty) {
          rendered = Container(
            width: double.infinity,

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.30),
              ),

              borderRadius: BorderRadius.circular(12),
            ),

            child: const Text('This visual input is not bound to a capture.'),
          );
        } else {
          rendered = runtime.buildCapture(captureKey, config);
        }

        break;

      case 'interaction.action_button':
        final actionId = block['actionId']?.toString();

        Map<String, dynamic>? action;

        for (final candidate in runtime.actions) {
          if (candidate['key']?.toString() == actionId) {
            action = candidate;
            break;
          }
        }

        final label =
            config['label']?.toString() ??
            action?['label']?.toString() ??
            'Continue';

        final busy =
            actionId != null && runtime.submittingActionKey == actionId;

        final style = config['style']?.toString() ?? 'primary';
        final size = config['size']?.toString() ?? 'large';
        final verticalPadding = size == 'small' ? 9.0 : size == 'medium' ? 12.0 : 15.0;
        final child = Padding(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        );
        final onPressed = action == null || busy
            ? null
            : () => unawaited(runtime.onRunAction(action!));

        Widget button;
        if (style == 'secondary') {
          button = FilledButton.tonal(onPressed: onPressed, child: child);
        } else if (style == 'outlined') {
          button = OutlinedButton(onPressed: onPressed, child: child);
        } else if (style == 'danger') {
          button = FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: onPressed,
            child: child,
          );
        } else {
          button = FilledButton(onPressed: onPressed, child: child);
        }

        rendered = SizedBox(width: double.infinity, child: button);
        break;

      case 'overlay.banner':
        rendered = Container(
          width: double.infinity,

          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10),

            borderRadius: BorderRadius.circular(16),
          ),

          child: Text(
            config['text']?.toString() ?? '',

            textAlign: TextAlign.center,

            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        );
        break;

      case 'overlay.fullscreen':
        final theme = Theme.of(context);

        final background =
            _hexColor(config['background']?.toString()) ??
            theme.scaffoldBackgroundColor;

        final foreground =
            _hexColor(config['foreground']?.toString()) ??
            theme.colorScheme.onSurface;

        rendered = Material(
          color: background,

          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),

                child: Text(
                  config['text']?.toString() ?? '',

                  textAlign: TextAlign.center,

                  style: theme.textTheme.displayLarge?.copyWith(
                    color: foreground,

                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
        break;

      case 'media.image':
        final bound = runtime.resolveBinding(block['binding']);

        final url = bound?.toString() ?? config['url']?.toString() ?? '';

        rendered = url.startsWith('http')
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),

                child: Image.network(url, fit: BoxFit.cover),
              )
            : const SizedBox.shrink();
        break;

      case 'animation.lottie':
        final url = config['url']?.toString() ?? '';

        final asset = config['asset']?.toString() ?? '';

        Widget lottie;

        if (url.startsWith('http')) {
          lottie = Lottie.network(
            url,
            repeat: config['repeat'] != false,
            animate: !suppressAnimations,
          );
        } else if (asset.isNotEmpty) {
          lottie = Lottie.asset(
            asset,
            repeat: config['repeat'] != false,
            animate: !suppressAnimations,
          );
        } else {
          lottie = const SizedBox.shrink();
        }

        rendered = KeyedSubtree(
          key: ValueKey<String>(
            'lottie:$blockId:${runtime.effectNonce(blockId)}',
          ),

          child: lottie,
        );
        break;

      case 'spacing.spacer':
        rendered = SizedBox(height: _double(config['height'], 16));
        break;

      case 'spacing.divider':
        rendered = const Divider();
        break;

      case 'stac.raw':
        final raw = config['json'];

        rendered = raw is Map
            ? (Stac.fromJson(Map<String, dynamic>.from(raw), context) ??
                  const SizedBox.shrink())
            : const SizedBox.shrink();
        break;

      default:
        rendered = const SizedBox.shrink();
    }

    return _animate(
      context,
      rendered,
      block,
      suppressAnimations: suppressAnimations,
    );
  }

  List<Widget> _children(
    BuildContext context,
    List<String> ids,
    Map<String, Map<String, dynamic>> map, {
    required Set<String> ancestry,
    required int depth,
    required bool suppressAnimations,
    required bool vertical,
    required double gap,
  }) {
    final result = <Widget>[];

    final visibleIds = ids.where((id) {
      final block = map[id];

      return block != null && runtime.blockVisible(block);
    }).toList();

    for (var index = 0; index < visibleIds.length; index += 1) {
      final block = map[visibleIds[index]]!;

      final child = _renderBlock(
        context,
        block,
        map,
        ancestry: ancestry,
        depth: depth,
        suppressAnimations: suppressAnimations,
      );

      result.add(vertical ? child : Expanded(child: child));

      if (index != visibleIds.length - 1) {
        result.add(vertical ? SizedBox(height: gap) : SizedBox(width: gap));
      }
    }

    return result;
  }

  Widget _textWidget(
    BuildContext context,
    String text,
    Map<String, dynamic> config,
  ) {
    final theme = Theme.of(context);

    final size = config['size']?.toString() ?? 'body';

    TextStyle? style;

    switch (size) {
      case 'hero':
        style = theme.textTheme.displayLarge;
        break;

      case 'large':
        style = theme.textTheme.headlineLarge;
        break;

      case 'title':
        style = theme.textTheme.titleLarge;
        break;

      case 'small':
        style = theme.textTheme.bodySmall;
        break;

      default:
        style = theme.textTheme.bodyLarge;
    }

    final alignment = config['alignment']?.toString();

    return SizedBox(
      width: double.infinity,

      child: Text(
        text,

        textAlign: alignment == 'center'
            ? TextAlign.center
            : alignment == 'right'
            ? TextAlign.right
            : TextAlign.left,

        style: style?.copyWith(
          fontWeight: size == 'hero' || size == 'large' || size == 'title'
              ? FontWeight.w800
              : style.fontWeight,
        ),
      ),
    );
  }

  Widget _animate(
    BuildContext context,
    Widget child,
    Map<String, dynamic> block, {
    required bool suppressAnimations,
  }) {
    /*
     * Above the recommended motion budget, preserve the business UI
     * but manufacture ZERO flutter_animate controllers/effects.
     */
    if (suppressAnimations) {
      return child;
    }

    final blockId = block['id']?.toString() ?? '';

    final raw = block['animation'];

    final authored = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final preset =
        runtime.effectAnimationPreset(blockId) ??
        authored['preset']?.toString() ??
        'none';

    if (preset == 'none') {
      return child;
    }

    /*
     * System accessibility outranks authored motion.
     */
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return child;
    }

    final rawDuration =
        runtime.effectAnimationDuration(blockId) ??
        (authored['durationMs'] as num?)?.toInt() ??
        350;

    final duration = Duration(milliseconds: rawDuration.clamp(50, 10000));

    final bindingValue = runtime.resolveBinding(block['binding']);

    dynamic visibilityValue;

    final rawVisibility = block['visibility'];

    if (rawVisibility is Map) {
      visibilityValue = runtime.resolveBinding(rawVisibility['binding']);
    }

    final reactionKey = [
      blockId,
      block['type'],
      preset,
      runtime.stateId,
      bindingValue,
      visibilityValue,
      runtime.effectNonce(blockId),
    ].map((value) => value?.toString() ?? '<null>').join('|');

    Widget animated;

    switch (preset) {
      case 'fade':
        animated = Animate(
          effects: [FadeEffect(duration: duration)],
          child: child,
        );
        break;

      case 'scale':
        animated = Animate(
          effects: [
            ScaleEffect(
              begin: const Offset(0.88, 0.88),
              end: const Offset(1, 1),
              duration: duration,
            ),
          ],
          child: child,
        );
        break;

      case 'fade_scale':
        animated = Animate(
          effects: [
            FadeEffect(duration: duration),
            ScaleEffect(
              begin: const Offset(0.82, 0.82),
              end: const Offset(1, 1),
              duration: duration,
            ),
          ],
          child: child,
        );
        break;

      case 'slide_up':
        animated = Animate(
          effects: [
            FadeEffect(duration: duration),
            SlideEffect(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
              duration: duration,
            ),
          ],
          child: child,
        );
        break;

      case 'pulse':
        animated = Animate(
          effects: [
            ScaleEffect(
              begin: const Offset(0.84, 0.84),
              end: const Offset(1, 1),
              duration: duration,
            ),
          ],
          child: child,
        );
        break;

      case 'shake':
        animated = Animate(
          effects: [ShakeEffect(duration: duration)],
          child: child,
        );
        break;

      default:
        animated = child;
    }

    return KeyedSubtree(key: ValueKey<String>(reactionKey), child: animated);
  }

  static CrossAxisAlignment _crossAxis(dynamic value) {
    switch (value?.toString()) {
      case 'center':
        return CrossAxisAlignment.center;

      case 'end':
      case 'right':
        return CrossAxisAlignment.end;

      default:
        return CrossAxisAlignment.stretch;
    }
  }

  static IconData _iconData(String? value) {
    switch (value) {
      case 'add':
        return Icons.add_rounded;
      case 'alert':
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'check':
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'close':
        return Icons.close_rounded;
      case 'edit':
        return Icons.edit_outlined;
      case 'inbox':
        return Icons.inbox_outlined;
      case 'info':
        return Icons.info_outline_rounded;
      case 'location':
        return Icons.location_on_outlined;
      case 'person':
        return Icons.person_outline_rounded;
      case 'phone':
        return Icons.phone_outlined;
      case 'search':
        return Icons.search_rounded;
      case 'star':
        return Icons.star_outline_rounded;
      case 'time':
        return Icons.schedule_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  static double _double(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _display(dynamic value) {
    if (value == null || value == '') {
      return '0';
    }

    if (value is num) {
      final number = value.toDouble();

      if (number == number.roundToDouble()) {
        return number.toInt().toString();
      }

      return number.toStringAsFixed(2);
    }

    return value.toString();
  }

  static Color? _hexColor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    var hex = value.replaceAll('#', '');

    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    final parsed = int.tryParse(hex, radix: 16);

    return parsed == null ? null : Color(parsed);
  }
}
