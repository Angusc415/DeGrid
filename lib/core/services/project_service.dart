import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../geometry/room.dart';
import '../geometry/opening.dart';
import '../geometry/carpet_product.dart';
import '../models/project.dart';
import '../../ui/canvas/viewport.dart';

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
        query..where((p) => p.folderId.isNull());
      } else {
        query..where((p) => p.folderId.equals(folderId));
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
      query..where((f) => f.parentId.isNull());
    } else {
      query..where((f) => f.parentId.equals(parentId));
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

    // Parse openings if available
    List<Opening> openings = const [];
    if (project.openingsJson != null && project.openingsJson!.isNotEmpty) {
      try {
        final list = jsonDecode(project.openingsJson!) as List<dynamic>;
        openings = Opening.listFromJson(list);
      } catch (e) {
        openings = [];
      }
    }

    // Parse carpet products if available
    List<CarpetProduct> carpetProducts = const [];
    if (project.carpetProductsJson != null && project.carpetProductsJson!.isNotEmpty) {
      try {
        final list = jsonDecode(project.carpetProductsJson!) as List<dynamic>;
        carpetProducts = CarpetProduct.listFromJson(list);
      } catch (e) {
        carpetProducts = [];
      }
    }

    // Parse room carpet assignments if available
    Map<int, int> roomCarpetAssignments = {};
    if (project.roomCarpetAssignmentsJson != null && project.roomCarpetAssignmentsJson!.isNotEmpty) {
      try {
        final list = jsonDecode(project.roomCarpetAssignmentsJson!) as List<dynamic>;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final ri = m['roomIndex'] as int?;
          final pi = m['productIndex'] as int?;
          if (ri != null && pi != null) roomCarpetAssignments[ri] = pi;
        }
      } catch (_) {}
    }

    // Parse room carpet seam overrides if available
    Map<int, List<double>> roomCarpetSeamOverrides = {};
    if (project.roomCarpetSeamOverridesJson != null && project.roomCarpetSeamOverridesJson!.isNotEmpty) {
      try {
        final map = jsonDecode(project.roomCarpetSeamOverridesJson!) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final roomIndex = int.tryParse(entry.key);
          if (roomIndex == null) continue;
          final list = entry.value as List<dynamic>?;
          if (list == null) continue;
          roomCarpetSeamOverrides[roomIndex] = list.map((e) => (e as num).toDouble()).toList();
        }
      } catch (_) {}
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
      viewportState: viewportState,
      backgroundImagePath: project.backgroundImagePath,
      backgroundImageState: backgroundImageState,
      wallWidthMm: project.wallWidthMm ?? 70.0,
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

    // Insert project
    final projectCompanion = ProjectsCompanion.insert(
      name: name,
      folderId: Value(folderId),
      useImperial: Value(useImperial),
      viewportJson: Value(viewportJson),
      wallWidthMm: Value(wallWidthMm),
      doorThicknessMm: doorThicknessMm != null ? Value(doorThicknessMm) : const Value.absent(),
    );

    final projectId = await _db.into(_db.projects).insert(projectCompanion);

    // Insert rooms in a transaction
    await _db.transaction(() async {
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
    });

    return projectId;
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
    PlanViewport? viewport,
    bool? useImperial,
    String? backgroundImagePath,
    BackgroundImageState? backgroundImageState,
    double? wallWidthMm,
    double? doorThicknessMm,
  }) async {
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
      wallWidthMm: wallWidthMm != null ? Value(wallWidthMm) : const Value.absent(),
      doorThicknessMm: doorThicknessMm != null ? Value(doorThicknessMm) : const Value.absent(),
    );

    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(projectUpdate);

    // If rooms are provided, replace all rooms
    if (rooms != null) {
      await _db.transaction(() async {
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
      });
    }
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
            (roomCarpetSeamOverrides != null && roomCarpetSeamOverrides.isNotEmpty)) {
          await updateProject(
            id: projectId,
            backgroundImagePath: backgroundImagePath,
            backgroundImageState: backgroundImageState,
            openings: openings,
            carpetProducts: carpetProducts,
            roomCarpetAssignments: roomCarpetAssignments,
            roomCarpetSeamOverrides: roomCarpetSeamOverrides,
          wallWidthMm: wallWidthMm,
          doorThicknessMm: doorThicknessMm,
          );
        }
        return projectId;
      } else {
        await updateProject(
          id: id,
          name: name,
          rooms: rooms,
          openings: openings,
          carpetProducts: carpetProducts,
          roomCarpetAssignments: roomCarpetAssignments,
          roomCarpetSeamOverrides: roomCarpetSeamOverrides,
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
