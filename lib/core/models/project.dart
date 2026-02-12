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
  final String? backgroundImagePath;
  final BackgroundImageState? backgroundImageState;

  ProjectModel({
    this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.useImperial = false,
    required this.rooms,
    this.viewportState,
    this.backgroundImagePath,
    this.backgroundImageState,
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
    String? backgroundImagePath,
    BackgroundImageState? backgroundImageState,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      useImperial: useImperial ?? this.useImperial,
      rooms: rooms ?? this.rooms,
      viewportState: viewportState ?? this.viewportState,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      backgroundImageState: backgroundImageState ?? this.backgroundImageState,
    );
  }
}

/// State for the floor plan background image (position and scale in world mm).
class BackgroundImageState {
  final double offsetX;
  final double offsetY;
  final double scaleMmPerPixel;
  final double opacity;

  BackgroundImageState({
    this.offsetX = 0,
    this.offsetY = 0,
    this.scaleMmPerPixel = 1,
    this.opacity = 0.7,
  });

  BackgroundImageState copyWith({
    double? offsetX,
    double? offsetY,
    double? scaleMmPerPixel,
    double? opacity,
  }) {
    return BackgroundImageState(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scaleMmPerPixel: scaleMmPerPixel ?? this.scaleMmPerPixel,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scaleMmPerPixel': scaleMmPerPixel,
        'opacity': opacity,
      };

  factory BackgroundImageState.fromJson(Map<String, dynamic> json) {
    return BackgroundImageState(
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scaleMmPerPixel: (json['scaleMmPerPixel'] as num?)?.toDouble() ?? 1,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.7,
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
