import 'dart:math' as math;
import 'dart:ui';

/// Pure geometry helpers for rotating a room's vertices and snapping the
/// rotation angle. Kept widget-free so they can be unit tested directly.

/// Rotate each vertex in [vertices] about [pivot] by [radians] (clockwise on
/// screen, since screen-space y grows downward; positive [radians] follows the
/// standard math convention applied to the world coordinates).
List<Offset> rotateVerticesAround(
  List<Offset> vertices,
  Offset pivot,
  double radians,
) {
  if (radians == 0) return List<Offset>.from(vertices);
  final cosA = math.cos(radians);
  final sinA = math.sin(radians);
  return vertices.map((v) {
    final dx = v.dx - pivot.dx;
    final dy = v.dy - pivot.dy;
    return Offset(
      pivot.dx + dx * cosA - dy * sinA,
      pivot.dy + dx * sinA + dy * cosA,
    );
  }).toList();
}

/// Snap a raw rotation delta (in degrees) for room rotation.
///
/// When [fine] is true the raw value is returned unchanged (free rotation).
/// Otherwise the value snaps to the nearest [stepDeg] increment (default 15),
/// except that when it lands within [stickyDeg] of a 90 degree multiple it
/// snaps to that right angle (sticky right angles).
double snapRotationDeg(
  double rawDeg, {
  bool fine = false,
  double stepDeg = 15.0,
  double stickyDeg = 4.0,
}) {
  if (fine) return rawDeg;
  final nearestRightAngle = (rawDeg / 90.0).roundToDouble() * 90.0;
  if ((rawDeg - nearestRightAngle).abs() <= stickyDeg) {
    return nearestRightAngle;
  }
  return (rawDeg / stepDeg).roundToDouble() * stepDeg;
}
