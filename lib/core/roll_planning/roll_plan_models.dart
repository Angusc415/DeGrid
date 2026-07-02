import 'dart:ui';

import '../geometry/carpet_product.dart';
import '../geometry/room.dart';
import 'roll_planner.dart';

/// A single cut piece on a roll plan.
class RollCutPiece {
  final String cutId;
  final int roomIndex;
  final String roomName;
  final int rollLaneIndex;
  final CarpetProduct product;
  final int stripIndex;
  final double lengthMm;
  final double trimMm;
  final double breadthMm;
  final bool isSliver;
  final double? patternRepeatMm;
  final bool fromOffcut;
  final int? sourceOffcutRollIndex;
  final List<Offset>? roomShapeVerticesMm;
  final bool? layAlongX;

  const RollCutPiece({
    required this.cutId,
    required this.roomIndex,
    required this.roomName,
    required this.rollLaneIndex,
    required this.product,
    required this.stripIndex,
    required this.lengthMm,
    required this.trimMm,
    required this.breadthMm,
    required this.isSliver,
    this.fromOffcut = false,
    this.sourceOffcutRollIndex,
    this.patternRepeatMm,
    this.roomShapeVerticesMm,
    this.layAlongX,
  });

  RollCutPiece copyWith({
    String? cutId,
    int? roomIndex,
    String? roomName,
    int? rollLaneIndex,
    CarpetProduct? product,
    int? stripIndex,
    double? lengthMm,
    double? trimMm,
    double? breadthMm,
    bool? isSliver,
    double? patternRepeatMm,
    bool? fromOffcut,
    int? sourceOffcutRollIndex,
    List<Offset>? roomShapeVerticesMm,
    bool? layAlongX,
  }) {
    return RollCutPiece(
      cutId: cutId ?? this.cutId,
      roomIndex: roomIndex ?? this.roomIndex,
      roomName: roomName ?? this.roomName,
      rollLaneIndex: rollLaneIndex ?? this.rollLaneIndex,
      product: product ?? this.product,
      stripIndex: stripIndex ?? this.stripIndex,
      lengthMm: lengthMm ?? this.lengthMm,
      trimMm: trimMm ?? this.trimMm,
      breadthMm: breadthMm ?? this.breadthMm,
      isSliver: isSliver ?? this.isSliver,
      patternRepeatMm: patternRepeatMm ?? this.patternRepeatMm,
      fromOffcut: fromOffcut ?? this.fromOffcut,
      sourceOffcutRollIndex:
          sourceOffcutRollIndex ?? this.sourceOffcutRollIndex,
      roomShapeVerticesMm: roomShapeVerticesMm ?? this.roomShapeVerticesMm,
      layAlongX: layAlongX ?? this.layAlongX,
    );
  }
}

/// Format a cut ID matching the roll cut sheet: `A1`, `A2`, or `A1-1` when a
/// strip is split into multiple along-run pieces (cross-join).
String formatCutId({
  required int roomLetterIndex,
  required int stripIndex,
  required int pieceIndex,
  required int pieceCountInStrip,
}) {
  final letter = String.fromCharCode(65 + roomLetterIndex);
  final stripNum = stripIndex + 1;
  if (pieceCountInStrip > 1) {
    return '$letter$stripNum-${pieceIndex + 1}';
  }
  return '$letter$stripNum';
}

/// Letter index (0 = A) per room among carpet-assigned rooms with the same
/// product, in [assignments] iteration order. Matches cut sheet ordering when
/// a single product roll is shown.
Map<int, int> buildRoomLetterIndicesByProduct(Map<int, int> assignments) {
  final counters = <int, int>{};
  final result = <int, int>{};
  for (final e in assignments.entries) {
    final pi = e.value;
    final li = counters[pi] ?? 0;
    result[e.key] = li;
    counters[pi] = li + 1;
  }
  return result;
}

/// Letter index for [roomIndex] among same-product rooms that have a plannable
/// layout, in [assignments] iteration order. Matches `_roomsWithCarpet` in the
/// cut sheet. Returns null when the room has no assignment or no layout.
int? roomLetterIndexInProduct({
  required Map<int, int> assignments,
  required int roomIndex,
  required bool Function(int roomIndex) hasPlannableLayout,
}) {
  final productIndex = assignments[roomIndex];
  if (productIndex == null) return null;
  var li = 0;
  for (final e in assignments.entries) {
    if (e.value != productIndex) continue;
    final ri = e.key;
    if (!hasPlannableLayout(ri)) {
      if (ri == roomIndex) return null;
      continue;
    }
    if (ri == roomIndex) return li;
    li++;
  }
  return null;
}

/// World-space anchor for one cut piece (floor plan arrow + hit test).
class CutPieceAnchor {
  final String cutId;
  final int roomIndex;
  final int stripIndex;
  final int pieceIndex;
  final Offset centerWorld;
  final Offset baseWorld;
  final Offset tipWorld;
  final double pieceLenMm;

  const CutPieceAnchor({
    required this.cutId,
    required this.roomIndex,
    required this.stripIndex,
    required this.pieceIndex,
    required this.centerWorld,
    required this.baseWorld,
    required this.tipWorld,
    required this.pieceLenMm,
  });
}

/// Ray-cast point-in-polygon test. [verts] should be the open vertex ring.
bool pointInPolygonWorld(Offset p, List<Offset> verts) {
  if (verts.length < 3) return false;
  var inside = false;
  for (var i = 0, j = verts.length - 1; i < verts.length; j = i++) {
    final vi = verts[i];
    final vj = verts[j];
    final intersects = ((vi.dy > p.dy) != (vj.dy > p.dy)) &&
        (p.dx < (vj.dx - vi.dx) * (p.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx);
    if (intersects) inside = !inside;
  }
  return inside;
}

/// Polygon area centroid in world mm (open vertex ring).
Offset polygonAreaCentroidWorld(List<Offset> verts) {
  if (verts.length < 3) return verts.isNotEmpty ? verts.first : Offset.zero;
  var signedArea = 0.0;
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0; i < verts.length; i++) {
    final j = (i + 1) % verts.length;
    final cross = verts[i].dx * verts[j].dy - verts[j].dx * verts[i].dy;
    signedArea += cross;
    cx += (verts[i].dx + verts[j].dx) * cross;
    cy += (verts[i].dy + verts[j].dy) * cross;
  }
  signedArea *= 0.5;
  if (signedArea.abs() < 1e-9) {
    var sx = 0.0, sy = 0.0;
    for (final v in verts) {
      sx += v.dx;
      sy += v.dy;
    }
    return Offset(sx / verts.length, sy / verts.length);
  }
  return Offset(cx / (6 * signedArea), cy / (6 * signedArea));
}

/// Concave-safe placement for a piece bbox center (samples along centerline).
Offset? piecePlacementWorld({
  required StripLayout layout,
  required List<Offset> verts,
  required double alongMid,
  required double perpMid,
  required double pieceLen,
}) {
  Offset pieceCenterWorld;
  if (layout.layAlongX) {
    final y = layout.bboxMinY + perpMid;
    pieceCenterWorld = Offset(layout.bboxMinX + alongMid, y);
  } else {
    final x = layout.bboxMinX + perpMid;
    pieceCenterWorld = Offset(x, layout.bboxMinY + alongMid);
  }
  if (pointInPolygonWorld(pieceCenterWorld, verts)) return pieceCenterWorld;

  const samples = 5;
  var bestDist = double.infinity;
  Offset? best;
  for (var s = 0; s < samples; s++) {
    final f = (s + 0.5) / samples;
    final along = (alongMid - pieceLen / 2) + f * pieceLen;
    final candidate = layout.layAlongX
        ? Offset(layout.bboxMinX + along, layout.bboxMinY + perpMid)
        : Offset(layout.bboxMinX + perpMid, layout.bboxMinY + along);
    if (!pointInPolygonWorld(candidate, verts)) continue;
    final d = (candidate - pieceCenterWorld).distance;
    if (d < bestDist) {
      bestDist = d;
      best = candidate;
    }
  }
  return best;
}

/// Enumerate cut-piece anchors for a room layout. Skips pieces with no valid
/// inside placement or within [nameAvoidMm] of [nameCentroidWorld] when set.
List<CutPieceAnchor> enumerateCutPieceAnchors({
  required int roomIndex,
  required Room room,
  required StripLayout layout,
  required int roomLetterIndex,
  Offset? nameCentroidWorld,
  double nameAvoidMm = 250.0,
  double maxShaftLenMm = 160.0,
}) {
  final verts = room.vertices.length > 1 && room.vertices.first == room.vertices.last
      ? room.vertices.sublist(0, room.vertices.length - 1)
      : room.vertices;
  if (verts.length < 3 || layout.numStrips < 1) return [];

  final dir = layout.layAlongX ? const Offset(1, 0) : const Offset(0, 1);
  final anchors = <CutPieceAnchor>[];

  for (var stri = 0; stri < layout.numStrips; stri++) {
    final pieces = layout.pieceLengthsForStrip(stri);
    if (pieces.isEmpty) continue;
    var stripStartPerp = 0.0;
    for (var i = 0; i < stri; i++) {
      stripStartPerp += i < layout.stripWidthsMm.length
          ? layout.stripWidthsMm[i]
          : layout.rollWidthMm;
    }
    final stripWidth = stri < layout.stripWidthsMm.length
        ? layout.stripWidthsMm[stri]
        : (layout.layAlongX ? layout.bboxHeight : layout.bboxWidth);
    final perpMid = stripStartPerp + stripWidth / 2;

    var alongStart = 0.0;
    for (var pi = 0; pi < pieces.length; pi++) {
      final pieceLen = pieces[pi];
      final alongMid = alongStart + pieceLen / 2;
      alongStart += pieceLen;
      if (pieceLen <= 1e-6) continue;

      final placeWorld = piecePlacementWorld(
        layout: layout,
        verts: verts,
        alongMid: alongMid,
        perpMid: perpMid,
        pieceLen: pieceLen,
      );
      if (placeWorld == null) continue;

      if (nameCentroidWorld != null &&
          (placeWorld - nameCentroidWorld).distance < nameAvoidMm) {
        continue;
      }

      final shaftLenMm = pieceLen * 0.5 < maxShaftLenMm
          ? pieceLen * 0.5
          : maxShaftLenMm;
      final half = shaftLenMm / 2;
      final cutId = formatCutId(
        roomLetterIndex: roomLetterIndex,
        stripIndex: stri,
        pieceIndex: pi,
        pieceCountInStrip: pieces.length,
      );
      anchors.add(
        CutPieceAnchor(
          cutId: cutId,
          roomIndex: roomIndex,
          stripIndex: stri,
          pieceIndex: pi,
          centerWorld: placeWorld,
          baseWorld: placeWorld - dir * half,
          tipWorld: placeWorld + dir * half,
          pieceLenMm: pieceLen,
        ),
      );
    }
  }
  return anchors;
}

/// One roll lane on the board.
class RollLaneData {
  final int rollIndex;
  final Room? room;
  final CarpetProduct product;
  final StripLayout? layout;
  final double totalLinearMm;

  RollLaneData({
    required this.rollIndex,
    this.room,
    required this.product,
    this.layout,
    required this.totalLinearMm,
  });

  double get rollWidthMm =>
      product.rollWidthMm > 0 ? product.rollWidthMm : 4000;

  double get rollLengthMm {
    if (product.rollLengthM != null && product.rollLengthM! > 0) {
      return product.rollLengthM! * 1000;
    }
    final minLength = rollWidthMm;
    return (totalLinearMm * 1.2).clamp(minLength, double.infinity);
  }
}

typedef RollCutPlacement = Offset;

/// Remaining piece on a roll lane after placed cuts.
class RollOffcut {
  final int rollIndex;
  final double startAlongMm;
  final double lengthMm;
  final double breadthMm;

  const RollOffcut({
    required this.rollIndex,
    required this.startAlongMm,
    required this.lengthMm,
    required this.breadthMm,
  });
}

/// State for the roll planning board.
class RollPlanState {
  final List<RollCutPiece> allCuts;
  final List<RollLaneData> lanes;
  final Map<String, RollCutPlacement> placements;
  final String? selectedCutId;
  final bool cutListExpanded;
  final double totalScoreCostMm;

  const RollPlanState({
    required this.allCuts,
    required this.lanes,
    required this.placements,
    this.selectedCutId,
    this.cutListExpanded = true,
    this.totalScoreCostMm = 0,
  });

  List<RollCutPiece> get unplacedCuts =>
      allCuts.where((c) => !placements.containsKey(c.cutId)).toList();

  List<RollCutPiece> placedCutsOnLane(int rollIndex) {
    return allCuts
        .where(
          (c) =>
              c.rollLaneIndex == rollIndex && placements.containsKey(c.cutId),
        )
        .toList()
      ..sort((a, b) {
        final pa = placements[a.cutId]!;
        final pb = placements[b.cutId]!;
        final cmp = pa.dx.compareTo(pb.dx);
        return cmp != 0 ? cmp : pa.dy.compareTo(pb.dy);
      });
  }

  double totalLinearMm() =>
      allCuts.fold<double>(0, (sum, cut) => sum + cut.lengthMm);

  double wasteMmForLane(int rollIndex) {
    final placed = placedCutsOnLane(rollIndex);
    if (placed.isEmpty) return 0;
    final lane = lanes[rollIndex];
    final rollArea = lane.rollLengthMm * lane.rollWidthMm;
    final usedArea = placed.fold<double>(
      0,
      (sum, cut) => sum + cut.lengthMm * cut.breadthMm,
    );
    return ((rollArea - usedArea) / lane.rollWidthMm).clamp(0, double.infinity);
  }

  List<RollOffcut> offcuts() {
    final offcuts = <RollOffcut>[];
    for (final lane in lanes) {
      final placed = placedCutsOnLane(lane.rollIndex);
      final endAlong = placed.isEmpty
          ? 0.0
          : placed.fold<double>(0, (maxValue, cut) {
              final end = placements[cut.cutId]!.dx + cut.lengthMm;
              return end > maxValue ? end : maxValue;
            });
      final tailLength = (lane.rollLengthMm - endAlong).clamp(
        0.0,
        double.infinity,
      );
      if (tailLength > 0) {
        offcuts.add(
          RollOffcut(
            rollIndex: lane.rollIndex,
            startAlongMm: endAlong,
            lengthMm: tailLength,
            breadthMm: lane.rollWidthMm,
          ),
        );
      }
    }
    return offcuts;
  }

  bool _cutsOverlap(RollCutPiece a, RollCutPiece b) {
    final pa = placements[a.cutId]!;
    final pb = placements[b.cutId]!;
    final aRight = pa.dx + a.lengthMm;
    final aBottom = pa.dy + a.breadthMm;
    final bRight = pb.dx + b.lengthMm;
    final bBottom = pb.dy + b.breadthMm;
    return pa.dx < bRight &&
        pb.dx < aRight &&
        pa.dy < bBottom &&
        pb.dy < aBottom;
  }

  int get overlapCount {
    int count = 0;
    for (final lane in lanes) {
      final placed = placedCutsOnLane(lane.rollIndex);
      for (int i = 0; i < placed.length; i++) {
        for (int j = i + 1; j < placed.length; j++) {
          if (_cutsOverlap(placed[i], placed[j])) count++;
        }
      }
    }
    return count;
  }

  Set<String> overlappingCutIds() {
    final ids = <String>{};
    for (final lane in lanes) {
      final placed = placedCutsOnLane(lane.rollIndex);
      for (int i = 0; i < placed.length; i++) {
        for (int j = 0; j < placed.length; j++) {
          if (i == j) continue;
          if (_cutsOverlap(placed[i], placed[j])) {
            ids.add(placed[i].cutId);
            ids.add(placed[j].cutId);
          }
        }
      }
    }
    return ids;
  }

  RollPlanState copyWith({
    List<RollCutPiece>? allCuts,
    List<RollLaneData>? lanes,
    Map<String, RollCutPlacement>? placements,
    String? selectedCutId,
    bool clearSelection = false,
    bool? cutListExpanded,
    double? totalScoreCostMm,
  }) {
    return RollPlanState(
      allCuts: allCuts ?? this.allCuts,
      lanes: lanes ?? this.lanes,
      placements:
          placements ?? Map<String, RollCutPlacement>.from(this.placements),
      selectedCutId: clearSelection
          ? null
          : (selectedCutId ?? this.selectedCutId),
      cutListExpanded: cutListExpanded ?? this.cutListExpanded,
      totalScoreCostMm: totalScoreCostMm ?? this.totalScoreCostMm,
    );
  }
}
