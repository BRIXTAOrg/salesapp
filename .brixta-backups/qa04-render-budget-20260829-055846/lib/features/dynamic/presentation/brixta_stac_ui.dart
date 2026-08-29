import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:stac/stac.dart';

import '../../../core/design/responsibility_theme.dart';

typedef BrixtaUiRunAction = Future<void> Function(Map<String, dynamic> action);

class BrixtaUiRuntime {
  const BrixtaUiRuntime({
    required this.record,
    required this.stateId,
    required this.actions,
    required this.submittingActionKey,
    required this.onRunAction,
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
  final Future<void> Function()? onRefresh;

  final Map<String, int> effectNonces;
  final Map<String, String> effectAnimationPresets;
  final Map<String, int> effectAnimationDurations;
  final Set<String> forceVisibleBlockIds;
  final Set<String> forceHiddenBlockIds;

  @override
  Widget build(BuildContext context) {
    final runtime = BrixtaUiRuntime(
      record: record,
      stateId: stateId,
      actions: actions,
      submittingActionKey: submittingActionKey,
      onRunAction: onRunAction,
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

class _BrixtaDocumentView extends StatelessWidget {
  const _BrixtaDocumentView({required this.document, required this.runtime});

  // BRIXTA_RENDER_GRAPH_GUARD_V1
  //
  // CMS-authored UI is untrusted declarative input.
  // A malformed graph must never be able to recurse until the
  // employee application exhausts its Dart stack.
  static const int _maxRenderDepth = 64;

  final Map<String, dynamic> document;
  final BrixtaUiRuntime runtime;

  List<Map<String, dynamic>> get blocks {
    final raw = document['blocks'];

    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, Map<String, dynamic>> get byId {
    return {
      for (final block in blocks)
        if (block['id'] != null) block['id'].toString(): block,
    };
  }

  List<String> get rootIds {
    final raw = document['rootIds'];

    if (raw is! List) {
      return const [];
    }

    return raw.map((item) => item.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final map = byId;

    final normal = <Widget>[];

    final overlays = <Widget>[];

    for (final id in rootIds) {
      final block = map[id];

      if (block == null || !runtime.blockVisible(block)) {
        continue;
      }

      final type = block['type']?.toString() ?? '';

      final widget = _renderBlock(context, block, map);

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
            );
          }).toList(),
        );
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

        rendered = SizedBox(
          width: double.infinity,

          child: FilledButton(
            onPressed: action == null || busy
                ? null
                : () => unawaited(runtime.onRunAction(action!)),

            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),

              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(label),
            ),
          ),
        );
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
          lottie = Lottie.network(url, repeat: config['repeat'] != false);
        } else if (asset.isNotEmpty) {
          lottie = Lottie.asset(asset, repeat: config['repeat'] != false);
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

    return _animate(context, rendered, block);
  }

  List<Widget> _children(
    BuildContext context,
    List<String> ids,
    Map<String, Map<String, dynamic>> map, {
    required Set<String> ancestry,
    required int depth,
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
    Map<String, dynamic> block,
  ) {
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
