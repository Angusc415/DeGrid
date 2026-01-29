import 'package:flutter/material.dart';
import 'dart:ui';
import 'viewport.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';


class PlanCanvas extends StatefulWidget {
  const PlanCanvas({super.key});

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<PlanCanvas> {
 final PlanViewport _vp = PlanViewport(
    mmPerPx: 5.0,
    worldOriginMm: const Offset(-500, -500),
  );

List<Offset> _pointsWorldMm = [];

  double _startMmPerPx = 5.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,

      // PAN (web): Shift + left-drag
      onPointerMove: (e) {
        if (kIsWeb &&
            e.buttons == 1 &&
            HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftLeft)) {
          setState(() {
            _vp.panByScreenDelta(e.delta);
          });
        }
      },

      // ZOOM (web): mouse wheel / trackpad scroll zoom
      onPointerSignal: (signal) {
        if (!kIsWeb) return;
        if (signal is PointerScrollEvent) {
          // scroll up => zoom in, scroll down => zoom out
          final scrollY = signal.scrollDelta.dy;
          final zoomFactor = (scrollY > 0) ? 1.08 : 0.92;

          setState(() {
            _vp.zoomAt(
              zoomFactor: zoomFactor,
              focalScreenPx: signal.localPosition,
            );
          });
        }
      },

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // IMPORTANT: disable scale on web to stop left-drag pan weirdness
        onScaleStart: kIsWeb
            ? null
            : (_) {
                _startMmPerPx = _vp.mmPerPx;
              },
        onScaleUpdate: kIsWeb
            ? null
            : (d) {
                setState(() {
                  _vp.panByScreenDelta(d.focalPointDelta);

                  final desiredMmPerPx = _startMmPerPx / d.scale;
                  final zoomFactor = desiredMmPerPx / _vp.mmPerPx;
                  _vp.zoomAt(
                    zoomFactor: zoomFactor,
                    focalScreenPx: d.focalPoint,
                  );
                });
              },

        // Place points
        onTapDown: (d) {
          setState(() {
            _pointsWorldMm = [
              ..._pointsWorldMm,
              _vp.screenToWorld(d.localPosition),
            ];
          });
        },

        child: SizedBox.expand(
          child: CustomPaint(
            painter: _PlanPainter(vp: _vp, pointsWorldMm: _pointsWorldMm),
          ),
        ),
      ),
    );

  }
}

class _PlanPainter extends CustomPainter {
final PlanViewport vp; 
final List<Offset> pointsWorldMm;

_PlanPainter({required this.vp, required this.pointsWorldMm});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

    _drawGrid(canvas, size);

    final pPaint = Paint()..color = Colors.black;
    for (final w in pointsWorldMm) {
      final s = vp.worldToScreen(w);
      canvas.drawCircle(s, 4, pPaint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    const gridMm = 100.0; // 10cm
    final topLeftW = vp.screenToWorld(Offset.zero);
    final bottomRightW = vp.screenToWorld(Offset(size.width, size.height));

    double startX = (topLeftW.dx / gridMm).floor() * gridMm;
    double startY = (topLeftW.dy / gridMm).floor() * gridMm;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 1;

    for (double x = startX; x <= bottomRightW.dx; x += gridMm) {
      final a = vp.worldToScreen(Offset(x, topLeftW.dy));
      final b = vp.worldToScreen(Offset(x, bottomRightW.dy));
      canvas.drawLine(a, b, gridPaint);
    }
    for (double y = startY; y <= bottomRightW.dy; y += gridMm) {
      final a = vp.worldToScreen(Offset(topLeftW.dx, y));
      final b = vp.worldToScreen(Offset(bottomRightW.dx, y));
      canvas.drawLine(a, b, gridPaint);
    }
  }

  @override
bool shouldRepaint(covariant _PlanPainter oldDelegate) => true;
}
