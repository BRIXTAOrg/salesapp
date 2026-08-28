import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BRIXTA interaction feedback.
///
/// Deliberately restrained:
/// - navigation / selection = light native feedback
/// - opening / committing = stronger action feedback
///
/// No continuously-playing audio and no bundled audio dependency.
abstract final class BrixtaFeedback {
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> action() async {
    await HapticFeedback.lightImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
  }
}

/// Adds physical press movement without intercepting the child's
/// existing InkWell/GestureDetector.
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
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 95),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
