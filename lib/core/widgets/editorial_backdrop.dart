import 'package:flutter/material.dart';

import '../design/app_design.dart';

class EditorialBackdrop extends StatelessWidget {
  const EditorialBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppDesign.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _EditorialGridPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _EditorialGridPainter extends CustomPainter {
  const _EditorialGridPainter();

  static const spacing = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;

    // --------------------------------------------------------
    // 40px GRID
    //
    // Opacity fades as lines move away from the visual centre.
    // This approximates the requested radial grid mask without
    // requiring a composited web-style CSS mask.
    // --------------------------------------------------------

    final centerX = size.width / 2;

    final centerY = size.height / 2;

    for (double x = 0; x <= size.width; x += spacing) {
      final distance = ((x - centerX).abs() / centerX).clamp(0.0, 1.0);

      final alpha = .18 * (1 - distance) * (1 - distance);

      paint.color = AppDesign.line.withValues(alpha: alpha);

      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      final distance = ((y - centerY).abs() / centerY).clamp(0.0, 1.0);

      final alpha = .16 * (1 - distance) * (1 - distance);

      paint.color = AppDesign.line.withValues(alpha: alpha);

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // --------------------------------------------------------
    // STRUCTURAL 4-COLUMN GUIDES
    // --------------------------------------------------------

    paint
      ..strokeWidth = 1
      ..color = AppDesign.line.withValues(alpha: .82);

    for (final fraction in const [.25, .50, .75]) {
      final x = size.width * fraction;

      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Technical 2px scan line.
///
/// Used where the runtime is actively syncing.
class EditorialScanLine extends StatefulWidget {
  const EditorialScanLine({super.key, this.color = AppDesign.blue});

  final Color color;

  @override
  State<EditorialScanLine> createState() => _EditorialScanLineState();
}

class _EditorialScanLineState extends State<EditorialScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 2,
        child: ColoredBox(
          color: AppDesign.line,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Align(
                alignment: Alignment(-1 + (_controller.value * 2), 0),
                child: FractionallySizedBox(
                  widthFactor: .38,
                  heightFactor: 1,
                  child: ColoredBox(color: widget.color),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
