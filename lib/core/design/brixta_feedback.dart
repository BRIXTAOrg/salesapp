import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BRIXTA SONIC LANGUAGE V1
///
/// These are product earcons, not Android/iOS stock click sounds.
///
/// selection:
/// navigation, chips, light selection
///
/// action:
/// opening Responsibilities / meaningful taps
///
/// decision:
/// approval/rejection choices
///
/// success:
/// completed mutation / successful operation
///
/// notice:
/// surfaced contextual notification
abstract final class BrixtaFeedback {
  static AudioPool? _selectionPool;
  static AudioPool? _actionPool;
  static AudioPool? _decisionPool;
  static AudioPool? _successPool;
  static AudioPool? _noticePool;

  static Future<void>? _bootFuture;

  static final AudioContext _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
    respectSilence: true,
    stayAwake: false,
  ).build();

  static Future<void> warmUp() {
    return _bootFuture ??= _boot();
  }

  static Future<void> _boot() async {
    try {
      _selectionPool = await AudioPool.create(
        source: AssetSource('sounds/brixta_select.mp3'),
        minPlayers: 1,
        maxPlayers: 4,
        playerMode: PlayerMode.lowLatency,
        audioContext: _context,
      );

      _actionPool = await AudioPool.create(
        source: AssetSource('sounds/brixta_action.mp3'),
        minPlayers: 1,
        maxPlayers: 4,
        playerMode: PlayerMode.lowLatency,
        audioContext: _context,
      );

      _decisionPool = await AudioPool.create(
        source: AssetSource('sounds/brixta_decision.mp3'),
        minPlayers: 1,
        maxPlayers: 3,
        playerMode: PlayerMode.lowLatency,
        audioContext: _context,
      );

      _successPool = await AudioPool.create(
        source: AssetSource('sounds/brixta_success.mp3'),
        minPlayers: 1,
        maxPlayers: 2,
        playerMode: PlayerMode.lowLatency,
        audioContext: _context,
      );

      _noticePool = await AudioPool.create(
        source: AssetSource('sounds/brixta_notice.mp3'),
        minPlayers: 1,
        maxPlayers: 2,
        playerMode: PlayerMode.lowLatency,
        audioContext: _context,
      );
    } catch (_) {
      // Sound is enhancement only.
      //
      // Audio failure must NEVER break navigation,
      // Responsibilities, Pixel Logic, login or submissions.
    }
  }

  static Future<void> _play(
    AudioPool? Function() getPool, {
    required double volume,
  }) async {
    try {
      await warmUp();

      final pool = getPool();

      if (pool != null) {
        await pool.start(volume: volume);
      }
    } catch (_) {
      // Interaction remains functional without audio.
    }
  }

  static Future<void> selection() async {
    await HapticFeedback.selectionClick();

    await _play(() => _selectionPool, volume: .17);
  }

  static Future<void> action() async {
    await HapticFeedback.lightImpact();

    await _play(() => _actionPool, volume: .20);
  }

  static Future<void> decision() async {
    await HapticFeedback.lightImpact();

    await _play(() => _decisionPool, volume: .21);
  }

  static Future<void> success() async {
    await HapticFeedback.mediumImpact();

    await _play(() => _successPool, volume: .23);
  }

  static Future<void> notice() async {
    await HapticFeedback.selectionClick();

    await _play(() => _noticePool, volume: .17);
  }

  static Future<void> shutdown() async {
    final pools = [
      _selectionPool,
      _actionPool,
      _decisionPool,
      _successPool,
      _noticePool,
    ];

    for (final pool in pools) {
      try {
        await pool?.dispose();
      } catch (_) {}
    }

    _selectionPool = null;
    _actionPool = null;
    _decisionPool = null;
    _successPool = null;
    _noticePool = null;

    _bootFuture = null;
  }
}

/// Physical micro-interaction used by BRIXTA controls.
///
/// Does not intercept the actual gesture underneath.
class BrixtaPressScale extends StatefulWidget {
  const BrixtaPressScale({super.key, required this.child, this.scale = .975});

  final Widget child;
  final double scale;

  @override
  State<BrixtaPressScale> createState() => _BrixtaPressScaleState();
}

class _BrixtaPressScaleState extends State<BrixtaPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || value == _pressed) {
      return;
    }

    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations == true;

    return Listener(
      behavior: HitTestBehavior.translucent,

      onPointerDown: (_) => _setPressed(true),

      onPointerUp: (_) => _setPressed(false),

      onPointerCancel: (_) => _setPressed(false),

      child: AnimatedScale(
        scale: reducedMotion ? 1 : (_pressed ? widget.scale : 1),

        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 95),

        curve: Curves.easeOutCubic,

        child: widget.child,
      ),
    );
  }
}
