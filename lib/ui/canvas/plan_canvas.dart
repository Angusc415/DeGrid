import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'viewport.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../core/geometry/room.dart';
import '../../core/units/unit_converter.dart';
import 'plan_toolbar.dart';


class PlanCanvas extends StatefulWidget {
  const PlanCanvas({super.key});

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<PlanCanvas> {
  final PlanViewport _vp = PlanViewport(
    mmPerPx: 5.0,
    worldOriginMm: const Offset(-500, -500),
  );

  // Completed rooms (polygons)
  final List<Room> _completedRooms = [];
  
  // Counter for default room names
  int _roomCounter = 1;
  
  // Unit system: false = metric (mm/cm), true = imperial (ft/in)
  bool _useImperial = false;
  
  // Grid visibility toggle
  bool _showGrid = true;
  
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
  
  // Hovered vertex for visual feedback: (roomIndex, vertexIndex)
  // null = no vertex hovered
  ({int roomIndex, int vertexIndex})? _hoveredVertex;
  
  // Currently drawing a room (null = not drawing)
  List<Offset>? _draftRoomVertices;
  
  // Current cursor/hover position for preview line (world-space mm)
  Offset? _hoverPositionWorldMm;
  
  // Drag state: track if we're currently dragging to draw a wall
  bool _isDragging = false;
  Offset? _dragStartPositionWorldMm;
  
  // Vertex editing state: true when dragging a vertex to reshape room
  bool _isEditingVertex = false;

  double _startMmPerPx = 5.0;
  
  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();
  
  // Screen-space tolerance for "clicking near start vertex" to close room
  static const double _closeTolerancePx = 20.0;
  
  // Screen-space tolerance for clicking on a vertex (in pixels)
  static const double _vertexSelectTolerancePx = 12.0;
  
  // Grid spacing in millimeters (matches grid drawing)
  static const double _gridSpacingMm = 100.0; // 10cm = 100mm

  @override
  void initState() {
    super.initState();
    // Initialize history with empty state
    _saveHistoryState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
    });
  }
  
  /// Toggle grid visibility
  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        KeyboardListener(
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
            default:
              break;
          }
        }
          },
          child: Listener(
      behavior: HitTestBehavior.opaque,

            // PAN (web): Shift + left-drag OR right-click drag
            // Also track hover position for preview line (when not actively dragging to draw)
      onPointerMove: (e) {
          // Update hover position for preview line (only when not dragging to draw walls)
          // Pan gestures are handled separately
          if (e.buttons == 0 && _draftRoomVertices != null && !_isDragging && !_isEditingVertex) {
            setState(() {
              _hoverPositionWorldMm = _vp.screenToWorld(e.localPosition);
            });
          }
          
          // Update hovered vertex for visual feedback (when not drawing or editing)
          if (e.buttons == 0 && _draftRoomVertices == null && !_isEditingVertex) {
            setState(() {
              _hoveredVertex = _findVertexAtPosition(e.localPosition);
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

        // IMPORTANT: disable scale on web to stop left-drag pan weirdness
        onScaleStart: kIsWeb
            ? null
            : (_) {
                _startMmPerPx = _vp.mmPerPx;
              },
        onScaleUpdate: kIsWeb
            ? null
            : (d) {
                setState(() {
                  _vp.panByScreenDelta(d.focalPointDelta);

                  final desiredMmPerPx = _startMmPerPx / d.scale;
                  final zoomFactor = desiredMmPerPx / _vp.mmPerPx;
                  _vp.zoomAt(
                    zoomFactor: zoomFactor,
                    focalScreenPx: d.focalPoint,
                  );
                });
              },

        // Room drawing: click and drag to draw wall segments
        onPanStart: (d) {
          _handlePanStart(d.localPosition);
        },
        
        onPanUpdate: (d) {
          _handlePanUpdate(d.localPosition);
        },
        
        onPanEnd: (d) {
          _handlePanEnd(d.localPosition);
        },
        
        // Double-tap: close room if drafting
        onDoubleTapDown: (d) {
          if (_draftRoomVertices != null && _draftRoomVertices!.length >= 3) {
            // Close draft room
            _closeDraftRoom();
          }
        },
        
        // Single tap: select room or edit name if clicking center
        onTapDown: (d) {
          if (_draftRoomVertices == null && !_isEditingVertex) {
            // Only handle clicks when not drawing or editing
            // Check if clicking on a vertex first
            final clickedVertex = _findVertexAtPosition(d.localPosition);
            
            if (clickedVertex != null) {
              // Click on vertex = select it (but don't start editing until drag)
              setState(() {
                _selectedVertex = clickedVertex;
                _selectedRoomIndex = clickedVertex.roomIndex;
              });
              return;
            }
            
            // Otherwise, check for room center or room area
            final worldPos = _vp.screenToWorld(d.localPosition);
            final clickedRoomIndex = _findRoomAtPosition(worldPos);
            if (clickedRoomIndex != null) {
              final room = _completedRooms[clickedRoomIndex];
              final center = _getRoomCenter(room.vertices);
              final centerScreen = _vp.worldToScreen(center);
              final distance = (d.localPosition - centerScreen).distance;
              
              setState(() {
                _selectedVertex = null; // Deselect vertex when clicking room
                // Click area: 40px radius (covers button or name text)
                if (distance < 40) {
                  // Click on center = edit name
                  _editRoomName(clickedRoomIndex);
                  _selectedRoomIndex = clickedRoomIndex; // Keep selected after editing
                } else {
                  // Click elsewhere on room = select it
                  _selectedRoomIndex = clickedRoomIndex;
                }
              });
            } else {
              // Click outside any room = deselect
          setState(() {
                _selectedRoomIndex = null;
                _selectedVertex = null;
              });
            }
          }
        },
        
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

        child: SizedBox.expand(
                key: ValueKey('plan_painter_${_completedRooms.length}_${_draftRoomVertices?.length ?? 0}'),
          child: CustomPaint(
            painter: _PlanPainter(
              vp: _vp,
              completedRooms: _safeCopyRooms(_completedRooms),
              draftRoomVertices: _draftRoomVertices != null 
                  ? List<Offset>.from(_draftRoomVertices!) 
                  : null,
              hoverPositionWorldMm: _hoverPositionWorldMm,
              useImperial: _useImperial,
              isDragging: _isDragging,
              selectedRoomIndex: _selectedRoomIndex,
              selectedVertex: _selectedVertex,
              hoveredVertex: _hoveredVertex,
              showGrid: _showGrid,
            ),
              ),
            ),
          ),
        ),
        ),
        // Toolbar positioned at top-left
        Positioned(
          top: 8,
          left: 8,
          child: PlanToolbar(
            useImperial: _useImperial,
            showGrid: _showGrid,
            canUndo: _canUndo,
            canRedo: _canRedo,
            onToggleUnit: _toggleUnit,
            onToggleGrid: _toggleGrid,
            onUndo: _undo,
            onRedo: _redo,
          ),
        ),
      ],
    );
  }

  /// Snap a world-space position to the nearest grid point.
  /// 
  /// This ensures vertices align to the grid for precise floor plan drawing.
  /// Grid spacing is 100mm (10cm).
  Offset _snapToGrid(Offset worldPositionMm) {
    final snappedX = (worldPositionMm.dx / _gridSpacingMm).round() * _gridSpacingMm;
    final snappedY = (worldPositionMm.dy / _gridSpacingMm).round() * _gridSpacingMm;
    return Offset(snappedX, snappedY);
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
    // First check if clicking on a vertex to edit
    final clickedVertex = _findVertexAtPosition(screenPosition);
    
    if (clickedVertex != null && _draftRoomVertices == null) {
      // Start editing this vertex
      setState(() {
        _selectedVertex = clickedVertex;
        _selectedRoomIndex = clickedVertex.roomIndex;
        _isEditingVertex = true;
        _isDragging = false;
      });
      return;
    }
    
    // Otherwise, proceed with normal room drawing
    final worldPosition = _vp.screenToWorld(screenPosition);
    final snappedPosition = _snapToGrid(worldPosition);
    
    setState(() {
      _selectedVertex = null; // Deselect vertex when starting new drawing
      _isEditingVertex = false;
      
      if (_draftRoomVertices == null) {
        // Start a new room with first vertex (snapped to grid)
        _draftRoomVertices = [snappedPosition];
        _dragStartPositionWorldMm = snappedPosition;
        _isDragging = true;
        _hoverPositionWorldMm = snappedPosition;
        // Save state to history when starting a new draft room
        _saveHistoryState();
      } else {
        // Check if starting drag near the start vertex (close room)
        if (_draftRoomVertices!.isNotEmpty) {
          final startScreen = _vp.worldToScreen(_draftRoomVertices!.first);
          final distance = (screenPosition - startScreen).distance;
          
          // Close room if starting drag near start AND we have at least 3 vertices
          if (distance < _closeTolerancePx && _draftRoomVertices!.length >= 3) {
            _closeDraftRoom(); // Fire and forget - async call
            return;
          }
        }
        
        // Start a new wall segment from the last vertex
        _dragStartPositionWorldMm = _draftRoomVertices!.isNotEmpty 
            ? _draftRoomVertices!.last 
            : worldPosition;
        _isDragging = true;
        _hoverPositionWorldMm = worldPosition;
      }
    });
  }

  /// Handle pan update: update preview line as user drags, or move vertex if editing.
  void _handlePanUpdate(Offset screenPosition) {
    // If editing a vertex, move it
    if (_isEditingVertex && _selectedVertex != null) {
      final worldPosition = _vp.screenToWorld(screenPosition);
      final snappedPosition = _snapToGrid(worldPosition);
      
      setState(() {
        final roomIdx = _selectedVertex!.roomIndex;
        final vertexIdx = _selectedVertex!.vertexIndex;
        
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
          }
        }
      });
      return;
    }
    
    // Otherwise, handle normal drawing preview
    if (!_isDragging) return;
    
    final worldPosition = _vp.screenToWorld(screenPosition);
    final snappedPosition = _snapToGrid(worldPosition);
    
    setState(() {
      // Update hover position to show preview line (snapped to grid)
      _hoverPositionWorldMm = snappedPosition;
      
      // Update hovered vertex for visual feedback
      final hoveredVertex = _findVertexAtPosition(screenPosition);
      _hoveredVertex = hoveredVertex;
    });
  }

  /// Handle pan end: place the wall segment (add vertex) or finish editing vertex.
  void _handlePanEnd(Offset screenPosition) {
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
    final snappedPosition = _snapToGrid(worldPosition);
    
    setState(() {
      _isDragging = false;
      
      if (_draftRoomVertices == null || _dragStartPositionWorldMm == null) {
        return;
      }
      
      // Check if ending near the start vertex (close room)
      // Use snapped position for close detection to be more forgiving
      if (_draftRoomVertices!.isNotEmpty && _draftRoomVertices!.length >= 3) {
        final startScreen = _vp.worldToScreen(_draftRoomVertices!.first);
        final distance = (screenPosition - startScreen).distance;
        
        if (distance < _closeTolerancePx) {
          _closeDraftRoom(); // Fire and forget - async call
          _dragStartPositionWorldMm = null;
          return;
        }
      }
      
      // Add new vertex at end of drag (snapped to grid)
      // Prevent duplicate vertices (dragging to same spot)
      final minDistanceMm = _gridSpacingMm * 0.5; // Minimum half grid spacing between vertices
      if (_draftRoomVertices!.isEmpty ||
          (snappedPosition - _draftRoomVertices!.last).distance > minDistanceMm) {
        _draftRoomVertices = [..._draftRoomVertices!, snappedPosition];
        _hoverPositionWorldMm = snappedPosition;
        // Save state to history after adding a vertex to draft room
        _saveHistoryState();
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
      }
      
      // Clear draft
      _draftRoomVertices = null;
      _hoverPositionWorldMm = null;
      
      // Save state to history after room creation
      _saveHistoryState();
    });
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
        // Save state to history after room deletion
        _saveHistoryState();
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
      // Save state to history after room name change
      _saveHistoryState();
    });
  }
}

class _PlanPainter extends CustomPainter {
  final PlanViewport vp;
  final List<Room> completedRooms;
  final List<Offset>? draftRoomVertices;
  final Offset? hoverPositionWorldMm;
  final bool useImperial;
  final bool isDragging;
  final int? selectedRoomIndex;
  final ({int roomIndex, int vertexIndex})? selectedVertex;
  final ({int roomIndex, int vertexIndex})? hoveredVertex;
  final bool showGrid;

  _PlanPainter({
    required this.vp,
    List<Room>? completedRooms,
    required this.draftRoomVertices,
    required this.hoverPositionWorldMm,
    required this.useImperial,
    required this.isDragging,
    required this.selectedRoomIndex,
    this.selectedVertex,
    this.hoveredVertex,
    required this.showGrid,
  }) : completedRooms = completedRooms ?? [];

  @override
  void paint(Canvas canvas, Size size) {
    // Wrap entire paint method in try-catch to prevent red screen on errors
    try {
      // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

      // Draw grid only if enabled
      if (showGrid) {
    _drawGrid(canvas, size);
      }

      // Draw completed rooms (filled polygons with outline)
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

    // Outline - thicker and different color when selected
    final outlinePath = Path();
    outlinePath.addPolygon(screenPoints, true);
    canvas.drawPath(
      outlinePath,
      Paint()
        ..color = isSelected ? Colors.orange : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2,
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
    
    if (room.name != null && room.name!.isNotEmpty) {
      // Draw room name with area below it
      final areaText = UnitConverter.formatArea(room.areaMm2, useImperial: useImperial);
      final nameText = '${room.name!}\n$areaText';
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: nameText,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 16,
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
      
      textPainter.layout();
      
      // Draw text centered on the room
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    } else {
      // Draw name button (icon) when room has no name
      // Also show area below button
      _drawNameButton(canvas, center);
      
      final areaText = UnitConverter.formatArea(room.areaMm2, useImperial: useImperial);
      final areaPainter = TextPainter(
        text: TextSpan(
          text: areaText,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            backgroundColor: Colors.white.withOpacity(0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      areaPainter.layout();
      areaPainter.paint(
        canvas,
        Offset(
          center.dx - areaPainter.width / 2,
          center.dy + 25, // Below the button
        ),
      );
    }
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
  
  /// Draw a dimension line with measurement text for a wall segment.
  void _drawDimension(Canvas canvas, Offset start, Offset end, double distanceMm) {
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
    
    // Draw dimension line (perpendicular to wall)
    final dimLinePaint = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(dimensionLineStart, dimensionLineEnd, dimLinePaint);
    
    // Draw extension lines (from wall to dimension line)
    final extLinePaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawLine(start, dimensionLineStart, extLinePaint);
    canvas.drawLine(end, dimensionLineStart, extLinePaint);
    
    // Format measurement text
    final measurementText = UnitConverter.formatDistance(distanceMm, useImperial: useImperial);
    
    // Draw measurement text
    final textPainter = TextPainter(
      text: TextSpan(
        text: measurementText,
        style: TextStyle(
          color: Colors.grey.shade700,
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

  /// Draw the draft room with vertices, lines, and preview line to cursor.
  void _drawDraftRoom(Canvas canvas) {
    if (draftRoomVertices == null || draftRoomVertices!.isEmpty) return;

    final vertices = draftRoomVertices!;

    // Draw lines between vertices
    if (vertices.length > 1) {
      final linePaint = Paint()
        ..color = Colors.blue.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      for (int i = 0; i < vertices.length - 1; i++) {
        final a = vp.worldToScreen(vertices[i]);
        final b = vp.worldToScreen(vertices[i + 1]);
        canvas.drawLine(a, b, linePaint);
      }
    }

    // Draw preview line from last vertex to cursor (if hovering or dragging)
    // During drag, show line from drag start; when hovering, show from last vertex
    if (hoverPositionWorldMm != null && vertices.isNotEmpty) {
      final lastWorld = vertices.last;
      final lastScreen = vp.worldToScreen(lastWorld);
      final hoverScreen = vp.worldToScreen(hoverPositionWorldMm!);
      
      // Calculate distance of current segment in mm
      final distanceMm = (hoverPositionWorldMm! - lastWorld).distance;
      
      final previewPaint = Paint()
        ..color = Colors.blue.withOpacity(0.5) // More visible during drag
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 // Thicker during drag
        ..strokeCap = StrokeCap.round;
      
      // Solid preview line (more visible than dashed)
      canvas.drawLine(lastScreen, hoverScreen, previewPaint);
      
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
    final startVertexPaint = Paint()..color = Colors.green; // First vertex is green
    
    for (int i = 0; i < vertices.length; i++) {
      final screenPos = vp.worldToScreen(vertices[i]);
      final paint = (i == 0) ? startVertexPaint : vertexPaint;
      canvas.drawCircle(screenPos, 5, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    const gridMm = 100.0; // 10cm
    final topLeftW = vp.screenToWorld(Offset.zero);
    final bottomRightW = vp.screenToWorld(Offset(size.width, size.height));

    double startX = (topLeftW.dx / gridMm).floor() * gridMm;
    double startY = (topLeftW.dy / gridMm).floor() * gridMm;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 1;

    for (double x = startX; x <= bottomRightW.dx; x += gridMm) {
      final a = vp.worldToScreen(Offset(x, topLeftW.dy));
      final b = vp.worldToScreen(Offset(x, bottomRightW.dy));
      canvas.drawLine(a, b, gridPaint);
    }
    for (double y = startY; y <= bottomRightW.dy; y += gridMm) {
      final a = vp.worldToScreen(Offset(topLeftW.dx, y));
      final b = vp.worldToScreen(Offset(bottomRightW.dx, y));
      canvas.drawLine(a, b, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) => true;
}
