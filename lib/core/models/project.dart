import 'dart:ui';
import '../geometry/room.dart';
import '../geometry/opening.dart';
import '../../ui/canvas/viewport.dart';

/// Represents a saved project with its rooms and viewport state.
class ProjectModel {
  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool useImperial;
  final List<Room> rooms;
  final List<Opening> openings;
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
    List<Opening>? openings,
    this.viewportState,
    this.backgroundImagePath,
    this.backgroundImageState,
  }) : openings = openings ?? const [];

  /// Create a copy with updated fields.
  ProjectModel copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? useImperial,
    List<Room>? rooms,
    List<Opening>? openings,
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
      openings: openings ?? this.openings,
      viewportState: viewportState ?? this.viewportState,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      backgroundImageState: backgroundImageState ?? this.backgroundImageState,
    );
  }
}

/// State for the floor plan background image (position and scale in world mm).
/// [scaleMmPerPixel] is the real-world scale (from calibration); [scaleFactor] is a
/// display multiplier (1 = 100%, 2 = image twice as large, 0.5 = half size).
class BackgroundImageState {
  final double offsetX;
  final double offsetY;
  final double scaleMmPerPixel;
  /// Display size multiplier: effective scale = scaleMmPerPixel / scaleFactor.
  final double scaleFactor;
  final double opacity;
  /// When true, the floorplan cannot be moved (move mode disabled).
  final bool locked;

  BackgroundImageState({
    this.offsetX = 0,
    this.offsetY = 0,
    this.scaleMmPerPixel = 1,
    this.scaleFactor = 1,
    this.opacity = 0.7,
    this.locked = false,
  });

  /// Effective mm per pixel when drawing (calibrated scale divided by display scale factor).
  double get effectiveScaleMmPerPixel => scaleMmPerPixel / scaleFactor;

  BackgroundImageState copyWith({
    double? offsetX,
    double? offsetY,
    double? scaleMmPerPixel,
    double? scaleFactor,
    double? opacity,
    bool? locked,
  }) {
    return BackgroundImageState(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scaleMmPerPixel: scaleMmPerPixel ?? this.scaleMmPerPixel,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      opacity: opacity ?? this.opacity,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => {
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scaleMmPerPixel': scaleMmPerPixel,
        'scaleFactor': scaleFactor,
        'opacity': opacity,
        'locked': locked,
      };

  factory BackgroundImageState.fromJson(Map<String, dynamic> json) {
    return BackgroundImageState(
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scaleMmPerPixel: (json['scaleMmPerPixel'] as num?)?.toDouble() ?? 1,
      scaleFactor: (json['scaleFactor'] as num?)?.toDouble() ?? 1,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.7,
      locked: json['locked'] == true,
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
