part of 'plan_canvas.dart';

void _handleCanvasTapImpl(PlanCanvasState state, Offset localPosition) {
  if (state._isCalibrating) {
    state._handleCalibrationTap(localPosition);
    return;
  }

  if (state._isAddDoorMode) {
    final worldPos = state._vp.screenToWorld(localPosition);
    const maxDistanceMm = 150.0;
    final result = state._findClosestEdgeToPoint(
      worldPos,
      maxDistanceMm: maxDistanceMm,
    );
    if (result != null) {
      state.setState(() {
        state._pendingDoorEdge = (
          roomIndex: result.roomIndex,
          edgeIndex: result.edgeIndex,
          edgeLenMm: result.edgeLenMm,
        );
      });
      state._showAddDoorDialog(
        roomIndex: result.roomIndex,
        edgeIndex: result.edgeIndex,
        edgeLenMm: result.edgeLenMm,
      );
    }
    return;
  }

  if (state._isAddDimensionMode) {
    final worldPos = state._vp.screenToWorld(localPosition);
    state.setState(() {
      if (state._addDimensionP1World == null) {
        state._addDimensionP1World = worldPos;
      } else {
        state._placedDimensions.add((
          fromMm: state._addDimensionP1World!,
          toMm: worldPos,
        ));
        state._addDimensionP1World = null;
      }
    });
    return;
  }

  if (state._draftRoomVertices != null &&
      state._draftRoomVertices!.length == 1 &&
      state._draftStartedFromVertexOrDoor &&
      !state._isPanMode) {
    final draftPoint = state._draftRoomVertices!.single;
    final clickedVertex = state._findVertexAtPosition(localPosition);
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
    final doorEdgePoint = state._findDoorEdgePointAtPosition(localPosition);
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
    if (state._findVertexAtPosition(localPosition) == null &&
        state._findDoorEdgePointAtPosition(localPosition) == null) {
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

  if (state._draftRoomVertices != null &&
      state._draftRoomVertices!.length >= 3 &&
      !state._isPanMode) {
    final closeTargetScreen = state._vp.worldToScreen(state._draftCloseTarget);
    final distance = (localPosition - closeTargetScreen).distance;
    if (distance < PlanCanvasState._closeTolerancePx) {
      state._closeDraftRoom();
      return;
    }
  }

  if (state._draftRoomVertices == null && !state._isPanMode) {
    final clickedVertex = state._findVertexAtPosition(localPosition);
    if (clickedVertex != null) {
      final firstPoint = state._getVertexWorldPosition(
        clickedVertex.roomIndex,
        clickedVertex.vertexIndex,
      );
      state.setState(() {
        state._selectedVertex = null;
        state._isEditingVertex = false;
        state._draftRoomVertices = [firstPoint];
        state._draftStartedFromVertexOrDoor = true;
        state._dragStartPositionWorldMm = firstPoint;
        state._isDragging = false;
        state._hoverPositionWorldMm = firstPoint;
        state._lengthInputController.clear();
        state._desiredLengthMm = null;
        state._inlineGuideStartWorld = null;
        state._inlineGuideEndWorld = null;
        state._saveHistoryState();
      });
      return;
    }
    final doorEdgePoint = state._findDoorEdgePointAtPosition(localPosition);
    if (doorEdgePoint != null) {
      state.setState(() {
        state._selectedVertex = null;
        state._isEditingVertex = false;
        state._draftRoomVertices = [doorEdgePoint];
        state._draftStartedFromVertexOrDoor = true;
        state._dragStartPositionWorldMm = doorEdgePoint;
        state._isDragging = false;
        state._hoverPositionWorldMm = doorEdgePoint;
        state._lengthInputController.clear();
        state._desiredLengthMm = null;
        state._inlineGuideStartWorld = null;
        state._inlineGuideEndWorld = null;
        state._saveHistoryState();
      });
      return;
    }
  }

  if (state._draftRoomVertices == null) {
    final worldPos = state._vp.screenToWorld(localPosition);
    final clickedRoomIndex = state._findRoomAtPosition(worldPos);
    final tapOnImage =
        state._backgroundImage != null &&
        state._backgroundImageState != null &&
        state._isPointOnBackgroundImage(localPosition);

    if (state._isPanMode) {
      if (state._showFloorplanMenu && !tapOnImage) {
        state.setState(() => state._showFloorplanMenu = false);
      }
      final clickedVertex = state._findVertexAtPosition(localPosition);
      if (clickedVertex != null) {
        if (state._selectedVertex != null &&
            state._selectedVertex!.roomIndex == clickedVertex.roomIndex &&
            state._selectedVertex!.vertexIndex == clickedVertex.vertexIndex) {
          state._pendingSelectedVertex = null;
          state.setState(() {
            state._selectedVertex = null;
            state._isEditingVertex = false;
          });
          return;
        }
        state._pendingSelectedVertex = clickedVertex;
        state.setState(() {
          state._selectedVertex = clickedVertex;
          state._selectedRoomIndex = clickedVertex.roomIndex;
          state._isEditingVertex = false;
          state._isDragging = false;
        });
        return;
      }
      if (state._selectedVertex != null) {
        state._pendingSelectedVertex = null;
        state.setState(() {
          state._selectedVertex = null;
          state._isEditingVertex = false;
        });
      }
      if (tapOnImage && clickedRoomIndex == null) {
        state.setState(() => state._showFloorplanMenu = true);
        return;
      }
    } else {
      if (state._selectedVertex != null) {
        state.setState(() {
          state._selectedVertex = null;
          state._isEditingVertex = false;
        });
      }
    }

    if (clickedRoomIndex != null) {
      if (state._selectedRoomIndex == clickedRoomIndex) {
        state._pendingSelectedVertex = null;
        if (state.mounted) {
          state.setState(() {
            state._selectedVertex = null;
            state._selectedRoomIndex = null;
            state._isEditingVertex = false;
            state._showRoomActionsMenu = false;
            state._showCarpetDirectionPicker = false;
          });
        }
        state.widget.onRoomsChanged?.call(
          state._completedRooms,
          state._useImperial,
          null,
        );
        return;
      }

      final room = state._completedRooms[clickedRoomIndex];
      final center = state._getRoomCenter(room.vertices);
      final centerScreen = state._vp.worldToScreen(center);
      final distance = (localPosition - centerScreen).distance;
      state._pendingSelectedVertex = null;
      state.setState(() {
        state._selectedVertex = null;
        state._selectedRoomIndex = clickedRoomIndex;
        state._isEditingVertex = false;
      });
      state.widget.onRoomsChanged?.call(
        state._completedRooms,
        state._useImperial,
        state._selectedRoomIndex,
      );
      if (distance < 40) {
        state._editRoomName(clickedRoomIndex);
      }
      return;
    }

    state._pendingSelectedVertex = null;
    if (state.mounted) {
      state.setState(() {
        state._selectedRoomIndex = null;
        state._selectedVertex = null;
        state._isEditingVertex = false;
        state._showRoomActionsMenu = false;
        state._showCarpetDirectionPicker = false;
      });
    }
    state.widget.onRoomsChanged?.call(
      state._completedRooms,
      state._useImperial,
      null,
    );
  }
}
