part of 'plan_canvas.dart';

void _selectRoomImpl(PlanCanvasState state, int roomIndex, {bool pan = true}) {
  if (roomIndex < 0 || roomIndex >= state._completedRooms.length) return;

  final room = state._completedRooms[roomIndex];
  double centerX = 0;
  double centerY = 0;
  for (final vertex in room.vertices) {
    centerX += vertex.dx;
    centerY += vertex.dy;
  }
  centerX /= room.vertices.length;
  centerY /= room.vertices.length;

  if (!state.mounted) return;
  final screenSize = MediaQuery.of(state.context).size;

  state.setState(() {
    state._selectedRoomIndex = roomIndex;
    if (pan) {
      state._vp.worldOriginMm =
          Offset(centerX, centerY) -
          Offset(screenSize.width / 2, screenSize.height / 2) * state._vp.mmPerPx;
    }
  });

  state.widget.onRoomsChanged?.call(
    state._completedRooms,
    state._useImperial,
    state._selectedRoomIndex,
  );
}

Offset? _selectedRoomCenterScreenFor(PlanCanvasState state) {
  final idx = state._selectedRoomIndex;
  if (idx == null || idx < 0 || idx >= state._completedRooms.length) {
    return null;
  }
  final room = state._completedRooms[idx];
  if (room.vertices.isEmpty) return null;
  final centerWorld = state._getRoomCenter(room.vertices);
  return state._vp.worldToScreen(centerWorld);
}

/// Screen-space bounding box of the selected room (null when none selected).
Rect? _selectedRoomBoundsScreenFor(PlanCanvasState state) {
  final idx = state._selectedRoomIndex;
  if (idx == null || idx < 0 || idx >= state._completedRooms.length) {
    return null;
  }
  final verts = state._completedRooms[idx].vertices;
  if (verts.isEmpty) return null;
  double minX = double.infinity, minY = double.infinity;
  double maxX = -double.infinity, maxY = -double.infinity;
  for (final v in verts) {
    final s = state._vp.worldToScreen(v);
    if (s.dx < minX) minX = s.dx;
    if (s.dy < minY) minY = s.dy;
    if (s.dx > maxX) maxX = s.dx;
    if (s.dy > maxY) maxY = s.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Top-right anchor (screen space) for the three-dots room actions button.
/// Sits just outside the room's top-right corner, clamped so it stays clear of
/// the center on small/zoomed-out rooms.
Offset? _roomDotsScreenPosFor(PlanCanvasState state) {
  final center = state._selectedRoomCenterScreen;
  final bounds = _selectedRoomBoundsScreenFor(state);
  if (center == null || bounds == null) return null;
  const gap = PlanCanvasState._roomControlGapPx;
  const minOffset = PlanCanvasState._roomControlMinOffsetPx;
  final dx = math.max(bounds.right + gap, center.dx + minOffset);
  final dy = math.min(bounds.top - gap, center.dy - minOffset);
  return Offset(dx, dy);
}

({int roomIndex, int vertexIndex})? _findVertexAtPositionImpl(
  PlanCanvasState state,
  Offset screenPosition,
) {
  double closestDistance = PlanCanvasState._vertexSelectTolerancePx;
  ({int roomIndex, int vertexIndex})? closestVertex;

  for (int roomIdx = 0; roomIdx < state._completedRooms.length; roomIdx++) {
    final room = state._completedRooms[roomIdx];
    final uniqueVertices =
        room.vertices.length > 1 && room.vertices.first == room.vertices.last
        ? room.vertices.sublist(0, room.vertices.length - 1)
        : room.vertices;

    for (int vertexIdx = 0; vertexIdx < uniqueVertices.length; vertexIdx++) {
      final vertexScreen = state._vp.worldToScreen(uniqueVertices[vertexIdx]);
      final distance = (screenPosition - vertexScreen).distance;

      if (distance < closestDistance) {
        closestDistance = distance;
        closestVertex = (roomIndex: roomIdx, vertexIndex: vertexIdx);
      }
    }
  }

  return closestVertex;
}

List<Room> _safeCopyRoomsImpl(List<Room>? rooms) {
  if (rooms == null) {
    debugPrint('Warning: rooms list is null, returning empty');
    return [];
  }

  try {
    return List<Room>.from(rooms);
  } catch (e) {
    debugPrint('Warning: Could not copy rooms list, returning empty: $e');
    return [];
  }
}

void _deleteRoomAtIndex(PlanCanvasState state, int roomIndex) {
  if (roomIndex < 0 || roomIndex >= state._completedRooms.length) return;

  state.setState(() {
    state._completedRooms.removeAt(roomIndex);
    state._openings.removeWhere((o) => o.roomIndex == roomIndex);
    final newOpenings = state._openings.map((o) {
      if (o.roomIndex > roomIndex) {
        return Opening(
          roomIndex: o.roomIndex - 1,
          edgeIndex: o.edgeIndex,
          offsetMm: o.offsetMm,
          widthMm: o.widthMm,
          isDoor: o.isDoor,
        );
      }
      return o;
    }).toList();
    state._openings
      ..clear()
      ..addAll(newOpenings);

    final newAssignments = <int, int>{};
    for (final entry in state._roomCarpetAssignments.entries) {
      if (entry.key == roomIndex) continue;
      newAssignments[entry.key > roomIndex ? entry.key - 1 : entry.key] =
          entry.value;
    }
    state._roomCarpetAssignments
      ..clear()
      ..addAll(newAssignments);

    final newSeamOverrides = <int, List<double>>{};
    for (final entry in state._roomCarpetSeamOverrides.entries) {
      if (entry.key == roomIndex) continue;
      newSeamOverrides[entry.key > roomIndex ? entry.key - 1 : entry.key] =
          entry.value;
    }
    state._roomCarpetSeamOverrides
      ..clear()
      ..addAll(newSeamOverrides);

    final newSeamLayDirectionDeg = <int, double>{};
    for (final entry in state._roomCarpetSeamLayDirectionDeg.entries) {
      if (entry.key == roomIndex) continue;
      newSeamLayDirectionDeg[entry.key > roomIndex
              ? entry.key - 1
              : entry.key] =
          entry.value;
    }
    state._roomCarpetSeamLayDirectionDeg
      ..clear()
      ..addAll(newSeamLayDirectionDeg);

    final newLayoutVariantIndex = <int, int>{};
    for (final entry in state._roomCarpetLayoutVariantIndex.entries) {
      if (entry.key == roomIndex) continue;
      newLayoutVariantIndex[entry.key > roomIndex
              ? entry.key - 1
              : entry.key] =
          entry.value;
    }
    state._roomCarpetLayoutVariantIndex
      ..clear()
      ..addAll(newLayoutVariantIndex);

    final newStripPieceLengths = <int, List<List<double>>>{};
    for (final entry
        in state._roomCarpetStripPieceLengthsOverrideMm.entries) {
      if (entry.key == roomIndex) continue;
      newStripPieceLengths[entry.key > roomIndex
              ? entry.key - 1
              : entry.key] =
          entry.value;
    }
    state._roomCarpetStripPieceLengthsOverrideMm
      ..clear()
      ..addAll(newStripPieceLengths);

    if (state._selectedRoomIndex == roomIndex) {
      state._selectedRoomIndex = null;
    } else if (state._selectedRoomIndex != null &&
        state._selectedRoomIndex! > roomIndex) {
      state._selectedRoomIndex = state._selectedRoomIndex! - 1;
    }

    state._hasUnsavedChanges = true;
    state._saveHistoryState();
  });

  state.widget.onRoomsChanged?.call(
    state._completedRooms,
    state._useImperial,
    state._selectedRoomIndex,
  );
  state.widget.onRoomCarpetAssignmentsChanged?.call(
    Map<int, int>.from(state._roomCarpetAssignments),
  );
}

Future<void> _showDeleteRoomDialogImpl(
  PlanCanvasState state,
  int roomIndex,
) async {
  if (roomIndex < 0 || roomIndex >= state._completedRooms.length) return;

  final room = state._completedRooms[roomIndex];
  final roomName = room.name ?? 'Room ${roomIndex + 1}';

  final context = state.context;
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Room'),
      content: Text(
        'Are you sure you want to delete "$roomName"?\n\nThis action cannot be undone.',
      ),
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

  if (!state.mounted) return;
  if (confirmed == true) {
    _deleteRoomAtIndex(state, roomIndex);
  }
}
