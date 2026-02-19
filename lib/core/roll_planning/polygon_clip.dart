import 'dart:ui';

/// Clips a polygon to an axis-aligned rectangle using Sutherland-Hodgman.
/// Returns the intersection polygon (may be empty or degenerate).
List<Offset> clipPolygonToRect(List<Offset> polygon, double left, double top, double right, double bottom) {
  if (polygon.length < 3) return [];
  List<Offset> out = List<Offset>.from(polygon);
  // Clip to each edge: left (x >= left), right (x <= right), top (y >= top), bottom (y <= bottom).
  out = _clipToHalfPlane(out, 1, 0, left);   // x >= left
  if (out.length < 3) return [];
  out = _clipToHalfPlane(out, -1, 0, -right); // x <= right
  if (out.length < 3) return [];
  out = _clipToHalfPlane(out, 0, 1, top);    // y >= top
  if (out.length < 3) return [];
  out = _clipToHalfPlane(out, 0, -1, -bottom); // y <= bottom
  return out;
}

/// Clip polygon to half-plane: nx*x + ny*y >= c (with (nx,ny) normal).
List<Offset> _clipToHalfPlane(List<Offset> poly, int nx, int ny, double c) {
  final out = <Offset>[];
  final n = poly.length;
  for (int i = 0; i < n; i++) {
    final v0 = poly[i];
    final v1 = poly[(i + 1) % n];
    final d0 = nx * v0.dx + ny * v0.dy - c;
    final d1 = nx * v1.dx + ny * v1.dy - c;
    if (d0 >= 0) out.add(v0);
    if ((d0 >= 0) != (d1 >= 0)) {
      final t = d0 / (d0 - d1);
      out.add(Offset(v0.dx + t * (v1.dx - v0.dx), v0.dy + t * (v1.dy - v0.dy)));
    }
  }
  return out;
}
