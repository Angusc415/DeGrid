import 'dart:ui';

class PlanViewport {
  double mmPerPx;
  Offset worldOriginMm;

  PlanViewport({
    required this.mmPerPx,
    required this.worldOriginMm,
  });

  Offset screenToWorld(Offset screenPx) => worldOriginMm + screenPx * mmPerPx;

  Offset worldToScreen(Offset worldMm) => (worldMm - worldOriginMm) / mmPerPx;

  void panByScreenDelta(Offset deltaPx) {
    worldOriginMm -= deltaPx * mmPerPx;
  }

  void zoomAt({
    required double zoomFactor,
    required Offset focalScreenPx,
  }) {
    final before = screenToWorld(focalScreenPx);
    mmPerPx *= zoomFactor;
    final after = screenToWorld(focalScreenPx);
    worldOriginMm += (before - after);
  }
}
