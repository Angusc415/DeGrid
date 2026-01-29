import 'dart:ui';

/// Represents a completed room (polygon) in the floor plan.
/// 
/// This is a simple immutable data class. Later we'll add:
/// - Validation (self-intersection checks)
/// - Area/perimeter calculations
/// - Room names/IDs for multi-room projects
class Room {
  /// Vertices in world-space coordinates (millimeters).
  /// Must have at least 3 vertices to form a valid polygon.
  final List<Offset> vertices;
  
  /// Optional room name/label.
  final String? name;

  Room({
    required this.vertices,
    this.name,
  }) : assert(vertices.length >= 3, 'Room must have at least 3 vertices');

  /// Check if this room forms a valid closed polygon.
  bool get isValid => vertices.length >= 3;

  /// Calculate the area of the room in square millimeters.
  /// Uses the shoelace formula for polygon area.
  /// 
  /// Returns 0 if the room is invalid (less than 3 vertices).
  double get areaMm2 {
    if (!isValid) return 0.0;
    
    double sum = 0.0;
    for (int i = 0; i < vertices.length; i++) {
      final j = (i + 1) % vertices.length;
      sum += vertices[i].dx * vertices[j].dy;
      sum -= vertices[j].dx * vertices[i].dy;
    }
    return (sum / 2).abs();
  }
}
