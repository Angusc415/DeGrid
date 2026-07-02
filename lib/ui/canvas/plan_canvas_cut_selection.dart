part of 'plan_canvas.dart';

/// Hit-test cut ID labels/arrows on the floor plan. Returns cut id + room index.
({String cutId, int roomIndex})? _findCutAtPosition(
  PlanCanvasState state,
  Offset localPosition,
) {
  if (state._isRotatingRoom || state._isMovingRoom) return null;
  if (state._draftRoomVertices != null) return null;

  const hitRadiusPx = 22.0;
  ({String cutId, int roomIndex})? best;
  var bestDist = hitRadiusPx;

  for (var ri = 0; ri < state._completedRooms.length; ri++) {
    if (!state._roomCarpetAssignments.containsKey(ri)) continue;
    final room = state._completedRooms[ri];
    final layout = state._computeStripLayoutForRoom(ri, room);
    if (layout == null || layout.numStrips < 1) continue;

    final letterIndex = roomLetterIndexInProduct(
      assignments: state._roomCarpetAssignments,
      roomIndex: ri,
      hasPlannableLayout: (idx) {
        final l = state._computeStripLayoutForRoom(idx, state._completedRooms[idx]);
        return l != null && l.numStrips > 0;
      },
    );
    if (letterIndex == null) continue;

    final verts = room.vertices.length > 1 && room.vertices.first == room.vertices.last
        ? room.vertices.sublist(0, room.vertices.length - 1)
        : room.vertices;
    final nameCentroid = room.name != null && room.name!.isNotEmpty
        ? polygonAreaCentroidWorld(verts)
        : null;

    final anchors = enumerateCutPieceAnchors(
      roomIndex: ri,
      room: room,
      layout: layout,
      roomLetterIndex: letterIndex,
      nameCentroidWorld: nameCentroid,
    );

    for (final a in anchors) {
      final screen = state._vp.worldToScreen(a.centerWorld);
      final d = (localPosition - screen).distance;
      if (d <= bestDist) {
        bestDist = d;
        best = (cutId: a.cutId, roomIndex: ri);
      }
    }
  }
  return best;
}
