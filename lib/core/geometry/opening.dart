import 'dart:ui';
import 'dart:convert';

/// Represents a door or opening in a wall between two rooms.
///
/// The opening is defined on one room's edge: [roomIndex] and [edgeIndex]
/// (edge from vertex[edgeIndex] to vertex[edgeIndex+1]). [offsetMm] is the
/// distance along the edge to the start of the opening; [widthMm] is the
/// opening width. [isDoor] true = draw door swing arc; false = opening only (gap, no arc).
class Opening {
  final int roomIndex;
  final int edgeIndex;
  /// Distance along the edge (mm) to the start of the opening.
  final double offsetMm;
  /// Width of the opening (mm), e.g. 900 for a standard door.
  final double widthMm;
  /// True = door (draw swing arc). False = opening only (window, pass-through; just the gap).
  final bool isDoor;

  Opening({
    required this.roomIndex,
    required this.edgeIndex,
    required this.offsetMm,
    required this.widthMm,
    this.isDoor = true,
  });

  Map<String, dynamic> toJson() => {
        'roomIndex': roomIndex,
        'edgeIndex': edgeIndex,
        'offsetMm': offsetMm,
        'widthMm': widthMm,
        'isDoor': isDoor,
      };

  factory Opening.fromJson(Map<String, dynamic> json) {
    return Opening(
      roomIndex: json['roomIndex'] as int,
      edgeIndex: json['edgeIndex'] as int,
      offsetMm: (json['offsetMm'] as num).toDouble(),
      widthMm: (json['widthMm'] as num).toDouble(),
      isDoor: json['isDoor'] as bool? ?? true,
    );
  }

  static List<Opening> listFromJson(List<dynamic>? list) {
    if (list == null) return [];
    return list
        .map((e) => Opening.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Map<String, dynamic>> listToJson(List<Opening> openings) {
    return openings.map((o) => o.toJson()).toList();
  }
}
