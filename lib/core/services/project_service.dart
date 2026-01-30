import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../geometry/room.dart';
import '../models/project.dart';
import '../../ui/canvas/viewport.dart';

/// Service layer for project database operations.
/// Handles all CRUD operations for projects and rooms.
class ProjectService {
  final AppDatabase _db;

  ProjectService(this._db);

  /// Get all projects (without rooms).
  /// Returns a list of project summaries.
  Future<List<Project>> getAllProjects() async {
    final query = _db.select(_db.projects)
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);
    
    return await query.get();
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
        // If viewport JSON is invalid, use default (null)
        viewportState = null;
      }
    }

    return ProjectModel(
      id: project.id,
      name: project.name,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      useImperial: project.useImperial,
      rooms: rooms,
      viewportState: viewportState,
    );
  }

  /// Create a new project with rooms.
  /// Returns the created project ID.
  Future<int> createProject({
    required String name,
    required List<Room> rooms,
    required PlanViewport viewport,
    bool useImperial = false,
  }) async {
    // Serialize viewport state
    final viewportState = PlanViewportState.fromViewport(viewport);
    final viewportJson = jsonEncode(viewportState.toJson());

    // Insert project
    final projectCompanion = ProjectsCompanion.insert(
      name: name,
      useImperial: Value(useImperial),
      viewportJson: Value(viewportJson),
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
  /// Replaces all rooms for the project.
  Future<void> updateProject({
    required int id,
    String? name,
    List<Room>? rooms,
    PlanViewport? viewport,
    bool? useImperial,
  }) async {
    // Build update companion
    final projectUpdate = ProjectsCompanion(
      id: Value(id),
      updatedAt: Value(DateTime.now()),
      name: name != null ? Value(name) : const Value.absent(),
      useImperial: useImperial != null ? Value(useImperial) : const Value.absent(),
      viewportJson: viewport != null
          ? Value(jsonEncode(PlanViewportState.fromViewport(viewport).toJson()))
          : const Value.absent(),
    );

    // Update project
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
    required PlanViewport viewport,
    bool useImperial = false,
  }) async {
    try {
      if (id == null) {
        // Create new project
        debugPrint('Creating new project: $name with ${rooms.length} rooms');
        final projectId = await createProject(
          name: name,
          rooms: rooms,
          viewport: viewport,
          useImperial: useImperial,
        );
        debugPrint('Created project with ID: $projectId');
        return projectId;
      } else {
        // Update existing project
        debugPrint('Updating project $id: $name with ${rooms.length} rooms');
        await updateProject(
          id: id,
          name: name,
          rooms: rooms,
          viewport: viewport,
          useImperial: useImperial,
        );
        debugPrint('Updated project $id');
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
