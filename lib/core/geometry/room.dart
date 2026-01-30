import 'dart:ui';
import 'dart:convert';

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

  /// Convert Room to JSON string for database storage.
  /// 
  /// Format: {"vertices": [{"x": 0.0, "y": 0.0}, ...], "name": "Room Name"}
  String toJsonString() {
    final json = <String, dynamic>{
      'vertices': vertices.map((v) => {'x': v.dx, 'y': v.dy}).toList(),
    };
    if (name != null && name!.isNotEmpty) {
      json['name'] = name;
    }
    return jsonEncode(json);
  }

  /// Create Room from JSON string (from database).
  /// 
  /// Throws FormatException if JSON is invalid.
  factory Room.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    
    final verticesList = json['vertices'] as List;
    final vertices = verticesList
        .map((v) => Offset(
              (v as Map<String, dynamic>)['x'] as double,
              v['y'] as double,
            ))
        .toList();
    
    final name = json['name'] as String?;
    
    return Room(vertices: vertices, name: name);
  }

  /// Convert vertices to JSON-compatible list format.
  /// Used for serialization to database.
  List<Map<String, double>> get verticesAsJson {
    return vertices.map((v) => {'x': v.dx, 'y': v.dy}).toList();
  }
}
