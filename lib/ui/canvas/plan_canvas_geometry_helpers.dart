part of 'plan_canvas.dart';

extension PlanCanvasGeometryHelpers on PlanCanvasState {
  Offset? _snapToVertexOrDoor(Offset worldPositionMm) {
    final screen = _vp.worldToScreen(worldPositionMm);
    final tolerancePx = PlanCanvasState._vertexSelectTolerancePx;
    double closestDist = tolerancePx;
    Offset? closestWorld;

    for (int ri = 0; ri < _completedRooms.length; ri++) {
      final room = _completedRooms[ri];
      final verts =
          room.vertices.length > 1 && room.vertices.first == room.vertices.last
          ? room.vertices.sublist(0, room.vertices.length - 1)
          : room.vertices;
      for (int vi = 0; vi < verts.length; vi++) {
        final screenPos = _vp.worldToScreen(verts[vi]);
        final d = (screen - screenPos).distance;
        if (d < closestDist) {
          closestDist = d;
          closestWorld = verts[vi];
        }
      }
    }

    for (final o in _openings) {
      if (o.roomIndex < 0 || o.roomIndex >= _completedRooms.length) continue;
      final room = _completedRooms[o.roomIndex];
      final verts = room.vertices;
      if (o.edgeIndex >= verts.length) continue;
      final i1 = (o.edgeIndex + 1) % verts.length;
      final v0 = verts[o.edgeIndex];
      final v1 = verts[i1];
      final edgeLen = (v1 - v0).distance;
      if (edgeLen <= 0) continue;
      final t0 = (o.offsetMm / edgeLen).clamp(0.0, 1.0);
      final t1 = ((o.offsetMm + o.widthMm) / edgeLen).clamp(0.0, 1.0);
      final gapStart = Offset(
        v0.dx + t0 * (v1.dx - v0.dx),
        v0.dy + t0 * (v1.dy - v0.dy),
      );
      final gapEnd = Offset(
        v0.dx + t1 * (v1.dx - v0.dx),
        v0.dy + t1 * (v1.dy - v0.dy),
      );
      for (final world in [gapStart, gapEnd]) {
        final screenPos = _vp.worldToScreen(world);
        final d = (screen - screenPos).distance;
        if (d < closestDist) {
          closestDist = d;
          closestWorld = world;
        }
      }
    }
    return closestWorld;
  }

  Offset _snapToGrid(Offset worldPositionMm) {
    final snappedX =
        (worldPositionMm.dx / PlanCanvasState._snapSpacingMm).round() *
        PlanCanvasState._snapSpacingMm;
    final snappedY =
        (worldPositionMm.dy / PlanCanvasState._snapSpacingMm).round() *
        PlanCanvasState._snapSpacingMm;
    return Offset(snappedX.toDouble(), snappedY.toDouble());
  }

  void _addOpeningOnAdjacentRoom(Opening primary) {
    if (primary.roomIndex < 0 || primary.roomIndex >= _completedRooms.length) {
      return;
    }
    final room1 = _completedRooms[primary.roomIndex];
    final verts1 = room1.vertices;
    if (verts1.isEmpty) return;
    final i1 = primary.edgeIndex % verts1.length;
    final j1 = (i1 + 1) % verts1.length;
    final v0 = verts1[i1];
    final v1 = verts1[j1];
    final edgeLen = (v1 - v0).distance;
    if (edgeLen <= 0) return;

    const double tol = 1e-3;

    for (int ri = 0; ri < _completedRooms.length; ri++) {
      if (ri == primary.roomIndex) continue;
      final room2 = _completedRooms[ri];
      final verts2 = room2.vertices;
      if (verts2.isEmpty) continue;
      for (int ei = 0; ei < verts2.length; ei++) {
        final k0 = ei;
        final k1 = (ei + 1) % verts2.length;
        final w0 = verts2[k0];
        final w1 = verts2[k1];
        if ((v0 - w1).distance > tol || (v1 - w0).distance > tol) continue;

        final width = primary.widthMm.clamp(0.0, edgeLen);
        final off2 = (edgeLen - (primary.offsetMm + width)).clamp(
          0.0,
          edgeLen - width,
        );

        _openings.add(
          Opening(
            roomIndex: ri,
            edgeIndex: ei,
            offsetMm: off2,
            widthMm: width,
            isDoor: primary.isDoor,
          ),
        );
        return;
      }
    }
  }

  Offset _snapAngleToConstraint(
    Offset fromMm,
    Offset toMm,
    DrawAngleLock lock,
  ) {
    if (lock == DrawAngleLock.none) return _snapToGrid(toMm);
    final dx = toMm.dx - fromMm.dx;
    final dy = toMm.dy - fromMm.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 1e-6) return _snapToGrid(toMm);
    double angleDeg = math.atan2(dy, dx) * (180.0 / math.pi);
    if (angleDeg < 0) angleDeg += 360.0;
    double snappedDeg;
    if (lock == DrawAngleLock.snap90) {
      snappedDeg = (angleDeg / 90.0).round() * 90.0;
      if (snappedDeg >= 360) snappedDeg = 0;
    } else {
      assert(lock == DrawAngleLock.snap45);
      snappedDeg = (angleDeg / 45.0).round() * 45.0;
      if (snappedDeg >= 360) snappedDeg = 0;
    }
    final rad = snappedDeg * (math.pi / 180.0);
    final snapped = Offset(
      fromMm.dx + distance * math.cos(rad),
      fromMm.dy + distance * math.sin(rad),
    );
    return _snapToGrid(snapped);
  }

  Offset _snapToGridAndAngle(Offset worldPositionMm) {
    final vertexOrDoor = _snapToVertexOrDoor(worldPositionMm);
    if (vertexOrDoor != null) return vertexOrDoor;
    final snapped = _snapToGrid(worldPositionMm);
    if (_drawAngleLock == DrawAngleLock.none) return snapped;
    if (_draftRoomVertices == null || _draftRoomVertices!.isEmpty) {
      return snapped;
    }
    return _snapAngleToConstraint(_draftDrawingFrom, snapped, _drawAngleLock);
  }

  ({Offset snapped, Offset? guideStart, Offset? guideEnd}) _applyInlineSnap(
    Offset snappedWorld,
  ) {
    Offset? guideStart;
    Offset? guideEnd;

    if (_draftRoomVertices == null || _draftRoomVertices!.isEmpty) {
      return (snapped: snappedWorld, guideStart: null, guideEnd: null);
    }

    final from = _draftDrawingFrom;
    final dir = snappedWorld - from;
    if (dir.dx.abs() < 1e-6 && dir.dy.abs() < 1e-6) {
      return (snapped: snappedWorld, guideStart: null, guideEnd: null);
    }

    final snappedScreen = _vp.worldToScreen(snappedWorld);
    double bestYDistPx = PlanCanvasState._inlineSnapTolerancePx;
    Offset? bestYVertexWorld;
    double bestXDistPx = PlanCanvasState._inlineSnapTolerancePx;
    Offset? bestXVertexWorld;

    bool isSamePoint(Offset a, Offset b) => (a - b).distanceSquared < 1e-6;

    for (final room in _completedRooms) {
      final verts =
          room.vertices.length > 1 && room.vertices.first == room.vertices.last
          ? room.vertices.sublist(0, room.vertices.length - 1)
          : room.vertices;
      for (final v in verts) {
        if (isSamePoint(v, from)) continue;
        final screen = _vp.worldToScreen(v);
        final dyPx = (screen.dy - snappedScreen.dy).abs();
        if (dyPx < bestYDistPx) {
          bestYDistPx = dyPx;
          bestYVertexWorld = v;
        }
        final dxPx = (screen.dx - snappedScreen.dx).abs();
        if (dxPx < bestXDistPx) {
          bestXDistPx = dxPx;
          bestXVertexWorld = v;
        }
      }
    }

    final draftVerts = _draftRoomVertices!;
    for (final v in draftVerts) {
      if (isSamePoint(v, from)) continue;
      final screen = _vp.worldToScreen(v);
      final dyPx = (screen.dy - snappedScreen.dy).abs();
      if (dyPx < bestYDistPx) {
        bestYDistPx = dyPx;
        bestYVertexWorld = v;
      }
      final dxPx = (screen.dx - snappedScreen.dx).abs();
      if (dxPx < bestXDistPx) {
        bestXDistPx = dxPx;
        bestXVertexWorld = v;
      }
    }

    Offset adjusted = snappedWorld;
    if (bestYVertexWorld == null && bestXVertexWorld == null) {
      return (snapped: snappedWorld, guideStart: null, guideEnd: null);
    }

    final preferHorizontal = dir.dx.abs() >= dir.dy.abs();
    final hasY = bestYVertexWorld != null;
    final hasX = bestXVertexWorld != null;

    if (hasY && hasX) {
      final yScreen = _vp.worldToScreen(bestYVertexWorld);
      final xScreen = _vp.worldToScreen(bestXVertexWorld);
      final dyPx = (yScreen.dy - snappedScreen.dy).abs();
      final dxPx = (xScreen.dx - snappedScreen.dx).abs();
      if (dyPx <= dxPx) {
        adjusted = Offset(snappedWorld.dx, bestYVertexWorld.dy);
        guideStart = bestYVertexWorld;
        guideEnd = Offset(adjusted.dx, bestYVertexWorld.dy);
      } else {
        adjusted = Offset(bestXVertexWorld.dx, snappedWorld.dy);
        guideStart = bestXVertexWorld;
        guideEnd = Offset(bestXVertexWorld.dx, adjusted.dy);
      }
    } else if (hasY && (preferHorizontal || !hasX)) {
      adjusted = Offset(snappedWorld.dx, bestYVertexWorld.dy);
      guideStart = bestYVertexWorld;
      guideEnd = Offset(adjusted.dx, bestYVertexWorld.dy);
    } else if (hasX) {
      adjusted = Offset(bestXVertexWorld.dx, snappedWorld.dy);
      guideStart = bestXVertexWorld;
      guideEnd = Offset(bestXVertexWorld.dx, adjusted.dy);
    }

    return (snapped: adjusted, guideStart: guideStart, guideEnd: guideEnd);
  }

  double? get _currentSegmentAngleDeg {
    if (_draftRoomVertices == null ||
        _draftRoomVertices!.isEmpty ||
        _hoverPositionWorldMm == null) {
      return null;
    }
    final from = _draftDrawingFrom;
    final to = _hoverPositionWorldMm!;
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return null;
    double deg = math.atan2(dy, dx) * (180.0 / math.pi);
    if (deg < 0) deg += 360.0;
    return deg;
  }

  double? get _angleBetweenLinesDeg {
    final prev = _draftDrawingFromPrev;
    if (prev == null || _hoverPositionWorldMm == null) return null;
    final last = _draftDrawingFrom;
    final hover = _hoverPositionWorldMm!;
    final dir1 = Offset(last.dx - prev.dx, last.dy - prev.dy);
    final dir2 = Offset(hover.dx - last.dx, hover.dy - last.dy);
    final l1 = math.sqrt(dir1.dx * dir1.dx + dir1.dy * dir1.dy);
    final l2 = math.sqrt(dir2.dx * dir2.dx + dir2.dy * dir2.dy);
    if (l1 < 1e-6 || l2 < 1e-6) return null;
    final angle1 = math.atan2(dir1.dy, dir1.dx);
    final angle2 = math.atan2(dir2.dy, dir2.dx);
    double diffRad = angle2 - angle1;
    while (diffRad < 0) {
      diffRad += 2 * math.pi;
    }
    while (diffRad >= 2 * math.pi) {
      diffRad -= 2 * math.pi;
    }
    double deg = diffRad * (180.0 / math.pi);
    if (deg > 180.0) deg = 360.0 - deg;
    if (deg < 2.0) return null;
    return 180.0 - deg;
  }

  Offset _getRoomCenter(List<Offset> vertices) {
    if (vertices.isEmpty) return Offset.zero;

    final uniqueVertices =
        vertices.length > 1 && vertices.first == vertices.last
        ? vertices.sublist(0, vertices.length - 1)
        : vertices;

    double centerX = 0;
    double centerY = 0;
    for (final vertex in uniqueVertices) {
      centerX += vertex.dx;
      centerY += vertex.dy;
    }

    if (uniqueVertices.isEmpty) return Offset.zero;
    return Offset(
      centerX / uniqueVertices.length,
      centerY / uniqueVertices.length,
    );
  }

  Offset _getVertexWorldPosition(int roomIndex, int vertexIndex) {
    final room = _completedRooms[roomIndex];
    return room.vertices[vertexIndex];
  }

  Offset? _findDoorEdgePointAtPosition(Offset screenPosition) {
    final tolerancePx = PlanCanvasState._vertexSelectTolerancePx;
    double closestDist = tolerancePx;
    Offset? closestWorld;
    for (final o in _openings) {
      if (o.roomIndex < 0 || o.roomIndex >= _completedRooms.length) continue;
      final room = _completedRooms[o.roomIndex];
      final verts = room.vertices;
      if (o.edgeIndex >= verts.length) continue;
      final i1 = (o.edgeIndex + 1) % verts.length;
      final v0 = verts[o.edgeIndex];
      final v1 = verts[i1];
      final edgeLen = (v1 - v0).distance;
      if (edgeLen <= 0) continue;
      final t0 = (o.offsetMm / edgeLen).clamp(0.0, 1.0);
      final t1 = ((o.offsetMm + o.widthMm) / edgeLen).clamp(0.0, 1.0);
      final gapStart = Offset(
        v0.dx + t0 * (v1.dx - v0.dx),
        v0.dy + t0 * (v1.dy - v0.dy),
      );
      final gapEnd = Offset(
        v0.dx + t1 * (v1.dx - v0.dx),
        v0.dy + t1 * (v1.dy - v0.dy),
      );
      for (final world in [gapStart, gapEnd]) {
        final screen = _vp.worldToScreen(world);
        final d = (screenPosition - screen).distance;
        if (d < closestDist) {
          closestDist = d;
          closestWorld = world;
        }
      }
    }
    return closestWorld;
  }

  ({int roomIndex, int edgeIndex, double offsetAlongEdgeMm, double edgeLenMm})?
  _findClosestEdgeToPoint(Offset worldPosMm, {double maxDistanceMm = 200}) {
    double bestDist = double.infinity;
    int? bestRoom;
    int? bestEdge;
    double? bestT;
    double? bestLen;
    for (int ri = 0; ri < _completedRooms.length; ri++) {
      final room = _completedRooms[ri];
      final verts = room.vertices;
      for (int i = 0; i < verts.length; i++) {
        final i1 = (i + 1) % verts.length;
        final a = verts[i];
        final b = verts[i1];
        final len = (b - a).distance;
        if (len <= 0) continue;
        final res = PlanCanvasState._closestPointOnSegment(worldPosMm, a, b);
        if (res.distanceMm < bestDist && res.distanceMm <= maxDistanceMm) {
          bestDist = res.distanceMm;
          bestRoom = ri;
          bestEdge = i;
          bestT = res.t;
          bestLen = len;
        }
      }
    }
    if (bestRoom == null ||
        bestEdge == null ||
        bestT == null ||
        bestLen == null) {
      return null;
    }
    return (
      roomIndex: bestRoom,
      edgeIndex: bestEdge,
      offsetAlongEdgeMm: bestT * bestLen,
      edgeLenMm: bestLen,
    );
  }

  int? _findRoomAtPosition(Offset worldPosMm) {
    for (int i = 0; i < _completedRooms.length; i++) {
      final room = _completedRooms[i];
      if (_pointInPolygon(worldPosMm, room.vertices)) {
        return i;
      }
    }
    return null;
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx;
      final yi = polygon[i].dy;
      final xj = polygon[j].dx;
      final yj = polygon[j].dy;

      final intersect =
          ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
