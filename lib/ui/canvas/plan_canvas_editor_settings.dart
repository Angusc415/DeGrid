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
    setStripSplitStrategy: state.setStripSplitStrategy,
    setCarpetPlanningSettings: state.setCarpetPlanningSettings,
  );
}

void _publishEditorControllerState(PlanCanvasState state) {
  state.widget.controller?.updateState(
    EditorViewState(
      // Deep-copy rooms (vertices are mutated in place during edits) so
      // listeners can detect changes by comparing old vs new state by value.
      rooms: state._completedRooms
          .map((r) => Room(vertices: List<Offset>.from(r.vertices), name: r.name))
          .toList(),
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
      stripSplitStrategy: state._stripSplitStrategy,
      roomCarpetStripPieceLengthsOverrideMm: Map<int, List<List<double>>>.from(
        state._roomCarpetStripPieceLengthsOverrideMm.map(
          (k, v) => MapEntry(k, v.map((p) => List<double>.from(p)).toList()),
        ),
      ),
      carpetPlanningSettings: state._carpetPlanningSettings,
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

  StripSplitStrategy get stripSplitStrategy => _stripSplitStrategy;

  void setStripSplitStrategy(StripSplitStrategy value) {
    setState(() {
      _stripSplitStrategy = value;
      _hasUnsavedChanges = true;
    });
  }

  CarpetPlanningSettings get carpetPlanningSettings => _carpetPlanningSettings;

  void setCarpetPlanningSettings(CarpetPlanningSettings value) {
    setState(() {
      _carpetPlanningSettings = value;
      _hasUnsavedChanges = true;
    });
  }
}
