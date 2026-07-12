import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../geometry/room.dart';
import '../geometry/opening.dart';
import '../geometry/carpet_product.dart';
import '../models/project.dart';
import '../roll_planning/carpet_layout_options.dart';
import '../../ui/canvas/viewport.dart';

/// Thrown when a stored project field fails to deserialize.
///
/// Load must fail loudly rather than silently substituting empty data:
/// otherwise the next save would overwrite the (still recoverable) stored
/// JSON with the empty in-memory state and make the loss permanent.
class ProjectDataException implements Exception {
  final String message;
  ProjectDataException(this.message);

  @override
  String toString() => 'ProjectDataException: $message';
}

/// Service layer for project database operations.
/// Handles all CRUD operations for projects and rooms.
class ProjectService {
  final AppDatabase _db;

  ProjectService(this._db);

  /// Get all projects (without rooms).
  /// Returns a list of project summaries.
  /// If [folderId] is provided, returns only projects in that folder.
  /// If [folderId] is 0, returns only projects at root (no folder).
  Future<List<Project>> getAllProjects({int? folderId}) async {
    final query = _db.select(_db.projects)
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);
    
    if (folderId != null) {
      if (folderId == 0) {
        query.where((p) => p.folderId.isNull());
      } else {
        query.where((p) => p.folderId.equals(folderId));
      }
    }
    
    return await query.get();
  }

  /// Get all folders, optionally filtered by parent.
  /// [parentId] null = root folders only; [parentId] = id = children of that folder.
  Future<List<Folder>> getFolders({int? parentId}) async {
    final query = _db.select(_db.folders)
      ..orderBy([(f) => OrderingTerm.asc(f.orderIndex), (f) => OrderingTerm.asc(f.name)]);
    
    if (parentId == null) {
      query.where((f) => f.parentId.isNull());
    } else {
      query.where((f) => f.parentId.equals(parentId));
    }
    
    return await query.get();
  }

  /// Create a new folder.
  Future<int> createFolder({required String name, int? parentId}) async {
    return await _db.into(_db.folders).insert(
      FoldersCompanion.insert(
        name: name,
        parentId: Value(parentId),
      ),
    );
  }

  /// Delete a folder. Projects in the folder move to root (folderId set null).
  Future<void> deleteFolder(int id) async {
    await (_db.update(_db.projects)..where((p) => p.folderId.equals(id)))
        .write(const ProjectsCompanion(folderId: Value(null)));
    await (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
  }

  /// Move a project to a folder. [folderId] null = root.
  Future<void> moveProjectToFolder(int projectId, int? folderId) async {
    await (_db.update(_db.projects)..where((p) => p.id.equals(projectId)))
        .write(ProjectsCompanion(folderId: Value(folderId), updatedAt: Value(DateTime.now())));
  }

  /// Move a folder to a new parent. [newParentId] null = root.
  /// Caller must ensure newParentId is not the folder itself or a descendant (to avoid cycles).
  Future<void> moveFolderToFolder(int folderId, int? newParentId) async {
    await (_db.update(_db.folders)..where((f) => f.id.equals(folderId)))
        .write(FoldersCompanion(parentId: Value(newParentId)));
  }

  /// Runs [parse] for a user-data field of [project], converting any failure
  /// into a [ProjectDataException] that names the project and field.
  ///
  /// The stored JSON stays untouched in the database, so the project remains
  /// recoverable; the caller (load path) surfaces the error instead of
  /// silently continuing with empty data that a later save would persist.
  T _parseUserData<T>(Project project, String field, T Function() parse) {
    try {
      return parse();
    } catch (e) {
      throw ProjectDataException(
        'Project "${project.name}" (id ${project.id}): failed to parse $field: $e',
      );
    }
  }

  /// Get a single project with all its rooms.
  /// Returns null if project doesn't exist.
  Future<ProjectModel?> getProject(int id) async {
    // Get project
    final projectQuery = _db.select(_db.projects)..where((p) => p.id.equals(id));
    final project = await projectQuery.getSingleOrNull();
    
    if (project == null) return null;

    // Get all rooms for this project
    final roomsQuery = _db.select(_db.rooms)
      ..where((r) => r.projectId.equals(id))
      ..orderBy([(r) => OrderingTerm.asc(r.orderIndex)]);
    
    final roomDataList = await roomsQuery.get();

    // Convert RoomData to Room
    final rooms = roomDataList.map((roomData) {
      return Room.fromJsonString(roomData.verticesJson);
    }).toList();

    // Parse viewport state if available
    PlanViewportState? viewportState;
    if (project.viewportJson != null && project.viewportJson!.isNotEmpty) {
      try {
        final viewportJson = jsonDecode(project.viewportJson!) as Map<String, dynamic>;
        viewportState = PlanViewportState.fromJson(viewportJson);
      } catch (e) {
        viewportState = null;
      }
    }

    // Parse background image state if available
    BackgroundImageState? backgroundImageState;
    if (project.backgroundImageJson != null && project.backgroundImageJson!.isNotEmpty) {
      try {
        final bgJson = jsonDecode(project.backgroundImageJson!) as Map<String, dynamic>;
        backgroundImageState = BackgroundImageState.fromJson(bgJson);
      } catch (e) {
        backgroundImageState = null;
      }
    }

    // Parse user data fields. Unlike viewport/background-image state above
    // (cosmetic, safe to reset), a parse failure here must abort the load via
    // ProjectDataException — see _parseUserData. Silently substituting empty
    // collections would let the next save permanently wipe the stored data.

    // Parse openings if available
    List<Opening> openings = const [];
    if (project.openingsJson != null && project.openingsJson!.isNotEmpty) {
      openings = _parseUserData(project, 'openings', () {
        final list = jsonDecode(project.openingsJson!) as List<dynamic>;
        return Opening.listFromJson(list);
      });
    }

    // Parse carpet products if available
    List<CarpetProduct> carpetProducts = const [];
    if (project.carpetProductsJson != null && project.carpetProductsJson!.isNotEmpty) {
      carpetProducts = _parseUserData(project, 'carpet products', () {
        final list = jsonDecode(project.carpetProductsJson!) as List<dynamic>;
        return CarpetProduct.listFromJson(list);
      });
    }

    // Parse room carpet assignments if available
    Map<int, int> roomCarpetAssignments = {};
    if (project.roomCarpetAssignmentsJson != null && project.roomCarpetAssignmentsJson!.isNotEmpty) {
      roomCarpetAssignments = _parseUserData(project, 'room carpet assignments', () {
        final result = <int, int>{};
        final list = jsonDecode(project.roomCarpetAssignmentsJson!) as List<dynamic>;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final ri = m['roomIndex'] as int?;
          final pi = m['productIndex'] as int?;
          if (ri != null && pi != null) result[ri] = pi;
        }
        return result;
      });
    }

    // Parse room carpet seam overrides if available
    Map<int, List<double>> roomCarpetSeamOverrides = {};
    if (project.roomCarpetSeamOverridesJson != null && project.roomCarpetSeamOverridesJson!.isNotEmpty) {
      roomCarpetSeamOverrides = _parseUserData(project, 'seam overrides', () {
        final result = <int, List<double>>{};
        final map = jsonDecode(project.roomCarpetSeamOverridesJson!) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final roomIndex = int.tryParse(entry.key);
          if (roomIndex == null) continue;
          final list = entry.value as List<dynamic>?;
          if (list == null) continue;
          result[roomIndex] = list.map((e) => (e as num).toDouble()).toList();
        }
        return result;
      });
    }

    // Parse locked seam lay directions if available
    Map<int, double> roomCarpetSeamLayDirectionDeg = {};
    if (project.roomCarpetSeamLayDirectionDegJson != null &&
        project.roomCarpetSeamLayDirectionDegJson!.isNotEmpty) {
      roomCarpetSeamLayDirectionDeg = _parseUserData(project, 'seam lay directions', () {
        final result = <int, double>{};
        final map = jsonDecode(project.roomCarpetSeamLayDirectionDegJson!)
            as Map<String, dynamic>;
        for (final entry in map.entries) {
          final roomIndex = int.tryParse(entry.key);
          final deg = entry.value as num?;
          if (roomIndex == null || deg == null) continue;
          result[roomIndex] = deg.toDouble();
        }
        return result;
      });
    }

    // Parse per-room layout variant indices if available
    Map<int, int> roomCarpetLayoutVariantIndex = {};
    if (project.roomCarpetLayoutVariantIndexJson != null &&
        project.roomCarpetLayoutVariantIndexJson!.isNotEmpty) {
      roomCarpetLayoutVariantIndex = _parseUserData(project, 'layout variants', () {
        final result = <int, int>{};
        final map = jsonDecode(project.roomCarpetLayoutVariantIndexJson!)
            as Map<String, dynamic>;
        for (final entry in map.entries) {
          final roomIndex = int.tryParse(entry.key);
          final variant = entry.value as int?;
          if (roomIndex == null || variant == null) continue;
          result[roomIndex] = variant;
        }
        return result;
      });
    }

    // Parse per-room piece-length overrides if available
    Map<int, List<List<double>>> roomCarpetStripPieceLengthsOverrideMm = {};
    if (project.roomCarpetStripPieceLengthsJson != null &&
        project.roomCarpetStripPieceLengthsJson!.isNotEmpty) {
      roomCarpetStripPieceLengthsOverrideMm =
          _parseUserData(project, 'strip piece-length overrides', () {
        final result = <int, List<List<double>>>{};
        final map = jsonDecode(project.roomCarpetStripPieceLengthsJson!)
            as Map<String, dynamic>;
        for (final entry in map.entries) {
          final roomIndex = int.tryParse(entry.key);
          final strips = entry.value as List<dynamic>?;
          if (roomIndex == null || strips == null) continue;
          result[roomIndex] = strips
              .map((s) => (s as List<dynamic>)
                  .map((e) => (e as num).toDouble())
                  .toList())
              .toList();
        }
        return result;
      });
    }

    final legacyStripSplitStrategy = StripSplitStrategy.values[
        project.stripSplitStrategy
            .clamp(0, StripSplitStrategy.values.length - 1)];

    // Full planning settings from JSON when present; older projects fall back
    // to defaults seeded with the legacy waste + strategy columns. A JSON blob
    // written before the strategy moved into the settings lacks the key, so
    // the legacy column fills it in.
    CarpetPlanningSettings carpetPlanningSettings = CarpetPlanningSettings(
      wasteAllowancePercent: project.carpetWasteAllowancePercent,
      stripSplitStrategy: legacyStripSplitStrategy,
    );
    if (project.carpetPlanningSettingsJson != null &&
        project.carpetPlanningSettingsJson!.isNotEmpty) {
      carpetPlanningSettings =
          _parseUserData(project, 'carpet planning settings', () {
        final map = jsonDecode(project.carpetPlanningSettingsJson!)
            as Map<String, dynamic>;
        var settings = CarpetPlanningSettings.fromJson(map);
        if (!map.containsKey('stripSplitStrategy')) {
          settings =
              settings.copyWith(stripSplitStrategy: legacyStripSplitStrategy);
        }
        return settings;
      });
    }

    return ProjectModel(
      id: project.id,
      name: project.name,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      useImperial: project.useImperial,
      rooms: rooms,
      openings: openings,
      carpetProducts: carpetProducts,
      roomCarpetAssignments: roomCarpetAssignments,
      roomCarpetSeamOverrides: roomCarpetSeamOverrides,
      roomCarpetSeamLayDirectionDeg: roomCarpetSeamLayDirectionDeg,
      roomCarpetLayoutVariantIndex: roomCarpetLayoutVariantIndex,
      roomCarpetStripPieceLengthsOverrideMm:
          roomCarpetStripPieceLengthsOverrideMm,
      carpetWasteAllowancePercent: project.carpetWasteAllowancePercent,
      carpetPlanningSettings: carpetPlanningSettings,
      viewportState: viewportState,
      backgroundImagePath: project.backgroundImagePath,
      backgroundImageState: backgroundImageState,
      wallWidthMm: project.wallWidthMm,
      doorThicknessMm: project.doorThicknessMm,
    );
  }

  /// Create a new project with rooms.
  /// Returns the created project ID.
  Future<int> createProject({
    required String name,
    required List<Room> rooms,
    required PlanViewport viewport,
    bool useImperial = false,
    int? folderId,
    double wallWidthMm = 70.0,
    double? doorThicknessMm,
  }) async {
    // Serialize viewport state
    final viewportState = PlanViewportState.fromViewport(viewport);
    final viewportJson = jsonEncode(viewportState.toJson());

    final projectCompanion = ProjectsCompanion.insert(
      name: name,
      folderId: Value(folderId),
      useImperial: Value(useImperial),
      viewportJson: Value(viewportJson),
      wallWidthMm: Value(wallWidthMm),
      doorThicknessMm: doorThicknessMm != null ? Value(doorThicknessMm) : const Value.absent(),
    );

    // Insert project and rooms in ONE transaction: a failure after the
    // project insert must not commit an empty project row while the rooms
    // roll back.
    return await _db.transaction(() async {
      final projectId = await _db.into(_db.projects).insert(projectCompanion);

      for (int i = 0; i < rooms.length; i++) {
        final room = rooms[i];
        final roomCompanion = RoomsCompanion.insert(
          projectId: projectId,
          name: Value(room.name),
          verticesJson: room.toJsonString(),
          orderIndex: Value(i),
        );
        await _db.into(_db.rooms).insert(roomCompanion);
      }

      return projectId;
    });
  }

  /// Update an existing project.
  /// Replaces all rooms for the project when [rooms] is provided.
  Future<void> updateProject({
    required int id,
    String? name,
    List<Room>? rooms,
    List<Opening>? openings,
    List<CarpetProduct>? carpetProducts,
    Map<int, int>? roomCarpetAssignments,
    Map<int, List<double>>? roomCarpetSeamOverrides,
    Map<int, double>? roomCarpetSeamLayDirectionDeg,
    Map<int, int>? roomCarpetLayoutVariantIndex,
    Map<int, List<List<double>>>? roomCarpetStripPieceLengthsOverrideMm,
    double? carpetWasteAllowancePercent,
    CarpetPlanningSettings? carpetPlanningSettings,
    PlanViewport? viewport,
    bool? useImperial,
    String? backgroundImagePath,
    BackgroundImageState? backgroundImageState,
    double? wallWidthMm,
    double? doorThicknessMm,
  }) async {
    // Keep the legacy waste column in sync when full settings are written.
    final effectiveWastePercent = carpetWasteAllowancePercent ??
        carpetPlanningSettings?.wasteAllowancePercent;
    final projectUpdate = ProjectsCompanion(
      id: Value(id),
      updatedAt: Value(DateTime.now()),
      name: name != null ? Value(name) : const Value.absent(),
      useImperial: useImperial != null ? Value(useImperial) : const Value.absent(),
      viewportJson: viewport != null
          ? Value(jsonEncode(PlanViewportState.fromViewport(viewport).toJson()))
          : const Value.absent(),
      backgroundImagePath: backgroundImagePath != null ? Value(backgroundImagePath) : const Value.absent(),
      backgroundImageJson: backgroundImageState != null
          ? Value(jsonEncode(backgroundImageState.toJson()))
          : const Value.absent(),
      openingsJson: openings != null
          ? Value(jsonEncode(Opening.listToJson(openings)))
          : const Value.absent(),
      carpetProductsJson: carpetProducts != null
          ? Value(jsonEncode(CarpetProduct.listToJson(carpetProducts)))
          : const Value.absent(),
      roomCarpetAssignmentsJson: roomCarpetAssignments != null
          ? Value(jsonEncode(roomCarpetAssignments.entries
              .map((e) => {'roomIndex': e.key, 'productIndex': e.value})
              .toList()))
          : const Value.absent(),
      roomCarpetSeamOverridesJson: roomCarpetSeamOverrides != null
          ? Value(jsonEncode(roomCarpetSeamOverrides.map((k, v) => MapEntry(k.toString(), v))))
          : const Value.absent(),
      roomCarpetSeamLayDirectionDegJson: roomCarpetSeamLayDirectionDeg != null
          ? Value(jsonEncode(roomCarpetSeamLayDirectionDeg
              .map((k, v) => MapEntry(k.toString(), v))))
          : const Value.absent(),
      roomCarpetLayoutVariantIndexJson: roomCarpetLayoutVariantIndex != null
          ? Value(jsonEncode(roomCarpetLayoutVariantIndex
              .map((k, v) => MapEntry(k.toString(), v))))
          : const Value.absent(),
      roomCarpetStripPieceLengthsJson:
          roomCarpetStripPieceLengthsOverrideMm != null
              ? Value(jsonEncode(roomCarpetStripPieceLengthsOverrideMm
                  .map((k, v) => MapEntry(k.toString(), v))))
              : const Value.absent(),
      carpetWasteAllowancePercent: effectiveWastePercent != null
          ? Value(effectiveWastePercent)
          : const Value.absent(),
      carpetPlanningSettingsJson: carpetPlanningSettings != null
          ? Value(jsonEncode(carpetPlanningSettings.toJson()))
          : const Value.absent(),
      stripSplitStrategy: carpetPlanningSettings != null
          ? Value(carpetPlanningSettings.stripSplitStrategy.index)
          : const Value.absent(),
      wallWidthMm: wallWidthMm != null ? Value(wallWidthMm) : const Value.absent(),
      doorThicknessMm: doorThicknessMm != null ? Value(doorThicknessMm) : const Value.absent(),
    );

    // Metadata write and rooms replacement must commit atomically: the
    // metadata includes room-index-keyed JSON blobs (openings, carpet
    // assignments, seam overrides, ...), so committing one without the other
    // leaves those blobs referencing a room list they were not written for.
    await _db.transaction(() async {
      await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(projectUpdate);

      // If rooms are provided, replace all rooms
      if (rooms != null) {
        // Delete existing rooms
        await (_db.delete(_db.rooms)..where((r) => r.projectId.equals(id))).go();

        // Insert new rooms
        for (int i = 0; i < rooms.length; i++) {
          final room = rooms[i];
          final roomCompanion = RoomsCompanion.insert(
            projectId: id,
            name: Value(room.name),
            verticesJson: room.toJsonString(),
            orderIndex: Value(i),
          );
          await _db.into(_db.rooms).insert(roomCompanion);
        }
      }
    });
  }

  /// Delete a project and all its rooms (CASCADE).
  Future<void> deleteProject(int id) async {
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
    // Rooms are automatically deleted due to CASCADE foreign key
  }

  /// Unified save method: creates new project or updates existing.
  /// Returns the project ID.
  Future<int> saveProject({
    int? id,
    required String name,
    required List<Room> rooms,
    List<Opening>? openings,
    List<CarpetProduct>? carpetProducts,
    Map<int, int>? roomCarpetAssignments,
    Map<int, List<double>>? roomCarpetSeamOverrides,
    Map<int, double>? roomCarpetSeamLayDirectionDeg,
    Map<int, int>? roomCarpetLayoutVariantIndex,
    Map<int, List<List<double>>>? roomCarpetStripPieceLengthsOverrideMm,
    double? carpetWasteAllowancePercent,
    CarpetPlanningSettings? carpetPlanningSettings,
    required PlanViewport viewport,
    bool useImperial = false,
    int? folderId,
    String? backgroundImagePath,
    BackgroundImageState? backgroundImageState,
    double wallWidthMm = 70.0,
    double? doorThicknessMm,
  }) async {
    try {
      if (id == null) {
        // Run create + follow-up metadata update as ONE transaction (the
        // inner transactions in createProject/updateProject nest into this
        // one), so a new project is never committed half-written.
        return await _db.transaction(() async {
        final projectId = await createProject(
          name: name,
          rooms: rooms,
          viewport: viewport,
          useImperial: useImperial,
          folderId: folderId,
        wallWidthMm: wallWidthMm,
        doorThicknessMm: doorThicknessMm,
        );
        if (backgroundImagePath != null ||
            backgroundImageState != null ||
            (openings != null && openings.isNotEmpty) ||
            (carpetProducts != null && carpetProducts.isNotEmpty) ||
            (roomCarpetAssignments != null && roomCarpetAssignments.isNotEmpty) ||
            (roomCarpetSeamOverrides != null && roomCarpetSeamOverrides.isNotEmpty) ||
            (roomCarpetSeamLayDirectionDeg != null && roomCarpetSeamLayDirectionDeg.isNotEmpty) ||
            (roomCarpetLayoutVariantIndex != null && roomCarpetLayoutVariantIndex.isNotEmpty) ||
            (roomCarpetStripPieceLengthsOverrideMm != null && roomCarpetStripPieceLengthsOverrideMm.isNotEmpty) ||
            carpetWasteAllowancePercent != null ||
            carpetPlanningSettings != null) {
          await updateProject(
            id: projectId,
            backgroundImagePath: backgroundImagePath,
            backgroundImageState: backgroundImageState,
            openings: openings,
            carpetProducts: carpetProducts,
            roomCarpetAssignments: roomCarpetAssignments,
            roomCarpetSeamOverrides: roomCarpetSeamOverrides,
            roomCarpetSeamLayDirectionDeg: roomCarpetSeamLayDirectionDeg,
            roomCarpetLayoutVariantIndex: roomCarpetLayoutVariantIndex,
            roomCarpetStripPieceLengthsOverrideMm:
                roomCarpetStripPieceLengthsOverrideMm,
            carpetWasteAllowancePercent: carpetWasteAllowancePercent,
            carpetPlanningSettings: carpetPlanningSettings,
          wallWidthMm: wallWidthMm,
          doorThicknessMm: doorThicknessMm,
          );
        }
        return projectId;
        });
      } else {
        await updateProject(
          id: id,
          name: name,
          rooms: rooms,
          openings: openings,
          carpetProducts: carpetProducts,
          roomCarpetAssignments: roomCarpetAssignments,
          roomCarpetSeamOverrides: roomCarpetSeamOverrides,
          roomCarpetSeamLayDirectionDeg: roomCarpetSeamLayDirectionDeg,
          roomCarpetLayoutVariantIndex: roomCarpetLayoutVariantIndex,
          roomCarpetStripPieceLengthsOverrideMm:
              roomCarpetStripPieceLengthsOverrideMm,
          carpetWasteAllowancePercent: carpetWasteAllowancePercent,
          carpetPlanningSettings: carpetPlanningSettings,
          viewport: viewport,
          useImperial: useImperial,
          backgroundImagePath: backgroundImagePath,
          backgroundImageState: backgroundImageState,
          wallWidthMm: wallWidthMm,
          doorThicknessMm: doorThicknessMm,
        );
        return id;
      }
    } catch (e, stackTrace) {
      debugPrint('Error in saveProject: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get project count.
  Future<int> getProjectCount() async {
    final count = _db.selectOnly(_db.projects)
      ..addColumns([_db.projects.id.count()]);
    final result = await count.getSingle();
    return result.read(_db.projects.id.count()) ?? 0;
  }

  /// Check if a project exists.
  Future<bool> projectExists(int id) async {
    final query = _db.selectOnly(_db.projects)
      ..addColumns([_db.projects.id])
      ..where(_db.projects.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null;
  }
}
