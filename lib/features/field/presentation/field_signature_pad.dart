import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/brixta_feedback.dart';
import '../../../core/services/media/local_photo_store.dart';

// BRIXTA_FIELD_APP_CONTRACT_V2 — "Signature" input. The customer signs with
// a finger; the drawing is saved as a PNG on the phone and uploaded with the
// rest of the step, exactly like a photo (so it also works offline).

class FieldSignaturePad extends StatefulWidget {
  const FieldSignaturePad({super.key, required this.title});

  final String title;

  @override
  State<FieldSignaturePad> createState() => _FieldSignaturePadState();
}

class _FieldSignaturePadState extends State<FieldSignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _canvas = Size.zero;
  bool _saving = false;

  bool get _empty => _strokes.every((stroke) => stroke.length < 2);

  void _start(Offset point) {
    setState(() => _strokes.add([point]));
  }

  void _extend(Offset point) {
    if (_strokes.isEmpty) return;
    final inside = point.dx >= 0 &&
        point.dy >= 0 &&
        point.dx <= _canvas.width &&
        point.dy <= _canvas.height;
    if (!inside) return;
    setState(() => _strokes.last.add(point));
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  Future<void> _done() async {
    if (_empty || _saving) return;
    setState(() => _saving = true);
    try {
      const scale = 2.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale);
      _SignaturePainter(_strokes, background: true).paint(canvas, _canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (_canvas.width * scale).round(),
        (_canvas.height * scale).round(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('No image data');

      final temp = File(
        '${Directory.systemTemp.path}/signature-'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await temp.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      final path = await LocalPhotoStore.persist(
        XFile(temp.path),
        prefix: 'signature',
      );
      unawaited(temp.delete().then((_) {}, onError: (_) {}));
      unawaited(BrixtaFeedback.success());
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the signature. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          TextButton(
            onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
            child: const Text('CLEAR'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppDesign.white,
                    borderRadius: BorderRadius.circular(AppDesign.radius),
                    border: Border.all(color: AppDesign.line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesign.radius),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _canvas = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) => _start(details.localPosition),
                          onPanUpdate: (details) =>
                              _extend(details.localPosition),
                          child: CustomPaint(
                            size: _canvas,
                            painter: _SignaturePainter(_strokes),
                            child: _strokes.isEmpty
                                ? Center(
                                    child: Text(
                                      'SIGN HERE',
                                      style: AppDesign.mono(
                                        size: 11,
                                        color: AppDesign.faint,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                  )
                                : const SizedBox.expand(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _empty || _saving ? null : _done,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppDesign.white,
                          ),
                        )
                      : const Text('USE THIS SIGNATURE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, {this.background = false});

  final List<List<Offset>> strokes;
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    if (background) {
      canvas.drawRect(Offset.zero & size, Paint()..color = AppDesign.white);
    }
    final pen = Paint()
      ..color = AppDesign.ink
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.3, pen..style = PaintingStyle.fill);
        pen.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, pen);
    }
  }

  // Strokes are edited in place, so always repaint.
  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
