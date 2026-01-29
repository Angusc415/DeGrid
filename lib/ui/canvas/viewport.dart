import 'dart:ui';

class PlanViewport {
  double mmPerPx;
  Offset worldOriginMm;

  // Zoom limits: prevent zooming too far in or out
  static const double minMmPerPx = 0.1; // Very zoomed in (0.1mm per pixel)
  static const double maxMmPerPx = 100.0; // Very zoomed out (100mm = 10cm per pixel)

  PlanViewport({
    required this.mmPerPx,
    required this.worldOriginMm,
  });

  Offset screenToWorld(Offset screenPx) => worldOriginMm + screenPx * mmPerPx;

  Offset worldToScreen(Offset worldMm) => (worldMm - worldOriginMm) / mmPerPx;

  void panByScreenDelta(Offset deltaPx) {
    worldOriginMm -= deltaPx * mmPerPx;
  }

  void panByWorldDelta(Offset deltaMm) {
    worldOriginMm += deltaMm;
  }

  void zoomAt({
    required double zoomFactor,
    required Offset focalScreenPx,
  }) {
    final newMmPerPx = (mmPerPx * zoomFactor).clamp(minMmPerPx, maxMmPerPx);
    
    // Only zoom if we're within limits
    if (newMmPerPx == mmPerPx && zoomFactor != 1.0) {
      return; // Hit zoom limit
    }

    final before = screenToWorld(focalScreenPx);
    mmPerPx = newMmPerPx;
    final after = screenToWorld(focalScreenPx);
    worldOriginMm += (before - after);
  }

  void resetView({
    required Size screenSize,
    Offset? centerWorldMm,
  }) {
    // Reset to a reasonable default view
    mmPerPx = 5.0;
    final center = centerWorldMm ?? const Offset(0, 0);
    worldOriginMm = center - Offset(screenSize.width / 2, screenSize.height / 2) * mmPerPx;
  }
}
