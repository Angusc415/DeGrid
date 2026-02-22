import '../geometry/opening.dart';

/// Options for carpet layout computation.
/// Covers lay direction, waste, seam rules, trim, pattern repeat, and room openings for seam penalty.
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

  /// Seam penalty in mm-equivalent per seam when room has no doors (tuning weight).
  final double seamPenaltyMmNoDoors;

  /// Seam penalty in mm-equivalent per seam when room has doors (higher = avoid seams near doors).
  final double seamPenaltyMmWithDoors;

  /// Sliver penalty in mm-equivalent per strip that is narrower than minStripWidthMm.
  final double sliverPenaltyPerStripMm;

  /// When non-null, use these seam positions (mm from reference edge) instead of roll-width grid.
  /// Must be strictly increasing and within room extent; validated in RollPlanner.
  final List<double>? seamPositionsOverrideMm;

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
    this.sliverPenaltyPerStripMm = 500000,
    this.seamPositionsOverrideMm,
  });
}
