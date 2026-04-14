import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'viewport.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/background_image_io.dart';
import '../../core/geometry/room.dart';
import '../../core/geometry/opening.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/roll_planning/carpet_layout_options.dart';
import '../../core/roll_planning/roll_planner.dart';
import '../../core/database/database.dart';
import '../../core/services/project_service.dart';
import '../../core/models/project.dart';
import '../../core/config/feature_flags.dart';
import '../editor/editor_controller.dart';
import 'plan_toolbar.dart';
import 'plan_floorplan_menu.dart';
import 'plan_length_input_pad.dart';
import 'plan_painter.dart';

part 'plan_canvas_editor_settings.dart';
part 'plan_canvas_floorplan.dart';
part 'plan_canvas_gestures.dart';
part 'plan_canvas_geometry_helpers.dart';
part 'plan_canvas_persistence.dart';
part 'plan_canvas_room_management.dart';
part 'plan_canvas_room_editing.dart';
part 'plan_canvas_tap.dart';

/// Angle lock for draw mode: none (free), snap to 90°, or snap to 45°.
enum DrawAngleLock { none, snap90, snap45 }

class PlanCanvas extends StatefulWidget {
  final int? projectId;
  final String? initialProjectName;
  final Function(List<Room>, bool, int?)?
  onRoomsChanged; // Callback for rooms, useImperial, selectedIndex
  final Function(int)?
  onSelectRoomRequested; // Callback when external code wants to select a room
  final void Function(Map<int, int>)? onRoomCarpetAssignmentsChanged;
  final EditorController? controller;

  const PlanCanvas({
    super.key,
    this.projectId,
    this.initialProjectName,
    this.onRoomsChanged,
    this.onSelectRoomRequested,
    this.onRoomCarpetAssignmentsChanged,
    this.controller,
  });

  @override
  State<PlanCanvas> createState() => PlanCanvasState();
}

class PlanCanvasState extends State<PlanCanvas> {
  final PlanViewport _vp = PlanViewport(
    mmPerPx: 5.0,
    worldOriginMm: const Offset(-500, -500),
  );

  // Database and service
  AppDatabase? _db;
  ProjectService? _projectService;
  bool _isInitializing = true;

  // Project state
  int? _currentProjectId;
  String? _currentProjectName;
  bool _hasUnsavedChanges = false;
  bool _isLoading = false;

  // Floor plan background image (Phase 1: import, store path, draw)
  String? _backgroundImagePath;
  BackgroundImageState? _backgroundImageState;
  ui.Image? _backgroundImage;

  // Floorplan contextual menu (pan mode, tap on image)
  bool _showFloorplanMenu = false;
  Offset? _floorplanResizeStartGlobal;
  Offset? _floorplanResizeStartCornerScreen;
  int? _floorplanResizeCornerIndex; // 0=TL, 1=TR, 2=BR, 3=BL
  Offset? _floorplanResizeAnchorWorld;

  // Completed rooms (polygons)
  final List<Room> _completedRooms = [];
  // Door/openings between rooms (roomIndex, edgeIndex, offsetMm, widthMm)
  final List<Opening> _openings = [];
  // Carpet products (roll width etc.) for this project
  final List<CarpetProduct> _carpetProducts = [];
  // Room index -> carpet product index (Phase 2)
  final Map<int, int> _roomCarpetAssignments = {};

  /// Room index -> seam positions (mm from reference). When set, overrides auto layout.
  final Map<int, List<double>> _roomCarpetSeamOverrides = {};

  /// When a room has seam overrides, lock strip direction to this (0 or 90) so moving the seam doesn't flip direction.
  final Map<int, double> _roomCarpetSeamLayDirectionDeg = {};

  /// Room index -> layout variant index (0 = Auto, 1 = 0°, 2 = 90°). Default 0.
  final Map<int, int> _roomCarpetLayoutVariantIndex = {};

  /// Strip layout: when to split a strip into pieces along the run (user-adjustable).
  StripSplitStrategy _stripSplitStrategy = StripSplitStrategy.auto;

  /// Per-room override of piece lengths per strip (user merged pieces by dragging along-seams out).
  /// Key = roomIndex. Value = list of piece-length lists per strip; when set, replaces planner's stripPieceLengthsMm.
  final Map<int, List<List<double>>> _roomCarpetStripPieceLengthsOverrideMm = {};

  /// When non-null, user is dragging this seam (room index, seam index 0-based).
  int? _draggingSeamRoomIndex;
  int? _draggingSeamIndex;

  /// When non-null, user is dragging an along-run seam (strip split into pieces). Drag out of room to remove seam.
  int? _draggingAlongSeamRoomIndex;
  int? _draggingAlongSeamStripIndex;
  int? _draggingAlongSeamIndex;

  // Unit system: false = metric (mm/cm), true = imperial (ft/in)
  bool _useImperial = false;

  // Grid visibility toggle
  bool _showGrid = true;

  // Pan mode toggle: when true, single-finger drag pans instead of drawing
  bool _isPanMode = false;

  /// Draw mode angle lock: lines snap to 90°, 45°, or free angle.
  /// Default to 45° snapping so new drawings start locked.
  DrawAngleLock _drawAngleLock = DrawAngleLock.snap45;

  // Calibration mode (true scale): user taps 2 points then enters real distance.
  bool _isCalibrating = false;
  Offset? _calibrationP1Screen;
  Offset? _calibrationP2Screen;

  /// Move floorplan mode: drag to reposition the background image (offset).
  bool _isMoveFloorplanMode = false;
  bool _isMovingFloorplan = false;

  // Dimension tools
  /// Measure tool: temporary line between two points (tap-tap to set, tap again to clear).
  bool _isMeasureMode = false;
  final List<Offset> _measurePointsWorld = [];
  Offset? _measureCurrentWorld; // live point while dragging to add next segment
  /// Add dimension mode: tap two points to place a permanent dimension.
  bool _isAddDimensionMode = false;
  Offset? _addDimensionP1World;

  /// Placed dimensions (world mm); persisted with project later.
  final List<({Offset fromMm, Offset toMm})> _placedDimensions = [];

  /// Add door/opening mode: tap near a wall to place an opening.
  bool _isAddDoorMode = false;

  /// When set, user has tapped a wall; show highlight and dialog to confirm width/position before placing.
  ({int roomIndex, int edgeIndex, double edgeLenMm})? _pendingDoorEdge;

  // Room actions menu (three-dots) + carpet direction picker state
  bool _showRoomActionsMenu = false;
  bool _showCarpetDirectionPicker = false;

  // Pan mode state: track if we're currently panning
  bool _isPanning = false;
  Offset? _panStartScreen;

  /// Minimum drag distance (px) before a touch is treated as pan; below this, treat as tap (e.g. vertex select).
  static const double _panSlopPx = 18.0;

  /// True when the current scale gesture is "drag to move selected vertex" (set synchronously in onScaleStart so onScaleUpdate sees it before setState runs).
  bool _scaleGestureIsVertexEdit = false;

  /// Set to true to log vertex-edit vs pan decisions (debug only).
  static const bool _debugVertexEdit = false;

  /// Long-press (2s) on a room in pan mode: move whole room. Timer started on pointer down, cancelled on move/up.
  Timer? _longPressRoomMoveTimer;
  static const Duration _longPressRoomMoveDuration = Duration(seconds: 1);
  bool _isMovingRoom = false;
  int? _roomMoveRoomIndex;
  Offset? _roomMoveAnchorWorld;
  List<Offset>? _roomMoveVerticesAtStart;

  // Undo/Redo history
  // Each history entry contains both completed rooms and draft room vertices
  final List<({List<Room> rooms, List<Offset>? draftVertices})> _history = [];
  int _historyIndex =
      -1; // -1 means at initial state, 0 means after first action
  static const int _maxHistorySize = 50;

  // Selected room index for editing (null = no selection)
  int? _selectedRoomIndex;

  // Selected vertex for editing: (roomIndex, vertexIndex)
  // null = no vertex selected
  ({int roomIndex, int vertexIndex})? _selectedVertex;

  /// Set synchronously when a tap selects a vertex so the next touch (drag) sees it before setState rebuilds.
  ({int roomIndex, int vertexIndex})? _pendingSelectedVertex;

  // Hovered vertex for visual feedback: (roomIndex, vertexIndex)
  // null = no vertex hovered
  ({int roomIndex, int vertexIndex})? _hoveredVertex;

  // Currently drawing a room (null = not drawing)
  List<Offset>? _draftRoomVertices;

  /// True when the single-point draft was started by tapping a vertex/door (so untap = deselect). False when started from empty tap.
  bool _draftStartedFromVertexOrDoor = false;

  /// When true, new segments are drawn from the first vertex; when false, from the last.
  bool _drawFromStart = false;

  // Current cursor/hover position for preview line (world-space mm)
  Offset? _hoverPositionWorldMm;
  // Inline alignment guide between preview endpoint and another vertex (world-space mm).
  Offset? _inlineGuideStartWorld;
  Offset? _inlineGuideEndWorld;

  /// The vertex we're currently drawing from (start or end of draft chain).
  Offset get _draftDrawingFrom =>
      _drawFromStart ? _draftRoomVertices!.first : _draftRoomVertices!.last;

  /// The vertex before [ _draftDrawingFrom ] in draw order (for angle calculation).
  Offset? get _draftDrawingFromPrev {
    if (_draftRoomVertices == null || _draftRoomVertices!.length < 2)
      return null;
    return _drawFromStart
        ? _draftRoomVertices![1]
        : _draftRoomVertices![_draftRoomVertices!.length - 2];
  }

  /// The "other" end — used for close detection (drag near this to close).
  Offset get _draftCloseTarget =>
      _drawFromStart ? _draftRoomVertices!.last : _draftRoomVertices!.first;

  // Drag state: track if we're currently dragging to draw a wall
  bool _isDragging = false;

  /// True once the user has moved during this drag (so we know to add a point on release, not stay "connected").
  bool _dragMoved = false;
  Offset? _dragStartPositionWorldMm;

  // Vertex editing state: true when dragging a vertex to reshape room
  bool _isEditingVertex = false;

  // Last scale gesture position (for onScaleEnd)
  Offset? _lastScalePosition;

  double _startMmPerPx = 5.0;

  // Length input for wall segments
  final TextEditingController _lengthInputController = TextEditingController();
  bool _showNumberPad = true;
  Offset? _numberPadPosition;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _numberPadWrapperKey = GlobalKey();
  static const double _numberPadApproxWidth = 220;
  static const double _numberPadApproxHeight = 320;
  double? _desiredLengthMm; // Desired length in mm (null = use dragged length)
  Offset?
  _originalLastSegmentDirection; // Store original direction when user starts typing
  Offset?
  _originalSecondToLastVertex; // Store original second-to-last vertex position

  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  // Screen-space tolerance for "clicking near start vertex" to close room
  static const double _closeTolerancePx = 20.0;

  // Screen-space tolerance for clicking on a vertex (in pixels)
  static const double _vertexSelectTolerancePx = 12.0;

  // Snap spacing in mm: 1 = full mm precision; grid drawing uses adaptive spacing
  static const double _snapSpacingMm =
      1.0; // 1mm snap so you can work in mm and cm
  static const double _minVertexDistanceMm =
      1.0; // minimum 1mm between vertices
  // Screen-space tolerance for inline snap/alignment guides (in pixels)
  static const double _inlineSnapTolerancePx = 8.0;

  // Project-level wall width in millimeters (used when drawing completed rooms).
  double _wallWidthMm = 70.0;
  // Optional project-level door thickness in millimeters (used when drawing doors).
  double? _doorThicknessMm;

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
    _publishEditorControllerState(this);
  }

  @override
  void initState() {
    super.initState();
    _bindEditorController(this, widget.controller);
    _publishEditorControllerState(this);
    // Initialize history with empty state
    _saveHistoryState();
    // Initialize database and load project if provided
    _initializeDatabase(this);
  }

  @override
  void didUpdateWidget(covariant PlanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      _bindEditorController(this, widget.controller);
      _publishEditorControllerState(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.unbind();
    _longPressRoomMoveTimer?.cancel();
    _focusNode.dispose();
    _lengthInputController.dispose();
    _db?.close();
    super.dispose();
  }

  /// Save current state to history for undo/redo
  void _saveHistoryState() {
    // Remove any future history if we're not at the end
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    // Create a deep copy of current rooms
    final roomsCopy = _completedRooms
        .map((r) => Room(vertices: List<Offset>.from(r.vertices), name: r.name))
        .toList();

    // Create a deep copy of draft room vertices (if any)
    final draftCopy = _draftRoomVertices != null
        ? List<Offset>.from(_draftRoomVertices!)
        : null;

    _history.add((rooms: roomsCopy, draftVertices: draftCopy));
    _historyIndex = _history.length - 1;

    // Limit history size
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  /// Undo the last action
  void _undo() {
    // We save state *before* each action; current state is never pushed.
    // So we restore the last saved state (what we had before the last action).
    if (_historyIndex >= 0) {
      setState(() {
        final state = _history[_historyIndex];

        // Restore completed rooms
        _completedRooms.clear();
        _completedRooms.addAll(
          state.rooms.map(
            (r) => Room(vertices: List<Offset>.from(r.vertices), name: r.name),
          ),
        );

        // Restore draft room vertices
        _draftRoomVertices = state.draftVertices != null
            ? List<Offset>.from(state.draftVertices!)
            : null;
        _draftStartedFromVertexOrDoor = false;

        // Clear selection and hover state
        _selectedRoomIndex = null;
        _hoverPositionWorldMm = null;

        _historyIndex--;
      });
    }
  }

  /// Redo the last undone action
  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        final state = _history[_historyIndex];

        // Restore completed rooms
        _completedRooms.clear();
        _completedRooms.addAll(
          state.rooms.map(
            (r) => Room(vertices: List<Offset>.from(r.vertices), name: r.name),
          ),
        );

        // Restore draft room vertices
        _draftRoomVertices = state.draftVertices != null
            ? List<Offset>.from(state.draftVertices!)
            : null;
        _draftStartedFromVertexOrDoor = false;

        // Clear selection and hover state
        _selectedRoomIndex = null;
        _hoverPositionWorldMm = null;
      });
    }
  }

  /// Check if undo is available
  bool get _canUndo => _historyIndex >= 0;

  /// Check if redo is available
  bool get _canRedo => _historyIndex < _history.length - 1;

  /// Toggle between metric and imperial units
  void _toggleUnit() {
    setState(() {
      _useImperial = !_useImperial;
      _hasUnsavedChanges = true;
    });
  }

  /// Toggle grid visibility
  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _togglePanMode() {
    _togglePanModeImpl(this);
  }

  /// Handle a single tap on the canvas (vertex select, room select, etc.).
  /// Called from onTapDown (web) and from onScaleEnd when scale gesture was a tap (mobile).
  void _handleCanvasTap(Offset localPosition) {
    _handleCanvasTapImpl(this, localPosition);
  }

  void _toggleCalibration() {
    setState(() {
      if (_isCalibrating) {
        _isCalibrating = false;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
      } else {
        _isCalibrating = true;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
        _isMoveFloorplanMode = false;
        _isMovingFloorplan = false;
        _panStartScreen = null;
        // Exit other interaction modes while calibrating
        _isPanMode = false;
        _isDragging = false;
        _isEditingVertex = false;
        _isMeasureMode = false;
        _measurePointsWorld.clear();
        _measureCurrentWorld = null;
        _isAddDimensionMode = false;
        _addDimensionP1World = null;
        _isAddDoorMode = false;
      }
    });
  }

  void _toggleMoveFloorplanMode() {
    setState(() {
      _isMoveFloorplanMode = !_isMoveFloorplanMode;
      if (_isMoveFloorplanMode) {
        _isCalibrating = false;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
        _isMovingFloorplan = false;
        _panStartScreen = null;
      }
    });
  }

  void _toggleFloorplanLock() {
    if (_backgroundImageState == null) return;
    setState(() {
      _backgroundImageState = _backgroundImageState!.copyWith(
        locked: !_backgroundImageState!.locked,
      );
      if (_backgroundImageState!.locked) {
        _showFloorplanMenu = false;
        _isMoveFloorplanMode = false;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _fitFloorplanToView() {
    if (_backgroundImage == null || _backgroundImageState == null || !mounted)
      return;
    final screenSize = MediaQuery.of(context).size;
    final eff = _backgroundImageState!.effectiveScaleMmPerPixel;
    final ox = _backgroundImageState!.offsetX;
    final oy = _backgroundImageState!.offsetY;
    final wMm = _backgroundImage!.width * eff;
    final hMm = _backgroundImage!.height * eff;
    double minX = ox;
    double minY = oy;
    double maxX = ox + wMm;
    double maxY = oy + hMm;
    const padding = 24.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;
    final width = maxX - minX;
    final height = maxY - minY;
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final scaleX = screenSize.width / width;
    final scaleY = screenSize.height / height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.9;
    setState(() {
      _vp.mmPerPx = (1.0 / scale).clamp(
        PlanViewport.minMmPerPx,
        PlanViewport.maxMmPerPx,
      );
      _vp.worldOriginMm =
          center -
          Offset(screenSize.width / 2, screenSize.height / 2) * _vp.mmPerPx;
      _hasUnsavedChanges = true;
    });
  }

  void _resetFloorplanTransform() {
    if (_backgroundImageState == null) return;
    setState(() {
      _backgroundImageState = _backgroundImageState!.copyWith(scaleFactor: 1.0);
      _hasUnsavedChanges = true;
    });
  }

  void _removeFloorplanImage() {
    _endFloorplanResize();
    setState(() {
      _backgroundImage?.dispose();
      _backgroundImagePath = null;
      _backgroundImageState = null;
      _backgroundImage = null;
      _showFloorplanMenu = false;
      _isMoveFloorplanMode = false;
      _hasUnsavedChanges = true;
    });
  }

  void _toggleMeasureMode() {
    setState(() {
      if (_isMeasureMode) {
        _isMeasureMode = false;
        _measurePointsWorld.clear();
        _measureCurrentWorld = null;
      } else {
        _isMeasureMode = true;
        _measurePointsWorld.clear();
        _measureCurrentWorld = null;
        _isAddDimensionMode = false;
        _addDimensionP1World = null;
        _isAddDoorMode = false;
        _isCalibrating = false;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
      }
    });
  }

  void _toggleAddDimensionMode() {
    setState(() {
      if (_isAddDimensionMode) {
        _isAddDimensionMode = false;
        _addDimensionP1World = null;
      } else {
        _isAddDimensionMode = true;
        _addDimensionP1World = null;
        _isMeasureMode = false;
        _measurePointsWorld.clear();
        _measureCurrentWorld = null;
        _isAddDoorMode = false;
        _isCalibrating = false;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
      }
    });
  }

  void _toggleAddDoorMode() {
    setState(() {
      if (_isAddDoorMode) {
        _isAddDoorMode = false;
      } else {
        _isAddDoorMode = true;
        _isMeasureMode = false;
        _measurePointsWorld.clear();
        _measureCurrentWorld = null;
        _isAddDimensionMode = false;
        _addDimensionP1World = null;
        _isCalibrating = false;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
      }
    });
  }

  void _removeLastDimension() {
    if (_placedDimensions.isEmpty) return;
    setState(() => _placedDimensions.removeLast());
  }

  /// Shows a short-lived prompt at the top center (below toolbar): "Move room — drag to reposition".
  void _showMoveRoomPrompt() {
    _showMoveRoomPromptImpl(this);
  }

  /// Convert a screen point to image pixel coordinates using current background image state.
  Offset? _screenToBackgroundImagePixel(Offset screenPx) {
    return _screenToBackgroundImagePixelImpl(this, screenPx);
  }

  /// True if the given screen point lies inside the drawn background image bounds.
  /// Uses a 1px tolerance so edge taps are not missed due to rounding.
  bool _isPointOnBackgroundImage(Offset screenPx) {
    return _isPointOnBackgroundImageImpl(this, screenPx);
  }

  /// Screen-space rectangle of the drawn background image (for anchoring the floorplan toolbar).
  Rect? _backgroundImageScreenRect() {
    return _backgroundImageScreenRectImpl(this);
  }

  /// Start resize by corner; [cornerIndex] 0=TL, 1=TR, 2=BR, 3=BL. Opposite corner stays fixed.
  void _startFloorplanResize(
    int cornerIndex,
    Offset cornerScreen,
    Offset globalPosition,
  ) {
    _startFloorplanResizeImpl(this, cornerIndex, cornerScreen, globalPosition);
  }

  void _updateFloorplanResize(Offset globalPosition) {
    _updateFloorplanResizeImpl(this, globalPosition);
  }

  void _endFloorplanResize() {
    _endFloorplanResizeImpl(this);
  }

  Future<void> _handleCalibrationTap(Offset screenPos) async {
    if (_calibrationP1Screen == null) {
      setState(() => _calibrationP1Screen = screenPos);
      return;
    }
    if (_calibrationP2Screen == null) {
      setState(() => _calibrationP2Screen = screenPos);
      final p1 = _calibrationP1Screen!;
      final p2 = _calibrationP2Screen!;
      final pxDist = (p2 - p1).distance;
      if (pxDist < 3) {
        setState(() => _calibrationP2Screen = null);
        return;
      }

      // When a floorplan image is present, calibrate its scale (and set origin at first point).
      if (_backgroundImage != null && _backgroundImageState != null) {
        final p1Pixel = _screenToBackgroundImagePixel(p1);
        final p2Pixel = _screenToBackgroundImagePixel(p2);
        if (p1Pixel == null || p2Pixel == null) {
          setState(() => _calibrationP2Screen = null);
          return;
        }
        final pixelDist = (p2Pixel - p1Pixel).distance;
        if (pixelDist < 1) {
          setState(() => _calibrationP2Screen = null);
          return;
        }

        final controller = TextEditingController();
        final ctx = context;
        final result = await showDialog<String>(
          context: ctx,
          builder: (context) => AlertDialog(
            title: const Text('Calibrate floorplan scale'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _useImperial
                    ? 'Real distance (ft / in)'
                    : 'Real distance (mm / cm / m)',
                hintText: _useImperial
                    ? 'e.g. 10\' 6"'
                    : 'e.g. 3000mm, 300cm, 3m',
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Apply'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (result == null || result.trim().isEmpty) {
          setState(() => _calibrationP2Screen = null);
          return;
        }

        final mm = _parseLengthInput(result);
        if (mm == null || mm <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid distance. Try again.')),
          );
          setState(() => _calibrationP2Screen = null);
          return;
        }

        final newScale = mm / pixelDist;
        final newOffsetX = -p1Pixel.dx * newScale;
        final newOffsetY = -p1Pixel.dy * newScale;
        setState(() {
          _backgroundImageState = _backgroundImageState!.copyWith(
            scaleMmPerPixel: newScale,
            offsetX: newOffsetX,
            offsetY: newOffsetY,
          );
          _hasUnsavedChanges = true;
          _isCalibrating = false;
          _calibrationP1Screen = null;
          _calibrationP2Screen = null;
        });
        await _saveProject(this);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Floorplan scale set. You can trace rooms on top.'),
            ),
          );
        }
        return;
      }

      // No background image: calibrate viewport scale (existing behavior)
      final controller = TextEditingController();
      final ctx = context;
      final result = await showDialog<String>(
        context: ctx,
        builder: (context) => AlertDialog(
          title: const Text('Calibrate scale'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _useImperial
                  ? 'Distance (ft / in)'
                  : 'Distance (mm / cm / m)',
              hintText: _useImperial
                  ? 'e.g. 10\' 6"'
                  : 'e.g. 3000mm, 300cm, 3m',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (result == null || result.trim().isEmpty) return;

      final mm = _parseLengthInput(result);
      if (mm == null || mm <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid distance. Try again.')),
        );
        return;
      }

      final newMmPerPx = mm / pxDist;
      final zoomFactor = newMmPerPx / _vp.mmPerPx;
      final focal = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

      setState(() {
        _vp.zoomAt(zoomFactor: zoomFactor, focalScreenPx: focal);
        _hasUnsavedChanges = true;
        _isCalibrating = false;
        _calibrationP1Screen = null;
        _calibrationP2Screen = null;
      });
    }
  }

  void _zoomIn() {
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;
    final centerScreen = Offset(screenSize.width / 2, screenSize.height / 2);
    setState(() {
      // Zoom in: decrease mmPerPx (see more detail)
      _vp.zoomAt(zoomFactor: 0.833, focalScreenPx: centerScreen); // 1/1.2
      _hasUnsavedChanges = true;
    });
  }

  void _zoomOut() {
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;
    final centerScreen = Offset(screenSize.width / 2, screenSize.height / 2);
    setState(() {
      // Zoom out: increase mmPerPx (see less detail, more area)
      _vp.zoomAt(zoomFactor: 1.2, focalScreenPx: centerScreen);
      _hasUnsavedChanges = true;
    });
  }

  void _fitToScreen() {
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;

    if (_completedRooms.isEmpty) {
      // No rooms: reset to default view
      setState(() {
        _vp.resetView(screenSize: screenSize);
        _hasUnsavedChanges = true;
      });
      return;
    }

    // Calculate bounding box of all rooms
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final room in _completedRooms) {
      for (final vertex in room.vertices) {
        minX = minX < vertex.dx ? minX : vertex.dx;
        minY = minY < vertex.dy ? minY : vertex.dy;
        maxX = maxX > vertex.dx ? maxX : vertex.dx;
        maxY = maxY > vertex.dy ? maxY : vertex.dy;
      }
    }

    // Add padding (10% on each side)
    final padding = (maxX - minX).abs().clamp(100, 1000) * 0.1;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final width = maxX - minX;
    final height = maxY - minY;
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    // Calculate zoom to fit
    final scaleX = screenSize.width / width;
    final scaleY = screenSize.height / height;
    final scale =
        (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to add margin

    setState(() {
      _vp.mmPerPx = (1.0 / scale).clamp(
        PlanViewport.minMmPerPx,
        PlanViewport.maxMmPerPx,
      );
      _vp.worldOriginMm =
          center -
          Offset(screenSize.width / 2, screenSize.height / 2) * _vp.mmPerPx;
      _hasUnsavedChanges = true;
    });
  }

  /// Select a room and center the view on it.
  /// This is called from external code (e.g., room summary panel).
  void selectRoom(int roomIndex) {
    _selectRoomImpl(this, roomIndex);
  }

  /// Delete a room by index (called from external code).
  void deleteRoom(int roomIndex) {
    _showDeleteRoomDialogImpl(this, roomIndex);
  }

  /// Carpet products for this project (for Phase 1 carpet planning).
  List<CarpetProduct> get carpetProducts =>
      List<CarpetProduct>.from(_carpetProducts);

  void setCarpetProducts(List<CarpetProduct> list) {
    setState(() {
      _carpetProducts.clear();
      _carpetProducts.addAll(list);
      _hasUnsavedChanges = true;
    });
  }

  /// Room carpet assignments (roomIndex -> productIndex). Read-only copy.
  Map<int, int> get roomCarpetAssignments =>
      Map<int, int>.from(_roomCarpetAssignments);

  /// Openings (doors, pass-throughs) for layout options. Read-only copy.
  List<Opening> get openings => List<Opening>.from(_openings);

  /// Room carpet seam overrides (room index -> seam positions mm). Read-only copy.
  Map<int, List<double>> get roomCarpetSeamOverrides =>
      Map<int, List<double>>.from(
        _roomCarpetSeamOverrides.map(
          (k, v) => MapEntry(k, List<double>.from(v)),
        ),
      );

  /// Locked strip direction (0 or 90) per room when room has seam overrides. Read-only copy.
  Map<int, double> get roomCarpetSeamLayDirectionDeg =>
      Map<int, double>.from(_roomCarpetSeamLayDirectionDeg);

  /// Clear seam overrides for one room (reset to auto layout).
  void clearSeamOverridesForRoom(int roomIndex) {
    if (!_roomCarpetSeamOverrides.containsKey(roomIndex)) return;
    setState(() {
      _roomCarpetSeamOverrides.remove(roomIndex);
      _roomCarpetSeamLayDirectionDeg.remove(roomIndex);
      _hasUnsavedChanges = true;
    });
  }

  /// Layout variant index per room (0 = Auto, 1 = 0°, 2 = 90°). Read-only copy.
  Map<int, int> get roomCarpetLayoutVariantIndex =>
      Map<int, int>.from(_roomCarpetLayoutVariantIndex);

  /// Set layout variant for a room (0 = Auto, 1 = 0°, 2 = 90°).
  /// Clears seam overrides and direction lock for this room so the new direction takes effect.
  void setRoomLayoutVariant(int roomIndex, int variantIndex) {
    if (variantIndex < 0 || variantIndex > 2) return;
    setState(() {
      _roomCarpetLayoutVariantIndex[roomIndex] = variantIndex;
      _roomCarpetSeamOverrides.remove(roomIndex);
      _roomCarpetSeamLayDirectionDeg.remove(roomIndex);
      _hasUnsavedChanges = true;
    });
  }

  /// Screen-space center of the currently selected room, or null if none.
  Offset? get _selectedRoomCenterScreen => _selectedRoomCenterScreenFor(this);

  void _applyCarpetDirectionForSelectedRoom(int variantIndex) {
    if (!kEnableCarpetFeatures) return;
    final idx = _selectedRoomIndex;
    if (idx == null) return;
    // Reuse existing variant semantics: 0 = Auto, 1 = horizontal, 2 = vertical.
    if (variantIndex < 0 || variantIndex > 2) return;
    setRoomLayoutVariant(idx, variantIndex);
    setState(() {
      _showCarpetDirectionPicker = false;
    });
  }

  static double? _layDirectionDegFromVariant(int variantIndex) {
    return variantIndex == 0 ? null : (variantIndex == 1 ? 0.0 : 90.0);
  }

  /// Compute strip layout for a room (used for hit-test and drag). Same logic as painter.
  StripLayout? _computeStripLayoutForRoom(int roomIndex, Room room) {
    final productIndex = _roomCarpetAssignments[roomIndex];
    if (productIndex == null ||
        productIndex < 0 ||
        productIndex >= _carpetProducts.length) {
      return null;
    }
    final product = _carpetProducts[productIndex];
    if (product.rollWidthMm <= 0) return null;
    final seamOverride = _roomCarpetSeamOverrides[roomIndex];
    final variantIndex = _roomCarpetLayoutVariantIndex[roomIndex] ?? 0;
    // When room has seam overrides, use locked direction so moving the seam doesn't flip strip direction.
    final layDirectionDeg =
        _roomCarpetSeamLayDirectionDeg[roomIndex] ??
        _layDirectionDegFromVariant(variantIndex);
    final opts = CarpetLayoutOptions.forRoom(
      roomIndex: roomIndex,
      minStripWidthMm: product.minStripWidthMm ?? 100,
      trimAllowanceMm: product.trimAllowanceMm ?? 75,
      patternRepeatMm: product.patternRepeatMm ?? 0,
      wasteAllowancePercent: 5,
      openings: _openings,
      seamPositionsOverrideMm: seamOverride?.isNotEmpty == true
          ? seamOverride
          : null,
      layDirectionDeg: layDirectionDeg,
      maxSinglePieceLengthMm: product.rollLengthM != null ? product.rollLengthM! * 1000 : null,
      stripSplitStrategy: _stripSplitStrategy,
    );
    final layout = RollPlanner.computeLayout(room, product.rollWidthMm, opts);
    // Apply user's along-seam merges (dragged seams out) if any.
    final override = _roomCarpetStripPieceLengthsOverrideMm[roomIndex];
    if (override != null &&
        override.isNotEmpty &&
        override.length == layout.numStrips) {
      final stripLengthsMm = override
          .map((p) => p.fold<double>(0.0, (a, b) => a + b))
          .toList();
      return StripLayout(
        numStrips: layout.numStrips,
        stripLengthsMm: stripLengthsMm,
        stripWidthsMm: layout.stripWidthsMm,
        stripPieceLengthsMm: override,
        layAngleDeg: layout.layAngleDeg,
        bboxMinX: layout.bboxMinX,
        bboxMinY: layout.bboxMinY,
        bboxWidth: layout.bboxWidth,
        bboxHeight: layout.bboxHeight,
        layAlongX: layout.layAlongX,
        rollWidthMm: layout.rollWidthMm,
        seamCount: layout.seamCount,
        totalLinearWithWasteMm: layout.totalLinearWithWasteMm,
        seamPositionsMmOverride: layout.seamPositionsMmOverride,
        isSinglePiece: layout.isSinglePiece,
        roomShapeVerticesMm: layout.roomShapeVerticesMm,
        scoreMaterialMm: layout.scoreMaterialMm,
        scoreSeamPenaltyMm: layout.scoreSeamPenaltyMm,
        scoreSliverPenaltyMm: layout.scoreSliverPenaltyMm,
        scoreCostMm: layout.scoreCostMm,
      );
    }
    return layout;
  }

  /// Hit-test: find seam line near [screenPos]. Returns (roomIndex, seamIndex) or null.
  ({int roomIndex, int seamIndex})? _findSeamAtScreenPosition(
    Offset screenPos,
  ) {
    const hitSlopPx = 14.0;
    ({int roomIndex, int seamIndex})? best;
    double bestDist = hitSlopPx + 1;
    for (int ri = 0; ri < _completedRooms.length; ri++) {
      if (!_roomCarpetAssignments.containsKey(ri)) continue;
      final layout = _computeStripLayoutForRoom(ri, _completedRooms[ri]);
      if (layout == null || layout.numStrips < 2) continue;
      final positions = layout.seamPositionsFromReferenceMm;
      for (int si = 0; si < positions.length; si++) {
        final perpOffset = positions[si];
        Offset p1World;
        Offset p2World;
        if (layout.layAlongX) {
          final y = layout.bboxMinY + perpOffset;
          p1World = Offset(layout.bboxMinX, y);
          p2World = Offset(layout.bboxMinX + layout.bboxWidth, y);
        } else {
          final x = layout.bboxMinX + perpOffset;
          p1World = Offset(x, layout.bboxMinY);
          p2World = Offset(x, layout.bboxMinY + layout.bboxHeight);
        }
        final p1 = _vp.worldToScreen(p1World);
        final p2 = _vp.worldToScreen(p2World);
        final seg = p2 - p1;
        final len = seg.distance;
        if (len <= 0) continue;
        final toPoint = screenPos - p1;
        final t = (toPoint.dx * seg.dx + toPoint.dy * seg.dy) / (len * len);
        final closest = t.clamp(0.0, 1.0);
        final proj = p1 + Offset(seg.dx * closest, seg.dy * closest);
        final d = (screenPos - proj).distance;
        if (d < bestDist) {
          bestDist = d;
          best = (roomIndex: ri, seamIndex: si);
        }
      }
    }
    return best;
  }

  /// Hit-test: find along-run seam (between pieces of same strip) near [screenPos].
  /// Returns (roomIndex, stripIndex, alongSeamIndex) or null. Drag such a seam out of room to remove it (merge pieces).
  ({int roomIndex, int stripIndex, int alongSeamIndex})? _findAlongSeamAtScreenPosition(
    Offset screenPos,
  ) {
    const hitSlopPx = 14.0;
    ({int roomIndex, int stripIndex, int alongSeamIndex})? best;
    double bestDist = hitSlopPx + 1;
    for (int ri = 0; ri < _completedRooms.length; ri++) {
      if (!_roomCarpetAssignments.containsKey(ri)) continue;
      final layout = _computeStripLayoutForRoom(ri, _completedRooms[ri]);
      if (layout == null) continue;
      for (int stri = 0; stri < layout.numStrips; stri++) {
        final pieces = layout.pieceLengthsForStrip(stri);
        if (pieces.length < 2) continue;
        double cum = 0.0;
        for (int ai = 0; ai < pieces.length - 1; ai++) {
          cum += pieces[ai];
          Offset p1World;
          Offset p2World;
          final stripWidth = stri < layout.stripWidthsMm.length
              ? layout.stripWidthsMm[stri]
              : (layout.rollWidthMm > 0 ? layout.rollWidthMm : (layout.layAlongX ? layout.bboxHeight : layout.bboxWidth));
          final stripStart = stri == 0 ? 0.0 : (stri < layout.stripWidthsMm.length
              ? layout.stripWidthsMm.sublist(0, stri).fold<double>(0.0, (a, b) => a + b)
              : stri * (layout.rollWidthMm > 0 ? layout.rollWidthMm : stripWidth));
          final stripEnd = stripStart + stripWidth;
          if (layout.layAlongX) {
            final x = layout.bboxMinX + cum;
            p1World = Offset(x, layout.bboxMinY + stripStart);
            p2World = Offset(x, layout.bboxMinY + stripEnd);
          } else {
            final y = layout.bboxMinY + cum;
            p1World = Offset(layout.bboxMinX + stripStart, y);
            p2World = Offset(layout.bboxMinX + stripEnd, y);
          }
          final p1 = _vp.worldToScreen(p1World);
          final p2 = _vp.worldToScreen(p2World);
          final seg = p2 - p1;
          final len = seg.distance;
          if (len <= 0) continue;
          final toPoint = screenPos - p1;
          final t = (toPoint.dx * seg.dx + toPoint.dy * seg.dy) / (len * len);
          final closest = t.clamp(0.0, 1.0);
          final proj = p1 + Offset(seg.dx * closest, seg.dy * closest);
          final d = (screenPos - proj).distance;
          if (d < bestDist) {
            bestDist = d;
            best = (roomIndex: ri, stripIndex: stri, alongSeamIndex: ai);
          }
        }
      }
    }
    return best;
  }

  void setRoomCarpet(int roomIndex, int? productIndex) {
    setState(() {
      if (productIndex == null) {
        _roomCarpetAssignments.remove(roomIndex);
      } else {
        _roomCarpetAssignments[roomIndex] = productIndex;
      }
      _hasUnsavedChanges = true;
    });
    widget.onRoomCarpetAssignmentsChanged?.call(
      Map<int, int>.from(_roomCarpetAssignments),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        KeyboardListener(
          key: _stackKey,
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              const panSpeed = 50.0; // pixels per key press
              const zoomFactor = 1.2;

              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowLeft:
                  setState(() {
                    _vp.panByScreenDelta(const Offset(panSpeed, 0));
                  });
                  break;
                case LogicalKeyboardKey.arrowRight:
                  setState(() {
                    _vp.panByScreenDelta(const Offset(-panSpeed, 0));
                  });
                  break;
                case LogicalKeyboardKey.arrowUp:
                  setState(() {
                    _vp.panByScreenDelta(const Offset(0, panSpeed));
                  });
                  break;
                case LogicalKeyboardKey.arrowDown:
                  setState(() {
                    _vp.panByScreenDelta(const Offset(0, -panSpeed));
                  });
                  break;
                case LogicalKeyboardKey.equal:
                case LogicalKeyboardKey.numpadAdd:
                  // Zoom in at center of screen
                  if (context.mounted) {
                    final size = MediaQuery.of(context).size;
                    setState(() {
                      _vp.zoomAt(
                        zoomFactor: zoomFactor,
                        focalScreenPx: Offset(size.width / 2, size.height / 2),
                      );
                    });
                  }
                  break;
                case LogicalKeyboardKey.minus:
                case LogicalKeyboardKey.numpadSubtract:
                  // Zoom out at center of screen
                  if (context.mounted) {
                    final size = MediaQuery.of(context).size;
                    setState(() {
                      _vp.zoomAt(
                        zoomFactor: 1.0 / zoomFactor,
                        focalScreenPx: Offset(size.width / 2, size.height / 2),
                      );
                    });
                  }
                  break;
                case LogicalKeyboardKey.escape:
                  // Cancel current draft room or deselect room
                  if (_draftRoomVertices != null) {
                    // Save state before canceling draft room (so undo can restore it)
                    _saveHistoryState();
                    setState(() {
                      _draftRoomVertices = null;
                      _draftStartedFromVertexOrDoor = false;
                      _drawFromStart = false;
                      _hoverPositionWorldMm = null;
                    });
                  } else {
                    setState(() {
                      _selectedRoomIndex = null; // Deselect room
                    });
                  }
                  break;
                case LogicalKeyboardKey.delete:
                case LogicalKeyboardKey.backspace:
                  // Delete selected room
                  if (_selectedRoomIndex != null &&
                      _draftRoomVertices == null) {
                    final idx = _selectedRoomIndex!;
                    if (idx >= 0 && idx < _completedRooms.length) {
                      _deleteRoomAtIndex(this, idx);
                    }
                  }
                  break;
                case LogicalKeyboardKey.keyZ:
                  // Undo (Ctrl+Z) or Redo (Ctrl+Shift+Z)
                  if (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed) {
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      // Redo
                      _redo();
                    } else {
                      // Undo
                      _undo();
                    }
                  }
                  break;
                case LogicalKeyboardKey.keyS:
                  // Save (Ctrl+S or Cmd+S)
                  if (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed) {
                    _saveProject(this);
                  }
                  break;
                default:
                  break;
              }
            }
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,

            onPointerDown: (e) {
              if (kIsWeb && _isMeasureMode && e.buttons == 1) {
                final world = _vp.screenToWorld(e.localPosition);
                setState(() {
                  if (_measurePointsWorld.isEmpty) {
                    _measurePointsWorld.add(world);
                    _measureCurrentWorld = world;
                  } else {
                    _measureCurrentWorld = world;
                  }
                });
                return;
              }
              // Start long-press timer for "move room" (all platforms: web mouse/touch, desktop, mobile)
              // Accept buttons == 1 (mouse) or 0 (touch on web often sends 0)
              if ((e.buttons == 1 || e.buttons == 0) &&
                  _isPanMode &&
                  _draftRoomVertices == null) {
                final touchOnImage =
                    _backgroundImage != null &&
                    _backgroundImageState != null &&
                    _isPointOnBackgroundImage(e.localPosition);
                final worldPos = _vp.screenToWorld(e.localPosition);
                final roomIdx = _findRoomAtPosition(worldPos);
                if (roomIdx != null &&
                    !touchOnImage &&
                    _findVertexAtPosition(e.localPosition) == null) {
                  _panStartScreen = e.localPosition;
                  _longPressRoomMoveTimer?.cancel();
                  _longPressRoomMoveTimer = Timer(
                    _longPressRoomMoveDuration,
                    () {
                      _longPressRoomMoveTimer?.cancel();
                      _longPressRoomMoveTimer = null;
                      if (!mounted) return;
                      if (_panStartScreen == null) return;
                      final room = _completedRooms[roomIdx];
                      setState(() {
                        _isMovingRoom = true;
                        _roomMoveRoomIndex = roomIdx;
                        _roomMoveAnchorWorld = _vp.screenToWorld(
                          _panStartScreen!,
                        );
                        _roomMoveVerticesAtStart = List<Offset>.from(
                          room.vertices,
                        );
                        _selectedVertex = null;
                        _pendingSelectedVertex = null;
                        _isEditingVertex = false;
                      });
                      HapticFeedback.mediumImpact();
                      _showMoveRoomPrompt();
                    },
                  );
                }
              }
              // Along-seam drag: in pan mode, check for along-run seam hit first (drag out to remove seam)
              if ((e.buttons == 1 || e.buttons == 0) &&
                  _isPanMode &&
                  _draftRoomVertices == null) {
                final alongHit = _findAlongSeamAtScreenPosition(e.localPosition);
                if (alongHit != null) {
                  setState(() {
                    final layout = _computeStripLayoutForRoom(
                      alongHit.roomIndex,
                      _completedRooms[alongHit.roomIndex],
                    );
                    if (layout != null) {
                      final pieces = layout.pieceLengthsForStrip(alongHit.stripIndex);
                      if (pieces.length >= 2) {
                        if (!_roomCarpetStripPieceLengthsOverrideMm.containsKey(alongHit.roomIndex)) {
                          _roomCarpetStripPieceLengthsOverrideMm[alongHit.roomIndex] = [
                            for (int i = 0; i < layout.numStrips; i++)
                              List<double>.from(layout.pieceLengthsForStrip(i)),
                          ];
                        }
                        _draggingAlongSeamRoomIndex = alongHit.roomIndex;
                        _draggingAlongSeamStripIndex = alongHit.stripIndex;
                        _draggingAlongSeamIndex = alongHit.alongSeamIndex;
                        _hasUnsavedChanges = true;
                      }
                    }
                  });
                } else {
                  // Cross-strip seam drag
                  final hit = _findSeamAtScreenPosition(e.localPosition);
                  if (hit != null) {
                    setState(() {
                      final layout = _computeStripLayoutForRoom(
                        hit.roomIndex,
                        _completedRooms[hit.roomIndex],
                      );
                      if (layout != null && layout.numStrips >= 2) {
                        if (!_roomCarpetSeamOverrides.containsKey(
                          hit.roomIndex,
                        )) {
                          _roomCarpetSeamOverrides[hit.roomIndex] =
                              List<double>.from(
                                layout.seamPositionsFromReferenceMm,
                              );
                          _roomCarpetSeamLayDirectionDeg[hit.roomIndex] =
                              layout.layAlongX ? 0.0 : 90.0;
                        }
                        _draggingSeamRoomIndex = hit.roomIndex;
                        _draggingSeamIndex = hit.seamIndex;
                        _hasUnsavedChanges = true;
                      }
                    });
                  }
                }
              }
            },
            onPointerUp: (e) {
              _longPressRoomMoveTimer?.cancel();
              _longPressRoomMoveTimer = null;
              if (_isMovingRoom) {
                setState(() {
                  _isMovingRoom = false;
                  _roomMoveRoomIndex = null;
                  _roomMoveAnchorWorld = null;
                  _roomMoveVerticesAtStart = null;
                });
                _saveHistoryState();
                widget.onRoomsChanged?.call(
                  _completedRooms,
                  _useImperial,
                  _selectedRoomIndex,
                );
              }
              _panStartScreen = null;
              if (kIsWeb && _isMeasureMode) {
                setState(() {
                  if (_measureCurrentWorld != null) {
                    _measurePointsWorld.add(_measureCurrentWorld!);
                    _measureCurrentWorld = null;
                  }
                });
              }
              if (_draggingSeamRoomIndex != null) {
                setState(() {
                  _draggingSeamRoomIndex = null;
                  _draggingSeamIndex = null;
                });
              }
              if (_draggingAlongSeamRoomIndex != null) {
                setState(() {
                  _draggingAlongSeamRoomIndex = null;
                  _draggingAlongSeamStripIndex = null;
                  _draggingAlongSeamIndex = null;
                });
              }
            },

            // PAN (web): Shift + left-drag OR right-click drag
            // Also track hover position for preview line (when not actively dragging to draw)
            onPointerMove: (e) {
              // Move whole room (works on web and supports mobile if scale doesn't deliver updates)
              if (_isMovingRoom &&
                  _roomMoveRoomIndex != null &&
                  _roomMoveAnchorWorld != null &&
                  _roomMoveVerticesAtStart != null) {
                final currentWorld = _vp.screenToWorld(e.localPosition);
                final baseDelta = currentWorld - _roomMoveAnchorWorld!;

                // Snap moving room so its vertices "magnetize" to nearby vertices or door endpoints
                // of other rooms when within ~20mm. This helps rooms snap together cleanly.
                const double snapToleranceMm = 20.0;
                double bestDist = snapToleranceMm;
                Offset snappedDelta = baseDelta;

                final idx = _roomMoveRoomIndex!;

                // Candidate points: vertices of other rooms (excluding the moving room)
                for (int ri = 0; ri < _completedRooms.length; ri++) {
                  if (ri == idx) continue;
                  final room = _completedRooms[ri];
                  final verts =
                      room.vertices.length > 1 &&
                          room.vertices.first == room.vertices.last
                      ? room.vertices.sublist(0, room.vertices.length - 1)
                      : room.vertices;
                  for (final vStatic in verts) {
                    for (final vMovingStart in _roomMoveVerticesAtStart!) {
                      final moved = vMovingStart + baseDelta;
                      final d = (moved - vStatic).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        snappedDelta = baseDelta + (vStatic - moved);
                      }
                    }
                  }
                }

                // Also allow snapping to door/opening endpoints on other rooms
                for (final o in _openings) {
                  if (o.roomIndex == idx) continue;
                  if (o.roomIndex < 0 || o.roomIndex >= _completedRooms.length)
                    continue;
                  final room = _completedRooms[o.roomIndex];
                  final verts = room.vertices;
                  if (o.edgeIndex >= verts.length) continue;
                  final i1 = (o.edgeIndex + 1) % verts.length;
                  final v0 = verts[o.edgeIndex];
                  final v1 = verts[i1];
                  final edgeLen = (v1 - v0).distance;
                  if (edgeLen <= 0) continue;
                  final t0 = (o.offsetMm / edgeLen).clamp(0.0, 1.0);
                  final t1 = ((o.offsetMm + o.widthMm) / edgeLen).clamp(
                    0.0,
                    1.0,
                  );
                  final gapStart = Offset(
                    v0.dx + t0 * (v1.dx - v0.dx),
                    v0.dy + t0 * (v1.dy - v0.dy),
                  );
                  final gapEnd = Offset(
                    v0.dx + t1 * (v1.dx - v0.dx),
                    v0.dy + t1 * (v1.dy - v0.dy),
                  );
                  for (final vStatic in [gapStart, gapEnd]) {
                    for (final vMovingStart in _roomMoveVerticesAtStart!) {
                      final moved = vMovingStart + baseDelta;
                      final d = (moved - vStatic).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        snappedDelta = baseDelta + (vStatic - moved);
                      }
                    }
                  }
                }

                final newVertices = _roomMoveVerticesAtStart!
                    .map((v) => v + snappedDelta)
                    .toList();
                final room = _completedRooms[idx];
                setState(() {
                  _completedRooms[idx] = Room(
                    vertices: newVertices,
                    name: room.name,
                  );
                  _hasUnsavedChanges = true;
                });
                widget.onRoomsChanged?.call(
                  _completedRooms,
                  _useImperial,
                  _selectedRoomIndex,
                );
                return;
              }
              // Cancel long-press timer if user moved before 2s (all platforms).
              // Do not clear _panStartScreen so the scale gesture can still start panning.
              if (!_isMovingRoom &&
                  _panStartScreen != null &&
                  (e.buttons == 1 || e.buttons == 0)) {
                final distance = (e.localPosition - _panStartScreen!).distance;
                if (distance > _panSlopPx) {
                  _longPressRoomMoveTimer?.cancel();
                  _longPressRoomMoveTimer = null;
                }
              }
              // Along-seam drag: if dragged out of room run, remove seam (merge pieces)
              if (_draggingAlongSeamRoomIndex != null &&
                  _draggingAlongSeamStripIndex != null &&
                  _draggingAlongSeamIndex != null) {
                final ri = _draggingAlongSeamRoomIndex!;
                final stri = _draggingAlongSeamStripIndex!;
                final ai = _draggingAlongSeamIndex!;
                final layout = _computeStripLayoutForRoom(ri, _completedRooms[ri]);
                if (layout != null) {
                  final runLen = layout.layAlongX ? layout.bboxWidth : layout.bboxHeight;
                  final world = _vp.screenToWorld(e.localPosition);
                  final runCoord = layout.layAlongX
                      ? (world.dx - layout.bboxMinX)
                      : (world.dy - layout.bboxMinY);
                  const outMarginMm = 50.0;
                  if (runCoord < -outMarginMm || runCoord > runLen + outMarginMm) {
                    setState(() {
                      final override = _roomCarpetStripPieceLengthsOverrideMm[ri]!;
                      final stripPieces = List<double>.from(override[stri]);
                      if (ai >= 0 && ai < stripPieces.length - 1) {
                        stripPieces[ai] = stripPieces[ai] + stripPieces[ai + 1];
                        stripPieces.removeAt(ai + 1);
                        override[stri] = stripPieces;
                        _draggingAlongSeamRoomIndex = null;
                        _draggingAlongSeamStripIndex = null;
                        _draggingAlongSeamIndex = null;
                        _hasUnsavedChanges = true;
                      }
                    });
                    return;
                  }
                }
              }
              // Seam drag: update seam position
              if (_draggingSeamRoomIndex != null &&
                  _draggingSeamIndex != null) {
                final ri = _draggingSeamRoomIndex!;
                final si = _draggingSeamIndex!;
                if (ri >= _completedRooms.length) {
                  setState(() {
                    _draggingSeamRoomIndex = null;
                    _draggingSeamIndex = null;
                  });
                  return;
                }
                final room = _completedRooms[ri];
                final layout = _computeStripLayoutForRoom(ri, room);
                if (layout == null) {
                  setState(() {
                    _draggingSeamRoomIndex = null;
                    _draggingSeamIndex = null;
                  });
                  return;
                }
                final perpLen = layout.layAlongX
                    ? layout.bboxHeight
                    : layout.bboxWidth;
                final world = _vp.screenToWorld(e.localPosition);
                double newPerpMm = layout.layAlongX
                    ? (world.dy - layout.bboxMinY)
                    : (world.dx - layout.bboxMinX);
                final positions = List<double>.from(
                  _roomCarpetSeamOverrides[ri]!,
                );
                const minGap = 50.0;
                final prev = si > 0 ? positions[si - 1] + minGap : 0.0;
                final next = si < positions.length - 1
                    ? positions[si + 1] - minGap
                    : perpLen - minGap;
                newPerpMm = newPerpMm.clamp(prev, next);
                setState(() {
                  positions[si] = newPerpMm;
                  _roomCarpetSeamOverrides[ri] = positions;
                  _hasUnsavedChanges = true;
                });
                return;
              }
              if (kIsWeb &&
                  _isMeasureMode &&
                  _measurePointsWorld.isNotEmpty &&
                  e.buttons == 1) {
                setState(() {
                  _measureCurrentWorld = _vp.screenToWorld(e.localPosition);
                });
              }
              // Update hover position for preview line (only when not dragging to draw walls)
              // Pan gestures are handled separately
              if (e.buttons == 0 &&
                  _draftRoomVertices != null &&
                  !_isDragging &&
                  !_isEditingVertex) {
                setState(() {
                  final worldPosition = _vp.screenToWorld(e.localPosition);
                  final snapped = _snapToGridAndAngle(worldPosition);
                  final result = _applyInlineSnap(snapped);
                  _hoverPositionWorldMm = result.snapped;
                  _inlineGuideStartWorld = result.guideStart;
                  _inlineGuideEndWorld = result.guideEnd;
                });
              }

              // Update hovered vertex for visual feedback (only in pan mode, when not drawing or editing)
              if (e.buttons == 0 &&
                  _draftRoomVertices == null &&
                  !_isEditingVertex &&
                  _isPanMode) {
                setState(() {
                  _hoveredVertex = _findVertexAtPosition(e.localPosition);
                });
              } else if (!_isPanMode) {
                // In draw mode, clear hovered vertex
                setState(() {
                  _hoveredVertex = null;
                });
              }

              // Pan handling
              if (kIsWeb && e.buttons == 1) {
                // Shift + left-drag
                if (HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.shiftLeft,
                )) {
                  setState(() {
                    _vp.panByScreenDelta(e.delta);
                    // Update hover position during pan
                    if (_draftRoomVertices != null) {
                      _hoverPositionWorldMm = _vp.screenToWorld(
                        e.localPosition,
                      );
                    }
                  });
                }
              } else if (kIsWeb && e.buttons == 2) {
                // Right-click drag
                setState(() {
                  _vp.panByScreenDelta(e.delta);
                  // Update hover position during pan
                  if (_draftRoomVertices != null) {
                    _hoverPositionWorldMm = _vp.screenToWorld(e.localPosition);
                  }
                });
              }
            },

            // ZOOM (web): mouse wheel / trackpad scroll zoom
            onPointerSignal: (signal) {
              if (!kIsWeb) return;
              if (signal is PointerScrollEvent) {
                // scroll up => zoom in, scroll down => zoom out
                final scrollY = signal.scrollDelta.dy;
                // Smooth zoom: use exponential scaling for natural feel
                // Negative scrollY = scroll up = zoom in
                // Positive scrollY = scroll down = zoom out
                final zoomFactor = scrollY < 0 ? 1.1 : 0.9;

                setState(() {
                  _vp.zoomAt(
                    zoomFactor: zoomFactor,
                    focalScreenPx: signal.localPosition,
                  );
                });
              }
            },

            child: GestureDetector(
              behavior: HitTestBehavior.opaque,

              // Use scale gestures for both pan/zoom (multi-touch) and drawing (single-touch)
              // On web, scale gestures are disabled to avoid conflicts with Listener
              onScaleStart: kIsWeb
                  ? null
                  : (details) {
                      // Check pointer count: 1 = drawing/panning/vertex-edit/measure, 2+ = pan/zoom
                      if (details.pointerCount == 1) {
                        if (_isMoveFloorplanMode &&
                            _backgroundImageState != null) {
                          setState(() {
                            _panStartScreen = details.localFocalPoint;
                            _isMovingFloorplan = false;
                          });
                          return;
                        }
                        if (_isMeasureMode) {
                          setState(() {
                            if (_measurePointsWorld.isEmpty) {
                              _measurePointsWorld.add(
                                _vp.screenToWorld(details.localFocalPoint),
                              );
                              _measureCurrentWorld = _vp.screenToWorld(
                                details.localFocalPoint,
                              );
                            } else {
                              _measureCurrentWorld = _vp.screenToWorld(
                                details.localFocalPoint,
                              );
                            }
                          });
                          return;
                        }
                        if (_isAddDoorMode) {
                          setState(
                            () => _panStartScreen = details.localFocalPoint,
                          );
                          return;
                        }
                        if (_isPanMode) {
                          // Pan mode: tap on background image should open floorplan menu, not vertex edit
                          final touchOnImage =
                              _backgroundImage != null &&
                              _backgroundImageState != null &&
                              _isPointOnBackgroundImage(
                                details.localFocalPoint,
                              );
                          final hasSelectedVertex =
                              (_selectedVertex != null ||
                                  _pendingSelectedVertex != null) &&
                              _draftRoomVertices == null;
                          if (hasSelectedVertex && !touchOnImage) {
                            _scaleGestureIsVertexEdit = true;
                            final v = _selectedVertex ?? _pendingSelectedVertex;
                            if (_debugVertexEdit)
                              debugPrint(
                                'PlanCanvas: scaleStart → vertex edit (vertex=${v!.roomIndex},${v.vertexIndex})',
                              );
                            _handlePanStart(details.localFocalPoint);
                          } else {
                            _scaleGestureIsVertexEdit = false;
                            // Non-web: also start along-seam or cross-seam drag if pointer hits a seam
                            final alongHit = _findAlongSeamAtScreenPosition(
                              details.localFocalPoint,
                            );
                            if (alongHit != null) {
                              setState(() {
                                final layout = _computeStripLayoutForRoom(
                                  alongHit.roomIndex,
                                  _completedRooms[alongHit.roomIndex],
                                );
                                if (layout != null) {
                                  final pieces = layout.pieceLengthsForStrip(alongHit.stripIndex);
                                  if (pieces.length >= 2) {
                                    if (!_roomCarpetStripPieceLengthsOverrideMm.containsKey(alongHit.roomIndex)) {
                                      _roomCarpetStripPieceLengthsOverrideMm[alongHit.roomIndex] = [
                                        for (int i = 0; i < layout.numStrips; i++)
                                          List<double>.from(layout.pieceLengthsForStrip(i)),
                                      ];
                                    }
                                    _draggingAlongSeamRoomIndex = alongHit.roomIndex;
                                    _draggingAlongSeamStripIndex = alongHit.stripIndex;
                                    _draggingAlongSeamIndex = alongHit.alongSeamIndex;
                                    _hasUnsavedChanges = true;
                                  }
                                }
                              });
                            } else {
                              final hit = _findSeamAtScreenPosition(
                                details.localFocalPoint,
                              );
                              if (hit != null) {
                                setState(() {
                                  final layout = _computeStripLayoutForRoom(
                                    hit.roomIndex,
                                    _completedRooms[hit.roomIndex],
                                  );
                                  if (layout != null && layout.numStrips >= 2) {
                                    if (!_roomCarpetSeamOverrides.containsKey(
                                      hit.roomIndex,
                                    )) {
                                      _roomCarpetSeamOverrides[hit.roomIndex] =
                                          List<double>.from(
                                            layout.seamPositionsFromReferenceMm,
                                          );
                                      _roomCarpetSeamLayDirectionDeg[hit
                                          .roomIndex] = layout.layAlongX
                                          ? 0.0
                                          : 90.0;
                                    }
                                    _draggingSeamRoomIndex = hit.roomIndex;
                                    _draggingSeamIndex = hit.seamIndex;
                                    _hasUnsavedChanges = true;
                                  }
                                });
                              } else {
                              if (_debugVertexEdit)
                                debugPrint(
                                  'PlanCanvas: scaleStart → potential pan/tap (no vertex or tap on image)',
                                );
                              setState(() {
                                _panStartScreen = details.localFocalPoint;
                              });
                            }
                            }
                            // Long-press timer for "move room" is started in Listener.onPointerDown (all platforms)
                          }
                        } else {
                          // Draw mode: start drawing
                          _handlePanStart(details.localFocalPoint);
                        }
                      } else {
                        // Multi-finger: start pan/zoom
                        _startMmPerPx = _vp.mmPerPx;
                      }
                    },
              onScaleUpdate: kIsWeb
                  ? null
                  : (details) {
                      // Check pointer count: 1 = drawing/panning/measure/seam-drag, 2+ = pan/zoom
                      if (details.pointerCount == 1) {
                        // Along-seam drag: if dragged out of room run, remove seam (merge pieces)
                        if (_draggingAlongSeamRoomIndex != null &&
                            _draggingAlongSeamStripIndex != null &&
                            _draggingAlongSeamIndex != null) {
                          final ri = _draggingAlongSeamRoomIndex!;
                          final stri = _draggingAlongSeamStripIndex!;
                          final ai = _draggingAlongSeamIndex!;
                          final layout = _computeStripLayoutForRoom(ri, _completedRooms[ri]);
                          if (layout != null) {
                            final runLen = layout.layAlongX ? layout.bboxWidth : layout.bboxHeight;
                            final world = _vp.screenToWorld(details.localFocalPoint);
                            final runCoord = layout.layAlongX
                                ? (world.dx - layout.bboxMinX)
                                : (world.dy - layout.bboxMinY);
                            const outMarginMm = 50.0;
                            if (runCoord < -outMarginMm || runCoord > runLen + outMarginMm) {
                              setState(() {
                                final override = _roomCarpetStripPieceLengthsOverrideMm[ri]!;
                                final stripPieces = List<double>.from(override[stri]);
                                if (ai >= 0 && ai < stripPieces.length - 1) {
                                  stripPieces[ai] = stripPieces[ai] + stripPieces[ai + 1];
                                  stripPieces.removeAt(ai + 1);
                                  override[stri] = stripPieces;
                                  _draggingAlongSeamRoomIndex = null;
                                  _draggingAlongSeamStripIndex = null;
                                  _draggingAlongSeamIndex = null;
                                  _hasUnsavedChanges = true;
                                }
                              });
                              return;
                            }
                          }
                          return;
                        }
                        // Seam drag: update position (non-web; Listener handles web)
                        if (_draggingSeamRoomIndex != null &&
                            _draggingSeamIndex != null) {
                          final ri = _draggingSeamRoomIndex!;
                          final si = _draggingSeamIndex!;
                          if (ri < _completedRooms.length) {
                            final room = _completedRooms[ri];
                            final layout = _computeStripLayoutForRoom(ri, room);
                            if (layout != null &&
                                _roomCarpetSeamOverrides.containsKey(ri)) {
                              final perpLen = layout.layAlongX
                                  ? layout.bboxHeight
                                  : layout.bboxWidth;
                              final world = _vp.screenToWorld(
                                details.localFocalPoint,
                              );
                              double newPerpMm = layout.layAlongX
                                  ? (world.dy - layout.bboxMinY)
                                  : (world.dx - layout.bboxMinX);
                              final positions = List<double>.from(
                                _roomCarpetSeamOverrides[ri]!,
                              );
                              const minGap = 50.0;
                              final prev = si > 0
                                  ? positions[si - 1] + minGap
                                  : 0.0;
                              final next = si < positions.length - 1
                                  ? positions[si + 1] - minGap
                                  : perpLen - minGap;
                              newPerpMm = newPerpMm.clamp(prev, next);
                              setState(() {
                                positions[si] = newPerpMm;
                                _roomCarpetSeamOverrides[ri] = positions;
                                _hasUnsavedChanges = true;
                              });
                            }
                          }
                          return;
                        }
                        // Don't pan the viewport while moving a room
                        if (_isMovingRoom) return;
                        if (_isMoveFloorplanMode &&
                            _backgroundImageState != null) {
                          if (_panStartScreen != null) {
                            final distance =
                                (details.localFocalPoint - _panStartScreen!)
                                    .distance;
                            if (distance > _panSlopPx) {
                              _longPressRoomMoveTimer?.cancel();
                              _longPressRoomMoveTimer = null;
                              setState(() {
                                _isMovingFloorplan = true;
                                _panStartScreen = null;
                              });
                            }
                          }
                          if (_isMovingFloorplan) {
                            setState(() {
                              final mmPerPx = _vp.mmPerPx;
                              _backgroundImageState = _backgroundImageState!
                                  .copyWith(
                                    offsetX:
                                        _backgroundImageState!.offsetX +
                                        details.focalPointDelta.dx * mmPerPx,
                                    offsetY:
                                        _backgroundImageState!.offsetY +
                                        details.focalPointDelta.dy * mmPerPx,
                                  );
                              _lastScalePosition = details.localFocalPoint;
                              _hasUnsavedChanges = true;
                            });
                          }
                          return;
                        }
                        if (_isMeasureMode && _measurePointsWorld.isNotEmpty) {
                          setState(() {
                            _measureCurrentWorld = _vp.screenToWorld(
                              details.localFocalPoint,
                            );
                          });
                          return;
                        }
                        // Vertex editing (pan mode): drag to move selected vertex (use sync flag so we see it before setState runs)
                        if (_scaleGestureIsVertexEdit || _isEditingVertex) {
                          _lastScalePosition = details.localFocalPoint;
                          if (_debugVertexEdit &&
                              _scaleGestureIsVertexEdit &&
                              !_isEditingVertex)
                            debugPrint(
                              'PlanCanvas: scaleUpdate → vertex move (sync flag)',
                            );
                          _handlePanUpdate(details.localFocalPoint);
                        } else if (_isPanning) {
                          // Pan mode: pan the viewport
                          setState(() {
                            _vp.panByScreenDelta(details.focalPointDelta);
                            _lastScalePosition = details.localFocalPoint;
                          });
                        } else if (_isPanMode &&
                            _panStartScreen != null &&
                            !_isPanning) {
                          // Pan mode: only start panning after finger moves past slop (so tap can select vertex / long-press move room)
                          final distance =
                              (details.localFocalPoint - _panStartScreen!)
                                  .distance;
                          if (distance > _panSlopPx) {
                            _longPressRoomMoveTimer?.cancel();
                            _longPressRoomMoveTimer = null;
                            setState(() {
                              _isPanning = true;
                              _vp.panByScreenDelta(details.focalPointDelta);
                              _lastScalePosition = details.localFocalPoint;
                            });
                          }
                        } else if (_isPanning) {
                          // Pan mode: continue panning (handled in branch above when slop just exceeded)
                          setState(() {
                            _vp.panByScreenDelta(details.focalPointDelta);
                            _lastScalePosition = details.localFocalPoint;
                          });
                        } else if (!_isPanMode) {
                          // Draw mode: continue drawing
                          _lastScalePosition = details.localFocalPoint;
                          _handlePanUpdate(details.localFocalPoint);
                        }
                      } else {
                        // Multi-finger: pan and zoom
                        setState(() {
                          _vp.panByScreenDelta(details.focalPointDelta);

                          final desiredMmPerPx = _startMmPerPx / details.scale;
                          final zoomFactor = desiredMmPerPx / _vp.mmPerPx;
                          _vp.zoomAt(
                            zoomFactor: zoomFactor,
                            focalScreenPx: details.localFocalPoint,
                          );
                        });
                      }
                    },
              onScaleEnd: kIsWeb
                  ? null
                  : (_) {
                      _longPressRoomMoveTimer?.cancel();
                      _longPressRoomMoveTimer = null;
                      // End seam drag (non-web); skip tap so release-after-drag doesn't select room
                      if (_draggingSeamRoomIndex != null) {
                        setState(() {
                          _draggingSeamRoomIndex = null;
                          _draggingSeamIndex = null;
                        });
                        return;
                      }
                      if (_draggingAlongSeamRoomIndex != null) {
                        setState(() {
                          _draggingAlongSeamRoomIndex = null;
                          _draggingAlongSeamStripIndex = null;
                          _draggingAlongSeamIndex = null;
                        });
                        return;
                      }
                      final wasMovingRoom = _isMovingRoom;
                      if (_isMovingRoom) {
                        setState(() {
                          _isMovingRoom = false;
                          _roomMoveRoomIndex = null;
                          _roomMoveAnchorWorld = null;
                          _roomMoveVerticesAtStart = null;
                        });
                        _saveHistoryState();
                        widget.onRoomsChanged?.call(
                          _completedRooms,
                          _useImperial,
                          _selectedRoomIndex,
                        );
                      }
                      if (_isMoveFloorplanMode) {
                        setState(() {
                          _isMovingFloorplan = false;
                          _panStartScreen = null;
                        });
                      }
                      if (_isMeasureMode) {
                        setState(() {
                          if (_measureCurrentWorld != null) {
                            _measurePointsWorld.add(_measureCurrentWorld!);
                            _measureCurrentWorld = null;
                          }
                        });
                      }
                      // If we were panning, end panning
                      if (_isPanning) {
                        _scaleGestureIsVertexEdit = false;
                        _pendingSelectedVertex = null;
                        setState(() {
                          _isPanning = false;
                          _panStartScreen = null;
                        });
                      } else if ((_scaleGestureIsVertexEdit ||
                              _isEditingVertex) &&
                          _lastScalePosition != null) {
                        // Vertex edit drag finished
                        _scaleGestureIsVertexEdit = false;
                        _pendingSelectedVertex = null;
                        _handlePanEnd(_lastScalePosition!);
                        _lastScalePosition = null;
                      } else if (_panStartScreen != null && !wasMovingRoom) {
                        // Single-finger touch in pan mode that didn't move past slop = treat as tap (e.g. vertex select)
                        _scaleGestureIsVertexEdit = false;
                        final tapPosition = _panStartScreen!;
                        setState(() => _panStartScreen = null);
                        _handleCanvasTap(tapPosition);
                      }
                      // If we were drawing (single finger gesture), finish drawing
                      if (_isDragging && _lastScalePosition != null) {
                        // Connected to vertex/door with 1 point and lifted without moving: stay connected (tap same vertex again to deselect)
                        final stayedConnected =
                            _draftRoomVertices != null &&
                            _draftRoomVertices!.length == 1 &&
                            _draftStartedFromVertexOrDoor &&
                            !_dragMoved &&
                            !_isPanMode;
                        if (stayedConnected) {
                          setState(() {
                            _isDragging = false;
                            _dragMoved = false;
                          });
                          _lastScalePosition = null;
                        } else {
                          _handlePanEnd(_lastScalePosition!);
                          setState(() => _dragMoved = false);
                          _lastScalePosition = null;
                        }
                      }
                    },

              // Double-tap: close room if drafting
              onDoubleTapDown: (d) {
                if (_draftRoomVertices != null &&
                    _draftRoomVertices!.length >= 3) {
                  // Close draft room
                  _closeDraftRoom();
                }
              },

              // Single tap: select room or edit name if clicking center, or place roll (web / when tap wins)
              onTapDown: (d) => _handleCanvasTap(d.localPosition),

              // Right-click (or long-press on mobile): show delete option
              onSecondaryTapDown: (d) {
                if (_draftRoomVertices == null) {
                  final worldPos = _vp.screenToWorld(d.localPosition);
                  final clickedRoomIndex = _findRoomAtPosition(worldPos);
                  if (clickedRoomIndex != null) {
                    _showDeleteRoomDialog(clickedRoomIndex);
                  }
                }
              },

              child: LayoutBuilder(
                key: ValueKey(
                  'plan_painter_${_completedRooms.length}_${_draftRoomVertices?.length ?? 0}',
                ),
                builder: (context, constraints) {
                  final w =
                      constraints.maxWidth.isFinite &&
                          constraints.maxWidth < double.infinity
                      ? constraints.maxWidth
                      : 0.0;
                  final h =
                      constraints.maxHeight.isFinite &&
                          constraints.maxHeight < double.infinity
                      ? constraints.maxHeight
                      : 0.0;
                  final hasSize = w > 0 && h > 0;
                  return SizedBox(
                    width: hasSize ? w : double.infinity,
                    height: hasSize ? h : double.infinity,
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: PlanPainter(
                        PlanPaintModel(
                          vp: _vp,
                          completedRooms: _safeCopyRooms(_completedRooms),
                          openings: List<Opening>.from(_openings),
                          roomCarpetAssignments: kEnableCarpetFeatures
                              ? _roomCarpetAssignments
                              : const {},
                          carpetProducts: _carpetProducts,
                          roomCarpetSeamOverrides: kEnableCarpetFeatures
                              ? _roomCarpetSeamOverrides
                              : const {},
                          roomCarpetSeamLayDirectionDeg: kEnableCarpetFeatures
                              ? _roomCarpetSeamLayDirectionDeg
                              : const {},
                          roomCarpetLayoutVariantIndex: kEnableCarpetFeatures
                              ? _roomCarpetLayoutVariantIndex
                              : const {},
                          roomCarpetStripPieceLengthsOverrideMm:
                              kEnableCarpetFeatures
                              ? Map<int, List<List<double>>>.from(
                                  _roomCarpetStripPieceLengthsOverrideMm.map(
                                    (k, v) => MapEntry(
                                      k,
                                      v
                                          .map((p) => List<double>.from(p))
                                          .toList(),
                                    ),
                                  ),
                                )
                              : const {},
                          pendingDoorEdge: _pendingDoorEdge,
                          draftRoomVertices: _draftRoomVertices != null
                              ? List<Offset>.from(_draftRoomVertices!)
                              : null,
                          hoverPositionWorldMm: _hoverPositionWorldMm,
                          previewLineAngleDeg:
                              _angleBetweenLinesDeg ?? _currentSegmentAngleDeg,
                          inlineGuideStartWorld: _inlineGuideStartWorld,
                          inlineGuideEndWorld: _inlineGuideEndWorld,
                          wallWidthMm: _wallWidthMm,
                          useImperial: _useImperial,
                          isDragging: _isDragging,
                          selectedRoomIndex: _selectedRoomIndex,
                          selectedVertex: _selectedVertex,
                          hoveredVertex: _hoveredVertex,
                          showGrid: _showGrid,
                          calibrationP1Screen: _calibrationP1Screen,
                          calibrationP2Screen: _calibrationP2Screen,
                          isMeasureMode: _isMeasureMode,
                          measurePointsWorld: List.from(_measurePointsWorld),
                          measureCurrentWorld: _measureCurrentWorld,
                          isAddDimensionMode: _isAddDimensionMode,
                          addDimensionP1World: _addDimensionP1World,
                          placedDimensions: List.from(_placedDimensions),
                          drawFromStart: _drawFromStart,
                          backgroundImage: _backgroundImage,
                          backgroundImageState: _backgroundImageState,
                          doorThicknessMm: _doorThicknessMm,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        // Room actions (three-dots) button + menu near selected room
        if (kEnableCarpetFeatures && _selectedRoomCenterScreen != null) ...[
          Positioned(
            left: _selectedRoomCenterScreen!.dx - 16,
            top: _selectedRoomCenterScreen!.dy - 44,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _showRoomActionsMenu = !_showRoomActionsMenu;
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(38),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.more_horiz, size: 20),
              ),
            ),
          ),
          if (_showRoomActionsMenu)
            Positioned(
              left: _selectedRoomCenterScreen!.dx + 20,
              top: _selectedRoomCenterScreen!.dy - 80,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 180),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showRoomActionsMenu = false;
                              _showCarpetDirectionPicker = true;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.unfold_more, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Carpet direction…',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
        if (kEnableCarpetFeatures &&
            _selectedRoomCenterScreen != null &&
            _showCarpetDirectionPicker)
          Positioned(
            left: _selectedRoomCenterScreen!.dx - 80,
            top: _selectedRoomCenterScreen!.dy - 140,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Carpet direction',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                          onPressed: () {
                            setState(() {
                              _showCarpetDirectionPicker = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Up arrow row
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.north),
                        tooltip: 'Up',
                        onPressed: () =>
                            _applyCarpetDirectionForSelectedRoom(2),
                      ),
                    ),
                    // Left / Auto / Right row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.west),
                          tooltip: 'Left',
                          onPressed: () =>
                              _applyCarpetDirectionForSelectedRoom(1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.radio_button_unchecked),
                          tooltip: 'Auto',
                          onPressed: () =>
                              _applyCarpetDirectionForSelectedRoom(0),
                        ),
                        IconButton(
                          icon: const Icon(Icons.east),
                          tooltip: 'Right',
                          onPressed: () =>
                              _applyCarpetDirectionForSelectedRoom(1),
                        ),
                      ],
                    ),
                    // Down arrow row
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.south),
                        tooltip: 'Down',
                        onPressed: () =>
                            _applyCarpetDirectionForSelectedRoom(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Top-left: collapsible View & Edit menu (unit, grid, draw, lock angle, zoom, undo, redo, delete, save)
        Positioned(
          top: 8,
          left: 8,
          child: CollapsibleToolbar(
            tooltip: 'View & Edit',
            icon: Icons.edit_note,
            initialExpanded: true,
            child: PlanToolbar(
              section: ToolbarSection.main,
              useImperial: _useImperial,
              showGrid: _showGrid,
              isPanMode: _isPanMode,
              canUndo: _canUndo,
              canRedo: _canRedo,
              canAutoCompleteRoom:
                  _draftRoomVertices != null && _draftRoomVertices!.length >= 3,
              onAutoCompleteRoom:
                  _draftRoomVertices != null && _draftRoomVertices!.length >= 3
                  ? _closeDraftRoom
                  : null,
              hasSelectedRoom: _selectedRoomIndex != null,
              onDeleteRoom:
                  _selectedRoomIndex != null && _draftRoomVertices == null
                  ? () => _showDeleteRoomDialog(_selectedRoomIndex!)
                  : null,
              hasProject: _currentProjectId != null,
              hasUnsavedChanges: _hasUnsavedChanges,
              onSave: () => _saveProject(this),
              isAngleLocked: _drawAngleLock != DrawAngleLock.none,
              onToggleAngleLock: _isPanMode
                  ? null
                  : () {
                      setState(() {
                        _drawAngleLock = _drawAngleLock == DrawAngleLock.none
                            ? DrawAngleLock.snap45
                            : DrawAngleLock.none;
                      });
                    },
              isDrawing:
                  _draftRoomVertices != null && _draftRoomVertices!.isNotEmpty,
              showNumberPad: _showNumberPad,
              onToggleNumberPad: () =>
                  setState(() => _showNumberPad = !_showNumberPad),
              drawFromStart: _drawFromStart,
              onToggleDrawFromStart: () => setState(() {
                _drawFromStart = !_drawFromStart;
                // Clear hover so we don't draw a misleading preview line from new endpoint to stale cursor
                _hoverPositionWorldMm = null;
              }),
              onToggleUnit: _toggleUnit,
              onToggleGrid: _toggleGrid,
              onTogglePanMode: _togglePanMode,
              onCalibrate: _toggleCalibration,
              isCalibrating: _isCalibrating,
              isMeasureMode: _isMeasureMode,
              onToggleMeasureMode: _toggleMeasureMode,
              isAddDimensionMode: _isAddDimensionMode,
              onToggleAddDimensionMode: _toggleAddDimensionMode,
              isAddDoorMode: _isAddDoorMode,
              onToggleAddDoorMode: _toggleAddDoorMode,
              hasPlacedDimensions: _placedDimensions.isNotEmpty,
              onRemoveLastDimension: _removeLastDimension,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onFitToScreen: _fitToScreen,
              onUndo: _undo,
              onRedo: _redo,
              onImportFloorplan: () => _importFloorplanImage(this),
              backgroundImageOpacity: _backgroundImageState?.opacity,
              onBackgroundOpacityChanged: _backgroundImageState == null
                  ? null
                  : (v) {
                      setState(() {
                        _backgroundImageState = _backgroundImageState!.copyWith(
                          opacity: v,
                        );
                        _hasUnsavedChanges = true;
                      });
                    },
              hasBackgroundImage: _backgroundImage != null,
              isFloorplanLocked: _backgroundImageState?.locked ?? false,
              onToggleFloorplanLock: _backgroundImage != null
                  ? _toggleFloorplanLock
                  : null,
              onFitFloorplan: _backgroundImage != null
                  ? _fitFloorplanToView
                  : null,
              onResetFloorplan: _backgroundImage != null
                  ? _resetFloorplanTransform
                  : null,
              backgroundImageScaleFactor: _backgroundImageState?.scaleFactor,
              onBackgroundScaleFactorChanged: _backgroundImageState == null
                  ? null
                  : (v) {
                      setState(() {
                        _backgroundImageState = _backgroundImageState!.copyWith(
                          scaleFactor: v,
                        );
                        _hasUnsavedChanges = true;
                      });
                    },
              isMoveFloorplanMode: _isMoveFloorplanMode,
              onToggleMoveFloorplanMode: _backgroundImage != null
                  ? _toggleMoveFloorplanMode
                  : null,
            ),
          ),
        ),
        if (_showFloorplanMenu &&
            _backgroundImage != null &&
            _backgroundImageState != null)
          Builder(
            builder: (context) {
              final imageRect = _backgroundImageScreenRect();
              if (imageRect == null) return const SizedBox.shrink();
              final locked = _backgroundImageState!.locked;
              final topLeft = imageRect.topLeft;
              final topRight = imageRect.topRight;
              final bottomRight = imageRect.bottomRight;
              final bottomLeft = imageRect.bottomLeft;
              const handleSize = 16.0;

              Widget buildHandle(Offset corner, int cornerIndex) {
                if (locked) return const SizedBox.shrink();
                return Positioned(
                  left: corner.dx - handleSize / 2,
                  top: corner.dy - handleSize / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      _startFloorplanResize(
                        cornerIndex,
                        corner,
                        details.globalPosition,
                      );
                    },
                    onPanUpdate: (details) {
                      _updateFloorplanResize(details.globalPosition);
                    },
                    onPanEnd: (_) {
                      _endFloorplanResize();
                    },
                    child: Container(
                      width: handleSize,
                      height: handleSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  Positioned(
                    left: imageRect.left,
                    top: imageRect.top,
                    width: imageRect.width,
                    child: PlanFloorplanContextMenu(
                      locked: locked,
                      opacity: _backgroundImageState!.opacity,
                      isMoveMode: _isMoveFloorplanMode,
                      onToggleLock: _toggleFloorplanLock,
                      onFit: _fitFloorplanToView,
                      onReset: _resetFloorplanTransform,
                      onToggleMoveMode: _toggleMoveFloorplanMode,
                      onDelete: _removeFloorplanImage,
                      onOpacityChanged: (v) {
                        setState(() {
                          _backgroundImageState = _backgroundImageState!
                              .copyWith(opacity: v);
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ),
                  buildHandle(topLeft, 0),
                  buildHandle(topRight, 1),
                  buildHandle(bottomRight, 2),
                  buildHandle(bottomLeft, 3),
                ],
              );
            },
          ),
        // Top-right: collapsible Dimensions menu (calibrate, measure, add dimension, remove last)
        Positioned(
          top: 8,
          right: 8,
          child: CollapsibleToolbar(
            tooltip: 'Dimensions',
            icon: Icons.straighten,
            initialExpanded: false,
            child: PlanToolbar(
              section: ToolbarSection.dimensions,
              useImperial: _useImperial,
              showGrid: _showGrid,
              isPanMode: _isPanMode,
              canUndo: _canUndo,
              canRedo: _canRedo,
              canAutoCompleteRoom: false,
              onAutoCompleteRoom: null,
              hasSelectedRoom: _selectedRoomIndex != null,
              onDeleteRoom:
                  _selectedRoomIndex != null && _draftRoomVertices == null
                  ? () => _showDeleteRoomDialog(_selectedRoomIndex!)
                  : null,
              hasProject: _currentProjectId != null,
              hasUnsavedChanges: _hasUnsavedChanges,
              onSave: () => _saveProject(this),
              isAngleLocked: false,
              onToggleAngleLock: null,
              onToggleUnit: _toggleUnit,
              onToggleGrid: _toggleGrid,
              onTogglePanMode: _togglePanMode,
              onCalibrate: _toggleCalibration,
              isCalibrating: _isCalibrating,
              isMeasureMode: _isMeasureMode,
              onToggleMeasureMode: _toggleMeasureMode,
              isAddDimensionMode: _isAddDimensionMode,
              onToggleAddDimensionMode: _toggleAddDimensionMode,
              isAddDoorMode: _isAddDoorMode,
              onToggleAddDoorMode: _toggleAddDoorMode,
              hasPlacedDimensions: _placedDimensions.isNotEmpty,
              onRemoveLastDimension: _removeLastDimension,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onFitToScreen: _fitToScreen,
              onUndo: _undo,
              onRedo: _redo,
              onImportFloorplan: () => _importFloorplanImage(this),
              hasBackgroundImage: _backgroundImage != null,
            ),
          ),
        ),
        // Length input number pad (visible when drawing and not hidden by user); draggable by its top bar
        ...(_draftRoomVertices != null &&
                _draftRoomVertices!.isNotEmpty &&
                _showNumberPad
            ? [
                Positioned(
                  left: _numberPadPosition?.dx,
                  top: _numberPadPosition?.dy,
                  right: _numberPadPosition == null ? 16 : null,
                  bottom: _numberPadPosition == null ? 60 : null,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _numberPadApproxWidth,
                      maxHeight: _numberPadApproxHeight,
                    ),
                    child: PlanDraggableNumberPadWrapper(
                      key: _numberPadWrapperKey,
                      onDragStart: () {
                        final box =
                            _numberPadWrapperKey.currentContext
                                    ?.findRenderObject()
                                as RenderBox?;
                        final stackBox =
                            _stackKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (box == null || stackBox == null) return;
                        final topLeftGlobal = box.localToGlobal(Offset.zero);
                        final topLeftLocal = stackBox.globalToLocal(
                          topLeftGlobal,
                        );
                        setState(() => _numberPadPosition = topLeftLocal);
                      },
                      onDragUpdate: (Offset delta) {
                        if (_numberPadPosition == null) return;
                        final stackBox =
                            _stackKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (stackBox == null) return;
                        final w = stackBox.size.width;
                        final h = stackBox.size.height;
                        setState(() {
                          _numberPadPosition = Offset(
                            (_numberPadPosition!.dx + delta.dx).clamp(
                              0.0,
                              w - _numberPadApproxWidth,
                            ),
                            (_numberPadPosition!.dy + delta.dy).clamp(
                              0.0,
                              h - _numberPadApproxHeight,
                            ),
                          );
                        });
                      },
                      child: PlanLengthInputPad(
                        controller: _lengthInputController,
                        useImperial: _useImperial,
                        onChanged: _onLengthInputChanged,
                      ),
                    ),
                  ),
                ),
              ]
            : []),
      ],
    );
  }

  /// Find the closest vertex to a screen position, if within tolerance.
  /// Returns (roomIndex, vertexIndex) or null if no vertex is close enough.
  ({int roomIndex, int vertexIndex})? _findVertexAtPosition(
    Offset screenPosition,
  ) => _findVertexAtPositionImpl(this, screenPosition);

  /// Safely copy rooms list, handling hot reload issues.
  List<Room> _safeCopyRooms(List<Room>? rooms) => _safeCopyRoomsImpl(rooms);

  /// Handle pan start: begin drawing a wall segment or start editing a vertex.
  void _handlePanStart(Offset screenPosition) {
    _handlePanStartImpl(this, screenPosition);
  }

  /// Handle pan update: update preview line as user drags, or move vertex if editing.
  void _handlePanUpdate(Offset screenPosition) {
    _handlePanUpdateImpl(this, screenPosition);
  }

  /// Handle pan end: place the wall segment (add vertex) or finish editing vertex.
  void _handlePanEnd(Offset screenPosition) {
    _handlePanEndImpl(this, screenPosition);
  }

  /// If the quad has exactly 90° corners (within tiny tolerance), return 4 vertices forming a perfect rectangle.
  /// Returns null if not a quad or any angle is not 90°.
  static List<Offset>? _makeRectangleFromQuad(List<Offset> quad) {
    if (quad.length != 4) return null;
    const toleranceDeg =
        0.5; // Only treat as rectangle if each angle is within 0.5° of 90°

    // Compute interior angle at each vertex (angle between incoming and outgoing edge)
    for (int i = 0; i < 4; i++) {
      final prev = quad[(i + 3) % 4];
      final curr = quad[i];
      final next = quad[(i + 1) % 4];
      final v1 = Offset(prev.dx - curr.dx, prev.dy - curr.dy);
      final v2 = Offset(next.dx - curr.dx, next.dy - curr.dy);
      final d1 = math.sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
      final d2 = math.sqrt(v2.dx * v2.dx + v2.dy * v2.dy);
      if (d1 < 1e-6 || d2 < 1e-6) return null;
      final angle = math.atan2(
        v1.dx * v2.dy - v1.dy * v2.dx,
        v1.dx * v2.dx + v1.dy * v2.dy,
      );
      final angleDeg = (angle.abs() * 180 / math.pi);
      if (angleDeg < 90 - toleranceDeg || angleDeg > 90 + toleranceDeg)
        return null; // Not 90°
    }

    final p0 = quad[0];
    final p1 = quad[1];
    final p2 = quad[2];
    final p3 = quad[3];
    final a = (p1 - p0).distance;
    final b = (p2 - p1).distance;
    final c = (p3 - p2).distance;
    final d = (p0 - p3).distance;
    final side1 = (a + c) / 2;
    final side2 = (b + d) / 2;

    final u = Offset(p1.dx - p0.dx, p1.dy - p0.dy);
    final uLen = math.sqrt(u.dx * u.dx + u.dy * u.dy);
    if (uLen < 1e-6) return null;
    final ux = u.dx / uLen;
    final uy = u.dy / uLen;
    // Perpendicular (rotate 90° CCW): v = (-uy, ux)
    return [
      p0,
      Offset(p0.dx + ux * side1, p0.dy + uy * side1),
      Offset(p0.dx + ux * side1 - uy * side2, p0.dy + uy * side1 + ux * side2),
      Offset(p0.dx - uy * side2, p0.dy + ux * side2),
    ];
  }

  /// Close the current draft room and add it to completed rooms.
  void _closeDraftRoom() {
    _closeDraftRoomImpl(this);
  }

  /// Handle length input change from number pad.
  /// Adjusts the last drawn segment to match the entered length in real-time.
  void _onLengthInputChanged(String value) {
    _onLengthInputChangedImpl(this, value);
  }

  /// Parse length input string to millimeters.
  /// Supports formats like "3000", "3000mm", "300cm", "10.5", "10' 6\"", etc.
  double? _parseLengthInput(String input) => _parseLengthInputImpl(this, input);

  /// Show a dialog to get the room name from the user.
  Future<String?> _showRoomNameDialog({String? initialName}) =>
      _showRoomNameDialogImpl(this, initialName: initialName);

  /// Show dialog to set door/opening width and position (mm). Called after user taps a wall in add-door mode.
  Future<void> _showAddDoorDialog({
    required int roomIndex,
    required int edgeIndex,
    required double edgeLenMm,
  }) => _showAddDoorDialogImpl(
    this,
    roomIndex: roomIndex,
    edgeIndex: edgeIndex,
    edgeLenMm: edgeLenMm,
  );

  /// Closest point on segment [a, b] to point p; returns t in [0,1] and distance.
  static ({double t, double distanceMm}) _closestPointOnSegment(
    Offset p,
    Offset a,
    Offset b,
  ) {
    final v = Offset(b.dx - a.dx, b.dy - a.dy);
    final w = Offset(p.dx - a.dx, p.dy - a.dy);
    final c1 = w.dx * v.dx + w.dy * v.dy;
    final c2 = v.dx * v.dx + v.dy * v.dy;
    final t = c2 <= 0 ? 0.0 : (c1 / c2).clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * v.dx, a.dy + t * v.dy);
    final dist = (p - proj).distance;
    return (t: t, distanceMm: dist);
  }

  /// Show a confirmation dialog to delete a room.
  Future<void> _showDeleteRoomDialog(int roomIndex) =>
      _showDeleteRoomDialogImpl(this, roomIndex);

  /// Edit the name of an existing room.
  Future<void> _editRoomName(int roomIndex) =>
      _editRoomNameImpl(this, roomIndex);
}
