import 'dart:ui';
import '../geometry/room.dart';
import '../../ui/canvas/viewport.dart';

/// Represents a saved project with its rooms and viewport state.
class ProjectModel {
  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool useImperial;
  final List<Room> rooms;
  final PlanViewportState? viewportState;

  ProjectModel({
    this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.useImperial = false,
    required this.rooms,
    this.viewportState,
  });

  /// Create a copy with updated fields.
  ProjectModel copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? useImperial,
    List<Room>? rooms,
    PlanViewportState? viewportState,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      useImperial: useImperial ?? this.useImperial,
      rooms: rooms ?? this.rooms,
      viewportState: viewportState ?? this.viewportState,
    );
  }
}

/// Represents the viewport state for serialization.
/// Stores the viewport configuration so we can restore the view when loading a project.
class PlanViewportState {
  final double mmPerPx;
  final double worldOriginX;
  final double worldOriginY;

  PlanViewportState({
    required this.mmPerPx,
    required this.worldOriginX,
    required this.worldOriginY,
  });

  /// Create from a PlanViewport instance.
  factory PlanViewportState.fromViewport(PlanViewport viewport) {
    return PlanViewportState(
      mmPerPx: viewport.mmPerPx,
      worldOriginX: viewport.worldOriginMm.dx,
      worldOriginY: viewport.worldOriginMm.dy,
    );
  }

  /// Restore a PlanViewport from this state.
  PlanViewport toViewport() {
    return PlanViewport(
      mmPerPx: mmPerPx,
      worldOriginMm: Offset(worldOriginX, worldOriginY),
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'mmPerPx': mmPerPx,
      'worldOriginX': worldOriginX,
      'worldOriginY': worldOriginY,
    };
  }

  /// Create from JSON.
  factory PlanViewportState.fromJson(Map<String, dynamic> json) {
    return PlanViewportState(
      mmPerPx: json['mmPerPx'] as double,
      worldOriginX: json['worldOriginX'] as double,
      worldOriginY: json['worldOriginY'] as double,
    );
  }
}
