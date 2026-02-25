import '../geometry/opening.dart';

/// Options for carpet layout computation.
///
/// **Scoring:** Layout cost = material (total linear mm) + seam penalty + sliver penalty.
/// The planner minimizes this cost when choosing lay direction and seam positions.
/// These penalty fields are the single source of truth; increase them to favour fewer seams
/// or fewer slivers over extra material.
///
/// **Doorways:** Seams that cross a doorway (opening with [Opening.isDoor]) use
/// [seamPenaltyMmInDoorway]; other seams use [seamPenaltyMmNoDoors] or [seamPenaltyMmWithDoors].
class CarpetLayoutOptions {
  /// Lay direction: null = auto (choose 0° vs 90° by cost), 0 = horizontal, 90 = vertical.
  final double? layDirectionDeg;

  /// Waste allowance as percent (e.g. 5 = 5%).
  final double wasteAllowancePercent;

  /// Minimum preferred strip width in mm. Narrower strips are still included but add sliver penalty to cost.
  final double minStripWidthMm;

  /// Trim allowance per cut end in mm (added at each end of each cut).
  final double trimAllowanceMm;

  /// Pattern repeat in mm for patterned carpet. Cuts rounded up to next repeat. 0 = plain.
  final double patternRepeatMm;

  /// Openings (doors, pass-throughs) for seam penalty. Seams crossing these are penalized.
  final List<Opening> openings;

  /// Room index (to match openings to this room).
  final int roomIndex;

  /// Seam penalty in mm-equivalent per seam when room has no doors. Used in cost; higher = prefer fewer seams.
  final double seamPenaltyMmNoDoors;

  /// Seam penalty in mm-equivalent per seam when room has doors but seam does not cross a doorway.
  final double seamPenaltyMmWithDoors;

  /// Seam penalty when the seam line crosses a doorway opening. Should be higher than [seamPenaltyMmWithDoors].
  static const double defaultSeamPenaltyMmInDoorway = 2000000;
  final double seamPenaltyMmInDoorway;

  /// Sliver penalty in mm-equivalent per strip narrower than [minStripWidthMm]. Used in cost.
  final double sliverPenaltyPerStripMm;

  /// When non-null, use these seam positions (mm from reference edge) instead of roll-width grid.
  /// Must be strictly increasing and within room extent; validated in RollPlanner.
  final List<double>? seamPositionsOverrideMm;

  /// Builds options for a room from product and overrides. Use this so cut list and roll sheet stay in sync.
  factory CarpetLayoutOptions.forRoom({
    required int roomIndex,
    required double minStripWidthMm,
    required double trimAllowanceMm,
    double patternRepeatMm = 0,
    double wasteAllowancePercent = 5,
    List<Opening> openings = const [],
    List<double>? seamPositionsOverrideMm,
    double? layDirectionDeg,
    double? seamPenaltyMmInDoorway,
  }) {
    return CarpetLayoutOptions(
      layDirectionDeg: layDirectionDeg,
      wasteAllowancePercent: wasteAllowancePercent,
      minStripWidthMm: minStripWidthMm,
      trimAllowanceMm: trimAllowanceMm,
      patternRepeatMm: patternRepeatMm,
      openings: openings,
      roomIndex: roomIndex,
      seamPositionsOverrideMm: seamPositionsOverrideMm?.isNotEmpty == true ? seamPositionsOverrideMm : null,
      seamPenaltyMmInDoorway: seamPenaltyMmInDoorway ?? defaultSeamPenaltyMmInDoorway,
    );
  }

  const CarpetLayoutOptions({
    this.layDirectionDeg,
    this.wasteAllowancePercent = 5.0,
    this.minStripWidthMm = 100.0,
    this.trimAllowanceMm = 75.0,
    this.patternRepeatMm = 0,
    this.openings = const [],
    this.roomIndex = 0,
    this.seamPenaltyMmNoDoors = 500000,
    this.seamPenaltyMmWithDoors = 1000000,
    this.seamPenaltyMmInDoorway = defaultSeamPenaltyMmInDoorway,
    this.sliverPenaltyPerStripMm = 500000,
    this.seamPositionsOverrideMm,
  });

  /// Copy with lay direction override. Pass [layDirectionDeg] to set (0, 90, or null for auto).
  /// Use [copyWithLayDirection] so null can be passed explicitly to mean "auto".
  CarpetLayoutOptions copyWithLayDirection(double? layDirectionDeg) {
    return CarpetLayoutOptions(
      layDirectionDeg: layDirectionDeg,
      wasteAllowancePercent: wasteAllowancePercent,
      minStripWidthMm: minStripWidthMm,
      trimAllowanceMm: trimAllowanceMm,
      patternRepeatMm: patternRepeatMm,
      openings: openings,
      roomIndex: roomIndex,
      seamPenaltyMmNoDoors: seamPenaltyMmNoDoors,
      seamPenaltyMmWithDoors: seamPenaltyMmWithDoors,
      seamPenaltyMmInDoorway: seamPenaltyMmInDoorway,
      sliverPenaltyPerStripMm: sliverPenaltyPerStripMm,
      seamPositionsOverrideMm: seamPositionsOverrideMm,
    );
  }
}
