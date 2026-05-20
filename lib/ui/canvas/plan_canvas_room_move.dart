part of 'plan_canvas.dart';

void _applyRoomMovePointerMove(PlanCanvasState state, Offset localPosition) {
  if (!state._isMovingRoom ||
      state._roomMoveRoomIndex == null ||
      state._roomMoveAnchorWorld == null ||
      state._roomMoveVerticesAtStart == null) {
    return;
  }

  final currentWorld = state._vp.screenToWorld(localPosition);
  final baseDelta = currentWorld - state._roomMoveAnchorWorld!;
  final idx = state._roomMoveRoomIndex!;

  final snap = computeRoomMoveSnap(
    movingRoomIndex: idx,
    movingVertsAtStart: state._roomMoveVerticesAtStart!,
    baseDelta: baseDelta,
    rooms: state._completedRooms,
    openings: state._openings,
  );

  final newVertices =
      state._roomMoveVerticesAtStart!.map((v) => v + snap.delta).toList();
  final room = state._completedRooms[idx];
  state.setState(() {
    state._completedRooms[idx] = Room(
      vertices: newVertices,
      name: room.name,
    );
    state._roomMoveAlignHints = snap.alignHints;
    state._hasUnsavedChanges = true;
  });
  state.widget.onRoomsChanged?.call(
    state._completedRooms,
    state._useImperial,
    state._selectedRoomIndex,
  );
}

void _finishRoomMove(PlanCanvasState state) {
  if (!state._isMovingRoom) return;
  state.setState(() {
    state._isMovingRoom = false;
    state._roomMoveRoomIndex = null;
    state._roomMoveAnchorWorld = null;
    state._roomMoveVerticesAtStart = null;
    state._roomMoveAlignHints = const [];
    state._replaceOpenings(
      syncMirroredOpenings(state._completedRooms, state._openings),
    );
  });
  state._saveHistoryState();
  state.widget.onRoomsChanged?.call(
    state._completedRooms,
    state._useImperial,
    state._selectedRoomIndex,
  );
}
