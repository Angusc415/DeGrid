import 'dart:ui';
import 'dart:convert';

/// Represents a door or opening in a wall between two rooms.
///
/// The opening is defined on one room's edge: [roomIndex] and [edgeIndex]
/// (edge from vertex[edgeIndex] to vertex[edgeIndex+1]). [offsetMm] is the
/// distance along the edge to the start of the opening; [widthMm] is the
/// opening width. The "other" room is found by shared-edge detection when drawing.
class Opening {
  final int roomIndex;
  final int edgeIndex;
  /// Distance along the edge (mm) to the start of the opening.
  final double offsetMm;
  /// Width of the opening (mm), e.g. 900 for a standard door.
  final double widthMm;

  Opening({
    required this.roomIndex,
    required this.edgeIndex,
    required this.offsetMm,
    required this.widthMm,
  });

  Map<String, dynamic> toJson() => {
        'roomIndex': roomIndex,
        'edgeIndex': edgeIndex,
        'offsetMm': offsetMm,
        'widthMm': widthMm,
      };

  factory Opening.fromJson(Map<String, dynamic> json) {
    return Opening(
      roomIndex: json['roomIndex'] as int,
      edgeIndex: json['edgeIndex'] as int,
      offsetMm: (json['offsetMm'] as num).toDouble(),
      widthMm: (json['widthMm'] as num).toDouble(),
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
