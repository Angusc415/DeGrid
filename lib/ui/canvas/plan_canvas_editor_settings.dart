part of 'plan_canvas.dart';

void _bindEditorController(
  PlanCanvasState state,
  EditorController? controller,
) {
  controller?.bind(
    selectRoom: state.selectRoom,
    deleteRoom: state.deleteRoom,
    setCarpetProducts: state.setCarpetProducts,
    setRoomCarpet: state.setRoomCarpet,
    setRoomLayoutVariant: state.setRoomLayoutVariant,
    clearSeamOverridesForRoom: state.clearSeamOverridesForRoom,
    setWallWidthMm: state.setWallWidthMm,
    setDoorThicknessMm: state.setDoorThicknessMm,
    setUseImperial: state.setUseImperial,
    setShowGrid: state.setShowGrid,
  );
}

void _publishEditorControllerState(PlanCanvasState state) {
  state.widget.controller?.updateState(
    EditorViewState(
      rooms: List<Room>.from(state._completedRooms),
      useImperial: state._useImperial,
      showGrid: state._showGrid,
      selectedRoomIndex: state._selectedRoomIndex,
      wallWidthMm: state._wallWidthMm,
      doorThicknessMm: state._doorThicknessMm,
      carpetProducts: List<CarpetProduct>.from(state._carpetProducts),
      roomCarpetAssignments: Map<int, int>.from(state._roomCarpetAssignments),
      openings: List<Opening>.from(state._openings),
      roomCarpetSeamOverrides: Map<int, List<double>>.from(
        state._roomCarpetSeamOverrides.map(
          (key, value) => MapEntry(key, List<double>.from(value)),
        ),
      ),
      roomCarpetSeamLayDirectionDeg: Map<int, double>.from(
        state._roomCarpetSeamLayDirectionDeg,
      ),
      roomCarpetLayoutVariantIndex: Map<int, int>.from(
        state._roomCarpetLayoutVariantIndex,
      ),
    ),
  );
}

extension PlanCanvasEditorSettingsAccessors on PlanCanvasState {
  double get wallWidthMm => _wallWidthMm;

  void setWallWidthMm(double value) {
    setState(() {
      _wallWidthMm = value.clamp(10.0, 500.0);
      _hasUnsavedChanges = true;
    });
  }

  double? get doorThicknessMm => _doorThicknessMm;

  void setDoorThicknessMm(double? value) {
    setState(() {
      _doorThicknessMm = value?.clamp(10.0, 500.0);
      _hasUnsavedChanges = true;
    });
  }

  bool get useImperial => _useImperial;
  bool get showGrid => _showGrid;

  void setUseImperial(bool value) {
    setState(() {
      _useImperial = value;
      _hasUnsavedChanges = true;
    });
  }

  void setShowGrid(bool value) {
    setState(() {
      _showGrid = value;
    });
  }
}
