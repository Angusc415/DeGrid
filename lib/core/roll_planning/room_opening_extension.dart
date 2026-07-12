import 'dart:math' as math;
import 'dart:ui';

import '../geometry/opening.dart';
import '../geometry/room.dart';

/// Returns [room] with a rectangular tab added at each of its openings,
/// extending the floor area [extensionMm] through the wall.
///
/// Carpet take-off convention: measure through doorways to under the closed
/// door (roughly half the wall thickness), not to the room polygon line.
/// Applies to doors and pass-through openings alike — both are floor-level
/// gaps in this model. Returns [room] unchanged when [extensionMm] <= 0 or no
/// openings belong to the room.
Room extendRoomThroughOpenings(
  Room room,
  List<Opening> openings,
  int roomIndex,
  double extensionMm,
) {
  if (extensionMm <= 0) return room;
  final verts =
      room.vertices.length > 1 && room.vertices.first == room.vertices.last
          ? room.vertices.sublist(0, room.vertices.length - 1)
          : room.vertices;
  if (verts.length < 3) return room;

  final byEdge = <int, List<Opening>>{};
  for (final o in openings) {
    if (o.roomIndex != roomIndex) continue;
    if (o.edgeIndex < 0 || o.edgeIndex >= verts.length) continue;
    if (o.widthMm <= 0) continue;
    (byEdge[o.edgeIndex] ??= []).add(o);
  }
  if (byEdge.isEmpty) return room;

  final out = <Offset>[];
  for (var i = 0; i < verts.length; i++) {
    final v0 = verts[i];
    final v1 = verts[(i + 1) % verts.length];
    out.add(v0);
    final edgeOpenings = byEdge[i];
    if (edgeOpenings == null) continue;
    final dx = v1.dx - v0.dx;
    final dy = v1.dy - v0.dy;
    final edgeLen = math.sqrt(dx * dx + dy * dy);
    if (edgeLen <= 0) continue;
    final dir = Offset(dx / edgeLen, dy / edgeLen);
    // Outward normal: pick the perpendicular whose probe point (just off the
    // edge midpoint) lands outside the polygon. Robust for either winding.
    var normal = Offset(-dir.dy, dir.dx);
    final mid = Offset(v0.dx + dx / 2, v0.dy + dy / 2);
    if (_pointInPolygon(mid + normal, verts)) {
      normal = -normal;
    }
    edgeOpenings.sort((a, b) => a.offsetMm.compareTo(b.offsetMm));
    var prevEnd = 0.0;
    for (final o in edgeOpenings) {
      final start = o.offsetMm.clamp(0.0, edgeLen);
      final end = (o.offsetMm + o.widthMm).clamp(0.0, edgeLen);
      // Skip degenerate or overlapping openings — a tab through another tab
      // would self-intersect the ring.
      if (end - start <= 1e-6 || start < prevEnd) continue;
      prevEnd = end;
      final p0 = Offset(v0.dx + dir.dx * start, v0.dy + dir.dy * start);
      final p1 = Offset(v0.dx + dir.dx * end, v0.dy + dir.dy * end);
      out.add(p0);
      out.add(p0 + normal * extensionMm);
      out.add(p1 + normal * extensionMm);
      out.add(p1);
    }
  }
  return Room(vertices: out, name: room.name);
}

bool _pointInPolygon(Offset p, List<Offset> verts) {
  var inside = false;
  for (var i = 0, j = verts.length - 1; i < verts.length; j = i++) {
    final vi = verts[i];
    final vj = verts[j];
    final intersects = ((vi.dy > p.dy) != (vj.dy > p.dy)) &&
        (p.dx < (vj.dx - vi.dx) * (p.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx);
    if (intersects) inside = !inside;
  }
  return inside;
}
