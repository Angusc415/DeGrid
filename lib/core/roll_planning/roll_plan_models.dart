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
