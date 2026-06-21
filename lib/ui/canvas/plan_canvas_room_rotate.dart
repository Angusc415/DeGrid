part of 'plan_canvas.dart';

/// Screen position of the rotate handle for the currently selected room:
/// centered above the room's top edge, but always at least
/// [_rotateHandleOffsetPx] above the center so it never collapses onto the
/// other controls on small/zoomed-out rooms. Single source of truth shared by
/// the hit-test and the painter.
Offset? _rotateHandleScreenPos(PlanCanvasState state) {
  final center = state._selectedRoomCenterScreen;
  if (center == null) return null;
  final bounds = state._selectedRoomBoundsScreen;
  const gap = PlanCanvasState._roomControlGapPx;
  const minOffset = PlanCanvasState._rotateHandleOffsetPx;
  final topY = bounds != null
      ? math.min(bounds.top - gap, center.dy - minOffset)
      : center.dy - minOffset;
  return Offset(center.dx, topY);
}

/// True when a room is selected and [localPosition] is within the handle's
/// hit radius.
bool _findRotateHandleAtPosition(
  PlanCanvasState state,
  Offset localPosition,
) {
  if (state._selectedRoomIndex == null) return false;
  final handle = _rotateHandleScreenPos(state);
  if (handle == null) return false;
  return (localPosition - handle).distance <=
      PlanCanvasState._rotateHandleHitRadiusPx;
}

void _startRoomRotate(PlanCanvasState state, Offset localPosition) {
  final idx = state._selectedRoomIndex;
  if (idx == null || idx < 0 || idx >= state._completedRooms.length) return;
  final room = state._completedRooms[idx];
  final pivot = state._getRoomCenter(room.vertices);
  final pointerWorld = state._vp.screenToWorld(localPosition);
  state.setState(() {
    state._isRotatingRoom = true;
    state._roomRotateRoomIndex = idx;
    state._roomRotatePivotWorld = pivot;
    state._roomRotateVerticesAtStart = List<Offset>.from(room.vertices);
    state._roomRotateStartPointerAngleRad = math.atan2(
      pointerWorld.dy - pivot.dy,
      pointerWorld.dx - pivot.dx,
    );
    state._roomRotateAppliedDeg = 0;
    state._selectedVertex = null;
    state._pendingSelectedVertex = null;
    state._isEditingVertex = false;
  });
  HapticFeedback.selectionClick();
}

void _applyRoomRotatePointerMove(
  PlanCanvasState state,
  Offset localPosition,
) {
  if (!state._isRotatingRoom ||
      state._roomRotateRoomIndex == null ||
      state._roomRotatePivotWorld == null ||
      state._roomRotateVerticesAtStart == null ||
      state._roomRotateStartPointerAngleRad == null) {
    return;
  }
  final idx = state._roomRotateRoomIndex!;
  final pivot = state._roomRotatePivotWorld!;
  final pointerWorld = state._vp.screenToWorld(localPosition);
  final currentAngle = math.atan2(
    pointerWorld.dy - pivot.dy,
    pointerWorld.dx - pivot.dx,
  );
  final rawDeltaDeg =
      (currentAngle - state._roomRotateStartPointerAngleRad!) *
          180.0 /
          math.pi;
  final shiftHeld = HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      );
  final snappedDeg = snapRotationDeg(rawDeltaDeg, fine: shiftHeld);
  final newVertices = rotateVerticesAround(
    state._roomRotateVerticesAtStart!,
    pivot,
    snappedDeg * math.pi / 180.0,
  );
  final room = state._completedRooms[idx];
  state.setState(() {
    state._completedRooms[idx] = Room(vertices: newVertices, name: room.name);
    state._roomRotateAppliedDeg = snappedDeg;
    state._hasUnsavedChanges = true;
  });
  state.widget.onRoomsChanged?.call(
    state._completedRooms,
    state._useImperial,
    state._selectedRoomIndex,
  );
}

void _finishRoomRotate(PlanCanvasState state) {
  if (!state._isRotatingRoom) return;
  state.setState(() {
    state._isRotatingRoom = false;
    state._roomRotateRoomIndex = null;
    state._roomRotatePivotWorld = null;
    state._roomRotateVerticesAtStart = null;
    state._roomRotateStartPointerAngleRad = null;
    state._roomRotateAppliedDeg = 0;
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

/// Rotate the selected room by a fixed [degrees] about its center (used by the
/// quick 90 degree / numeric menu actions).
void _rotateSelectedRoomBy(PlanCanvasState state, double degrees) {
  final idx = state._selectedRoomIndex;
  if (idx == null || idx < 0 || idx >= state._completedRooms.length) return;
  final room = state._completedRooms[idx];
  final pivot = state._getRoomCenter(room.vertices);
  final newVertices = rotateVerticesAround(
    room.vertices,
    pivot,
    degrees * math.pi / 180.0,
  );
  state.setState(() {
    state._completedRooms[idx] = Room(vertices: newVertices, name: room.name);
    state._hasUnsavedChanges = true;
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
