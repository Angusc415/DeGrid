import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'viewport.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../core/geometry/room.dart';
import '../../core/units/unit_converter.dart';
import '../../core/database/database.dart';
import '../../core/services/project_service.dart';
import '../../core/models/project.dart';
import 'plan_toolbar.dart';

/// Angle lock for draw mode: none (free), snap to 90°, or snap to 45°.
enum DrawAngleLock { none, snap90, snap45 }

class PlanCanvas extends StatefulWidget {
  final int? projectId;
  final String? initialProjectName;
  final Function(List<Room>, bool, int?)? onRoomsChanged; // Callback for rooms, useImperial, selectedIndex
  final Function(int)? onSelectRoomRequested; // Callback when external code wants to select a room

  const PlanCanvas({
    super.key,
    this.projectId,
    this.initialProjectName,
    this.onRoomsChanged,
    this.onSelectRoomRequested,
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

  // Completed rooms (polygons)
  final List<Room> _completedRooms = [];
  
  // Counter for default room names
  int _roomCounter = 1;
  
  // Unit system: false = metric (mm/cm), true = imperial (ft/in)
  bool _useImperial = false;
  
  // Grid visibility toggle
  bool _showGrid = true;
  
  // Pan mode toggle: when true, single-finger drag pans instead of drawing
  bool _isPanMode = false;
  
  /// Draw mode angle lock: lines snap to 90°, 45°, or free angle.
  DrawAngleLock _drawAngleLock = DrawAngleLock.none;

  // Calibration mode (true scale): user taps 2 points then enters real distance.
  bool _isCalibrating = false;
  Offset? _calibrationP1Screen;
  Offset? _calibrationP2Screen;

  // Dimension tools
  /// Measure tool: temporary line between two points (tap-tap to set, tap again to clear).
  bool _isMeasureMode = false;
  Offset? _measureP1World;
  Offset? _measureP2World;
  /// Add dimension mode: tap two points to place a permanent dimension.
  bool _isAddDimensionMode = false;
  Offset? _addDimensionP1World;
  /// Placed dimensions (world mm); persisted with project later.
  final List<({Offset fromMm, Offset toMm})> _placedDimensions = [];
  
  // Pan mode state: track if we're currently panning
  bool _isPanning = false;
  Offset? _panStartScreen;
  /// Minimum drag distance (px) before a touch is treated as pan; below this, treat as tap (e.g. vertex select).
  static const double _panSlopPx = 18.0;
  /// True when the current scale gesture is "drag to move selected vertex" (set synchronously in onScaleStart so onScaleUpdate sees it before setState runs).
  bool _scaleGestureIsVertexEdit = false;

  /// Set to true to log vertex-edit vs pan decisions (debug only).
  static const bool _debugVertexEdit = false;
  
  // Undo/Redo history
  // Each history entry contains both completed rooms and draft room vertices
  final List<({List<Room> rooms, List<Offset>? draftVertices})> _history = [];
  int _historyIndex = -1; // -1 means at initial state, 0 means after first action
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
  /// When true, new segments are drawn from the first vertex; when false, from the last.
  bool _drawFromStart = false;

  // Current cursor/hover position for preview line (world-space mm)
  Offset? _hoverPositionWorldMm;

  /// The vertex we're currently drawing from (start or end of draft chain).
  Offset get _draftDrawingFrom =>
      _drawFromStart ? _draftRoomVertices!.first : _draftRoomVertices!.last;
  /// The vertex before [ _draftDrawingFrom ] in draw order (for angle calculation).
  Offset? get _draftDrawingFromPrev {
    if (_draftRoomVertices == null || _draftRoomVertices!.length < 2) return null;
    return _drawFromStart ? _draftRoomVertices![1] : _draftRoomVertices![_draftRoomVertices!.length - 2];
  }
  /// The "other" end — used for close detection (drag near this to close).
  Offset get _draftCloseTarget =>
      _drawFromStart ? _draftRoomVertices!.last : _draftRoomVertices!.first;
  
  // Drag state: track if we're currently dragging to draw a wall
  bool _isDragging = false;
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
  Offset? _originalLastSegmentDirection; // Store original direction when user starts typing
  Offset? _originalSecondToLastVertex; // Store original second-to-last vertex position
  
  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();
  
  // Screen-space tolerance for "clicking near start vertex" to close room
  static const double _closeTolerancePx = 20.0;
  
  // Screen-space tolerance for clicking on a vertex (in pixels)
  static const double _vertexSelectTolerancePx = 12.0;
  
  // Snap spacing in mm: 1 = full mm precision; grid drawing uses adaptive spacing
  static const double _snapSpacingMm = 1.0; // 1mm snap so you can work in mm and cm
  static const double _minVertexDistanceMm = 1.0; // minimum 1mm between vertices

  @override
  void initState() {
    super.initState();
    // Initialize history with empty state
    _saveHistoryState();
    // Initialize database and load project if provided
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      debugPrint('PlanCanvas: Initializing database...');
      
      // Check if we're on web
      if (kIsWeb) {
        debugPrint('PlanCanvas: Running on web - database not supported');
        setState(() {
          _isInitializing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database is not supported on web.\n'
                'Please run on iOS, Android, macOS, Windows, or Linux for full functionality.\n'
                'You can still use the app, but projects cannot be saved.',
              ),
              duration: Duration(seconds: 8),
            ),
          );
        }
        // Allow app to continue without database
        setState(() {
          _currentProjectName = widget.initialProjectName;
        });
        return;
      }
      
      _db = AppDatabase();
      _projectService = ProjectService(_db!);
      debugPrint('PlanCanvas: Database and service created');
      
      // Pre-initialize the database connection by doing a simple query
      // This ensures the connection is established before we try to load/save
      try {
        await _db!.customSelect('SELECT 1', readsFrom: {}).get();
        debugPrint('PlanCanvas: Database connection established');
      } catch (e) {
        debugPrint('PlanCanvas: Warning - Could not pre-initialize database connection: $e');
        // Continue anyway - the connection will be established on first real query
      }
      
      setState(() {
        _isInitializing = false;
      });
      debugPrint('PlanCanvas: Initialization flag set to false');
      
      if (widget.projectId != null) {
        await _loadProject(widget.projectId!);
      } else {
        setState(() {
          _currentProjectName = widget.initialProjectName;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('PlanCanvas: Error initializing database: $e');
      debugPrint('PlanCanvas: Stack trace: $stackTrace');
      setState(() {
        _isInitializing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing database: $e\n\nPlease restart the app.'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _loadProject(int projectId) async {
    if (_projectService == null) {
      debugPrint('Cannot load project: _projectService is null');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Loading project $projectId...');
      final project = await _projectService!.getProject(projectId);
      debugPrint('Project loaded: ${project?.name}, rooms: ${project?.rooms.length}');
      
      if (project != null && mounted) {
        setState(() {
          _currentProjectId = project.id;
          _currentProjectName = project.name;
          _useImperial = project.useImperial;
          _completedRooms.clear();
          _completedRooms.addAll(project.rooms);
          
          // Restore viewport if available
          if (project.viewportState != null) {
            final restoredViewport = project.viewportState!.toViewport();
            _vp.mmPerPx = restoredViewport.mmPerPx;
            _vp.worldOriginMm = restoredViewport.worldOriginMm;
          }
          
          _hasUnsavedChanges = false;
          _isLoading = false;
        });
        
        // Notify parent of rooms change
        widget.onRoomsChanged?.call(_completedRooms, _useImperial, _selectedRoomIndex);
        
        // Reset history after loading
        _history.clear();
        _historyIndex = -1;
        _saveHistoryState();
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading project: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading project: $e')),
        );
      }
    }
  }

  Future<void> _saveProject() async {
    debugPrint('PlanCanvas: _saveProject called');
    
    // Check if we're on web
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saving is not supported on web.\n'
              'Please run on iOS, Android, macOS, Windows, or Linux to save projects.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    
    // Wait for initialization if still in progress
    if (_isInitializing) {
      debugPrint('PlanCanvas: Waiting for database initialization...');
      int waitCount = 0;
      const maxWait = 50; // 5 seconds
      while (_isInitializing && waitCount < maxWait) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
    }
    
    if (_projectService == null) {
      debugPrint('PlanCanvas: Cannot save project: _projectService is null after initialization');
      // Try to re-initialize once (only if not on web)
      if (!kIsWeb) {
        debugPrint('PlanCanvas: Attempting to re-initialize database...');
        try {
          _db = AppDatabase();
          _projectService = ProjectService(_db!);
          debugPrint('PlanCanvas: Database re-initialized successfully');
        } catch (e) {
          debugPrint('PlanCanvas: Failed to re-initialize: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Database not initialized. Please restart the app.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database is not supported on web.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }
    
    // If no project name, prompt for it
    String? projectName = _currentProjectName;
    if (projectName == null || projectName.isEmpty) {
      debugPrint('No project name, prompting user...');
      projectName = await _promptProjectName();
      if (projectName == null || projectName.isEmpty) {
        debugPrint('User cancelled project name prompt');
        return; // User cancelled
      }
      debugPrint('User entered project name: $projectName');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Saving project: name=$projectName, id=$_currentProjectId, rooms=${_completedRooms.length}, viewport=${_vp.mmPerPx}');
      final projectId = await _projectService!.saveProject(
        id: _currentProjectId,
        name: projectName,
        rooms: _completedRooms,
        viewport: _vp,
        useImperial: _useImperial,
      );
      debugPrint('Project saved successfully with ID: $projectId');

      setState(() {
        _currentProjectId = projectId;
        _currentProjectName = projectName;
        _hasUnsavedChanges = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "$projectName" saved successfully!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving project: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving project: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String?> _promptProjectName() async {
    final controller = TextEditingController(text: _currentProjectName ?? '');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return confirmed;
  }

  @override
  void dispose() {
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
    final roomsCopy = _completedRooms.map((r) => Room(
      vertices: List<Offset>.from(r.vertices),
      name: r.name,
    )).toList();
    
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
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        final state = _history[_historyIndex];
        
        // Restore completed rooms
        _completedRooms.clear();
        _completedRooms.addAll(state.rooms.map((r) => Room(
          vertices: List<Offset>.from(r.vertices),
          name: r.name,
        )));
        
        // Restore draft room vertices
        _draftRoomVertices = state.draftVertices != null
            ? List<Offset>.from(state.draftVertices!)
            : null;
        
        // Clear selection and hover state
        _selectedRoomIndex = null;
        _hoverPositionWorldMm = null;
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
        _completedRooms.addAll(state.rooms.map((r) => Room(
          vertices: List<Offset>.from(r.vertices),
          name: r.name,
        )));
        
        // Restore draft room vertices
        _draftRoomVertices = state.draftVertices != null
            ? List<Offset>.from(state.draftVertices!)
            : null;
        
        // Clear selection and hover state
        _selectedRoomIndex = null;
        _hoverPositionWorldMm = null;
      });
    }
  }
  
  /// Check if undo is available
  bool get _canUndo => _historyIndex > 0;
  
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
    setState(() {
      _isPanMode = !_isPanMode;
      _isPanning = false;
      _panStartScreen = null;
      _pendingSelectedVertex = null;
      _selectedVertex = null;
      _hoveredVertex = null;
      _isEditingVertex = false;
    });
  }

  /// Handle a single tap on the canvas (vertex select, room select, etc.).
  /// Called from onTapDown (web) and from onScaleEnd when scale gesture was a tap (mobile).
  void _handleCanvasTap(Offset localPosition) {
    // Calibration tap handling (takes priority over drawing/selecting)
    if (_isCalibrating) {
      _handleCalibrationTap(localPosition);
      return;
    }
    // Measure mode: now click-and-drag (handled in scale gesture / pointer events); no tap handling
    // Add dimension mode: tap two points to place permanent dimension
    if (_isAddDimensionMode) {
      final worldPos = _vp.screenToWorld(localPosition);
      setState(() {
        if (_addDimensionP1World == null) {
          _addDimensionP1World = worldPos;
        } else {
          _placedDimensions.add((fromMm: _addDimensionP1World!, toMm: worldPos));
          _addDimensionP1World = null;
        }
      });
      return;
    }
    if (_draftRoomVertices == null) {
      if (_isPanMode) {
        final clickedVertex = _findVertexAtPosition(localPosition);
        if (clickedVertex != null) {
          if (_selectedVertex != null &&
              _selectedVertex!.roomIndex == clickedVertex.roomIndex &&
              _selectedVertex!.vertexIndex == clickedVertex.vertexIndex) {
            _pendingSelectedVertex = null;
            setState(() {
              _selectedVertex = null;
              _isEditingVertex = false;
            });
            return;
          }
          // Set synchronously so next touch (drag) sees it before setState rebuilds
          _pendingSelectedVertex = clickedVertex;
          setState(() {
            _selectedVertex = clickedVertex;
            _selectedRoomIndex = clickedVertex.roomIndex;
            _isEditingVertex = false;
            _isDragging = false;
          });
          return;
        }
        if (_selectedVertex != null) {
          _pendingSelectedVertex = null;
          setState(() {
            _selectedVertex = null;
            _isEditingVertex = false;
          });
        }
      } else {
        if (_selectedVertex != null) {
          setState(() {
            _selectedVertex = null;
            _isEditingVertex = false;
          });
        }
      }

      final worldPos = _vp.screenToWorld(localPosition);
      final clickedRoomIndex = _findRoomAtPosition(worldPos);
      if (clickedRoomIndex != null) {
        final room = _completedRooms[clickedRoomIndex];
        final center = _getRoomCenter(room.vertices);
        final centerScreen = _vp.worldToScreen(center);
        final distance = (localPosition - centerScreen).distance;
        _pendingSelectedVertex = null;
        setState(() {
          _selectedVertex = null;
          _selectedRoomIndex = clickedRoomIndex;
          _isEditingVertex = false;
        });
        if (distance < 40) {
          _editRoomName(clickedRoomIndex);
        }
      } else {
        _pendingSelectedVertex = null;
        setState(() {
          _selectedRoomIndex = null;
          _selectedVertex = null;
          _isEditingVertex = false;
        });
      }
    }
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
        // Exit other interaction modes while calibrating
        _isPanMode = false;
        _isDragging = false;
        _isEditingVertex = false;
        _isMeasureMode = false;
        _measureP1World = null;
        _measureP2World = null;
        _isAddDimensionMode = false;
        _addDimensionP1World = null;
      }
    });
  }

  void _toggleMeasureMode() {
    setState(() {
      if (_isMeasureMode) {
        _isMeasureMode = false;
        _measureP1World = null;
        _measureP2World = null;
      } else {
        _isMeasureMode = true;
        _measureP1World = null;
        _measureP2World = null;
        _isAddDimensionMode = false;
        _addDimensionP1World = null;
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
        _measureP1World = null;
        _measureP2World = null;
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
        // Too small, reset second point
        setState(() => _calibrationP2Screen = null);
        return;
      }

      // Ask user for real-world distance
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
              labelText: _useImperial ? 'Distance (ft / in)' : 'Distance (mm / cm / m)',
              hintText: _useImperial ? 'e.g. 10\' 6"' : 'e.g. 3000mm, 300cm, 3m',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (result == null || result.trim().isEmpty) {
        // Keep calibrating; allow re-enter by tapping again.
        return;
      }

      final mm = _parseLengthInput(result);
      if (mm == null || mm <= 0) {
        // Invalid; keep points so user can try again
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
      return;
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
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to add margin
    
    setState(() {
      _vp.mmPerPx = (1.0 / scale).clamp(PlanViewport.minMmPerPx, PlanViewport.maxMmPerPx);
      _vp.worldOriginMm = center - Offset(screenSize.width / 2, screenSize.height / 2) * _vp.mmPerPx;
      _hasUnsavedChanges = true;
    });
  }

  /// Select a room and center the view on it.
  /// This is called from external code (e.g., room summary panel).
  void selectRoom(int roomIndex) {
    if (roomIndex < 0 || roomIndex >= _completedRooms.length) return;
    
    final room = _completedRooms[roomIndex];
    
    // Calculate room center
    double centerX = 0;
    double centerY = 0;
    for (final vertex in room.vertices) {
      centerX += vertex.dx;
      centerY += vertex.dy;
    }
    centerX /= room.vertices.length;
    centerY /= room.vertices.length;
    
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;
    
    setState(() {
      _selectedRoomIndex = roomIndex;
      // Center view on room
      _vp.worldOriginMm = Offset(centerX, centerY) - 
          Offset(screenSize.width / 2, screenSize.height / 2) * _vp.mmPerPx;
    });
    
    // Notify parent
    widget.onRoomsChanged?.call(_completedRooms, _useImperial, _selectedRoomIndex);
  }
  
  /// Delete a room by index (called from external code).
  void deleteRoom(int roomIndex) {
    _showDeleteRoomDialog(roomIndex);
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
              if (_selectedRoomIndex != null && _draftRoomVertices == null) {
                setState(() {
                  if (_selectedRoomIndex! >= 0 && 
                      _selectedRoomIndex! < _completedRooms.length) {
                    _completedRooms.removeAt(_selectedRoomIndex!);
                    _selectedRoomIndex = null;
                    _hasUnsavedChanges = true;
                    // Save state to history after room deletion
                    _saveHistoryState();
                  }
                });
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
                _saveProject();
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
                  _measureP1World = world;
                  _measureP2World = world;
                });
              }
            },
            onPointerUp: (e) {
              if (kIsWeb && _isMeasureMode) {
                setState(() {
                  _measureP1World = null;
                  _measureP2World = null;
                });
              }
            },

            // PAN (web): Shift + left-drag OR right-click drag
            // Also track hover position for preview line (when not actively dragging to draw)
      onPointerMove: (e) {
          if (kIsWeb && _isMeasureMode && _measureP1World != null && e.buttons == 1) {
            setState(() {
              _measureP2World = _vp.screenToWorld(e.localPosition);
            });
          }
          // Update hover position for preview line (only when not dragging to draw walls)
          // Pan gestures are handled separately
          if (e.buttons == 0 && _draftRoomVertices != null && !_isDragging && !_isEditingVertex) {
            setState(() {
              final worldPosition = _vp.screenToWorld(e.localPosition);
              _hoverPositionWorldMm = _snapToGridAndAngle(worldPosition);
            });
          }
          
          // Update hovered vertex for visual feedback (only in pan mode, when not drawing or editing)
          if (e.buttons == 0 && _draftRoomVertices == null && !_isEditingVertex && _isPanMode) {
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
            if (HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftLeft)) {
          setState(() {
            _vp.panByScreenDelta(e.delta);
                // Update hover position during pan
                if (_draftRoomVertices != null) {
                  _hoverPositionWorldMm = _vp.screenToWorld(e.localPosition);
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
                  if (_isMeasureMode) {
                    setState(() {
                      _measureP1World = _vp.screenToWorld(details.localFocalPoint);
                      _measureP2World = _vp.screenToWorld(details.localFocalPoint);
                    });
                    return;
                  }
                  if (_isPanMode) {
                    // Pan mode: if a vertex is selected (state or pending from tap), treat this drag as vertex edit
                    final hasSelectedVertex = (_selectedVertex != null || _pendingSelectedVertex != null) && _draftRoomVertices == null;
                    if (hasSelectedVertex) {
                      _scaleGestureIsVertexEdit = true;
                      final v = _selectedVertex ?? _pendingSelectedVertex;
                      if (_debugVertexEdit) debugPrint('PlanCanvas: scaleStart → vertex edit (vertex=${v!.roomIndex},${v.vertexIndex})');
                      _handlePanStart(details.localFocalPoint);
                    } else {
                      _scaleGestureIsVertexEdit = false;
                      if (_debugVertexEdit) debugPrint('PlanCanvas: scaleStart → potential pan (no selected vertex)');
                      setState(() {
                        _panStartScreen = details.localFocalPoint;
                      });
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
                // Check pointer count: 1 = drawing/panning/measure, 2+ = pan/zoom
                if (details.pointerCount == 1) {
                  if (_isMeasureMode && _measureP1World != null) {
                    setState(() {
                      _measureP2World = _vp.screenToWorld(details.localFocalPoint);
                    });
                    return;
                  }
                  // Vertex editing (pan mode): drag to move selected vertex (use sync flag so we see it before setState runs)
                  if (_scaleGestureIsVertexEdit || _isEditingVertex) {
                    _lastScalePosition = details.localFocalPoint;
                    if (_debugVertexEdit && _scaleGestureIsVertexEdit && !_isEditingVertex) debugPrint('PlanCanvas: scaleUpdate → vertex move (sync flag)');
                    _handlePanUpdate(details.localFocalPoint);
                  } else if (_isPanning) {
                    // Pan mode: pan the viewport
                    setState(() {
                      _vp.panByScreenDelta(details.focalPointDelta);
                      _lastScalePosition = details.localFocalPoint;
                    });
                  } else if (_isPanMode && _panStartScreen != null && !_isPanning) {
                    // Pan mode: only start panning after finger moves past slop (so tap can select vertex)
                    final distance = (details.localFocalPoint - _panStartScreen!).distance;
                    if (distance > _panSlopPx) {
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
                if (_isMeasureMode) {
                  setState(() {
                    _measureP1World = null;
                    _measureP2World = null;
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
                } else if ((_scaleGestureIsVertexEdit || _isEditingVertex) && _lastScalePosition != null) {
                  // Vertex edit drag finished
                  _scaleGestureIsVertexEdit = false;
                  _pendingSelectedVertex = null;
                  _handlePanEnd(_lastScalePosition!);
                  _lastScalePosition = null;
                } else if (_panStartScreen != null) {
                  // Single-finger touch in pan mode that didn't move past slop = treat as tap (e.g. vertex select)
                  _scaleGestureIsVertexEdit = false;
                  final tapPosition = _panStartScreen!;
                  setState(() => _panStartScreen = null);
                  _handleCanvasTap(tapPosition);
                }
                // If we were drawing (single finger gesture), finish drawing
                if (_isDragging && _lastScalePosition != null) {
                  _handlePanEnd(_lastScalePosition!);
                  _lastScalePosition = null;
                }
              },
        
        // Double-tap: close room if drafting
        onDoubleTapDown: (d) {
          if (_draftRoomVertices != null && _draftRoomVertices!.length >= 3) {
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
          key: ValueKey('plan_painter_${_completedRooms.length}_${_draftRoomVertices?.length ?? 0}'),
          builder: (context, constraints) {
            final w = constraints.maxWidth.isFinite && constraints.maxWidth < double.infinity
                ? constraints.maxWidth : 0.0;
            final h = constraints.maxHeight.isFinite && constraints.maxHeight < double.infinity
                ? constraints.maxHeight : 0.0;
            final hasSize = w > 0 && h > 0;
            return SizedBox(
              width: hasSize ? w : double.infinity,
              height: hasSize ? h : double.infinity,
              child: CustomPaint(
                size: Size(w, h),
                painter: _PlanPainter(
                  vp: _vp,
                  completedRooms: _safeCopyRooms(_completedRooms),
                  draftRoomVertices: _draftRoomVertices != null
                      ? List<Offset>.from(_draftRoomVertices!)
                      : null,
                  hoverPositionWorldMm: _hoverPositionWorldMm,
                  previewLineAngleDeg: _angleBetweenLinesDeg ?? _currentSegmentAngleDeg,
                  useImperial: _useImperial,
                  isDragging: _isDragging,
                  selectedRoomIndex: _selectedRoomIndex,
                  selectedVertex: _selectedVertex,
                  hoveredVertex: _hoveredVertex,
                  showGrid: _showGrid,
                  calibrationP1Screen: _calibrationP1Screen,
                  calibrationP2Screen: _calibrationP2Screen,
                  isMeasureMode: _isMeasureMode,
                  measureP1World: _measureP1World,
                  measureP2World: _measureP2World,
                  isAddDimensionMode: _isAddDimensionMode,
                  addDimensionP1World: _addDimensionP1World,
                  placedDimensions: List.from(_placedDimensions),
                  drawFromStart: _drawFromStart,
                ),
              ),
            );
          },
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
            hasSelectedRoom: _selectedRoomIndex != null,
            onDeleteRoom: _selectedRoomIndex != null && _draftRoomVertices == null
                ? () => _showDeleteRoomDialog(_selectedRoomIndex!)
                : null,
            hasProject: _currentProjectId != null,
            hasUnsavedChanges: _hasUnsavedChanges,
            onSave: _saveProject,
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
            isDrawing: _draftRoomVertices != null && _draftRoomVertices!.isNotEmpty,
            showNumberPad: _showNumberPad,
            onToggleNumberPad: () => setState(() => _showNumberPad = !_showNumberPad),
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
            hasPlacedDimensions: _placedDimensions.isNotEmpty,
            onRemoveLastDimension: _removeLastDimension,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onFitToScreen: _fitToScreen,
            onUndo: _undo,
            onRedo: _redo,
          ),
        ),
      ),
      // Bottom-right: collapsible Dimensions menu (calibrate, measure, add dimension, remove last)
      Positioned(
        bottom: 8,
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
            hasSelectedRoom: _selectedRoomIndex != null,
            onDeleteRoom: _selectedRoomIndex != null && _draftRoomVertices == null
                ? () => _showDeleteRoomDialog(_selectedRoomIndex!)
                : null,
            hasProject: _currentProjectId != null,
            hasUnsavedChanges: _hasUnsavedChanges,
            onSave: _saveProject,
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
            hasPlacedDimensions: _placedDimensions.isNotEmpty,
            onRemoveLastDimension: _removeLastDimension,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onFitToScreen: _fitToScreen,
            onUndo: _undo,
            onRedo: _redo,
          ),
        ),
      ),
      // Length input number pad (visible when drawing and not hidden by user); draggable by its top bar
      ...(_draftRoomVertices != null && _draftRoomVertices!.isNotEmpty && _showNumberPad
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
                  child: _DraggableNumberPadWrapper(
                    key: _numberPadWrapperKey,
                    onDragStart: () {
                      final box = _numberPadWrapperKey.currentContext?.findRenderObject() as RenderBox?;
                      final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
                      if (box == null || stackBox == null) return;
                      final topLeftGlobal = box.localToGlobal(Offset.zero);
                      final topLeftLocal = stackBox.globalToLocal(topLeftGlobal);
                      setState(() => _numberPadPosition = topLeftLocal);
                    },
                    onDragUpdate: (Offset delta) {
                      if (_numberPadPosition == null) return;
                      final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
                      if (stackBox == null) return;
                      final w = stackBox.size.width;
                      final h = stackBox.size.height;
                      setState(() {
                        _numberPadPosition = Offset(
                          (_numberPadPosition!.dx + delta.dx).clamp(0.0, w - _numberPadApproxWidth),
                          (_numberPadPosition!.dy + delta.dy).clamp(0.0, h - _numberPadApproxHeight),
                        );
                      });
                    },
                    child: _LengthInputPad(
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

  /// Snap a world-space position to the nearest grid point.
  /// 
  /// This ensures vertices align to the grid for precise floor plan drawing.
  /// Grid spacing is 100mm (10cm).
  Offset _snapToGrid(Offset worldPositionMm) {
    final snappedX = (worldPositionMm.dx / _snapSpacingMm).round() * _snapSpacingMm;
    final snappedY = (worldPositionMm.dy / _snapSpacingMm).round() * _snapSpacingMm;
    return Offset(snappedX, snappedY);
  }

  /// Snap a point from [fromMm] toward [toMm] so the angle snaps to 90° or 45° (or return grid-snapped [toMm] if lock is none).
  /// Keeps the same distance from [fromMm] as [toMm], then snaps to grid.
  Offset _snapAngleToConstraint(Offset fromMm, Offset toMm, DrawAngleLock lock) {
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

  /// Grid-snap then optionally angle-snap from last draft vertex. Use when updating hover or adding a vertex.
  Offset _snapToGridAndAngle(Offset worldPositionMm) {
    final snapped = _snapToGrid(worldPositionMm);
    if (_drawAngleLock == DrawAngleLock.none) return snapped;
    if (_draftRoomVertices == null || _draftRoomVertices!.isEmpty) return snapped;
    return _snapAngleToConstraint(_draftDrawingFrom, snapped, _drawAngleLock);
  }

  /// Current segment angle in degrees (drawing-from vertex to hover). Returns null if not drawing or no hover.
  double? get _currentSegmentAngleDeg {
    if (_draftRoomVertices == null || _draftRoomVertices!.isEmpty || _hoverPositionWorldMm == null) return null;
    final from = _draftDrawingFrom;
    final to = _hoverPositionWorldMm!;
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return null;
    double deg = math.atan2(dy, dx) * (180.0 / math.pi);
    if (deg < 0) deg += 360.0;
    return deg;
  }

  /// Angle of the second line (preview) relative to the first line (last drawn segment), in degrees [0, 180].
  /// 0° = same direction; 90° = turn 90° either way; 180° = straight back.
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
    while (diffRad < 0) diffRad += 2 * math.pi;
    while (diffRad >= 2 * math.pi) diffRad -= 2 * math.pi;
    double deg = diffRad * (180.0 / math.pi);
    // Show 0–180° either way (turn left or right gives same magnitude)
    if (deg > 180.0) deg = 360.0 - deg;
    // If the user is continuing straight (very small turn), don't draw angle annotation.
    // This avoids showing an "angle arc" when the segment is essentially straight.
    if (deg < 2.0) return null;
    // Display complementary angle (e.g. 9° → 171°)
    return 180.0 - deg;
  }

  /// Calculate the center point (centroid) of a polygon.
  Offset _getRoomCenter(List<Offset> vertices) {
    if (vertices.isEmpty) return Offset.zero;
    
    // Use unique vertices (skip the closing vertex if it's a duplicate of first)
    final uniqueVertices = vertices.length > 1 && 
                           vertices.first == vertices.last
        ? vertices.sublist(0, vertices.length - 1)
        : vertices;
    
    double centerX = 0;
    double centerY = 0;
    for (final vertex in uniqueVertices) {
      centerX += vertex.dx;
      centerY += vertex.dy;
    }
    
    if (uniqueVertices.isEmpty) return Offset.zero;
    return Offset(centerX / uniqueVertices.length, centerY / uniqueVertices.length);
  }

  /// Find the closest vertex to a screen position, if within tolerance.
  /// Returns (roomIndex, vertexIndex) or null if no vertex is close enough.
  ({int roomIndex, int vertexIndex})? _findVertexAtPosition(Offset screenPosition) {
    double closestDistance = _vertexSelectTolerancePx;
    ({int roomIndex, int vertexIndex})? closestVertex;
    
    for (int roomIdx = 0; roomIdx < _completedRooms.length; roomIdx++) {
      final room = _completedRooms[roomIdx];
      // Use unique vertices (skip closing vertex if duplicate)
      final uniqueVertices = room.vertices.length > 1 && 
                            room.vertices.first == room.vertices.last
          ? room.vertices.sublist(0, room.vertices.length - 1)
          : room.vertices;
      
      for (int vertexIdx = 0; vertexIdx < uniqueVertices.length; vertexIdx++) {
        final vertexScreen = _vp.worldToScreen(uniqueVertices[vertexIdx]);
        final distance = (screenPosition - vertexScreen).distance;
        
        if (distance < closestDistance) {
          closestDistance = distance;
          closestVertex = (roomIndex: roomIdx, vertexIndex: vertexIdx);
        }
      }
    }
    
    return closestVertex;
  }

  /// Safely copy rooms list, handling hot reload issues.
  List<Room> _safeCopyRooms(List<Room>? rooms) {
    // Handle null/undefined case (web hot reload issue)
    if (rooms == null) {
      debugPrint('Warning: rooms list is null, returning empty');
      return [];
    }
    
    try {
      // Try to check if it's iterable by checking length
      // This will throw if rooms is undefined or not a list
      final length = rooms.length;
      
      // Try to create a new list - this will fail if rooms is not iterable
      return List<Room>.from(rooms);
    } catch (e) {
      // If we can't iterate, return empty list (hot reload issue)
      debugPrint('Warning: Could not copy rooms list, returning empty: $e');
      return [];
    }
  }

  /// Handle pan start: begin drawing a wall segment or start editing a vertex.
  void _handlePanStart(Offset screenPosition) {
    // Don't start drawing if Shift is held (Shift+drag is for panning)
    if (HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftRight)) {
      return;
    }
    
    // Only allow vertex editing when in pan mode
    if (_isPanMode) {
      // Use state or pending (tap may have set pending before rebuild)
      final vertexToEdit = _selectedVertex ?? _pendingSelectedVertex;
      if (vertexToEdit != null && _draftRoomVertices == null) {
        setState(() {
          _selectedVertex = vertexToEdit;
          _selectedRoomIndex = vertexToEdit.roomIndex;
          _isEditingVertex = true;
          _isDragging = false;
        });
        return;
      }
      // Otherwise, check if clicking on a vertex to edit
      final clickedVertex = _findVertexAtPosition(screenPosition);
      if (clickedVertex != null && _draftRoomVertices == null) {
        setState(() {
          _selectedVertex = clickedVertex;
          _selectedRoomIndex = clickedVertex.roomIndex;
          _isEditingVertex = true;
          _isDragging = false;
        });
        return;
      }
    }
    
    // In draw mode, or if no vertex clicked: proceed with drawing
    // This allows drawing over existing room lines when in draw mode
    
    // Otherwise, proceed with normal room drawing
    final worldPosition = _vp.screenToWorld(screenPosition);
    final snappedPosition = _snapToGrid(worldPosition);
    
    _pendingSelectedVertex = null;
    setState(() {
      _selectedVertex = null;
      _isEditingVertex = false;
      
      if (_draftRoomVertices == null) {
        // Start a new room with first vertex (snapped to grid)
        _draftRoomVertices = [snappedPosition];
        _dragStartPositionWorldMm = snappedPosition;
        _isDragging = true;
        _hoverPositionWorldMm = snappedPosition;
        // Clear length input when starting new room
        _lengthInputController.clear();
        _desiredLengthMm = null;
        // Save state to history when starting a new draft room
        _saveHistoryState();
      } else {
        // Check if starting drag near the "other" endpoint (close room)
        if (_draftRoomVertices!.isNotEmpty) {
          final closeTargetScreen = _vp.worldToScreen(_draftCloseTarget);
          final distance = (screenPosition - closeTargetScreen).distance;
          
          // Close room if starting drag near close target AND we have at least 3 vertices
          if (distance < _closeTolerancePx && _draftRoomVertices!.length >= 3) {
            _closeDraftRoom(); // Fire and forget - async call
            return;
          }
        }
        
        // Start a new wall segment from the current drawing endpoint
        _dragStartPositionWorldMm = _draftRoomVertices!.isNotEmpty
            ? _draftDrawingFrom
            : worldPosition;
        _isDragging = true;
        _hoverPositionWorldMm = worldPosition;
      }
    });
  }

  /// Handle pan update: update preview line as user drags, or move vertex if editing.
  void _handlePanUpdate(Offset screenPosition) {
    // Don't update drawing if Shift is held (Shift+drag is for panning)
    if (HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftRight)) {
      return;
    }
    
    // If editing a vertex, move it (use state or pending so first drag frame works before setState)
    final vertexToEdit = _selectedVertex ?? _pendingSelectedVertex;
    if ((_isEditingVertex || _scaleGestureIsVertexEdit) && vertexToEdit != null) {
      final worldPosition = _vp.screenToWorld(screenPosition);
      final snappedPosition = _snapToGrid(worldPosition);
      
      setState(() {
        final roomIdx = vertexToEdit.roomIndex;
        final vertexIdx = vertexToEdit.vertexIndex;
        
        if (roomIdx >= 0 && roomIdx < _completedRooms.length) {
          final room = _completedRooms[roomIdx];
          final vertices = List<Offset>.from(room.vertices);
          
          // Handle closed polygon: if last vertex is duplicate of first, update both
          final isClosed = vertices.length > 1 && vertices.first == vertices.last;
          final uniqueVertexCount = isClosed ? vertices.length - 1 : vertices.length;
          
          if (vertexIdx >= 0 && vertexIdx < uniqueVertexCount) {
            vertices[vertexIdx] = snappedPosition;
            
            // If closed polygon, also update the closing vertex
            if (isClosed && vertexIdx == 0) {
              vertices[vertices.length - 1] = snappedPosition;
            } else if (isClosed && vertexIdx == uniqueVertexCount - 1) {
              vertices[vertices.length - 1] = snappedPosition;
            }
            
            // Create new room with updated vertices (Room is immutable)
            _completedRooms[roomIdx] = Room(
              vertices: vertices,
              name: room.name,
            );
            _hasUnsavedChanges = true;
          }
        }
      });
      return;
    }
    
    // Otherwise, handle normal drawing preview
    if (!_isDragging) return;
    
    final worldPosition = _vp.screenToWorld(screenPosition);
    final snappedPosition = _snapToGridAndAngle(worldPosition);
    
    setState(() {
      // Update hover position to show preview line (snapped to grid and optionally angle)
      // Don't apply length constraint during drawing - user draws freely first
      _hoverPositionWorldMm = snappedPosition;
      
      // Update hovered vertex for visual feedback (only in pan mode)
      if (_isPanMode) {
        final hoveredVertex = _findVertexAtPosition(screenPosition);
        _hoveredVertex = hoveredVertex;
      } else {
        _hoveredVertex = null;
      }
    });
  }

  /// Handle pan end: place the wall segment (add vertex) or finish editing vertex.
  void _handlePanEnd(Offset screenPosition) {
    // Don't finish drawing if Shift was held (Shift+drag is for panning)
    if (HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftRight)) {
      // Reset dragging state if we were drawing
      if (_isDragging) {
        setState(() {
          _isDragging = false;
        });
      }
      return;
    }
    
    // Finish editing vertex
    if (_isEditingVertex) {
      setState(() {
        _isEditingVertex = false;
        // Keep vertex selected for potential further edits
        // Save state to history after vertex edit completes
        _saveHistoryState();
      });
      return;
    }
    
    // Handle normal drawing
    if (!_isDragging) return;
    
    final worldPosition = _vp.screenToWorld(screenPosition);
    final snappedPosition = _snapToGridAndAngle(worldPosition);
    
    setState(() {
      _isDragging = false;
      
      if (_draftRoomVertices == null || _dragStartPositionWorldMm == null) {
        return;
      }
      
      // Check if ending near the "other" endpoint (close room)
      if (_draftRoomVertices!.isNotEmpty && _draftRoomVertices!.length >= 3) {
        final closeTargetScreen = _vp.worldToScreen(_draftCloseTarget);
        final distance = (screenPosition - closeTargetScreen).distance;
        if (distance < _closeTolerancePx) {
          _closeDraftRoom();
          _dragStartPositionWorldMm = null;
          return;
        }
      }
      
      // Add new vertex at current drawing end; prevent duplicate vertices
      final minDistanceMm = _minVertexDistanceMm;
      if (_draftRoomVertices!.isEmpty ||
          (snappedPosition - _draftDrawingFrom).distance > minDistanceMm) {
        if (_drawFromStart) {
          _draftRoomVertices = [snappedPosition, ..._draftRoomVertices!];
        } else {
          _draftRoomVertices = [..._draftRoomVertices!, snappedPosition];
        }
        _hoverPositionWorldMm = snappedPosition;
        // Save state to history after adding a vertex to draft room
        _saveHistoryState();
        
        // Clear length input when placing new vertex (user can now adjust this segment)
        _lengthInputController.clear();
        _desiredLengthMm = null;
        _originalLastSegmentDirection = null;
        _originalSecondToLastVertex = null;
      }
      
      _dragStartPositionWorldMm = null;
    });
  }

  /// Close the current draft room and add it to completed rooms.
  void _closeDraftRoom() {
    if (_draftRoomVertices == null || _draftRoomVertices!.length < 3) {
      return; // Can't close with less than 3 vertices
    }
    
    setState(() {
      // Create room - append first vertex to close the polygon
      // This preserves all vertices (e.g., 4 vertices for a square stays 4 + closing vertex)
      final vertices = List<Offset>.from(_draftRoomVertices!);
      if (vertices.length >= 3) {
        // Add first vertex at the end to close the polygon
        // Don't replace the last vertex - that would lose it!
        // Example: [A, B, C, D] becomes [A, B, C, D, A] (not [A, B, C, A])
        vertices.add(vertices.first);
        
        // Create room without a name - user can name it later by clicking the button
        _completedRooms.add(Room(vertices: vertices, name: null));
        _hasUnsavedChanges = true;
      }
      
      // Clear draft
      _draftRoomVertices = null;
      _drawFromStart = false;
      _hoverPositionWorldMm = null;
      _lengthInputController.clear();
      _desiredLengthMm = null;
      _originalLastSegmentDirection = null;
      _originalSecondToLastVertex = null;
      
      // Save state to history after room creation
      _saveHistoryState();
      
      // Notify parent of rooms change
      widget.onRoomsChanged?.call(_completedRooms, _useImperial, _selectedRoomIndex);
    });
  }
  
  /// Handle length input change from number pad.
  /// Adjusts the last drawn segment to match the entered length in real-time.
  void _onLengthInputChanged(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _desiredLengthMm = null;
        _originalLastSegmentDirection = null;
        _originalSecondToLastVertex = null;
        return;
      }
      
      // Try to parse the input - handle partial input (e.g., "3", "30", "300")
      // For partial input, try parsing as a simple number first
      double? parsed;
      
      // Try parsing as a simple number (for partial input like "3", "30", "3000")
      final simpleNumber = double.tryParse(value.trim());
      if (simpleNumber != null && simpleNumber > 0) {
        // If using imperial, assume feet; if metric, assume mm
        if (_useImperial) {
          const mmPerFoot = 304.8;
          parsed = simpleNumber * mmPerFoot;
        } else {
          parsed = simpleNumber; // Assume mm
        }
      } else {
        // Try full parsing (handles units like "3000mm", "10.5", etc.)
        parsed = _parseLengthInput(value);
      }
      
      if (parsed != null && parsed > 0) {
        _desiredLengthMm = parsed;
        
        // Adjust the last segment to match the entered length in real-time
        if (_draftRoomVertices != null && _draftRoomVertices!.length >= 2) {
          final secondToLast = _draftDrawingFromPrev!;
          final lastVertex = _draftDrawingFrom;
          // Store original direction and second-to-last vertex on first input
          if (_originalLastSegmentDirection == null || _originalSecondToLastVertex == null) {
            final direction = lastVertex - secondToLast;
            final directionLength = direction.distance;
            if (directionLength > 0) {
              _originalSecondToLastVertex = secondToLast;
              _originalLastSegmentDirection = Offset(
                direction.dx / directionLength,
                direction.dy / directionLength,
              );
            } else {
              return;
            }
          }
          if (_originalLastSegmentDirection != null && _originalSecondToLastVertex != null) {
            final newLastVertex = _originalSecondToLastVertex! + Offset(
              _originalLastSegmentDirection!.dx * _desiredLengthMm!,
              _originalLastSegmentDirection!.dy * _desiredLengthMm!,
            );
            final updatedVertices = List<Offset>.from(_draftRoomVertices!);
            if (_drawFromStart) {
              updatedVertices[0] = _snapToGrid(newLastVertex);
            } else {
              updatedVertices[updatedVertices.length - 1] = _snapToGrid(newLastVertex);
            }
            _draftRoomVertices = updatedVertices;
            _hoverPositionWorldMm = _drawFromStart ? updatedVertices.first : updatedVertices.last;
            
            // Mark as unsaved (but don't save to history on every keystroke - too many states)
            _hasUnsavedChanges = true;
          }
        }
      } else {
        // Invalid input - clear desired length but keep current vertex position
        _desiredLengthMm = null;
        _originalLastSegmentDirection = null;
        _originalSecondToLastVertex = null;
      }
    });
  }
  
  /// Parse length input string to millimeters.
  /// Supports formats like "3000", "3000mm", "300cm", "10.5", "10' 6\"", etc.
  double? _parseLengthInput(String input) {
    if (input.trim().isEmpty) return null;
    
    final trimmed = input.trim().toLowerCase();
    
    if (_useImperial) {
      // Imperial: Parse feet and inches
      // Simplified parsing - just parse numbers
      const mmPerFoot = 304.8;
      const mmPerInch = 25.4;
      
      // Try to match feet and inches: look for two numbers separated by space or quote
      // Pattern: number, optional quote/ft, optional second number, optional quote
      final pattern = '^(\\d+(?:\\.\\d+)?)\\s*(?:[\'"]|ft)?\\s*(?:(\\d+(?:\\.\\d+)?)\\s*(?:[\'"]|inch)?)?\$';
      final regex = RegExp(pattern);
      final match = regex.firstMatch(trimmed);
      
      if (match != null) {
        final feetStr = match.group(1);
        final inchesStr = match.group(2);
        
        if (feetStr != null) {
          final feet = double.tryParse(feetStr) ?? 0;
          final inches = inchesStr != null ? (double.tryParse(inchesStr) ?? 0) : 0;
          return (feet * mmPerFoot) + (inches * mmPerInch);
        }
      }
      
      // Try simple decimal (assume feet)
      final feet = double.tryParse(trimmed);
      if (feet != null) {
        return feet * mmPerFoot;
      }
    } else {
      // Metric: Parse mm or cm
      const mmPerCm = 10.0;
      if (trimmed.endsWith('cm')) {
        final cm = double.tryParse(trimmed.substring(0, trimmed.length - 2).trim());
        if (cm != null) return cm * mmPerCm;
      } else if (trimmed.endsWith('m')) {
        final m = double.tryParse(trimmed.substring(0, trimmed.length - 1).trim());
        if (m != null) return m * 1000; // meters to mm
      } else if (trimmed.endsWith('mm')) {
        final mm = double.tryParse(trimmed.substring(0, trimmed.length - 2).trim());
        if (mm != null) return mm;
      } else {
        // Assume mm if no unit
        final mm = double.tryParse(trimmed);
        if (mm != null) return mm;
      }
    }
    
    return null;
  }

  /// Show a dialog to get the room name from the user.
  Future<String?> _showRoomNameDialog({String? initialName}) async {
    final context = this.context;
    if (!context.mounted) return null;
    
    final controller = TextEditingController(text: initialName ?? '');
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Name Room' : 'Edit Room Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: initialName == null ? 'Enter room name' : 'Enter room name',
            border: const OutlineInputBorder(),
            helperText: 'Leave empty to remove name',
          ),
          onSubmitted: (value) {
            Navigator.of(context).pop(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''), // Empty string to remove name
            child: const Text('Remove Name'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Find which room (if any) contains the given world position.
  /// Returns the index of the room, or null if no room contains the point.
  int? _findRoomAtPosition(Offset worldPosMm) {
    for (int i = 0; i < _completedRooms.length; i++) {
      final room = _completedRooms[i];
      if (_pointInPolygon(worldPosMm, room.vertices)) {
        return i;
      }
    }
    return null;
  }
  
  /// Check if a point is inside a polygon using ray casting algorithm.
  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx;
      final yi = polygon[i].dy;
      final xj = polygon[j].dx;
      final yj = polygon[j].dy;
      
      final intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Show a confirmation dialog to delete a room.
  Future<void> _showDeleteRoomDialog(int roomIndex) async {
    if (roomIndex < 0 || roomIndex >= _completedRooms.length) return;
    
    final room = _completedRooms[roomIndex];
    final roomName = room.name ?? 'Room ${roomIndex + 1}';
    
    final context = this.context;
    if (!context.mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "$roomName"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (!mounted) return;
    
    if (confirmed == true) {
      setState(() {
        _completedRooms.removeAt(roomIndex);
        if (_selectedRoomIndex == roomIndex) {
          _selectedRoomIndex = null;
        } else if (_selectedRoomIndex != null && _selectedRoomIndex! > roomIndex) {
          // Adjust selection index if room before it was deleted
          _selectedRoomIndex = _selectedRoomIndex! - 1;
        }
        _hasUnsavedChanges = true;
        // Save state to history after room deletion
        _saveHistoryState();
        
        // Notify parent of rooms change
        widget.onRoomsChanged?.call(_completedRooms, _useImperial, _selectedRoomIndex);
      });
    }
  }

  /// Edit the name of an existing room.
  Future<void> _editRoomName(int roomIndex) async {
    if (roomIndex < 0 || roomIndex >= _completedRooms.length) return;
    
    final room = _completedRooms[roomIndex];
    final newName = await _showRoomNameDialog(initialName: room.name);
    
    if (!mounted) return;
    
    setState(() {
      // Create new room with updated name (rooms are immutable)
      // Allow empty name to remove the name (show button again)
      final updatedRoom = Room(
        vertices: room.vertices,
        name: newName?.trim().isNotEmpty == true ? newName!.trim() : null,
      );
      _completedRooms[roomIndex] = updatedRoom;
      _hasUnsavedChanges = true;
      // Save state to history after room name change
      _saveHistoryState();
    });
  }
}

/// Wraps the number pad with a draggable title bar (tap-hold and drag the top to move).
class _DraggableNumberPadWrapper extends StatelessWidget {
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final Widget child;

  const _DraggableNumberPadWrapper({
    super.key,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onDragStart(),
          onPanUpdate: (d) => onDragUpdate(d.delta),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Floating number pad widget for entering wall length.
class _LengthInputPad extends StatefulWidget {
  final TextEditingController controller;
  final bool useImperial;
  final ValueChanged<String> onChanged;

  const _LengthInputPad({
    required this.controller,
    required this.useImperial,
    required this.onChanged,
  });

  @override
  State<_LengthInputPad> createState() => _LengthInputPadState();
}

class _LengthInputPadState extends State<_LengthInputPad> {
  bool get _isTouchDevice => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  Widget build(BuildContext context) {
    if (_isTouchDevice) {
      // Mobile: Show compact number pad with buttons
      return Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Length',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            // Display area showing current value (updates live)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                widget.controller.text.isEmpty 
                    ? (widget.useImperial ? '0 ft' : '0 mm')
                    : widget.controller.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            // Compact number pad
            _buildNumberPad(),
          ],
        ),
      );
    } else {
      // Web: Simple text field
      return Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wall Length',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: widget.useImperial ? 'ft/in' : 'mm/cm',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: widget.onChanged,
            ),
            const SizedBox(height: 4),
            Text(
              widget.useImperial ? 'Enter feet (e.g., 10.5)' : 'Enter mm (e.g., 3000)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('1'),
            const SizedBox(width: 4),
            _buildNumberButton('2'),
            const SizedBox(width: 4),
            _buildNumberButton('3'),
          ],
        ),
        const SizedBox(height: 4),
        // Row 2: 4, 5, 6
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('4'),
            const SizedBox(width: 4),
            _buildNumberButton('5'),
            const SizedBox(width: 4),
            _buildNumberButton('6'),
          ],
        ),
        const SizedBox(height: 4),
        // Row 3: 7, 8, 9
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('7'),
            const SizedBox(width: 4),
            _buildNumberButton('8'),
            const SizedBox(width: 4),
            _buildNumberButton('9'),
          ],
        ),
        const SizedBox(height: 4),
        // Row 4: ., 0, ⌫
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('.'),
            const SizedBox(width: 4),
            _buildNumberButton('0'),
            const SizedBox(width: 4),
            _buildActionButton(Icons.backspace_outlined, () {
              if (widget.controller.text.isNotEmpty) {
                widget.controller.text = widget.controller.text.substring(0, widget.controller.text.length - 1);
                widget.onChanged(widget.controller.text);
                setState(() {}); // Update display
              }
            }),
          ],
        ),
        const SizedBox(height: 4),
        // Clear button
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(Icons.clear, () {
            widget.controller.clear();
            widget.onChanged('');
            setState(() {}); // Update display
          }, label: 'Clear'),
        ),
      ],
    );
  }

  Widget _buildNumberButton(String digit) {
    return Material(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () {
          widget.controller.text += digit;
          widget.onChanged(widget.controller.text);
          setState(() {}); // Update display
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 32,
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, {String? label}) {
    return Material(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: label != null ? double.infinity : 36,
          height: 32,
          alignment: Alignment.center,
          padding: label != null ? const EdgeInsets.symmetric(horizontal: 8) : null,
          child: label != null
              ? Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  final PlanViewport vp;
  final List<Room> completedRooms;
  final List<Offset>? draftRoomVertices;
  final Offset? hoverPositionWorldMm;
  /// When non-null (angle unlocked), draw this angle on the preview line.
  final double? previewLineAngleDeg;
  final bool useImperial;
  final bool isDragging;
  final int? selectedRoomIndex;
  final ({int roomIndex, int vertexIndex})? selectedVertex;
  final ({int roomIndex, int vertexIndex})? hoveredVertex;
  final bool showGrid;
  final Offset? calibrationP1Screen;
  final Offset? calibrationP2Screen;
  final bool isMeasureMode;
  final Offset? measureP1World;
  final Offset? measureP2World;
  final bool isAddDimensionMode;
  final Offset? addDimensionP1World;
  final List<({Offset fromMm, Offset toMm})> placedDimensions;
  final bool drawFromStart;

  _PlanPainter({
    required this.vp,
    List<Room>? completedRooms,
    required this.draftRoomVertices,
    required this.hoverPositionWorldMm,
    this.previewLineAngleDeg,
    required this.useImperial,
    required this.isDragging,
    required this.selectedRoomIndex,
    this.selectedVertex,
    this.hoveredVertex,
    required this.showGrid,
    this.calibrationP1Screen,
    this.calibrationP2Screen,
    this.isMeasureMode = false,
    this.measureP1World,
    this.measureP2World,
    this.isAddDimensionMode = false,
    this.addDimensionP1World,
    List<({Offset fromMm, Offset toMm})>? placedDimensions,
    this.drawFromStart = false,
  })  : completedRooms = completedRooms ?? [],
        placedDimensions = placedDimensions ?? [];

  @override
  void paint(Canvas canvas, Size size) {
    // Wrap entire paint method in try-catch to prevent red screen on errors
    try {
      // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

      // Draw completed rooms (filled polygons with outline) first
      // Defensive check: ensure completedRooms is a valid, iterable list
      // This handles hot reload issues where the list might become non-iterable or undefined
      try {
        // First check if completedRooms exists and is not null/undefined
        if (completedRooms == null) {
          debugPrint('Warning: completedRooms is null');
          // Continue to draw draft room even if completedRooms is null
        } else {
          // Check if it's actually a list and has items
          try {
            final length = completedRooms.length;
            if (length > 0) {
              // Use indexed iteration as it's more reliable on web
              for (int i = 0; i < length; i++) {
                try {
                  final room = completedRooms[i];
                  if (room != null && room.vertices.isNotEmpty) {
                    // Pass selection state to highlight selected room
                    _drawRoom(canvas, room, isDraft: false, isSelected: i == selectedRoomIndex);
                    // Draw vertices for this room
                    _drawRoomVertices(canvas, room, roomIndex: i);
                  }
                } catch (e) {
                  // Skip invalid rooms during hot reload
                  debugPrint('Error drawing room at index $i: $e');
                }
              }
            }
          } catch (e) {
            // If we can't access length, try for-in as fallback
            debugPrint('Indexed access failed, trying for-in: $e');
            try {
              int index = 0;
              for (final room in completedRooms) {
                try {
                    if (room != null && room.vertices.isNotEmpty) {
                      _drawRoom(canvas, room, isDraft: false, isSelected: index == selectedRoomIndex);
                      // Draw vertices for this room
                      _drawRoomVertices(canvas, room, roomIndex: index);
                      index++;
                    }
                } catch (e) {
                  debugPrint('Error drawing room: $e');
                }
              }
            } catch (e2) {
              debugPrint('For-in also failed: $e2');
            }
          }
        }
      } catch (e) {
        // Handle case where completedRooms is not accessible at all (hot reload issue)
        debugPrint('Error accessing completedRooms: $e');
      }

      // Draw draft room (vertices and lines, with preview)
      try {
        if (draftRoomVertices != null && draftRoomVertices!.isNotEmpty) {
          _drawDraftRoom(canvas);
        }
      } catch (e) {
        debugPrint('Error drawing draft room: $e');
      }

      // Draw grid on top so it is always visible when enabled
      if (showGrid && size.width > 0 && size.height > 0) {
        _drawGrid(canvas, size);
      }

      // Placed dimensions (permanent)
      for (final d in placedDimensions) {
        final startScreen = vp.worldToScreen(d.fromMm);
        final endScreen = vp.worldToScreen(d.toMm);
        final distanceMm = (d.toMm - d.fromMm).distance;
        _drawDimension(canvas, startScreen, endScreen, distanceMm, isDashed: true);
      }

      // Measure mode: temporary dimension line
      if (isMeasureMode && measureP1World != null && measureP2World != null) {
        final startScreen = vp.worldToScreen(measureP1World!);
        final endScreen = vp.worldToScreen(measureP2World!);
        final distanceMm = (measureP2World! - measureP1World!).distance;
        _drawDimension(canvas, startScreen, endScreen, distanceMm, isTemporary: true);
      } else if (isMeasureMode && measureP1World != null) {
        final p1Screen = vp.worldToScreen(measureP1World!);
        final dotPaint = Paint()
          ..color = Colors.teal
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1Screen, 6, dotPaint);
      }

      // Add dimension mode: preview line from first point to hover
      if (isAddDimensionMode && addDimensionP1World != null && hoverPositionWorldMm != null) {
        final startScreen = vp.worldToScreen(addDimensionP1World!);
        final endScreen = vp.worldToScreen(hoverPositionWorldMm!);
        final distanceMm = (hoverPositionWorldMm! - addDimensionP1World!).distance;
        _drawDimension(canvas, startScreen, endScreen, distanceMm, isTemporary: true);
      } else if (isAddDimensionMode && addDimensionP1World != null) {
        final p1Screen = vp.worldToScreen(addDimensionP1World!);
        final dotPaint = Paint()
          ..color = Colors.teal
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1Screen, 6, dotPaint);
      }

      // Calibration overlay (two tapped points + line)
      if (calibrationP1Screen != null) {
        final p1 = calibrationP1Screen!;
        final paintPts = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1, 6, paintPts);

        if (calibrationP2Screen != null) {
          final p2 = calibrationP2Screen!;
          canvas.drawCircle(p2, 6, paintPts);
          final linePaint = Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawLine(p1, p2, linePaint);
        }

        // Hint text
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Calibrate: tap 2 points',
            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, const Offset(12, 12));
      }
    } catch (e, stackTrace) {
      // Last resort: draw error message instead of crashing
      debugPrint('Critical error in paint: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Draw a simple error indicator
      final errorPaint = Paint()..color = Colors.red.withOpacity(0.3);
      canvas.drawRect(Offset.zero & size, errorPaint);
      
      // Try to draw text (might fail, but worth trying)
      try {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Rendering error - please restart the app',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(20, 20));
      } catch (_) {
        // Ignore text rendering errors
      }
    }
  }

  /// Draw a completed room as a filled polygon with outline.
  void _drawRoom(Canvas canvas, Room room, {required bool isDraft, bool isSelected = false}) {
    if (room.vertices.isEmpty) return;

    final screenPoints = room.vertices
        .map((v) => vp.worldToScreen(v))
        .toList();

    // Fill - highlight selected room
    final fillPath = Path();
    fillPath.addPolygon(screenPoints, true); // true = closed
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = isSelected 
            ? Colors.blue.withOpacity(0.3) // More visible when selected
            : Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Outline - visible stroke (thicker so lines don’t disappear when zoomed)
    final outlinePath = Path();
    outlinePath.addPolygon(screenPoints, true);
    canvas.drawPath(
      outlinePath,
      Paint()
        ..color = isSelected ? Colors.orange : Colors.blue.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.5 : 2.5,
    );
    
    // Draw room name/label or name button centered on the room
    _drawRoomLabel(canvas, room, screenPoints);
    
    // Draw wall measurements/dimensions
    _drawWallMeasurements(canvas, room, screenPoints);
  }
  
  /// Draw the room name/label or name button centered on the room.
  void _drawRoomLabel(Canvas canvas, Room room, List<Offset> screenPoints) {
    // Calculate centroid (center point) of the polygon
    double centerX = 0;
    double centerY = 0;
    int count = 0;
    
    // Use unique vertices (skip the closing vertex if it's a duplicate of first)
    final uniquePoints = screenPoints.length > 1 && 
                         screenPoints.first == screenPoints.last
        ? screenPoints.sublist(0, screenPoints.length - 1)
        : screenPoints;
    
    for (final point in uniquePoints) {
      centerX += point.dx;
      centerY += point.dy;
      count++;
    }
    
    if (count == 0) return;
    
    centerX /= count;
    centerY /= count;
    final center = Offset(centerX, centerY);
    
    // Always draw area prominently
    final areaText = UnitConverter.formatArea(room.areaMm2, useImperial: useImperial);
    
    if (room.name != null && room.name!.isNotEmpty) {
      // Draw room name with area below it (enhanced display)
      final namePainter = TextPainter(
        text: TextSpan(
          text: room.name!,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 3,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      namePainter.layout();
      
      // Calculate spacing: name height + gap + area height
      final nameHeight = namePainter.height;
      final areaHeight = 30.0; // Approximate area label height (text + padding)
      final gap = 16.0; // Increased gap to prevent overlap
      final totalHeight = nameHeight + gap + areaHeight;
      
      // Draw room name (positioned above center to make room for area below)
      namePainter.paint(
        canvas,
        Offset(
          center.dx - namePainter.width / 2,
          center.dy - totalHeight / 2,
        ),
      );
      
      // Draw area with prominent background box (below name with gap)
      _drawAreaLabel(canvas, center, areaText, offsetY: nameHeight / 2 + gap + areaHeight / 2);
    } else {
      // Draw name button (icon) when room has no name
      _drawNameButton(canvas, center);
      
      // Draw area prominently below button
      _drawAreaLabel(canvas, center, areaText, offsetY: 30);
    }
  }
  
  /// Draw area label with prominent background for better visibility.
  void _drawAreaLabel(Canvas canvas, Offset center, String areaText, {double offsetY = 0}) {
    final areaPainter = TextPainter(
      text: TextSpan(
        text: areaText,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    areaPainter.layout();
    
    // Draw background box for better readability
    final padding = 6.0;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - areaPainter.width / 2 - padding,
        center.dy + offsetY - areaPainter.height / 2 - padding,
        areaPainter.width + padding * 2,
        areaPainter.height + padding * 2,
      ),
      const Radius.circular(4),
    );
    
    // Draw white background with slight transparency
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(boxRect, backgroundPaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(boxRect, borderPaint);
    
    // Draw area text
    areaPainter.paint(
      canvas,
      Offset(
        center.dx - areaPainter.width / 2,
        center.dy + offsetY - areaPainter.height / 2,
      ),
    );
  }
  
  /// Draw a clickable button icon for naming/renaming the room.
  void _drawNameButton(Canvas canvas, Offset center) {
    // Draw button background circle
    final buttonPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, buttonPaint);
    
    // Draw button border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 20, borderPaint);
    
    // Draw "+" icon or edit icon (simple plus sign for "add name")
    final iconPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    // Draw plus sign
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      iconPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      iconPaint,
    );
  }

  /// Draw measurements on each wall segment of the room.
  void _drawWallMeasurements(Canvas canvas, Room room, List<Offset> screenPoints) {
    if (room.vertices.length < 2) return;
    
    // Get unique vertices (skip closing vertex if duplicate)
    final uniqueVertices = room.vertices.length > 1 && 
                           room.vertices.first == room.vertices.last
        ? room.vertices.sublist(0, room.vertices.length - 1)
        : room.vertices;
    
    final uniqueScreenPoints = screenPoints.length > 1 && 
                                screenPoints.first == screenPoints.last
        ? screenPoints.sublist(0, screenPoints.length - 1)
        : screenPoints;
    
    if (uniqueVertices.length < 2) return;
    
    // Draw dimension for each wall segment
    for (int i = 0; i < uniqueVertices.length; i++) {
      final j = (i + 1) % uniqueVertices.length;
      final startWorld = uniqueVertices[i];
      final endWorld = uniqueVertices[j];
      final startScreen = uniqueScreenPoints[i];
      final endScreen = uniqueScreenPoints[j];
      
      // Calculate distance in mm
      final distanceMm = (endWorld - startWorld).distance;
      
      // Only draw if wall is long enough to display measurement
      final screenDistance = (endScreen - startScreen).distance;
      if (screenDistance < 50) continue; // Skip very short walls
      
      _drawDimension(canvas, startScreen, endScreen, distanceMm);
    }
  }
  
  /// Draw vertices for a completed room with visual feedback for selection/hover.
  void _drawRoomVertices(Canvas canvas, Room room, {required int roomIndex}) {
    // Use unique vertices (skip closing vertex if duplicate)
    final uniqueVertices = room.vertices.length > 1 && 
                          room.vertices.first == room.vertices.last
        ? room.vertices.sublist(0, room.vertices.length - 1)
        : room.vertices;
    
    for (int vertexIdx = 0; vertexIdx < uniqueVertices.length; vertexIdx++) {
      final vertexScreen = vp.worldToScreen(uniqueVertices[vertexIdx]);
      
      // Determine if this vertex is selected or hovered
      final isSelected = selectedVertex != null &&
                        selectedVertex!.roomIndex == roomIndex &&
                        selectedVertex!.vertexIndex == vertexIdx;
      final isHovered = hoveredVertex != null &&
                       hoveredVertex!.roomIndex == roomIndex &&
                       hoveredVertex!.vertexIndex == vertexIdx;
      
      // Draw vertex circle
      final radius = isSelected ? 8.0 : (isHovered ? 7.0 : 6.0);
      final color = isSelected 
          ? Colors.orange 
          : (isHovered ? Colors.orange.withOpacity(0.7) : Colors.blue);
      
      // Outer ring for better visibility
      canvas.drawCircle(
        vertexScreen,
        radius + 1,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      
      // Main vertex circle
      canvas.drawCircle(
        vertexScreen,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      
      // Inner highlight for selected
      if (isSelected) {
        canvas.drawCircle(
          vertexScreen,
          radius * 0.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
      }
    }
  }
  
  /// Draw a dashed/dotted line between two points (for temporary dimension styling).
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      {double dashLength = 5, double gapLength = 4}) {
    final path = Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final segmentLength =
            (distance + dashLength <= metric.length) ? dashLength : metric.length - distance;
        if (segmentLength > 0) {
          final segment = metric.extractPath(distance, distance + segmentLength);
          canvas.drawPath(segment, paint);
        }
        distance += dashLength + gapLength;
      }
    }
  }

  /// Draw a dimension line with measurement text for a wall segment.
  /// When [isTemporary] is true, uses teal color and dotted lines for measure/add-dimension preview.
  /// When [isDashed] is true (e.g. permanent placed dimensions), uses grey color and dotted lines.
  void _drawDimension(Canvas canvas, Offset start, Offset end, double distanceMm, {bool isTemporary = false, bool isDashed = false}) {
    // Calculate midpoint and perpendicular offset for dimension line
    final midpoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final wallVector = end - start;
    final wallLength = wallVector.distance;
    if (wallLength == 0) return;
    
    // Perpendicular direction (rotate 90 degrees)
    final perp = Offset(-wallVector.dy / wallLength, wallVector.dx / wallLength);
    
    // Offset distance from wall (20 pixels)
    final offsetDistance = 20.0;
    final dimensionLineStart = midpoint + perp * offsetDistance;
    final dimensionLineEnd = midpoint - perp * offsetDistance;
    
    final lineColor = isTemporary ? Colors.teal : Colors.grey.withOpacity(0.6);
    final extColor = isTemporary ? Colors.teal.withOpacity(0.6) : Colors.grey.withOpacity(0.4);
    final useDashed = isTemporary || isDashed;
    
    // Draw dimension line (perpendicular to wall)
    final dimLinePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTemporary ? 2 : 1;
    if (useDashed) {
      _drawDashedLine(canvas, dimensionLineStart, dimensionLineEnd, dimLinePaint);
    } else {
      canvas.drawLine(dimensionLineStart, dimensionLineEnd, dimLinePaint);
    }
    
    // Draw extension lines (from wall to dimension line)
    final extLinePaint = Paint()
      ..color = extColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTemporary ? 1 : 0.5;
    if (useDashed) {
      _drawDashedLine(canvas, start, dimensionLineStart, extLinePaint);
      _drawDashedLine(canvas, end, dimensionLineStart, extLinePaint);
    } else {
      canvas.drawLine(start, dimensionLineStart, extLinePaint);
      canvas.drawLine(end, dimensionLineStart, extLinePaint);
    }
    
    // Format measurement text
    final measurementText = UnitConverter.formatDistance(distanceMm, useImperial: useImperial);
    
    // Draw measurement text
    final textPainter = TextPainter(
      text: TextSpan(
        text: measurementText,
        style: TextStyle(
          color: isTemporary ? Colors.teal.shade700 : Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    // Position text at dimension line, rotated to match wall angle
    final wallAngle = math.atan2(wallVector.dy, wallVector.dx);
    final textOffset = dimensionLineStart - Offset(textPainter.width / 2, textPainter.height / 2);
    
    canvas.save();
    canvas.translate(textOffset.dx + textPainter.width / 2, textOffset.dy + textPainter.height / 2);
    canvas.rotate(wallAngle);
    canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// Draw visual arc showing the angle between two lines.
  /// [vertexScreen] is the corner point; [prevScreen] and [nextScreen] are the two adjacent points.
  /// Arc is drawn from the first line to the second line so it always connects both.
  void _drawAngleArc(Canvas canvas, Offset vertexScreen, Offset prevScreen, Offset nextScreen, double angleDeg) {
    final toPrev = prevScreen - vertexScreen;
    final toNext = nextScreen - vertexScreen;
    final d1 = math.sqrt(toPrev.dx * toPrev.dx + toPrev.dy * toPrev.dy);
    final d2 = math.sqrt(toNext.dx * toNext.dx + toNext.dy * toNext.dy);
    if (d1 < 1e-6 || d2 < 1e-6) return;
    
    // Normalize direction vectors (pointing away from vertex along each line)
    final dir1 = Offset(toPrev.dx / d1, toPrev.dy / d1);
    final dir2 = Offset(toNext.dx / d2, toNext.dy / d2);
    
    // Angles in radians: direction of each line from the vertex
    final angle1 = math.atan2(dir1.dy, dir1.dx);
    final angle2 = math.atan2(dir2.dy, dir2.dx);
    
    // Sweep from angle1 to angle2 (normalized to (-π, π]) so the arc connects both lines exactly
    double sweep = angle2 - angle1;
    while (sweep > math.pi) sweep -= 2 * math.pi;
    while (sweep < -math.pi) sweep += 2 * math.pi;
    
    final startAngle = angle1;
    
    // Arc radius (visual size)
    const arcRadius = 18.0;
    
    // Create bounding rect for arc (centered at vertex)
    final rect = Rect.fromCircle(center: vertexScreen, radius: arcRadius);
    
    // Draw arc - start at angle1, sweep the correct amount
    final arcPaint = Paint()
      ..color = Colors.blue.shade600.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);
    
    // Draw small lines from vertex to the actual line directions (at arc radius)
    // These lines connect the vertex to where the arc should start/end on the actual lines
    final linePaint = Paint()
      ..color = Colors.blue.shade600.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // Line 1: from vertex along dir1 (first line direction)
    canvas.drawLine(
      vertexScreen,
      Offset(vertexScreen.dx + dir1.dx * arcRadius, vertexScreen.dy + dir1.dy * arcRadius),
      linePaint,
    );
    // Line 2: from vertex along dir2 (second line direction)
    canvas.drawLine(
      vertexScreen,
      Offset(vertexScreen.dx + dir2.dx * arcRadius, vertexScreen.dy + dir2.dy * arcRadius),
      linePaint,
    );
  }

  /// Draw angle label in the space between two lines (at the corner).
  /// [vertexScreen] is the corner point; [prevScreen] and [nextScreen] are the two adjacent points.
  void _drawAngleInCorner(Canvas canvas, Offset vertexScreen, Offset prevScreen, Offset nextScreen, double angleDeg) {
    // Draw visual arc first
    _drawAngleArc(canvas, vertexScreen, prevScreen, nextScreen, angleDeg);
    
    final toPrev = prevScreen - vertexScreen;
    final toNext = nextScreen - vertexScreen;
    final d1 = math.sqrt(toPrev.dx * toPrev.dx + toPrev.dy * toPrev.dy);
    final d2 = math.sqrt(toNext.dx * toNext.dx + toNext.dy * toNext.dy);
    if (d1 < 1e-6 || d2 < 1e-6) return;
    // Bisector from vertex into the corner (between the two segments)
    final out1 = Offset(-toPrev.dx / d1, -toPrev.dy / d1);
    final out2 = Offset(-toNext.dx / d2, -toNext.dy / d2);
    final bisector = Offset(out1.dx + out2.dx, out1.dy + out2.dy);
    final len = math.sqrt(bisector.dx * bisector.dx + bisector.dy * bisector.dy);
    if (len < 1e-6) return;
    const offsetPx = 22.0;
    final pos = Offset(
      vertexScreen.dx + bisector.dx / len * offsetPx,
      vertexScreen.dy + bisector.dy / len * offsetPx,
    );
    final angleText = '${angleDeg.round()}°';
    final textPainter = TextPainter(
      text: TextSpan(
        text: angleText,
        style: TextStyle(
          color: Colors.blue.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white.withOpacity(0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    const pad = 4.0;
    final w = textPainter.width + pad * 2;
    final h = textPainter.height + 2;
    final rect = Rect.fromCenter(center: pos, width: w, height: h);
    canvas.drawRect(rect, Paint()..color = Colors.white.withOpacity(0.95));
    textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2) + const Offset(0, 1));
  }

  /// Draw the draft room with vertices, lines, and preview line to cursor.
  void _drawDraftRoom(Canvas canvas) {
    if (draftRoomVertices == null || draftRoomVertices!.isEmpty) return;

    final vertices = draftRoomVertices!;

    // Draw lines between vertices with measurements
    if (vertices.length > 1) {
      final linePaint = Paint()
        ..color = Colors.blue.shade700.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < vertices.length - 1; i++) {
        final a = vp.worldToScreen(vertices[i]);
        final b = vp.worldToScreen(vertices[i + 1]);
        canvas.drawLine(a, b, linePaint);
        
        // Draw measurement on each completed segment
        final distanceMm = (vertices[i + 1] - vertices[i]).distance;
        final screenDistance = (b - a).distance;
        if (screenDistance > 50) { // Only draw if segment is long enough
          _drawDimension(canvas, a, b, distanceMm);
        }
      }

      // Draw angle at each interior corner: second segment relative to first, 0–180° either way
      for (int i = 1; i < vertices.length - 1; i++) {
        final prev = vp.worldToScreen(vertices[i - 1]);
        final vert = vp.worldToScreen(vertices[i]);
        final next = vp.worldToScreen(vertices[i + 1]);
        final dir1 = Offset(vertices[i].dx - vertices[i - 1].dx, vertices[i].dy - vertices[i - 1].dy);
        final dir2 = Offset(vertices[i + 1].dx - vertices[i].dx, vertices[i + 1].dy - vertices[i].dy);
        final l1 = math.sqrt(dir1.dx * dir1.dx + dir1.dy * dir1.dy);
        final l2 = math.sqrt(dir2.dx * dir2.dx + dir2.dy * dir2.dy);
        if (l1 >= 1e-6 && l2 >= 1e-6) {
          final angle1 = math.atan2(dir1.dy, dir1.dx);
          final angle2 = math.atan2(dir2.dy, dir2.dx);
          double diffRad = angle2 - angle1;
          while (diffRad < 0) diffRad += 2 * math.pi;
          while (diffRad >= 2 * math.pi) diffRad -= 2 * math.pi;
          double angleDeg = diffRad * (180.0 / math.pi);
          if (angleDeg > 180.0) angleDeg = 360.0 - angleDeg;
          // Display complementary angle (e.g. 9° → 171°)
          angleDeg = 180.0 - angleDeg;
          _drawAngleInCorner(canvas, vert, prev, next, angleDeg);
        }
      }
    }

    // Draw preview line from current drawing endpoint to cursor
    if (hoverPositionWorldMm != null && vertices.isNotEmpty) {
      final lastWorld = drawFromStart ? vertices.first : vertices.last;
      final lastScreen = vp.worldToScreen(lastWorld);
      final hoverScreen = vp.worldToScreen(hoverPositionWorldMm!);
      final distanceMm = (hoverPositionWorldMm! - lastWorld).distance;
      
      final previewPaint = Paint()
        ..color = Colors.blue.shade700.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      // Solid preview line (more visible than dashed)
      canvas.drawLine(lastScreen, hoverScreen, previewPaint);
      
      if (previewLineAngleDeg != null && vertices.length >= 2) {
        final prevWorld = drawFromStart ? vertices[1] : vertices[vertices.length - 2];
        final prevScreen = vp.worldToScreen(prevWorld);
        _drawAngleInCorner(canvas, lastScreen, prevScreen, hoverScreen, previewLineAngleDeg!);
      }
      
      // Draw live measurement on the preview line
      if (isDragging && distanceMm > 10) {
        // Only show if dragging and segment is meaningful length
        final measurementText = UnitConverter.formatDistance(distanceMm, useImperial: useImperial);
        
        // Calculate midpoint of preview line
        final midpoint = Offset(
          (lastScreen.dx + hoverScreen.dx) / 2,
          (lastScreen.dy + hoverScreen.dy) / 2,
        );
        
        // Draw measurement text with background
        final textPainter = TextPainter(
          text: TextSpan(
            text: measurementText,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              backgroundColor: Colors.white.withOpacity(0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        
        textPainter.layout();
        
        // Position text at midpoint, rotated to match line angle
        final lineVector = hoverScreen - lastScreen;
        final lineAngle = math.atan2(lineVector.dy, lineVector.dx);
        
        canvas.save();
        canvas.translate(midpoint.dx, midpoint.dy);
        canvas.rotate(lineAngle);
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
      
      // Draw visual feedback for snapped grid point
      // Outer highlight circle (subtle)
      final gridHighlightPaint = Paint()
        ..color = Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hoverScreen, 8, gridHighlightPaint);
      
      // Inner snap indicator (more visible)
      final snapIndicatorPaint = Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hoverScreen, 4, snapIndicatorPaint);
    }

    // Draw vertices as circles
    final vertexPaint = Paint()..color = Colors.blue;
    final startVertexPaint = Paint()..color = Colors.green; // First vertex (first placed) is green
    final drawingFromIndex = drawFromStart ? 0 : vertices.length - 1;

    for (int i = 0; i < vertices.length; i++) {
      final screenPos = vp.worldToScreen(vertices[i]);
      final paint = (i == 0) ? startVertexPaint : vertexPaint;
      canvas.drawCircle(screenPos, 5, paint);
    }

    // Indicator for "drawing from" vertex: ring + slight emphasis
    if (vertices.length >= 1) {
      final fromScreen = vp.worldToScreen(vertices[drawingFromIndex]);
      final ringPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(fromScreen, 9, ringPaint);
      final innerPaint = Paint()..color = Colors.orange.withOpacity(0.3);
      canvas.drawCircle(fromScreen, 7, innerPaint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // World-space grid: spacing scales so ~50–80px between lines on screen
    final targetScreenSpacingPx = 60.0;
    final targetWorldSpacingMm = targetScreenSpacingPx * vp.mmPerPx;
    final niceSpacings = [1.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0];
    double gridMm = niceSpacings.last;
    for (final spacing in niceSpacings) {
      if (spacing >= targetWorldSpacingMm * 0.5) {
        gridMm = spacing;
        break;
      }
    }

    final screenSpacingPx = gridMm / vp.mmPerPx;
    // Scale stroke with zoom: thinner when zoomed in (dense grid), slightly thicker when zoomed out
    final strokeWidth = (screenSpacingPx / 80).clamp(0.5, 2.0).toDouble();

    final topLeftW = vp.screenToWorld(Offset.zero);
    final bottomRightW = vp.screenToWorld(Offset(size.width, size.height));
    final minX = math.min(topLeftW.dx, bottomRightW.dx) - gridMm;
    final maxX = math.max(topLeftW.dx, bottomRightW.dx) + gridMm;
    final minY = math.min(topLeftW.dy, bottomRightW.dy) - gridMm;
    final maxY = math.max(topLeftW.dy, bottomRightW.dy) + gridMm;

    double startX = (minX / gridMm).floor() * gridMm;
    double startY = (minY / gridMm).floor() * gridMm;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (double x = startX; x <= maxX; x += gridMm) {
      final a = vp.worldToScreen(Offset(x, minY));
      final b = vp.worldToScreen(Offset(x, maxY));
      canvas.drawLine(a, b, gridPaint);
    }
    for (double y = startY; y <= maxY; y += gridMm) {
      final a = vp.worldToScreen(Offset(minX, y));
      final b = vp.worldToScreen(Offset(maxX, y));
      canvas.drawLine(a, b, gridPaint);
    }
  }
  
  /// Format grid spacing as a readable label (e.g., "1 cm", "1 m")
  String _formatGridLabel(double gridMm) {
    if (gridMm >= 10000) {
      return '${(gridMm / 1000).toStringAsFixed(0)} m';
    } else if (gridMm >= 1000) {
      return '${(gridMm / 1000).toStringAsFixed(1)} m';
    } else if (gridMm >= 100) {
      return '${(gridMm / 10).toStringAsFixed(0)} cm';
    } else if (gridMm >= 10) {
      return '${gridMm.toStringAsFixed(0)} cm';
    } else if (gridMm >= 1) {
      return '${gridMm.toStringAsFixed(0)} mm';
    } else {
      return '${(gridMm * 10).toStringAsFixed(0)} mm';
    }
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) => true;
}
