part of 'plan_canvas.dart';

void _togglePanModeImpl(PlanCanvasState state) {
  state.setState(() {
    state._isPanMode = !state._isPanMode;
    state._showFloorplanMenu = false;
    state._isPanning = false;
    state._panStartScreen = null;
    state._pendingSelectedVertex = null;
    state._selectedVertex = null;
    state._hoveredVertex = null;
    state._isEditingVertex = false;
    if (!state._isPanMode) {
      state._isAddDoorMode = false;
    }
  });
}

void _handlePanStartImpl(PlanCanvasState state, Offset screenPosition) {
  if (HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      )) {
    return;
  }

  if (state._isPanMode) {
    final vertexToEdit = state._selectedVertex ?? state._pendingSelectedVertex;
    if (vertexToEdit != null && state._draftRoomVertices == null) {
      state.setState(() {
        state._selectedVertex = vertexToEdit;
        state._selectedRoomIndex = vertexToEdit.roomIndex;
        state._isEditingVertex = true;
        state._isDragging = false;
      });
      return;
    }

    final clickedVertex = state._findVertexAtPosition(screenPosition);
    if (clickedVertex != null && state._draftRoomVertices == null) {
      state.setState(() {
        state._selectedVertex = clickedVertex;
        state._selectedRoomIndex = clickedVertex.roomIndex;
        state._isEditingVertex = true;
        state._isDragging = false;
      });
      return;
    }
  }

  final worldPosition = state._vp.screenToWorld(screenPosition);

  if (state._draftRoomVertices != null &&
      state._draftRoomVertices!.length == 1 &&
      state._draftStartedFromVertexOrDoor &&
      !state._isPanMode) {
    final draftPoint = state._draftRoomVertices!.single;
    final clickedVertex = state._findVertexAtPosition(screenPosition);
    if (clickedVertex != null) {
      final vertexWorld = state._getVertexWorldPosition(
        clickedVertex.roomIndex,
        clickedVertex.vertexIndex,
      );
      if ((vertexWorld - draftPoint).distance < 0.01) {
        state.setState(() {
          state._draftRoomVertices = null;
          state._draftStartedFromVertexOrDoor = false;
          state._dragMoved = false;
          state._dragStartPositionWorldMm = null;
          state._hoverPositionWorldMm = null;
          state._lengthInputController.clear();
          state._desiredLengthMm = null;
        });
        return;
      }
    }
    final doorEdgePoint = state._findDoorEdgePointAtPosition(screenPosition);
    if (doorEdgePoint != null && (doorEdgePoint - draftPoint).distance < 0.01) {
      state.setState(() {
        state._draftRoomVertices = null;
        state._draftStartedFromVertexOrDoor = false;
        state._dragMoved = false;
        state._dragStartPositionWorldMm = null;
        state._hoverPositionWorldMm = null;
        state._lengthInputController.clear();
        state._desiredLengthMm = null;
      });
      return;
    }
  }

  if (state._draftRoomVertices == null && !state._isPanMode) {
    final clickedVertex = state._findVertexAtPosition(screenPosition);
    if (clickedVertex != null) {
      final firstPoint = state._getVertexWorldPosition(
        clickedVertex.roomIndex,
        clickedVertex.vertexIndex,
      );
      state._pendingSelectedVertex = null;
      state.setState(() {
        state._selectedVertex = null;
        state._isEditingVertex = false;
        state._saveHistoryState();
        state._draftRoomVertices = [firstPoint];
        state._draftStartedFromVertexOrDoor = true;
        state._dragMoved = false;
        state._dragStartPositionWorldMm = firstPoint;
        state._isDragging = true;
        state._hoverPositionWorldMm = firstPoint;
        state._lengthInputController.clear();
        state._desiredLengthMm = null;
        state._inlineGuideStartWorld = null;
        state._inlineGuideEndWorld = null;
      });
      return;
    }
    final doorEdgePoint = state._findDoorEdgePointAtPosition(screenPosition);
    if (doorEdgePoint != null) {
      state._pendingSelectedVertex = null;
      state.setState(() {
        state._selectedVertex = null;
        state._isEditingVertex = false;
        state._saveHistoryState();
        state._draftRoomVertices = [doorEdgePoint];
        state._draftStartedFromVertexOrDoor = true;
        state._dragMoved = false;
        state._dragStartPositionWorldMm = doorEdgePoint;
        state._isDragging = true;
        state._hoverPositionWorldMm = doorEdgePoint;
        state._lengthInputController.clear();
        state._desiredLengthMm = null;
        state._inlineGuideStartWorld = null;
        state._inlineGuideEndWorld = null;
      });
      return;
    }
  }

  final snappedPosition = state._snapToGridAndAngle(worldPosition);

  state._pendingSelectedVertex = null;
  state.setState(() {
    state._selectedVertex = null;
    state._isEditingVertex = false;

    if (state._draftRoomVertices == null) {
      state._saveHistoryState();
      state._draftRoomVertices = [snappedPosition];
      state._draftStartedFromVertexOrDoor = false;
      state._dragMoved = false;
      state._dragStartPositionWorldMm = snappedPosition;
      state._isDragging = true;
      state._hoverPositionWorldMm = snappedPosition;
      state._lengthInputController.clear();
      state._desiredLengthMm = null;
    } else {
      if (state._draftRoomVertices!.isNotEmpty) {
        final closeTargetScreen = state._vp.worldToScreen(
          state._draftCloseTarget,
        );
        final distance = (screenPosition - closeTargetScreen).distance;
        if (distance < PlanCanvasState._closeTolerancePx &&
            state._draftRoomVertices!.length >= 3) {
          state._closeDraftRoom();
          return;
        }
      }

      state._dragStartPositionWorldMm = state._draftRoomVertices!.isNotEmpty
          ? state._draftDrawingFrom
          : worldPosition;
      state._isDragging = true;
      state._hoverPositionWorldMm = worldPosition;
    }
  });
}

void _handlePanUpdateImpl(PlanCanvasState state, Offset screenPosition) {
  if (HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      )) {
    return;
  }

  final vertexToEdit = state._selectedVertex ?? state._pendingSelectedVertex;
  if ((state._isEditingVertex || state._scaleGestureIsVertexEdit) &&
      vertexToEdit != null) {
    final worldPosition = state._vp.screenToWorld(screenPosition);
    final snappedPosition = state._snapToGrid(worldPosition);

    state.setState(() {
      final roomIdx = vertexToEdit.roomIndex;
      final vertexIdx = vertexToEdit.vertexIndex;

      if (roomIdx >= 0 && roomIdx < state._completedRooms.length) {
        final room = state._completedRooms[roomIdx];
        final vertices = List<Offset>.from(room.vertices);
        final isClosed = vertices.length > 1 && vertices.first == vertices.last;
        final uniqueVertexCount = isClosed
            ? vertices.length - 1
            : vertices.length;

        if (vertexIdx >= 0 && vertexIdx < uniqueVertexCount) {
          vertices[vertexIdx] = snappedPosition;

          if (isClosed && vertexIdx == 0) {
            vertices[vertices.length - 1] = snappedPosition;
          } else if (isClosed && vertexIdx == uniqueVertexCount - 1) {
            vertices[vertices.length - 1] = snappedPosition;
          }

          state._completedRooms[roomIdx] = Room(
            vertices: vertices,
            name: room.name,
          );
          state._hasUnsavedChanges = true;
        }
      }
    });
    return;
  }

  if (!state._isDragging) return;

  final worldPosition = state._vp.screenToWorld(screenPosition);
  final snappedBase = state._snapToGridAndAngle(worldPosition);
  final inlineResult = state._applyInlineSnap(snappedBase);
  final snappedPosition = inlineResult.snapped;

  state.setState(() {
    state._dragMoved = true;
    state._hoverPositionWorldMm = snappedPosition;
    state._inlineGuideStartWorld = inlineResult.guideStart;
    state._inlineGuideEndWorld = inlineResult.guideEnd;

    if (state._isPanMode) {
      state._hoveredVertex = state._findVertexAtPosition(screenPosition);
    } else {
      state._hoveredVertex = null;
    }
  });
}

void _handlePanEndImpl(PlanCanvasState state, Offset screenPosition) {
  if (HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      )) {
    if (state._isDragging) {
      state.setState(() {
        state._isDragging = false;
      });
    }
    return;
  }

  if (state._isEditingVertex) {
    state.setState(() {
      state._isEditingVertex = false;
      state._saveHistoryState();
    });
    return;
  }

  if (!state._isDragging) return;

  final worldPosition = state._vp.screenToWorld(screenPosition);
  final snappedBase = state._snapToGridAndAngle(worldPosition);
  final inlineResult = state._applyInlineSnap(snappedBase);
  final snappedPosition = inlineResult.snapped;

  state.setState(() {
    state._isDragging = false;

    if (state._draftRoomVertices == null ||
        state._dragStartPositionWorldMm == null) {
      state._inlineGuideStartWorld = null;
      state._inlineGuideEndWorld = null;
      return;
    }

    if (state._draftRoomVertices!.isNotEmpty &&
        state._draftRoomVertices!.length >= 3) {
      final closeTargetScreen = state._vp.worldToScreen(
        state._draftCloseTarget,
      );
      final snappedScreen = state._vp.worldToScreen(snappedPosition);
      final distance = (snappedScreen - closeTargetScreen).distance;
      if (distance < PlanCanvasState._closeTolerancePx) {
        state._closeDraftRoom();
        state._dragStartPositionWorldMm = null;
        return;
      }
    }

    final minDistanceMm = PlanCanvasState._minVertexDistanceMm;
    if (state._draftRoomVertices!.isEmpty ||
        (snappedPosition - state._draftDrawingFrom).distance > minDistanceMm) {
      state._saveHistoryState();
      if (state._drawFromStart) {
        state._draftRoomVertices = [
          snappedPosition,
          ...state._draftRoomVertices!,
        ];
      } else {
        state._draftRoomVertices = [
          ...state._draftRoomVertices!,
          snappedPosition,
        ];
      }
      state._hoverPositionWorldMm = snappedPosition;
      state._lengthInputController.clear();
      state._desiredLengthMm = null;
      state._originalLastSegmentDirection = null;
      state._originalSecondToLastVertex = null;
    }

    state._dragStartPositionWorldMm = null;
    state._inlineGuideStartWorld = null;
    state._inlineGuideEndWorld = null;
  });
}
