import 'dart:math' as math;
import 'dart:ui';
import '../geometry/room.dart';
import 'carpet_layout_options.dart';
import 'polygon_clip.dart';

/// Result of computing carpet strip layout for a room.
class StripLayout {
  final int numStrips;
  final List<double> stripLengthsMm;
  double get totalLinearMm =>
      stripLengthsMm.fold<double>(0, (s, l) => s + l);
  double get totalLinearM => totalLinearMm / 1000;
  final double layAngleDeg;
  final double bboxMinX;
  final double bboxMinY;
  final double bboxWidth;
  final double bboxHeight;
  final bool layAlongX;
  final double rollWidthMm;
  final int seamCount;
  final double? totalLinearWithWasteMm;

  StripLayout({
    required this.numStrips,
    required this.stripLengthsMm,
    required this.layAngleDeg,
    this.bboxMinX = 0,
    this.bboxMinY = 0,
    this.bboxWidth = 0,
    this.bboxHeight = 0,
    this.layAlongX = true,
    this.rollWidthMm = 0,
    this.seamCount = 0,
    this.totalLinearWithWasteMm,
  });
}

/// Computes carpet strip layout by intersecting strip bands with the room polygon.
///
/// - Direction: fixed or auto (compare 0° vs 90° by cost).
/// - Strip length = extent of (room ∩ strip band) in along direction + trim; pattern rounding applied.
/// - Narrow strips are included; sliver penalty added to cost so the algorithm prefers directions that avoid slivers.
/// - Cost = totalLinearMm + seamPenalty + sliverPenalty (all in mm-equivalent).
class RollPlanner {
  static const double _defaultMinStripWidthMm = 100.0;
  static const double _defaultTrimAllowanceMm = 75.0;
  static const double _defaultWastePercent = 5.0;

  static StripLayout computeLayout(
    Room room,
    double rollWidthMm, [
    CarpetLayoutOptions? options,
  ]) {
    if (rollWidthMm <= 0 || room.vertices.isEmpty) {
      return StripLayout(
        numStrips: 0,
        stripLengthsMm: const [],
        layAngleDeg: 0,
        rollWidthMm: 0,
      );
    }

    final opts = options ?? const CarpetLayoutOptions();
    final minStripWidth = opts.minStripWidthMm > 0 ? opts.minStripWidthMm : _defaultMinStripWidthMm;
    final trimAllowance = opts.trimAllowanceMm >= 0 ? opts.trimAllowanceMm : _defaultTrimAllowanceMm;
    final patternRepeat = opts.patternRepeatMm > 0 ? opts.patternRepeatMm : 0.0;
    final wastePercent = opts.wasteAllowancePercent >= 0 ? opts.wasteAllowancePercent : _defaultWastePercent;

    final verts = room.vertices;
    double minX = verts[0].dx, maxX = verts[0].dx;
    double minY = verts[0].dy, maxY = verts[0].dy;
    for (final v in verts) {
      minX = math.min(minX, v.dx);
      maxX = math.max(maxX, v.dx);
      minY = math.min(minY, v.dy);
      maxY = math.max(maxY, v.dy);
    }
    final bboxW = maxX - minX;
    final bboxH = maxY - minY;

    final bool layAlongX;
    if (opts.layDirectionDeg != null) {
      layAlongX = opts.layDirectionDeg! == 0;
    } else {
      final r0 = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, true, minStripWidth, trimAllowance, patternRepeat, opts);
      final r90 = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, false, minStripWidth, trimAllowance, patternRepeat, opts);
      layAlongX = r0.cost <= r90.cost;
    }

    final r = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts);
    final totalWithWaste = r.totalLinearMm * (1 + wastePercent / 100);

    return StripLayout(
      numStrips: r.stripLengthsMm.length,
      stripLengthsMm: r.stripLengthsMm,
      layAngleDeg: layAlongX ? 0 : 90,
      bboxMinX: minX,
      bboxMinY: minY,
      bboxWidth: bboxW,
      bboxHeight: bboxH,
      layAlongX: layAlongX,
      rollWidthMm: rollWidthMm,
      seamCount: r.seamCount,
      totalLinearWithWasteMm: totalWithWaste,
    );
  }

  /// For one direction: generate strip bands, intersect each with room polygon, compute cut lengths.
  /// Do not skip narrow strips; add sliver penalty. Seam count = numNonEmptyStrips - 1.
  static ({List<double> stripLengthsMm, double totalLinearMm, int seamCount, double cost}) _computeForDirection(
    Room room,
    double rollWidthMm,
    double minX,
    double minY,
    double bboxW,
    double bboxH,
    bool layAlongX,
    double minStripWidth,
    double trimAllowance,
    double patternRepeat,
    CarpetLayoutOptions opts,
  ) {
    final perpLen = layAlongX ? bboxH : bboxW;
    final stripLengths = <double>[];
    int sliverCount = 0;

    int i = 0;
    while (i < 1000) {
      final stripStart = i * rollWidthMm;
      if (stripStart >= perpLen) break;
      final stripEnd = math.min((i + 1) * rollWidthMm, perpLen);
      final stripWidth = stripEnd - stripStart;

      final double left, top, right, bottom;
      if (layAlongX) {
        left = minX;
        right = minX + bboxW;
        top = minY + stripStart;
        bottom = minY + stripEnd;
      } else {
        left = minX + stripStart;
        right = minX + stripEnd;
        top = minY;
        bottom = minY + bboxH;
      }

      final clipped = clipPolygonToRect(room.vertices, left, top, right, bottom);
      if (clipped.length >= 3) {
        double segmentLen = _extentAlong(clipped, layAlongX);
        if (segmentLen > 0) {
          double cutLen = segmentLen + trimAllowance * 2;
          if (patternRepeat > 0) {
            cutLen = (cutLen / patternRepeat).ceilToDouble() * patternRepeat;
          }
          stripLengths.add(cutLen);
          if (stripWidth < minStripWidth) sliverCount++;
        }
      }
      i++;
    }

    if (stripLengths.isEmpty) {
      final alongLen = layAlongX ? bboxW : bboxH;
      final cutLen = alongLen + trimAllowance * 2;
      stripLengths.add(patternRepeat > 0 ? (cutLen / patternRepeat).ceilToDouble() * patternRepeat : cutLen);
    }

    final totalLinear = stripLengths.fold<double>(0, (s, l) => s + l);
    final seamCount = stripLengths.isNotEmpty ? stripLengths.length - 1 : 0;
    final seamPenalty = _seamPenalty(seamCount, opts);
    final sliverPenalty = sliverCount * opts.sliverPenaltyPerStripMm;
    final cost = totalLinear + seamPenalty + sliverPenalty;

    return (stripLengthsMm: stripLengths, totalLinearMm: totalLinear, seamCount: seamCount, cost: cost);
  }

  static double _extentAlong(List<Offset> poly, bool alongX) {
    if (poly.isEmpty) return 0;
    double lo = alongX ? poly[0].dx : poly[0].dy;
    double hi = lo;
    for (final p in poly) {
      final v = alongX ? p.dx : p.dy;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return hi - lo;
  }

  static double _seamPenalty(int seamCount, CarpetLayoutOptions opts) {
    if (seamCount <= 0) return 0;
    final hasDoors = opts.openings.any((o) => o.roomIndex == opts.roomIndex && o.isDoor);
    return seamCount * (hasDoors ? opts.seamPenaltyMmWithDoors : opts.seamPenaltyMmNoDoors);
  }
}
