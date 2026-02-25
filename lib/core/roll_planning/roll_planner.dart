import 'dart:math' as math;
import 'dart:ui';
import '../geometry/opening.dart';
import '../geometry/room.dart';
import 'carpet_layout_options.dart';
import 'polygon_clip.dart';

/// Result of computing carpet strip layout for a room.
class StripLayout {
  final int numStrips;
  final List<double> stripLengthsMm;
  /// Width of each strip in mm (perpendicular to lay direction). Used to mark slivers.
  final List<double> stripWidthsMm;
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
  /// When layout used seam overrides, this holds the actual seam positions (mm from reference).
  final List<double>? seamPositionsMmOverride;
  /// True when room fits within roll width: one template cut in room shape (no seams).
  final bool isSinglePiece;
  /// Room polygon in world mm for single-piece visualization. Null in strip mode.
  final List<Offset>? roomShapeVerticesMm;
  /// Score breakdown (material + seam + sliver penalties). Used for UI and comparison.
  final double scoreMaterialMm;
  final double scoreSeamPenaltyMm;
  final double scoreSliverPenaltyMm;
  final double scoreCostMm;

  StripLayout({
    required this.numStrips,
    required this.stripLengthsMm,
    this.stripWidthsMm = const [],
    required this.layAngleDeg,
    this.bboxMinX = 0,
    this.bboxMinY = 0,
    this.bboxWidth = 0,
    this.bboxHeight = 0,
    this.layAlongX = true,
    this.rollWidthMm = 0,
    this.seamCount = 0,
    this.totalLinearWithWasteMm,
    this.seamPositionsMmOverride,
    this.isSinglePiece = false,
    this.roomShapeVerticesMm,
    this.scoreMaterialMm = 0,
    this.scoreSeamPenaltyMm = 0,
    this.scoreSliverPenaltyMm = 0,
    this.scoreCostMm = 0,
  });

  /// True if strip at [index] is narrower than [minWidthMm].
  bool isSliverAt(int index, double minWidthMm) {
    if (index < 0 || index >= stripWidthsMm.length || minWidthMm <= 0) return false;
    return stripWidthsMm[index] < minWidthMm;
  }

  /// Seam positions in mm from the reference edge (perpendicular to lay direction).
  /// When [seamPositionsMmOverride] is set, returns that; otherwise from roll-width grid.
  /// Empty when numStrips <= 1.
  List<double> get seamPositionsFromReferenceMm {
    if (numStrips <= 1) return [];
    if (seamPositionsMmOverride != null && seamPositionsMmOverride!.isNotEmpty) {
      return List<double>.from(seamPositionsMmOverride!);
    }
    if (rollWidthMm <= 0) return [];
    return List.generate(numStrips - 1, (i) => (i + 1) * rollWidthMm);
  }

  /// Label for the reference edge (for installer text: "from left wall" or "from top wall").
  /// Horizontal strips (layAlongX): reference is top (minY). Vertical: reference is left (minX).
  String get referenceEdgeLabel => layAlongX ? 'top wall' : 'left wall';
}

/// Computes carpet strip layout by intersecting strip bands with the room polygon.
///
/// Computes carpet strip layout by intersecting strip bands with the room polygon.
/// Auto-optimizes when no manual overrides: direction (0° vs 90° by cost), seam position (4 grid offsets, lowest cost), waste % for ordering.
/// Strip length = extent of (room ∩ strip band) + trim; pattern rounding applied. Sliver penalty in cost. Manual seam/cut overrides preserved.
class RollPlanner {
  static const double _defaultMinStripWidthMm = 100.0;
  static const double _defaultTrimAllowanceMm = 75.0;
  static const double _defaultWastePercent = 5.0;

  /// Returns up to three layout candidates: [Auto (balanced), 0° (horizontal), 90° (vertical)].
  /// Index 0 = auto (lowest cost), 1 = force 0°, 2 = force 90°. Use [roomLayoutVariantIndex] to pick one per room.
  static List<StripLayout> computeLayoutCandidates(
    Room room,
    double rollWidthMm, [
    CarpetLayoutOptions? options,
  ]) {
    final opts = options ?? const CarpetLayoutOptions();
    return [
      computeLayout(room, rollWidthMm, opts.copyWithLayDirection(null)),
      computeLayout(room, rollWidthMm, opts.copyWithLayDirection(0)),
      computeLayout(room, rollWidthMm, opts.copyWithLayDirection(90)),
    ];
  }

  static StripLayout computeLayout(
    Room room,
    double rollWidthMm, [
    CarpetLayoutOptions? options,
  ]) {
    if (rollWidthMm <= 0 || room.vertices.isEmpty) {
      return StripLayout(
        numStrips: 0,
        stripLengthsMm: const [],
        stripWidthsMm: const [],
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

    final perpLen0 = bboxH; // perpendicular when strips run along x
    final perpLen90 = bboxW;
    final fits0 = perpLen0 <= rollWidthMm;
    final fits90 = perpLen90 <= rollWidthMm;

    // Phase 1: single-piece mode when room fits within roll width (template cut, no seams)
    if (fits0 || fits90) {
      final layAlongX = (fits0 && fits90)
          ? (opts.layDirectionDeg != null ? opts.layDirectionDeg! == 0 : (bboxW <= bboxH))
          : fits0;
      final perpLen = layAlongX ? perpLen0 : perpLen90;
      final alongLen = layAlongX ? bboxW : bboxH;
      double cutLen = alongLen + trimAllowance * 2;
      if (patternRepeat > 0) {
        cutLen = (cutLen / patternRepeat).ceilToDouble() * patternRepeat;
      }
      final totalWithWaste = cutLen * (1 + wastePercent / 100);
      return StripLayout(
        numStrips: 1,
        stripLengthsMm: [cutLen],
        stripWidthsMm: [perpLen],
        layAngleDeg: layAlongX ? 0 : 90,
        bboxMinX: minX,
        bboxMinY: minY,
        bboxWidth: bboxW,
        bboxHeight: bboxH,
        layAlongX: layAlongX,
        rollWidthMm: rollWidthMm,
        seamCount: 0,
        totalLinearWithWasteMm: totalWithWaste,
        seamPositionsMmOverride: null,
        isSinglePiece: true,
        roomShapeVerticesMm: List<Offset>.from(room.vertices),
        scoreMaterialMm: cutLen,
        scoreSeamPenaltyMm: 0,
        scoreSliverPenaltyMm: 0,
        scoreCostMm: cutLen,
      );
    }

    // Strip mode: room wider than roll
    final bool layAlongX;
    if (opts.layDirectionDeg != null) {
      layAlongX = opts.layDirectionDeg! == 0;
    } else {
      final r0 = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, true, minStripWidth, trimAllowance, patternRepeat, opts, null);
      final r90 = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, false, minStripWidth, trimAllowance, patternRepeat, opts, null);
      layAlongX = r0.cost <= r90.cost;
    }

    final r = _computeBestLayoutForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts);
    final totalWithWaste = r.totalLinearMm * (1 + wastePercent / 100);
    final seamPenaltyMm = _seamPenaltyTotal(r.seamPositionsUsed, room, opts, layAlongX, minX, minY, r.seamCount, rollWidthMm);
    final sliverPenaltyMm = (r.cost - r.totalLinearMm - seamPenaltyMm).clamp(0.0, double.infinity);

    return StripLayout(
      numStrips: r.stripLengthsMm.length,
      stripLengthsMm: r.stripLengthsMm,
      stripWidthsMm: r.stripWidthsMm,
      layAngleDeg: layAlongX ? 0 : 90,
      bboxMinX: minX,
      bboxMinY: minY,
      bboxWidth: bboxW,
      bboxHeight: bboxH,
      layAlongX: layAlongX,
      rollWidthMm: rollWidthMm,
      seamCount: r.seamCount,
      totalLinearWithWasteMm: totalWithWaste,
      seamPositionsMmOverride: r.seamPositionsUsed,
      isSinglePiece: false,
      roomShapeVerticesMm: null,
      scoreMaterialMm: r.totalLinearMm,
      scoreSeamPenaltyMm: seamPenaltyMm,
      scoreSliverPenaltyMm: sliverPenaltyMm,
      scoreCostMm: r.cost,
    );
  }

  static const double _minStripWidthForOverrideMm = 50.0;
  static const int _seamOptimizationPhases = 4;

  /// Try several grid offsets (seam positions) and return the layout with lowest cost.
  static ({List<double> stripLengthsMm, List<double> stripWidthsMm, double totalLinearMm, int seamCount, double cost, List<double>? seamPositionsUsed}) _computeBestLayoutForDirection(
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
    if (opts.seamPositionsOverrideMm != null && opts.seamPositionsOverrideMm!.isNotEmpty) {
      return _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts, null);
    }
    var best = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts, null);
    final perpLen = layAlongX ? bboxH : bboxW;
    for (int phase = 1; phase < _seamOptimizationPhases; phase++) {
      final offset = (phase / _seamOptimizationPhases) * rollWidthMm;
      if (offset >= perpLen) break;
      final candidate = _computeForDirection(room, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts, offset);
      if (candidate.cost < best.cost) best = candidate;
    }
    return best;
  }

  /// For one direction: generate strip bands, intersect each with room polygon, compute cut lengths.
  /// When [opts.seamPositionsOverrideMm] is set, use those as strip boundaries (validated and clamped).
  /// When [gridOffsetMm] is non-null (and no overrides), use a shifted grid so seams are optimized (try 0, 0.25, 0.5, 0.75 * rollWidth).
  static ({List<double> stripLengthsMm, List<double> stripWidthsMm, double totalLinearMm, int seamCount, double cost, List<double>? seamPositionsUsed}) _computeForDirection(
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
    double? gridOffsetMm,
  ) {
    final perpLen = layAlongX ? bboxH : bboxW;
    final stripLengths = <double>[];
    final stripWidths = <double>[];
    int sliverCount = 0;
    List<double>? boundaries;

    if (opts.seamPositionsOverrideMm != null && opts.seamPositionsOverrideMm!.isNotEmpty) {
      // Validate and clamp override positions: sorted, in (0, perpLen), min gap _minStripWidthForOverrideMm
      final raw = List<double>.from(opts.seamPositionsOverrideMm!)..sort();
      boundaries = <double>[];
      double prev = 0;
      for (final p in raw) {
        final clamped = p.clamp(prev + _minStripWidthForOverrideMm, perpLen - _minStripWidthForOverrideMm);
        if (clamped > prev && (boundaries.isEmpty || clamped < perpLen)) {
          boundaries.add(clamped);
          prev = clamped;
        }
      }
      if (boundaries.isEmpty) boundaries = null;
    } else if (gridOffsetMm != null && gridOffsetMm > 0) {
      // Build boundaries from shifted grid: first boundary in (0, perpLen) at offset + k*rollWidth
      boundaries = <double>[];
      double b = gridOffsetMm;
      while (b <= 0) b += rollWidthMm;
      while (b < perpLen) {
        if (b > 0) boundaries.add(b);
        b += rollWidthMm;
      }
      boundaries.sort();
      if (boundaries.isEmpty) boundaries = null;
    } else {
      boundaries = null;
    }

    if (boundaries != null) {
      // Phase 2: Apply sweep-based logic to user seam overrides.
      // Each band [stripStart, stripEnd] can produce multiple strips for L/T-shaped rooms.
      final bandEnds = [...boundaries, perpLen];
      double stripStart = 0;
      for (final stripEnd in bandEnds) {
        final stripWidth = stripEnd - stripStart;
        final left = layAlongX ? minX : minX + stripStart;
        final top = layAlongX ? minY + stripStart : minY;
        final right = layAlongX ? minX + bboxW : minX + stripEnd;
        final bottom = layAlongX ? minY + stripEnd : minY + bboxH;

        for (final region in sweepBandForRegions(room.vertices, left, top, right, bottom, layAlongX)) {
          final clipped = clipPolygonToRect(room.vertices, region.left, region.top, region.right, region.bottom);
          if (clipped.length >= 3) {
            double segmentLen = _extentAlong(clipped, layAlongX);
            if (segmentLen > 0) {
              double cutLen = segmentLen + trimAllowance * 2;
              if (patternRepeat > 0) cutLen = (cutLen / patternRepeat).ceilToDouble() * patternRepeat;
              stripLengths.add(cutLen);
              stripWidths.add(stripWidth);
              if (stripWidth < minStripWidth) sliverCount++;
            }
          }
        }
        stripStart = stripEnd;
      }
    } else {
      // Phase 1 non-rectangular: sweep each band to find all disconnected regions
      // (e.g. L-shape vertical + horizontal legs). Output one strip per region.
      int i = 0;
      while (i < 1000) {
        final stripStart = i * rollWidthMm;
        if (stripStart >= perpLen) break;
        final stripEnd = math.min((i + 1) * rollWidthMm, perpLen);
        final stripWidth = stripEnd - stripStart;
        final left = layAlongX ? minX : minX + stripStart;
        final top = layAlongX ? minY + stripStart : minY;
        final right = layAlongX ? minX + bboxW : minX + stripEnd;
        final bottom = layAlongX ? minY + stripEnd : minY + bboxH;

        for (final region in sweepBandForRegions(room.vertices, left, top, right, bottom, layAlongX)) {
          final clipped = clipPolygonToRect(room.vertices, region.left, region.top, region.right, region.bottom);
          if (clipped.length >= 3) {
            double segmentLen = _extentAlong(clipped, layAlongX);
            if (segmentLen > 0) {
              double cutLen = segmentLen + trimAllowance * 2;
              if (patternRepeat > 0) {
                cutLen = (cutLen / patternRepeat).ceilToDouble() * patternRepeat;
              }
              stripLengths.add(cutLen);
              stripWidths.add(stripWidth);
              if (stripWidth < minStripWidth) sliverCount++;
            }
          }
        }
        i++;
      }

      if (stripLengths.isEmpty) {
        final alongLen = layAlongX ? bboxW : bboxH;
        final cutLen = alongLen + trimAllowance * 2;
        stripLengths.add(patternRepeat > 0 ? (cutLen / patternRepeat).ceilToDouble() * patternRepeat : cutLen);
        stripWidths.add(perpLen);
      }
    }

    final totalLinear = stripLengths.fold<double>(0, (s, l) => s + l);
    final seamCount = stripLengths.isNotEmpty ? stripLengths.length - 1 : 0;
    final seamPositionsForPenalty = boundaries ?? (seamCount > 0
        ? List.generate(seamCount, (i) => (i + 1) * rollWidthMm)
        : null);
    final seamPenalty = _seamPenaltyTotal(seamPositionsForPenalty, room, opts, layAlongX, minX, minY, seamCount, rollWidthMm);
    final sliverPenalty = sliverCount * opts.sliverPenaltyPerStripMm;
    final cost = totalLinear + seamPenalty + sliverPenalty;
    // Expose override positions when we used them (seam lines on plan). Strip count may exceed
    // boundaries.length + 1 for L/T-shaped rooms (multiple strips per band).
    final used = boundaries;

    return (stripLengthsMm: stripLengths, stripWidthsMm: stripWidths, totalLinearMm: totalLinear, seamCount: seamCount, cost: cost, seamPositionsUsed: used);
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

  /// Total seam penalty from per-seam logic: doorway-crossing seams use [seamPenaltyMmInDoorway].
  static double _seamPenaltyTotal(
    List<double>? seamPositionsMm,
    Room room,
    CarpetLayoutOptions opts,
    bool layAlongX,
    double minX,
    double minY,
    int seamCount,
    double rollWidthMm,
  ) {
    if (seamCount <= 0) return 0;
    final positions = seamPositionsMm ?? List.generate(seamCount, (i) => (i + 1) * rollWidthMm);
    final hasDoors = opts.openings.any((o) => o.roomIndex == opts.roomIndex && o.isDoor);
    double total = 0;
    for (final pos in positions) {
      if (_seamCrossesDoorway(room, opts.openings, opts.roomIndex, layAlongX, minX, minY, pos)) {
        total += opts.seamPenaltyMmInDoorway;
      } else {
        total += hasDoors ? opts.seamPenaltyMmWithDoors : opts.seamPenaltyMmNoDoors;
      }
    }
    return total;
  }

  /// True if the seam line at [seamPositionMm] (from reference edge) crosses any doorway opening.
  static bool _seamCrossesDoorway(
    Room room,
    List<Opening> openings,
    int roomIndex,
    bool layAlongX,
    double minX,
    double minY,
    double seamPositionMm,
  ) {
    final seamCoord = layAlongX ? minY + seamPositionMm : minX + seamPositionMm;
    for (final o in openings) {
      if (o.roomIndex != roomIndex || !o.isDoor) continue;
      final seg = _openingSegment(room, o);
      if (seg == null) continue;
      if (_seamLineCrossesSegment(layAlongX, seamCoord, seg.$1, seg.$2)) return true;
    }
    return false;
  }

  /// Opening segment in room coordinates (start, end). Null if edge index invalid.
  static (Offset, Offset)? _openingSegment(Room room, Opening o) {
    final v = room.vertices;
    if (v.isEmpty) return null;
    final i = o.edgeIndex;
    if (i < 0 || i >= v.length) return null;
    final v0 = v[i];
    final v1 = v[(i + 1) % v.length];
    final dx = v1.dx - v0.dx;
    final dy = v1.dy - v0.dy;
    final edgeLen = math.sqrt(dx * dx + dy * dy);
    if (edgeLen <= 0) return null;
    final t0 = o.offsetMm / edgeLen;
    final t1 = (o.offsetMm + o.widthMm) / edgeLen;
    final p0 = Offset(v0.dx + t0 * dx, v0.dy + t0 * dy);
    final p1 = Offset(v0.dx + t1 * dx, v0.dy + t1 * dy);
    return (p0, p1);
  }

  /// True if the seam line (horizontal at y=[seamCoord] when [layAlongX], else vertical at x=[seamCoord]) crosses the segment [p0]–[p1].
  static bool _seamLineCrossesSegment(bool layAlongX, double seamCoord, Offset p0, Offset p1) {
    if (layAlongX) {
      return (p0.dy - seamCoord) * (p1.dy - seamCoord) <= 0;
    } else {
      return (p0.dx - seamCoord) * (p1.dx - seamCoord) <= 0;
    }
  }
}
