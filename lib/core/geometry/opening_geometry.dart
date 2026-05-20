import 'dart:math' as math;
import 'dart:ui';

import 'opening.dart';
import 'room.dart';

/// Tolerance (mm) for treating two wall endpoints as coincident (shared edge).
const double kSharedEdgeTolMm = 1.0;

/// General snap when dragging a room (vertices, shared edges).
const double kRoomMoveSnapTolMm = 45.0;

/// Stronger snap for doorways / walls with openings (mm).
const double kOpeningWallSnapTolMm = 90.0;

/// Live dimension segments shown while aligning a room with a doorway.
typedef RoomMoveAlignHint = ({
  int roomIndex,
  int edgeIndex,
  Offset cornerStartMm,
  Offset gapStartMm,
  Offset gapEndMm,
  Offset cornerEndMm,
  double segBeforeMm,
  double openingWidthMm,
  double segAfterMm,
  /// When true, draw on the far side of the wall (host / snapped-to wall).
  bool hostWall,
});

/// Unique polygon vertices (drops duplicate closing vertex).
List<Offset> uniquePolygonVertices(List<Offset> vertices) {
  if (vertices.length <= 1) return vertices;
  if (vertices.first == vertices.last) {
    return vertices.sublist(0, vertices.length - 1);
  }
  return vertices;
}

/// Wall edge from vertex [edgeIndex] to next vertex (wraps).
({Offset a, Offset b}) edgeSegment(List<Offset> vertices, int edgeIndex) {
  final n = vertices.length;
  final i = edgeIndex % n;
  final j = (i + 1) % n;
  return (a: vertices[i], b: vertices[j]);
}

double edgeLengthMm(List<Offset> vertices, int edgeIndex) {
  final e = edgeSegment(vertices, edgeIndex);
  return (e.b - e.a).distance;
}

/// True when [edgeA] is the reverse of [edgeB] (shared wall between rooms).
bool edgesAreSharedReversed(
  ({Offset a, Offset b}) edgeA,
  ({Offset a, Offset b}) edgeB, {
  double tolMm = kSharedEdgeTolMm,
}) {
  return (edgeA.a - edgeB.b).distance <= tolMm &&
      (edgeA.b - edgeB.a).distance <= tolMm;
}

/// Opening gap along an edge in world mm.
({Offset start, Offset end})? openingGapWorld(
  List<Offset> vertices,
  Opening opening,
) {
  if (vertices.isEmpty) return null;
  final e = edgeSegment(vertices, opening.edgeIndex);
  final len = (e.b - e.a).distance;
  if (len <= 0) return null;
  final t0 = (opening.offsetMm / len).clamp(0.0, 1.0);
  final t1 = ((opening.offsetMm + opening.widthMm) / len).clamp(0.0, 1.0);
  return (
    start: Offset(
      e.a.dx + t0 * (e.b.dx - e.a.dx),
      e.a.dy + t0 * (e.b.dy - e.a.dy),
    ),
    end: Offset(
      e.a.dx + t1 * (e.b.dx - e.a.dx),
      e.a.dy + t1 * (e.b.dy - e.a.dy),
    ),
  );
}

/// Mirror offset on a reversed shared edge of the same length.
double mirrorOffsetOnEdge(double edgeLenMm, Opening primary) {
  final width = primary.widthMm.clamp(0.0, edgeLenMm);
  return (edgeLenMm - (primary.offsetMm + width)).clamp(0.0, edgeLenMm - width);
}

/// Finds a shared reversed edge between two rooms, if any.
({int roomIndex, int edgeIndex})? findSharedEdge(
  List<Room> rooms,
  int roomA,
  int edgeA,
) {
  if (roomA < 0 || roomA >= rooms.length) return null;
  final vertsA = rooms[roomA].vertices;
  if (vertsA.isEmpty) return null;
  final segA = edgeSegment(vertsA, edgeA);

  for (int ri = 0; ri < rooms.length; ri++) {
    if (ri == roomA) continue;
    final vertsB = rooms[ri].vertices;
    if (vertsB.isEmpty) continue;
    for (int ei = 0; ei < vertsB.length; ei++) {
      if (edgesAreSharedReversed(segA, edgeSegment(vertsB, ei))) {
        return (roomIndex: ri, edgeIndex: ei);
      }
    }
  }
  return null;
}

/// Wall the moving doorway is aligning to (shared or parallel within [tolMm]).
({int roomIndex, int edgeIndex})? findAlignTargetWall(
  List<Room> rooms,
  int movingRoomIndex,
  int movingEdgeIndex, {
  double tolMm = kOpeningWallSnapTolMm,
}) {
  final shared = findSharedEdge(rooms, movingRoomIndex, movingEdgeIndex);
  if (shared != null) return shared;

  if (movingRoomIndex < 0 || movingRoomIndex >= rooms.length) return null;
  final wall = edgeSegment(rooms[movingRoomIndex].vertices, movingEdgeIndex);

  ({int roomIndex, int edgeIndex})? best;
  double bestScore = tolMm;
  for (int ri = 0; ri < rooms.length; ri++) {
    if (ri == movingRoomIndex) continue;
    final vertsB = rooms[ri].vertices;
    for (int ej = 0; ej < vertsB.length; ej++) {
      final target = edgeSegment(vertsB, ej);
      if (!_edgesParallel(wall, target)) continue;
      final score = _distancePointToSegment(wall.a, target.a, target.b) +
          _distancePointToSegment(wall.b, target.a, target.b);
      if (score < bestScore) {
        bestScore = score;
        best = (roomIndex: ri, edgeIndex: ej);
      }
    }
  }
  return best;
}

Offset _projectPointOntoSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 <= 0) return a;
  final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  final tClamped = t.clamp(0.0, 1.0);
  return Offset(a.dx + tClamped * ab.dx, a.dy + tClamped * ab.dy);
}

/// Jamb dimensions along one wall from its corners through a door gap.
RoomMoveAlignHint? wallAlignHint({
  required int roomIndex,
  required int edgeIndex,
  required Offset cornerStartMm,
  required Offset cornerEndMm,
  required Offset gapStartMm,
  required Offset gapEndMm,
  bool hostWall = false,
}) {
  final edgeLen = (cornerEndMm - cornerStartMm).distance;
  if (edgeLen <= 0) return null;

  final p0 = _projectPointOntoSegment(gapStartMm, cornerStartMm, cornerEndMm);
  final p1 = _projectPointOntoSegment(gapEndMm, cornerStartMm, cornerEndMm);
  final d0 = (p0 - cornerStartMm).distance;
  final d1 = (p1 - cornerStartMm).distance;
  final Offset gs;
  final Offset ge;
  if (d0 <= d1) {
    gs = p0;
    ge = p1;
  } else {
    gs = p1;
    ge = p0;
  }

  return (
    roomIndex: roomIndex,
    edgeIndex: edgeIndex,
    cornerStartMm: cornerStartMm,
    gapStartMm: gs,
    gapEndMm: ge,
    cornerEndMm: cornerEndMm,
    segBeforeMm: (gs - cornerStartMm).distance,
    openingWidthMm: (ge - gs).distance,
    segAfterMm: (cornerEndMm - ge).distance,
    hostWall: hostWall,
  );
}

int? _indexOfMirror(
  List<Opening> openings,
  Opening primary,
  int mirrorRoomIndex,
  int mirrorEdgeIndex,
) {
  for (int i = 0; i < openings.length; i++) {
    final o = openings[i];
    if (o.roomIndex != mirrorRoomIndex || o.edgeIndex != mirrorEdgeIndex) {
      continue;
    }
    if (primary.linkId != null && o.linkId == primary.linkId) return i;
    if ((o.widthMm - primary.widthMm).abs() < 0.5 &&
        primary.linkId == null &&
        o.linkId == null) {
      return i;
    }
  }
  return null;
}

/// Ensures mirrored openings exist on all shared edges; updates link ids.
List<Opening> syncMirroredOpenings(List<Room> rooms, List<Opening> openings) {
  final result = List<Opening>.from(openings);
  final linkCounter = result
      .where((o) => o.linkId != null)
      .map((o) => int.tryParse(o.linkId!.replaceFirst('link_', '')) ?? 0)
      .fold<int>(0, (a, b) => a > b ? a : b);

  var nextLink = linkCounter + 1;
  String newLinkId() => 'link_${nextLink++}';

  for (int pi = 0; pi < result.length; pi++) {
    final primary = result[pi];
    if (primary.roomIndex < 0 || primary.roomIndex >= rooms.length) continue;
    final shared = findSharedEdge(rooms, primary.roomIndex, primary.edgeIndex);
    if (shared == null) continue;

    final edgeLen = edgeLengthMm(
      rooms[shared.roomIndex].vertices,
      shared.edgeIndex,
    );
    if (edgeLen <= 0) continue;

    final linkId = primary.linkId ?? newLinkId();
    final mirrored = Opening(
      roomIndex: shared.roomIndex,
      edgeIndex: shared.edgeIndex,
      offsetMm: mirrorOffsetOnEdge(edgeLen, primary),
      widthMm: primary.widthMm.clamp(0.0, edgeLen),
      isDoor: primary.isDoor,
      linkId: linkId,
    );

    final updatedPrimary = Opening(
      roomIndex: primary.roomIndex,
      edgeIndex: primary.edgeIndex,
      offsetMm: primary.offsetMm,
      widthMm: primary.widthMm,
      isDoor: primary.isDoor,
      linkId: linkId,
    );
    result[pi] = updatedPrimary;

    final mirrorIdx = _indexOfMirror(
      result,
      updatedPrimary,
      shared.roomIndex,
      shared.edgeIndex,
    );
    if (mirrorIdx != null) {
      result[mirrorIdx] = mirrored;
    } else {
      result.add(mirrored);
    }
  }

  return result;
}

bool _edgesParallel(
  ({Offset a, Offset b}) e1,
  ({Offset a, Offset b}) e2, {
  double maxAngleDeg = 10,
}) {
  final d1 = e1.b - e1.a;
  final d2 = e2.b - e2.a;
  if (d1.distance < 1e-6 || d2.distance < 1e-6) return false;
  final cross = (d1.dx * d2.dy - d1.dy * d2.dx).abs();
  final sinAngle = cross / (d1.distance * d2.distance);
  return sinAngle <= math.sin(maxAngleDeg * math.pi / 180);
}

/// Tracks the strongest snap in one pass (lowest [score] within [maxScore]).
class _SnapPass {
  _SnapPass(this.baseDelta, this.maxScore);

  final Offset baseDelta;
  final double maxScore;
  double bestScore = double.infinity;
  Offset? candidate;

  void consider(Offset correction, double score) {
    if (score > maxScore || score >= bestScore) return;
    bestScore = score;
    candidate = baseDelta + correction;
  }

  Offset apply(Offset delta) => candidate ?? delta;
}

/// Best translation delta when dragging [movingRoomIndex], including edge/opening snap.
({Offset delta, List<RoomMoveAlignHint> alignHints}) computeRoomMoveSnap({
  required int movingRoomIndex,
  required List<Offset> movingVertsAtStart,
  required Offset baseDelta,
  required List<Room> rooms,
  required List<Opening> openings,
  double snapToleranceMm = kRoomMoveSnapTolMm,
  double openingSnapToleranceMm = kOpeningWallSnapTolMm,
}) {
  Offset delta = baseDelta;
  final hints = <RoomMoveAlignHint>[];

  List<Offset> movedVerts(Offset d) =>
      movingVertsAtStart.map((v) => v + d).toList();

  // --- Opening-first (90 mm): doorway pulls to walls more strongly ---

  // A) Whole wall with a door → parallel static wall (lay flush on line).
  final passWall = _SnapPass(delta, openingSnapToleranceMm);
  for (final o in openings) {
    if (o.roomIndex != movingRoomIndex) continue;
    final wall = edgeSegment(movedVerts(passWall.baseDelta), o.edgeIndex);
    for (int ri = 0; ri < rooms.length; ri++) {
      if (ri == movingRoomIndex) continue;
      final vertsB = rooms[ri].vertices;
      for (int ej = 0; ej < vertsB.length; ej++) {
        final target = edgeSegment(vertsB, ej);
        if (!_edgesParallel(wall, target)) continue;
        final dA = _distancePointToSegment(wall.a, target.a, target.b);
        final dB = _distancePointToSegment(wall.b, target.a, target.b);
        final cA = _snapPointToSegment(wall.a, target.a, target.b);
        final cB = _snapPointToSegment(wall.b, target.a, target.b);
        passWall.consider(
          Offset((cA.dx + cB.dx) / 2, (cA.dy + cB.dy) / 2),
          dA + dB,
        );
      }
    }
  }
  delta = passWall.apply(delta);

  // B) Door gap endpoints → nearest static wall line.
  final passGap = _SnapPass(delta, openingSnapToleranceMm);
  for (final o in openings) {
    if (o.roomIndex != movingRoomIndex) continue;
    final gap = openingGapWorld(movedVerts(passGap.baseDelta), o);
    if (gap == null) continue;
    for (int ri = 0; ri < rooms.length; ri++) {
      if (ri == movingRoomIndex) continue;
      final vertsB = rooms[ri].vertices;
      for (int ej = 0; ej < vertsB.length; ej++) {
        final e = edgeSegment(vertsB, ej);
        if ((e.b - e.a).distance <= 0) continue;
        final dStart = _distancePointToSegment(gap.start, e.a, e.b);
        final dEnd = _distancePointToSegment(gap.end, e.a, e.b);
        final c0 = _snapPointToSegment(gap.start, e.a, e.b);
        final c1 = _snapPointToSegment(gap.end, e.a, e.b);
        passGap.consider(Offset((c0.dx + c1.dx) / 2, (c0.dy + c1.dy) / 2), dStart + dEnd);
      }
    }
  }
  delta = passGap.apply(delta);

  // C) Door gap → existing doorway on another room (jamb-to-jamb).
  final passJamb = _SnapPass(delta, openingSnapToleranceMm);
  for (final oMove in openings) {
    if (oMove.roomIndex != movingRoomIndex) continue;
    final gapMove = openingGapWorld(movedVerts(passJamb.baseDelta), oMove);
    if (gapMove == null) continue;
    for (final oStatic in openings) {
      if (oStatic.roomIndex == movingRoomIndex) continue;
      if (oStatic.roomIndex < 0 || oStatic.roomIndex >= rooms.length) continue;
      final gapStatic = openingGapWorld(
        rooms[oStatic.roomIndex].vertices,
        oStatic,
      );
      if (gapStatic == null) continue;
      for (final pair in [
        (gapMove.start, gapStatic.start, gapMove.end, gapStatic.end),
        (gapMove.start, gapStatic.end, gapMove.end, gapStatic.start),
      ]) {
        final correction = Offset(
          ((pair.$2 - pair.$1).dx + (pair.$4 - pair.$3).dx) / 2,
          ((pair.$2 - pair.$1).dy + (pair.$4 - pair.$3).dy) / 2,
        );
        passJamb.consider(
          correction,
          (pair.$1 - pair.$2).distance + (pair.$3 - pair.$4).distance,
        );
      }
    }
  }
  delta = passJamb.apply(delta);

  // D) Static door jambs → moving room vertices.
  final passJambVerts = _SnapPass(delta, openingSnapToleranceMm);
  for (final o in openings) {
    if (o.roomIndex == movingRoomIndex) continue;
    if (o.roomIndex < 0 || o.roomIndex >= rooms.length) continue;
    final gap = openingGapWorld(rooms[o.roomIndex].vertices, o);
    if (gap == null) continue;
    for (final vStatic in [gap.start, gap.end]) {
      for (final vMovingStart in movingVertsAtStart) {
        final moved = vMovingStart + passJambVerts.baseDelta;
        passJambVerts.consider(vStatic - moved, (moved - vStatic).distance);
      }
    }
  }
  delta = passJambVerts.apply(delta);

  // --- General room snap (45 mm) ---

  double bestScore = snapToleranceMm;
  Offset bestDelta = delta;

  final movingUnique = uniquePolygonVertices(movingVertsAtStart);
  for (int ei = 0; ei < movingUnique.length; ei++) {
    final segMoveStart = edgeSegment(movingVertsAtStart, ei);
    for (int ri = 0; ri < rooms.length; ri++) {
      if (ri == movingRoomIndex) continue;
      final vertsB = rooms[ri].vertices;
      if (vertsB.isEmpty) continue;
      for (int ej = 0; ej < vertsB.length; ej++) {
        final segStatic = edgeSegment(vertsB, ej);
        final segMove = (
          a: segMoveStart.a + delta,
          b: segMoveStart.b + delta,
        );
        if (!edgesAreSharedReversed(
          segMove,
          segStatic,
          tolMm: snapToleranceMm,
        )) {
          final d0 = (segMove.a - segStatic.b).distance;
          final d1 = (segMove.b - segStatic.a).distance;
          final score = d0 + d1;
          if (score < bestScore) {
            final c0 = segStatic.b - segMove.a;
            final c1 = segStatic.a - segMove.b;
            final correction = Offset((c0.dx + c1.dx) / 2, (c0.dy + c1.dy) / 2);
            bestScore = score;
            bestDelta = delta + correction;
          }
          continue;
        }
        final correction = segStatic.b - segMove.a;
        final score = correction.distance;
        if (score < bestScore) {
          bestScore = score;
          bestDelta = delta + correction;
        }
      }
    }
  }

  for (int ri = 0; ri < rooms.length; ri++) {
    if (ri == movingRoomIndex) continue;
    final staticVerts = uniquePolygonVertices(rooms[ri].vertices);
    for (final vStatic in staticVerts) {
      for (final vMovingStart in movingVertsAtStart) {
        final moved = vMovingStart + bestDelta;
        final score = (moved - vStatic).distance;
        if (score < bestScore) {
          bestScore = score;
          bestDelta = bestDelta + (vStatic - moved);
        }
      }
    }
  }

  delta = bestDelta;

  // Live jamb dimensions on the host wall only (not on the moving door wall).
  final finalVerts = movedVerts(delta);
  final movingRoom = Room(vertices: finalVerts);
  final roomsWithMoved = [
    for (int i = 0; i < rooms.length; i++)
      i == movingRoomIndex ? movingRoom : rooms[i],
  ];
  for (final o in openings) {
    if (o.roomIndex != movingRoomIndex) continue;
    final gap = openingGapWorld(finalVerts, o);
    if (gap == null) continue;

    final target = findAlignTargetWall(
      roomsWithMoved,
      movingRoomIndex,
      o.edgeIndex,
      tolMm: openingSnapToleranceMm,
    );
    if (target == null) continue;

    final targetWall = edgeSegment(
      roomsWithMoved[target.roomIndex].vertices,
      target.edgeIndex,
    );
    final hostHint = wallAlignHint(
      roomIndex: target.roomIndex,
      edgeIndex: target.edgeIndex,
      cornerStartMm: targetWall.a,
      cornerEndMm: targetWall.b,
      gapStartMm: gap.start,
      gapEndMm: gap.end,
      hostWall: true,
    );
    if (hostHint != null) hints.add(hostHint);
  }

  return (delta: delta, alignHints: hints);
}

double _distancePointToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 <= 0) return (p - a).distance;
  final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  final tClamped = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + tClamped * ab.dx, a.dy + tClamped * ab.dy);
  return (p - proj).distance;
}

Offset _snapPointToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 <= 0) return a - p;
  final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  final tClamped = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + tClamped * ab.dx, a.dy + tClamped * ab.dy);
  return proj - p;
}
