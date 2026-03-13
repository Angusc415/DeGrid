part of 'plan_canvas.dart';

const String _backgroundImageDir = 'degrid_backgrounds';

Future<void> _initializeDatabase(PlanCanvasState state) async {
  try {
    debugPrint('PlanCanvas: Initializing database...');

    if (kIsWeb) {
      debugPrint('PlanCanvas: Running on web - database not supported');
      state.setState(() {
        state._isInitializing = false;
      });
      if (state.mounted) {
        ScaffoldMessenger.of(state.context).showSnackBar(
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
      state.setState(() {
        state._currentProjectName = state.widget.initialProjectName;
      });
      return;
    }

    state._db = AppDatabase();
    state._projectService = ProjectService(state._db!);
    debugPrint('PlanCanvas: Database and service created');

    try {
      await state._db!.customSelect('SELECT 1', readsFrom: {}).get();
      debugPrint('PlanCanvas: Database connection established');
    } catch (e) {
      debugPrint(
        'PlanCanvas: Warning - Could not pre-initialize database connection: $e',
      );
    }

    state.setState(() {
      state._isInitializing = false;
    });
    debugPrint('PlanCanvas: Initialization flag set to false');

    if (state.widget.projectId != null) {
      await _loadProject(state, state.widget.projectId!);
    } else {
      state.setState(() {
        state._currentProjectName = state.widget.initialProjectName;
      });
    }
  } catch (e, stackTrace) {
    debugPrint('PlanCanvas: Error initializing database: $e');
    debugPrint('PlanCanvas: Stack trace: $stackTrace');
    state.setState(() {
      state._isInitializing = false;
    });
    if (state.mounted) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        SnackBar(
          content: Text(
            'Error initializing database: $e\n\nPlease restart the app.',
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }
}

Future<void> _loadProject(PlanCanvasState state, int projectId) async {
  if (state._projectService == null) {
    debugPrint('Cannot load project: _projectService is null');
    return;
  }

  state.setState(() {
    state._isLoading = true;
  });

  try {
    debugPrint('Loading project $projectId...');
    final project = await state._projectService!.getProject(projectId);
    debugPrint(
      'Project loaded: ${project?.name}, rooms: ${project?.rooms.length}',
    );

    if (project != null && state.mounted) {
      state.setState(() {
        state._currentProjectId = project.id;
        state._currentProjectName = project.name;
        state._useImperial = project.useImperial;
        state._wallWidthMm = project.wallWidthMm;
        state._doorThicknessMm = project.doorThicknessMm;
        state._completedRooms
          ..clear()
          ..addAll(project.rooms);
        state._openings
          ..clear()
          ..addAll(project.openings);
        state._carpetProducts
          ..clear()
          ..addAll(project.carpetProducts);
        state._roomCarpetAssignments
          ..clear()
          ..addAll(project.roomCarpetAssignments);
        state._roomCarpetSeamOverrides
          ..clear()
          ..addAll(project.roomCarpetSeamOverrides);
        state._roomCarpetSeamLayDirectionDeg.clear();
        state.widget.onRoomCarpetAssignmentsChanged?.call(
          Map<int, int>.from(state._roomCarpetAssignments),
        );

        if (project.viewportState != null) {
          final restoredViewport = project.viewportState!.toViewport();
          state._vp.mmPerPx = restoredViewport.mmPerPx;
          state._vp.worldOriginMm = restoredViewport.worldOriginMm;
        }
        state._backgroundImagePath = project.backgroundImagePath;
        state._backgroundImageState = project.backgroundImageState;
        state._backgroundImage = null;
        state._hasUnsavedChanges = false;
        state._isLoading = false;
      });
      if (project.backgroundImagePath != null && !kIsWeb) {
        _loadBackgroundImageFromPath(state, project.backgroundImagePath!);
      }
      state.widget.onRoomsChanged?.call(
        state._completedRooms,
        state._useImperial,
        state._selectedRoomIndex,
      );

      state._history.clear();
      state._historyIndex = -1;
      state._saveHistoryState();
    }
  } catch (e, stackTrace) {
    debugPrint('Error loading project: $e');
    debugPrint('Stack trace: $stackTrace');
    state.setState(() {
      state._isLoading = false;
    });
    if (state.mounted) {
      ScaffoldMessenger.of(
        state.context,
      ).showSnackBar(SnackBar(content: Text('Error loading project: $e')));
    }
  }
}

Future<void> _loadBackgroundImageFromPath(
  PlanCanvasState state,
  String relativePath,
) async {
  if (kIsWeb) return;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final fullPath = path.join(dir.path, relativePath);
    final bytes = await readBackgroundImageBytes(fullPath);
    if (bytes == null || !state.mounted) return;
    final image = await decodeImageFromList(bytes);
    if (!state.mounted) return;
    state.setState(() {
      state._backgroundImage?.dispose();
      state._backgroundImage = image;
    });
  } catch (e) {
    debugPrint('PlanCanvas: failed to load background image: $e');
  }
}

Future<void> _importFloorplanImage(PlanCanvasState state) async {
  if (kIsWeb) {
    if (state.mounted) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        const SnackBar(
          content: Text(
            'Import floorplan is not supported on web. Use a native app.',
          ),
        ),
      );
    }
    return;
  }
  if (state._currentProjectId == null) {
    if (state.mounted) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open or create a project first to import a floorplan.',
          ),
        ),
      );
    }
    return;
  }

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await readBackgroundImageBytes(file.path!);
    }
    if (bytes == null || bytes.isEmpty) {
      if (state.mounted) {
        ScaffoldMessenger.of(state.context).showSnackBar(
          const SnackBar(content: Text('Could not read image file')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final bgDir = path.join(dir.path, _backgroundImageDir);
    await ensureBackgroundImageDir(bgDir);
    final ext = path.extension(file.name).isEmpty
        ? '.png'
        : path.extension(file.name);
    final name =
        'bg_${state._currentProjectId ?? 0}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final relativePath = path.join(_backgroundImageDir, name);
    final destPath = path.join(dir.path, relativePath);
    await writeBackgroundImageBytes(destPath, bytes);
    if (!state.mounted) return;

    state.setState(() {
      state._backgroundImagePath = relativePath;
      state._backgroundImageState = BackgroundImageState();
      state._hasUnsavedChanges = true;
    });
    await _loadBackgroundImageFromPath(state, relativePath);
    if (state.mounted) {
      state._fitFloorplanToView();
    }
    await _saveProject(state);
    if (state.mounted) {
      ScaffoldMessenger.of(
        state.context,
      ).showSnackBar(const SnackBar(content: Text('Floorplan image imported')));
    }
  } catch (e) {
    debugPrint('Import floorplan error: $e');
    if (state.mounted) {
      ScaffoldMessenger.of(
        state.context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

Future<void> _saveProject(PlanCanvasState state) async {
  debugPrint('PlanCanvas: _saveProject called');

  if (kIsWeb) {
    if (state.mounted) {
      ScaffoldMessenger.of(state.context).showSnackBar(
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

  if (state._isInitializing) {
    debugPrint('PlanCanvas: Waiting for database initialization...');
    int waitCount = 0;
    const maxWait = 50;
    while (state._isInitializing && waitCount < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
  }

  if (state._projectService == null) {
    debugPrint(
      'PlanCanvas: Cannot save project: _projectService is null after initialization',
    );
    if (!kIsWeb) {
      debugPrint('PlanCanvas: Attempting to re-initialize database...');
      try {
        state._db = AppDatabase();
        state._projectService = ProjectService(state._db!);
        debugPrint('PlanCanvas: Database re-initialized successfully');
      } catch (e) {
        debugPrint('PlanCanvas: Failed to re-initialize: $e');
        if (state.mounted) {
          ScaffoldMessenger.of(state.context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database not initialized. Please restart the app.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    } else {
      if (state.mounted) {
        ScaffoldMessenger.of(state.context).showSnackBar(
          const SnackBar(
            content: Text('Database is not supported on web.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
  }

  String? projectName = state._currentProjectName;
  if (projectName == null || projectName.isEmpty) {
    debugPrint('No project name, prompting user...');
    projectName = await _promptProjectName(state);
    if (projectName == null || projectName.isEmpty) {
      debugPrint('User cancelled project name prompt');
      return;
    }
    debugPrint('User entered project name: $projectName');
  }

  state.setState(() {
    state._isLoading = true;
  });

  try {
    debugPrint(
      'Saving project: name=$projectName, id=${state._currentProjectId}, rooms=${state._completedRooms.length}, viewport=${state._vp.mmPerPx}',
    );
    final projectId = await state._projectService!.saveProject(
      id: state._currentProjectId,
      name: projectName,
      rooms: state._completedRooms,
      openings: state._openings,
      carpetProducts: state._carpetProducts,
      roomCarpetAssignments: state._roomCarpetAssignments,
      roomCarpetSeamOverrides: state._roomCarpetSeamOverrides,
      viewport: state._vp,
      useImperial: state._useImperial,
      backgroundImagePath: state._backgroundImagePath,
      backgroundImageState: state._backgroundImageState,
      wallWidthMm: state._wallWidthMm,
      doorThicknessMm: state._doorThicknessMm,
    );
    debugPrint('Project saved successfully with ID: $projectId');

    state.setState(() {
      state._currentProjectId = projectId;
      state._currentProjectName = projectName;
      state._hasUnsavedChanges = false;
      state._isLoading = false;
    });

    if (state.mounted) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        SnackBar(
          content: Text('Project "$projectName" saved successfully!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e, stackTrace) {
    debugPrint('Error saving project: $e');
    debugPrint('Stack trace: $stackTrace');
    state.setState(() {
      state._isLoading = false;
    });
    if (state.mounted) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        SnackBar(
          content: Text('Error saving project: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

Future<String?> _promptProjectName(PlanCanvasState state) async {
  final controller = TextEditingController(
    text: state._currentProjectName ?? '',
  );
  final confirmed = await showDialog<String>(
    context: state.context,
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
