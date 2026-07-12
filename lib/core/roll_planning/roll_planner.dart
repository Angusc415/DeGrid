import 'dart:math' as math;
import 'dart:ui';
import '../geometry/opening.dart';
import '../geometry/room.dart';
import 'carpet_layout_options.dart';
import 'polygon_clip.dart';
import 'room_opening_extension.dart';

/// Result of computing carpet strip layout for a room.
class StripLayout {
  final int numStrips;
  final List<double> stripLengthsMm;
  /// Width of each strip in mm (perpendicular to lay direction). Used to mark slivers.
  final List<double> stripWidthsMm;
  /// Perpendicular start of each strip in mm from the reference edge (bbox min).
  /// Strips in the same band (disconnected regions of an L/U room) share a start,
  /// so this must be used instead of accumulating [stripWidthsMm].
  final List<double> stripPerpStartsMm;
  /// Along-run start of each strip in mm from the bbox min along the lay
  /// direction (0 for strips spanning the full extent; > 0 for offset legs).
  final List<double> stripAlongStartsMm;
  /// When set, strip [i] is cut into multiple pieces along the run: [pieceLen1, pieceLen2, ...].
  /// When null, each strip is one piece (stripLengthsMm[i] = one cut). Sum per strip must match stripLengthsMm.
  final List<List<double>>? stripPieceLengthsMm;
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
    this.stripPerpStartsMm = const [],
    this.stripAlongStartsMm = const [],
    this.stripPieceLengthsMm,
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

  /// Piece lengths for strip [stripIndex]. When [stripPieceLengthsMm] is set, returns that strip's pieces; else one piece of length stripLengthsMm[stripIndex].
  List<double> pieceLengthsForStrip(int stripIndex) {
    if (stripIndex < 0 || stripIndex >= stripLengthsMm.length) return [];
    if (stripPieceLengthsMm != null &&
        stripIndex < stripPieceLengthsMm!.length &&
        stripPieceLengthsMm![stripIndex].isNotEmpty) {
      return List<double>.from(stripPieceLengthsMm![stripIndex]);
    }
    return [stripLengthsMm[stripIndex]];
  }

  /// Total number of cut pieces (sum of pieces per strip).
  int get totalPieceCount {
    if (stripPieceLengthsMm != null) {
      return stripPieceLengthsMm!.fold<int>(0, (s, list) => s + list.length);
    }
    return stripLengthsMm.length;
  }

  /// True if strip at [index] is narrower than [minWidthMm].
  bool isSliverAt(int index, double minWidthMm) {
    if (index < 0 || index >= stripWidthsMm.length || minWidthMm <= 0) return false;
    return stripWidthsMm[index] < minWidthMm;
  }

  /// Perpendicular start (mm from reference edge) of strip [index].
  /// Uses [stripPerpStartsMm] when available; falls back to accumulating
  /// widths (only correct when each band holds a single strip).
  double stripPerpStartAt(int index) {
    if (index >= 0 && index < stripPerpStartsMm.length) {
      return stripPerpStartsMm[index];
    }
    var start = 0.0;
    for (var i = 0; i < index; i++) {
      start += i < stripWidthsMm.length ? stripWidthsMm[i] : rollWidthMm;
    }
    return start;
  }

  /// Along-run start (mm from bbox min along lay direction) of strip [index].
  double stripAlongStartAt(int index) {
    if (index >= 0 && index < stripAlongStartsMm.length) {
      return stripAlongStartsMm[index];
    }
    return 0.0;
  }

  /// Seam positions in mm from the reference edge (perpendicular to lay direction).
  /// Prefers [seamPositionsMmOverride] (actual seam lines used by the layout),
  /// then distinct strip starts, then the roll-width grid. Empty when numStrips <= 1.
  List<double> get seamPositionsFromReferenceMm {
    if (numStrips <= 1) return [];
    if (seamPositionsMmOverride != null && seamPositionsMmOverride!.isNotEmpty) {
      return List<double>.from(seamPositionsMmOverride!);
    }
    if (stripPerpStartsMm.isNotEmpty) {
      final distinct = stripPerpStartsMm.where((p) => p > 0).toSet().toList()
        ..sort();
      return distinct;
    }
    if (rollWidthMm <= 0) return [];
    return List.generate(numStrips - 1, (i) => (i + 1) * rollWidthMm);
  }

  /// Label for the reference edge (for installer text: "from left wall" or "from top wall").
  /// Horizontal strips (layAlongX): reference is top (minY). Vertical: reference is left (minX).
  String get referenceEdgeLabel => layAlongX ? 'top wall' : 'left wall';

  /// Copy with selected fields replaced. Null keeps the current value.
  StripLayout copyWith({
    int? numStrips,
    List<double>? stripLengthsMm,
    List<double>? stripWidthsMm,
    List<double>? stripPerpStartsMm,
    List<double>? stripAlongStartsMm,
    List<List<double>>? stripPieceLengthsMm,
    double? layAngleDeg,
    double? bboxMinX,
    double? bboxMinY,
    double? bboxWidth,
    double? bboxHeight,
    bool? layAlongX,
    double? rollWidthMm,
    int? seamCount,
    double? totalLinearWithWasteMm,
    List<double>? seamPositionsMmOverride,
    bool? isSinglePiece,
    List<Offset>? roomShapeVerticesMm,
    double? scoreMaterialMm,
    double? scoreSeamPenaltyMm,
    double? scoreSliverPenaltyMm,
    double? scoreCostMm,
  }) {
    return StripLayout(
      numStrips: numStrips ?? this.numStrips,
      stripLengthsMm: stripLengthsMm ?? this.stripLengthsMm,
      stripWidthsMm: stripWidthsMm ?? this.stripWidthsMm,
      stripPerpStartsMm: stripPerpStartsMm ?? this.stripPerpStartsMm,
      stripAlongStartsMm: stripAlongStartsMm ?? this.stripAlongStartsMm,
      stripPieceLengthsMm: stripPieceLengthsMm ?? this.stripPieceLengthsMm,
      layAngleDeg: layAngleDeg ?? this.layAngleDeg,
      bboxMinX: bboxMinX ?? this.bboxMinX,
      bboxMinY: bboxMinY ?? this.bboxMinY,
      bboxWidth: bboxWidth ?? this.bboxWidth,
      bboxHeight: bboxHeight ?? this.bboxHeight,
      layAlongX: layAlongX ?? this.layAlongX,
      rollWidthMm: rollWidthMm ?? this.rollWidthMm,
      seamCount: seamCount ?? this.seamCount,
      totalLinearWithWasteMm:
          totalLinearWithWasteMm ?? this.totalLinearWithWasteMm,
      seamPositionsMmOverride:
          seamPositionsMmOverride ?? this.seamPositionsMmOverride,
      isSinglePiece: isSinglePiece ?? this.isSinglePiece,
      roomShapeVerticesMm: roomShapeVerticesMm ?? this.roomShapeVerticesMm,
      scoreMaterialMm: scoreMaterialMm ?? this.scoreMaterialMm,
      scoreSeamPenaltyMm: scoreSeamPenaltyMm ?? this.scoreSeamPenaltyMm,
      scoreSliverPenaltyMm: scoreSliverPenaltyMm ?? this.scoreSliverPenaltyMm,
      scoreCostMm: scoreCostMm ?? this.scoreCostMm,
    );
  }
}

/// Result of computing strips for one lay direction.
typedef _DirectionResult = ({
  List<double> stripLengthsMm,
  List<double> stripWidthsMm,
  List<double> stripPerpStartsMm,
  List<double> stripAlongStartsMm,
  double totalLinearMm,
  int seamCount,
  double cost,
  List<double>? seamPositionsUsed,
});

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

    // Take-off area: the room polygon extended through door/pass-through
    // openings (carpet runs to under the closed door). The original [room] is
    // still used for seam-vs-doorway checks, whose opening edge indices refer
    // to the unextended ring.
    final effectiveRoom = opts.doorwayExtensionMm > 0
        ? extendRoomThroughOpenings(
            room, opts.openings, opts.roomIndex, opts.doorwayExtensionMm)
        : room;

    final verts = effectiveRoom.vertices;
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

    // Phase 1: single-piece mode when room fits within roll width (template cut, no seams).
    // Honor an explicit lay direction: only take the no-seam path when the
    // requested direction actually fits within the roll width. Otherwise fall
    // through to strip mode so the user's chosen direction is respected (it just
    // needs seams), instead of silently snapping to the fitting orientation.
    final bool? requestedAlongX =
        opts.layDirectionDeg != null ? opts.layDirectionDeg! == 0 : null;
    final bool canSinglePiece = requestedAlongX == null
        ? (fits0 || fits90)
        : (requestedAlongX ? fits0 : fits90);
    if (canSinglePiece) {
      final layAlongX = requestedAlongX ??
          ((fits0 && fits90) ? (bboxW <= bboxH) : fits0);
      final perpLen = layAlongX ? perpLen0 : perpLen90;
      final alongLen = layAlongX ? bboxW : bboxH;
      double cutLen = alongLen + trimAllowance * 2;
      if (patternRepeat > 0) {
        cutLen = (cutLen / patternRepeat).ceilToDouble() * patternRepeat;
      }
      final totalWithWaste = cutLen * (1 + wastePercent / 100);
      final layout = StripLayout(
        numStrips: 1,
        stripLengthsMm: [cutLen],
        stripWidthsMm: [perpLen],
        stripPerpStartsMm: const [0],
        stripAlongStartsMm: const [0],
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
        roomShapeVerticesMm: List<Offset>.from(effectiveRoom.vertices),
        scoreMaterialMm: cutLen,
        scoreSeamPenaltyMm: 0,
        scoreSliverPenaltyMm: 0,
        scoreCostMm: cutLen,
      );
      return _applyStripSplitting(layout, opts, trimAllowance, wastePercent);
    }

    // Strip mode: room wider than roll
    final bool layAlongX;
    if (opts.layDirectionDeg != null) {
      layAlongX = opts.layDirectionDeg! == 0;
    } else {
      final r0 = _computeForDirection(effectiveRoom, room, rollWidthMm, minX, minY, bboxW, bboxH, true, minStripWidth, trimAllowance, patternRepeat, opts, null);
      final r90 = _computeForDirection(effectiveRoom, room, rollWidthMm, minX, minY, bboxW, bboxH, false, minStripWidth, trimAllowance, patternRepeat, opts, null);
      layAlongX = r0.cost <= r90.cost;
    }

    final r = _computeBestLayoutForDirection(effectiveRoom, room, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts);
    final totalWithWaste = r.totalLinearMm * (1 + wastePercent / 100);
    final seamPenaltyMm = _seamPenaltyTotal(r.seamPositionsUsed, room, opts, layAlongX, minX, minY, r.seamCount, rollWidthMm);
    final sliverPenaltyMm = (r.cost - r.totalLinearMm - seamPenaltyMm).clamp(0.0, double.infinity);

    final layout = StripLayout(
      numStrips: r.stripLengthsMm.length,
      stripLengthsMm: r.stripLengthsMm,
      stripWidthsMm: r.stripWidthsMm,
      stripPerpStartsMm: r.stripPerpStartsMm,
      stripAlongStartsMm: r.stripAlongStartsMm,
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
    return _applyStripSplitting(layout, opts, trimAllowance, wastePercent);
  }

  /// Default max piece length (mm) when product roll length is not set. Roll length is only a constraint (cap); splitting is still considered for long runs.
  static const double _defaultMaxPieceLengthMm = 6000.0;
  /// Min run length (mm) to consider splitting; avoids splitting very short runs.
  static const double _minRunLengthToConsiderSplittingMm = 2000.0;

  /// Splits strips into pieces along the run depending on [StripSplitStrategy]:
  ///
  /// - [StripSplitStrategy.never]: layout returned unchanged (caller may flag
  ///   pieces that exceed the physical roll length).
  /// - [StripSplitStrategy.auto]: split only when forced by the physical roll
  ///   length ([CarpetLayoutOptions.maxSinglePieceLengthMm]). When the roll has
  ///   no set length it is treated as infinitely long, so a strip is never
  ///   split — one piece per strip avoids needless seams and trim waste.
  /// - [StripSplitStrategy.preferStripInPieces]: additionally splits any run
  ///   of at least [_minRunLengthToConsiderSplittingMm] into >= 2 pieces
  ///   (e.g. to reuse offcuts). Pieces are sized to the roll length when set,
  ///   else to [_defaultMaxPieceLengthMm].
  ///
  /// Each extra piece adds one cut junction: `2 * trimAllowance` of material
  /// (trim on both sides of the new cut). Strip lengths, waste total and the
  /// cost score are updated to include this extra material.
  static StripLayout _applyStripSplitting(
    StripLayout layout,
    CarpetLayoutOptions opts,
    double trimAllowance,
    double wastePercent,
  ) {
    if (opts.stripSplitStrategy == StripSplitStrategy.never) return layout;
    if (layout.numStrips == 0) return layout;
    final prefer = opts.stripSplitStrategy == StripSplitStrategy.preferStripInPieces;
    final patternRepeat = opts.patternRepeatMm > 0 ? opts.patternRepeatMm : 0.0;
    // Physical hard cap from the roll length. Null = infinitely long roll, so
    // a cut is never *forced* to split.
    final hardCapMm = opts.maxSinglePieceLengthMm;
    // Length used when actually sizing split pieces. For preferStripInPieces
    // we still want to split long runs when no roll length is set, so fall back
    // to a default; for auto with no cap there is nothing to size against.
    var pieceCapMm =
        (hardCapMm ?? (prefer ? _defaultMaxPieceLengthMm : double.infinity))
            .clamp(100.0, double.infinity);
    // Patterned carpet: pieces are rounded up to whole repeats, so size them
    // against a repeat-aligned cap or the rounding would exceed the roll.
    if (patternRepeat > 0 && patternRepeat <= pieceCapMm && pieceCapMm.isFinite) {
      pieceCapMm = (pieceCapMm / patternRepeat).floorToDouble() * patternRepeat;
    }
    final pieceLengthsPerStrip = <List<double>>[];
    final newStripLengthsMm = <double>[];
    bool anySplit = false;
    double extraMaterialMm = 0;
    for (int i = 0; i < layout.numStrips; i++) {
      final L = layout.stripLengthsMm[i];
      final mustSplit = hardCapMm != null && L > hardCapMm;
      final wantSplit = prefer && L >= _minRunLengthToConsiderSplittingMm;
      if (!mustSplit && !wantSplit) {
        pieceLengthsPerStrip.add([L]);
        newStripLengthsMm.add(L);
        continue;
      }
      int n = math.max(
        mustSplit ? (L / pieceCapMm).ceil() : 1,
        wantSplit ? 2 : 1,
      );
      double total = L + (n - 1) * 2 * trimAllowance;
      // Extra trim can push pieces back over the cap; add pieces until they fit.
      while (total / n > pieceCapMm && n < 1000) {
        n++;
        total = L + (n - 1) * 2 * trimAllowance;
      }
      if (n <= 1) {
        pieceLengthsPerStrip.add([L]);
        newStripLengthsMm.add(L);
        continue;
      }
      anySplit = true;
      final step = total / n;
      var pieces = List<double>.generate(
        n,
        (j) => j < n - 1 ? step : total - step * (n - 1),
      );
      if (patternRepeat > 0) {
        // Each piece must start on a repeat so cross-joins pattern-match.
        pieces = [
          for (final p in pieces)
            (p / patternRepeat).ceilToDouble() * patternRepeat,
        ];
        total = pieces.fold<double>(0, (a, b) => a + b);
      }
      extraMaterialMm += total - L;
      pieceLengthsPerStrip.add(pieces);
      newStripLengthsMm.add(total);
    }
    if (!anySplit) return layout;
    final newTotalLinear =
        newStripLengthsMm.fold<double>(0, (a, b) => a + b);
    return layout.copyWith(
      stripLengthsMm: newStripLengthsMm,
      stripPieceLengthsMm: pieceLengthsPerStrip,
      totalLinearWithWasteMm: newTotalLinear * (1 + wastePercent / 100),
      scoreMaterialMm: layout.scoreMaterialMm + extraMaterialMm,
      scoreCostMm: layout.scoreCostMm + extraMaterialMm,
    );
  }

  static const double _minStripWidthForOverrideMm = 50.0;
  /// Number of grid offsets scanned when optimizing seam positions. Layouts
  /// are cheap to evaluate, and a finer scan often lands a seam on a notch
  /// edge or removes a sliver entirely.
  static const int _seamOptimizationPhases = 12;

  /// Try several grid offsets (seam positions) and return the layout with lowest cost.
  static _DirectionResult _computeBestLayoutForDirection(
    Room room,
    Room openingsRoom,
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
      return _computeForDirection(room, openingsRoom, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts, null);
    }
    var best = _computeForDirection(room, openingsRoom, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts, null);
    final perpLen = layAlongX ? bboxH : bboxW;

    // Candidate grid offsets: uniform phases plus notch-edge alignment. A
    // seam landing exactly on a notch edge (a vertex's perpendicular
    // coordinate) splits that band into separate legs instead of carpeting
    // across the void — often a large material saving for L/U/T rooms that
    // the uniform scan misses.
    final offsets = <double>{};
    for (int phase = 1; phase < _seamOptimizationPhases; phase++) {
      offsets.add((phase / _seamOptimizationPhases) * rollWidthMm);
    }
    final perpMin = layAlongX ? minY : minX;
    for (final v in room.vertices) {
      final perp = (layAlongX ? v.dy : v.dx) - perpMin;
      if (perp <= 0 || perp >= perpLen) continue;
      final offset = perp % rollWidthMm;
      if (offset > 0) offsets.add(offset);
    }

    for (final offset in offsets) {
      if (offset <= 0 || offset >= perpLen) continue;
      final candidate = _computeForDirection(room, openingsRoom, rollWidthMm, minX, minY, bboxW, bboxH, layAlongX, minStripWidth, trimAllowance, patternRepeat, opts, offset);
      if (candidate.cost < best.cost) best = candidate;
    }
    return best;
  }

  /// For one direction: generate strip bands, intersect each with room polygon, compute cut lengths.
  /// When [opts.seamPositionsOverrideMm] is set, use those as strip boundaries (validated and clamped).
  /// When [gridOffsetMm] is non-null (and no overrides), use a shifted grid so seams are optimized.
  /// [openingsRoom] is the unextended room whose edge indices match
  /// [CarpetLayoutOptions.openings] (for seam-vs-doorway penalty checks);
  /// [room] may be the doorway-extended polygon used for clipping.
  static _DirectionResult _computeForDirection(
    Room room,
    Room openingsRoom,
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
    final stripPerpStarts = <double>[];
    final stripAlongStarts = <double>[];
    int sliverCount = 0;
    List<double>? boundaries;

    // Seam width allowance: each seamed strip edge consumes this much usable
    // width, so the coverage grid steps by less than the roll width. The
    // first strip has one seamed edge (wall side needs none), interior strips
    // two. Ignored when it would leave no meaningful strip width.
    final seamAllowance = (opts.seamWidthAllowanceMm > 0 &&
            rollWidthMm - 2 * opts.seamWidthAllowanceMm >=
                _minStripWidthForOverrideMm)
        ? opts.seamWidthAllowanceMm
        : 0.0;
    final firstStep = rollWidthMm - seamAllowance;
    final innerStep = rollWidthMm - 2 * seamAllowance;

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
      // Build boundaries from a shifted grid: first boundary in (0, firstStep],
      // subsequent boundaries one usable-width apart.
      boundaries = <double>[];
      double b = gridOffsetMm.clamp(0.0, firstStep);
      while (b <= 0) {
        b += innerStep;
      }
      while (b < perpLen) {
        if (b > 0) boundaries.add(b);
        b += innerStep;
      }
      boundaries.sort();
      if (boundaries.isEmpty) boundaries = null;
    } else if (seamAllowance > 0 && perpLen > rollWidthMm) {
      // Default grid with seam allowance: boundaries at cumulative usable
      // widths instead of raw roll widths.
      boundaries = <double>[];
      double b = firstStep;
      while (b < perpLen) {
        boundaries.add(b);
        b += innerStep;
      }
      if (boundaries.isEmpty) boundaries = null;
    } else {
      boundaries = null;
    }

    // Each band [stripStart, stripEnd] can produce multiple strips for
    // L/T/U-shaped rooms. Sampled regions decide connectivity only; the exact
    // strip extent comes from clipping the polygon to the expanded cell
    // (see [expandRegionsToCells]) so angled walls are never truncated.
    // Inset the clip by a hair on the perpendicular axis: a room edge lying
    // exactly on a band boundary (e.g. a seam aligned with a notch edge)
    // otherwise contributes a zero-height full-width sliver to the clip and
    // inflates the strip's along-extent with material that isn't needed.
    const perpEps = 0.5;

    void addStripsForBand(double stripStart, double stripEnd) {
      final stripWidth = stripEnd - stripStart;
      final left = layAlongX ? minX : minX + stripStart;
      final top = layAlongX ? minY + stripStart : minY;
      final right = layAlongX ? minX + bboxW : minX + stripEnd;
      final bottom = layAlongX ? minY + stripEnd : minY + bboxH;
      final inset = stripWidth > 2 * perpEps ? perpEps : 0.0;
      final clipTop = layAlongX ? top + inset : top;
      final clipBottom = layAlongX ? bottom - inset : bottom;
      final clipLeft = layAlongX ? left : left + inset;
      final clipRight = layAlongX ? right : right - inset;

      final regions = expandRegionsToCells(
        sweepBandForRegions(room.vertices, left, top, right, bottom, layAlongX),
        left,
        top,
        right,
        bottom,
        layAlongX,
      );
      for (final region in regions) {
        final clipped = clipPolygonToRect(
          room.vertices,
          layAlongX ? region.left : clipLeft,
          layAlongX ? clipTop : region.top,
          layAlongX ? region.right : clipRight,
          layAlongX ? clipBottom : region.bottom,
        );
        if (clipped.length < 3) continue;
        final range = _rangeAlong(clipped, layAlongX);
        final segmentLen = range.hi - range.lo;
        if (segmentLen <= 0) continue;
        double cutLen = segmentLen + trimAllowance * 2;
        if (patternRepeat > 0) {
          cutLen = (cutLen / patternRepeat).ceilToDouble() * patternRepeat;
        }
        stripLengths.add(cutLen);
        stripWidths.add(stripWidth);
        stripPerpStarts.add(stripStart);
        stripAlongStarts.add(range.lo - (layAlongX ? minX : minY));
        if (stripWidth < minStripWidth) sliverCount++;
      }
    }

    if (boundaries != null) {
      // User seam overrides (or shifted grid) as strip boundaries.
      final bandEnds = [...boundaries, perpLen];
      double stripStart = 0;
      for (final stripEnd in bandEnds) {
        addStripsForBand(stripStart, stripEnd);
        stripStart = stripEnd;
      }
    } else {
      int i = 0;
      while (i < 1000) {
        final stripStart = i * rollWidthMm;
        if (stripStart >= perpLen) break;
        final stripEnd = math.min((i + 1) * rollWidthMm, perpLen);
        addStripsForBand(stripStart, stripEnd);
        i++;
      }
    }

    if (stripLengths.isEmpty) {
      final alongLen = layAlongX ? bboxW : bboxH;
      final cutLen = alongLen + trimAllowance * 2;
      stripLengths.add(patternRepeat > 0 ? (cutLen / patternRepeat).ceilToDouble() * patternRepeat : cutLen);
      stripWidths.add(perpLen);
      stripPerpStarts.add(0);
      stripAlongStarts.add(0);
    }

    final totalLinear = stripLengths.fold<double>(0, (s, l) => s + l);
    // Actual seam lines: distinct band boundaries where a strip starts. Strips
    // sharing a band (disconnected regions) do not add a seam between them.
    final seamLines = stripPerpStarts.where((p) => p > 0).toSet().toList()
      ..sort();
    final seamCount = seamLines.length;
    final seamPositionsUsed = seamLines.isNotEmpty ? seamLines : null;
    final seamPenalty = _seamPenaltyTotal(seamPositionsUsed, openingsRoom, opts, layAlongX, minX, minY, seamCount, rollWidthMm);
    final sliverPenalty = sliverCount * opts.sliverPenaltyPerStripMm;
    final cost = totalLinear + seamPenalty + sliverPenalty;

    return (
      stripLengthsMm: stripLengths,
      stripWidthsMm: stripWidths,
      stripPerpStartsMm: stripPerpStarts,
      stripAlongStartsMm: stripAlongStarts,
      totalLinearMm: totalLinear,
      seamCount: seamCount,
      cost: cost,
      seamPositionsUsed: seamPositionsUsed,
    );
  }

  static ({double lo, double hi}) _rangeAlong(List<Offset> poly, bool alongX) {
    if (poly.isEmpty) return (lo: 0, hi: 0);
    double lo = alongX ? poly[0].dx : poly[0].dy;
    double hi = lo;
    for (final p in poly) {
      final v = alongX ? p.dx : p.dy;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return (lo: lo, hi: hi);
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
