part of 'plan_canvas.dart';

void _closeDraftRoomImpl(PlanCanvasState state) {
  if (state._draftRoomVertices == null ||
      state._draftRoomVertices!.length < 3) {
    return;
  }

  state.setState(() {
    List<Offset> vertices = List<Offset>.from(state._draftRoomVertices!);
    if (vertices.length == 4) {
      final rect = PlanCanvasState._makeRectangleFromQuad(vertices);
      if (rect != null) vertices = rect;
    }
    if (vertices.length >= 3) {
      vertices = List<Offset>.from(vertices);
      vertices.add(vertices.first);
      state._completedRooms.add(Room(vertices: vertices, name: null));
      state._hasUnsavedChanges = true;
    }

    state._draftRoomVertices = null;
    state._draftStartedFromVertexOrDoor = false;
    state._drawFromStart = false;
    state._hoverPositionWorldMm = null;
    state._lengthInputController.clear();
    state._desiredLengthMm = null;
    state._originalLastSegmentDirection = null;
    state._originalSecondToLastVertex = null;
    state._saveHistoryState();
  });

  state.widget.onRoomsChanged?.call(
    state._completedRooms,
    state._useImperial,
    state._selectedRoomIndex,
  );
}

void _onLengthInputChangedImpl(PlanCanvasState state, String value) {
  state.setState(() {
    if (value.trim().isEmpty) {
      state._desiredLengthMm = null;
      state._originalLastSegmentDirection = null;
      state._originalSecondToLastVertex = null;
      return;
    }

    double? parsed;
    final simpleNumber = double.tryParse(value.trim());
    if (simpleNumber != null && simpleNumber > 0) {
      if (state._useImperial) {
        const mmPerFoot = 304.8;
        parsed = simpleNumber * mmPerFoot;
      } else {
        parsed = simpleNumber;
      }
    } else {
      parsed = _parseLengthInputImpl(state, value);
    }

    if (parsed != null && parsed > 0) {
      state._desiredLengthMm = parsed;

      if (state._draftRoomVertices != null &&
          state._draftRoomVertices!.length >= 2) {
        final secondToLast = state._draftDrawingFromPrev!;
        final lastVertex = state._draftDrawingFrom;
        if (state._originalLastSegmentDirection == null ||
            state._originalSecondToLastVertex == null) {
          final direction = lastVertex - secondToLast;
          final directionLength = direction.distance;
          if (directionLength > 0) {
            state._originalSecondToLastVertex = secondToLast;
            state._originalLastSegmentDirection = Offset(
              direction.dx / directionLength,
              direction.dy / directionLength,
            );
          } else {
            return;
          }
        }

        if (state._originalLastSegmentDirection != null &&
            state._originalSecondToLastVertex != null) {
          final newLastVertex =
              state._originalSecondToLastVertex! +
              Offset(
                state._originalLastSegmentDirection!.dx *
                    state._desiredLengthMm!,
                state._originalLastSegmentDirection!.dy *
                    state._desiredLengthMm!,
              );
          final updatedVertices = List<Offset>.from(state._draftRoomVertices!);
          if (state._drawFromStart) {
            updatedVertices[0] = state._snapToGrid(newLastVertex);
          } else {
            updatedVertices[updatedVertices.length - 1] = state._snapToGrid(
              newLastVertex,
            );
          }
          state._draftRoomVertices = updatedVertices;
          state._hoverPositionWorldMm = state._drawFromStart
              ? updatedVertices.first
              : updatedVertices.last;
          state._hasUnsavedChanges = true;
        }
      }
    } else {
      state._desiredLengthMm = null;
      state._originalLastSegmentDirection = null;
      state._originalSecondToLastVertex = null;
    }
  });
}

double? _parseLengthInputImpl(PlanCanvasState state, String input) {
  if (input.trim().isEmpty) return null;

  final trimmed = input.trim().toLowerCase();

  if (state._useImperial) {
    const mmPerFoot = 304.8;
    const mmPerInch = 25.4;
    final pattern =
        '^(\\d+(?:\\.\\d+)?)\\s*(?:[\'"]|ft)?\\s*(?:(\\d+(?:\\.\\d+)?)\\s*(?:[\'"]|inch)?)?\$';
    final regex = RegExp(pattern);
    final match = regex.firstMatch(trimmed);

    if (match != null) {
      final feetStr = match.group(1);
      final inchesStr = match.group(2);

      if (feetStr != null) {
        final feet = double.tryParse(feetStr) ?? 0;
        final inches = inchesStr != null
            ? (double.tryParse(inchesStr) ?? 0)
            : 0;
        return (feet * mmPerFoot) + (inches * mmPerInch);
      }
    }

    final feet = double.tryParse(trimmed);
    if (feet != null) {
      return feet * mmPerFoot;
    }
  } else {
    const mmPerCm = 10.0;
    if (trimmed.endsWith('cm')) {
      final cm = double.tryParse(
        trimmed.substring(0, trimmed.length - 2).trim(),
      );
      if (cm != null) return cm * mmPerCm;
    } else if (trimmed.endsWith('m')) {
      final meters = double.tryParse(
        trimmed.substring(0, trimmed.length - 1).trim(),
      );
      if (meters != null) return meters * 1000;
    } else if (trimmed.endsWith('mm')) {
      final mm = double.tryParse(
        trimmed.substring(0, trimmed.length - 2).trim(),
      );
      if (mm != null) return mm;
    } else {
      final mm = double.tryParse(trimmed);
      if (mm != null) return mm;
    }
  }

  return null;
}

Future<String?> _showRoomNameDialogImpl(
  PlanCanvasState state, {
  String? initialName,
}) async {
  final context = state.context;
  if (!context.mounted) return null;

  final controller = TextEditingController(text: initialName ?? '');

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initialName == null ? 'Name Room' : 'Edit Room Name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter room name',
          border: OutlineInputBorder(),
          helperText: 'Leave empty to remove name',
        ),
        onSubmitted: (value) {
          Navigator.of(context).pop(value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
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

Future<void> _showAddDoorDialogImpl(
  PlanCanvasState state, {
  required int roomIndex,
  required int edgeIndex,
  required double edgeLenMm,
}) async {
  final context = state.context;
  if (!context.mounted) return;
  final edgeLenRound = (edgeLenMm.round()).toDouble();
  double widthMm = 900;
  bool centerOnWall = true;
  bool isDoor = true;
  double offsetMm = (edgeLenRound - widthMm) / 2;
  final widthController = TextEditingController(text: '900');
  final offsetController = TextEditingController(
    text: offsetMm.round().toString(),
  );

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          void updateOffsetFromCenter() {
            if (centerOnWall) {
              offsetMm =
                  (edgeLenRound - widthMm).clamp(0.0, double.infinity) / 2;
              offsetController.text = offsetMm.round().toString();
            }
          }

          return AlertDialog(
            title: const Text('Add door or opening'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wall length: ${edgeLenRound.round()} mm',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Door'),
                        selected: isDoor,
                        onSelected: (v) => setDialogState(() => isDoor = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Opening'),
                        selected: !isDoor,
                        onSelected: (v) => setDialogState(() => isDoor = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isDoor ? 'Door width (mm)' : 'Opening width (mm)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<double>(
                    value: widthMm,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 600, child: Text('600 mm')),
                      DropdownMenuItem(value: 750, child: Text('750 mm')),
                      DropdownMenuItem(
                        value: 900,
                        child: Text('900 mm (standard)'),
                      ),
                      DropdownMenuItem(value: 1000, child: Text('1000 mm')),
                      DropdownMenuItem(value: 1200, child: Text('1200 mm')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        widthMm = v;
                        widthController.text = v.round().toString();
                        updateOffsetFromCenter();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: centerOnWall,
                        onChanged: (v) {
                          setDialogState(() {
                            centerOnWall = v ?? true;
                            if (centerOnWall) {
                              offsetMm =
                                  (edgeLenRound - widthMm).clamp(
                                    0.0,
                                    double.infinity,
                                  ) /
                                  2;
                              offsetController.text = offsetMm
                                  .round()
                                  .toString();
                            }
                          });
                        },
                      ),
                      const Expanded(child: Text('Center on wall')),
                    ],
                  ),
                  if (!centerOnWall) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Offset from wall start (mm)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: offsetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '0',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (state.mounted) {
                    state.setState(() => state._pendingDoorEdge = null);
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final parsedWidth =
                      double.tryParse(widthController.text) ?? widthMm;
                  final width = parsedWidth.clamp(0.0, edgeLenRound);
                  final off = centerOnWall
                      ? (edgeLenRound - width) / 2
                      : (double.tryParse(offsetController.text) ?? offsetMm)
                            .clamp(0.0, edgeLenRound - width);
                  if (!state.mounted) return;
                  state.setState(() {
                    final primary = Opening(
                      roomIndex: roomIndex,
                      edgeIndex: edgeIndex,
                      offsetMm: off,
                      widthMm: width,
                      isDoor: isDoor,
                    );
                    state._openings.add(primary);
                    state._addOpeningOnAdjacentRoom(primary);
                    state._pendingDoorEdge = null;
                    state._hasUnsavedChanges = true;
                  });
                  Navigator.of(dialogContext).pop();
                },
                child: Text(isDoor ? 'Place door' : 'Place opening'),
              ),
            ],
          );
        },
      );
    },
  );

  if (state.mounted && state._pendingDoorEdge != null) {
    state.setState(() => state._pendingDoorEdge = null);
  }
}

Future<void> _editRoomNameImpl(PlanCanvasState state, int roomIndex) async {
  if (roomIndex < 0 || roomIndex >= state._completedRooms.length) return;

  final room = state._completedRooms[roomIndex];
  final newName = await state._showRoomNameDialog(initialName: room.name);

  if (!state.mounted) return;

  state.setState(() {
    final updatedRoom = Room(
      vertices: room.vertices,
      name: newName?.trim().isNotEmpty == true ? newName!.trim() : null,
    );
    state._completedRooms[roomIndex] = updatedRoom;
    state._hasUnsavedChanges = true;
    state._saveHistoryState();
  });
}
