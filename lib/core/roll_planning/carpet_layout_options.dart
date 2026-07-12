import '../geometry/opening.dart';

/// Strategy for splitting a strip into multiple pieces along its length (lay direction).
///
/// Splitting can reduce waste or allow using offcuts from another room; roll length
/// (when set) only caps max piece length and does not decide whether to split.
enum StripSplitStrategy {
  /// One piece per strip unless the max piece length (roll length cap) forces a split.
  auto,

  /// Always one piece per strip; never split a strip along its length.
  never,

  /// Split long runs (>= ~2m) into at least two pieces (e.g. to use offcuts), capped at the max piece length.
  preferStripInPieces,
}

/// User-adjustable planning settings shared by canvas, cut list and roll sheet.
///
/// Persisted per project as JSON (see `carpetPlanningSettingsJson`); these
/// knobs feed [CarpetLayoutOptions].
class CarpetPlanningSettings {
  /// Waste allowance as percent (e.g. 5 = 5%).
  final double wasteAllowancePercent;

  /// Seam penalty (mm-equivalent) per seam when room has no doors.
  final double seamPenaltyMmNoDoors;

  /// Seam penalty per seam when room has doors but seam does not cross a doorway.
  final double seamPenaltyMmWithDoors;

  /// Seam penalty per seam crossing a doorway opening.
  final double seamPenaltyMmInDoorway;

  /// How far (mm) carpet extends through each door/pass-through opening —
  /// standard take-off measures to under the closed door, roughly half the
  /// wall thickness. 0 disables the extension.
  final double doorwayExtensionMm;

  /// Extra usable-width allowance (mm) consumed per seamed strip edge for
  /// seam trimming/pattern matching. 0 = strips tile the room width exactly.
  final double seamWidthAllowanceMm;

  /// Penalty (mm-equivalent) per strip narrower than the product's minimum
  /// strip width; higher = avoid slivers harder.
  final double sliverPenaltyPerStripMm;

  /// How strips split into pieces along the run. Travels with the other
  /// planning knobs so every layout consumer sees the same value.
  final StripSplitStrategy stripSplitStrategy;

  const CarpetPlanningSettings({
    this.wasteAllowancePercent = 5.0,
    this.seamPenaltyMmNoDoors = 500000,
    this.seamPenaltyMmWithDoors = 1000000,
    this.seamPenaltyMmInDoorway =
        CarpetLayoutOptions.defaultSeamPenaltyMmInDoorway,
    this.doorwayExtensionMm = 35.0,
    this.seamWidthAllowanceMm = 0.0,
    this.sliverPenaltyPerStripMm = 500000,
    this.stripSplitStrategy = StripSplitStrategy.auto,
  });

  Map<String, dynamic> toJson() => {
        'wasteAllowancePercent': wasteAllowancePercent,
        'seamPenaltyMmNoDoors': seamPenaltyMmNoDoors,
        'seamPenaltyMmWithDoors': seamPenaltyMmWithDoors,
        'seamPenaltyMmInDoorway': seamPenaltyMmInDoorway,
        'doorwayExtensionMm': doorwayExtensionMm,
        'seamWidthAllowanceMm': seamWidthAllowanceMm,
        'sliverPenaltyPerStripMm': sliverPenaltyPerStripMm,
        'stripSplitStrategy': stripSplitStrategy.name,
      };

  factory CarpetPlanningSettings.fromJson(Map<String, dynamic> json) {
    const defaults = CarpetPlanningSettings();
    double read(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    final strategyName = json['stripSplitStrategy'] as String?;
    return CarpetPlanningSettings(
      wasteAllowancePercent:
          read('wasteAllowancePercent', defaults.wasteAllowancePercent),
      seamPenaltyMmNoDoors:
          read('seamPenaltyMmNoDoors', defaults.seamPenaltyMmNoDoors),
      seamPenaltyMmWithDoors:
          read('seamPenaltyMmWithDoors', defaults.seamPenaltyMmWithDoors),
      seamPenaltyMmInDoorway:
          read('seamPenaltyMmInDoorway', defaults.seamPenaltyMmInDoorway),
      doorwayExtensionMm:
          read('doorwayExtensionMm', defaults.doorwayExtensionMm),
      seamWidthAllowanceMm:
          read('seamWidthAllowanceMm', defaults.seamWidthAllowanceMm),
      sliverPenaltyPerStripMm:
          read('sliverPenaltyPerStripMm', defaults.sliverPenaltyPerStripMm),
      stripSplitStrategy: StripSplitStrategy.values.asNameMap()[strategyName] ??
          defaults.stripSplitStrategy,
    );
  }

  CarpetPlanningSettings copyWith({
    double? wasteAllowancePercent,
    double? seamPenaltyMmNoDoors,
    double? seamPenaltyMmWithDoors,
    double? seamPenaltyMmInDoorway,
    double? doorwayExtensionMm,
    double? seamWidthAllowanceMm,
    double? sliverPenaltyPerStripMm,
    StripSplitStrategy? stripSplitStrategy,
  }) {
    return CarpetPlanningSettings(
      wasteAllowancePercent:
          wasteAllowancePercent ?? this.wasteAllowancePercent,
      seamPenaltyMmNoDoors: seamPenaltyMmNoDoors ?? this.seamPenaltyMmNoDoors,
      seamPenaltyMmWithDoors:
          seamPenaltyMmWithDoors ?? this.seamPenaltyMmWithDoors,
      seamPenaltyMmInDoorway:
          seamPenaltyMmInDoorway ?? this.seamPenaltyMmInDoorway,
      doorwayExtensionMm: doorwayExtensionMm ?? this.doorwayExtensionMm,
      seamWidthAllowanceMm:
          seamWidthAllowanceMm ?? this.seamWidthAllowanceMm,
      sliverPenaltyPerStripMm:
          sliverPenaltyPerStripMm ?? this.sliverPenaltyPerStripMm,
      stripSplitStrategy: stripSplitStrategy ?? this.stripSplitStrategy,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CarpetPlanningSettings &&
        other.wasteAllowancePercent == wasteAllowancePercent &&
        other.seamPenaltyMmNoDoors == seamPenaltyMmNoDoors &&
        other.seamPenaltyMmWithDoors == seamPenaltyMmWithDoors &&
        other.seamPenaltyMmInDoorway == seamPenaltyMmInDoorway &&
        other.doorwayExtensionMm == doorwayExtensionMm &&
        other.seamWidthAllowanceMm == seamWidthAllowanceMm &&
        other.sliverPenaltyPerStripMm == sliverPenaltyPerStripMm &&
        other.stripSplitStrategy == stripSplitStrategy;
  }

  @override
  int get hashCode => Object.hash(
        wasteAllowancePercent,
        seamPenaltyMmNoDoors,
        seamPenaltyMmWithDoors,
        seamPenaltyMmInDoorway,
        doorwayExtensionMm,
        seamWidthAllowanceMm,
        sliverPenaltyPerStripMm,
        stripSplitStrategy,
      );
}

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

  /// When to split one strip into multiple pieces along the run. User-adjustable.
  final StripSplitStrategy stripSplitStrategy;

  /// Max length in mm for a single piece. When set (e.g. from roll length), caps piece length; when null, a default is used so splitting can still apply for long runs (waste/offcut-driven).
  final double? maxSinglePieceLengthMm;

  /// Extend the room polygon this far (mm) through each opening before
  /// computing strips — carpet runs to under the closed door. 0 = off.
  final double doorwayExtensionMm;

  /// Usable-width allowance (mm) consumed per seamed strip edge for seam
  /// trimming/pattern matching. First strip loses it once (seam side only),
  /// interior strips twice. 0 = strips tile the room width exactly.
  final double seamWidthAllowanceMm;

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
    double? seamPenaltyMmNoDoors,
    double? seamPenaltyMmWithDoors,
    double? seamPenaltyMmInDoorway,
    StripSplitStrategy stripSplitStrategy = StripSplitStrategy.auto,
    double? maxSinglePieceLengthMm,
    double doorwayExtensionMm = 0,
    double seamWidthAllowanceMm = 0,
    double sliverPenaltyPerStripMm = 500000,
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
      seamPenaltyMmNoDoors: seamPenaltyMmNoDoors ?? 500000,
      seamPenaltyMmWithDoors: seamPenaltyMmWithDoors ?? 1000000,
      seamPenaltyMmInDoorway: seamPenaltyMmInDoorway ?? defaultSeamPenaltyMmInDoorway,
      stripSplitStrategy: stripSplitStrategy,
      maxSinglePieceLengthMm: maxSinglePieceLengthMm,
      doorwayExtensionMm: doorwayExtensionMm,
      seamWidthAllowanceMm: seamWidthAllowanceMm,
      sliverPenaltyPerStripMm: sliverPenaltyPerStripMm,
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
    this.stripSplitStrategy = StripSplitStrategy.auto,
    this.maxSinglePieceLengthMm,
    this.doorwayExtensionMm = 0,
    this.seamWidthAllowanceMm = 0,
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
      stripSplitStrategy: stripSplitStrategy,
      maxSinglePieceLengthMm: maxSinglePieceLengthMm,
      doorwayExtensionMm: doorwayExtensionMm,
      seamWidthAllowanceMm: seamWidthAllowanceMm,
    );
  }

  /// Copy with strip split strategy (for user preference).
  CarpetLayoutOptions copyWithStripSplitStrategy(StripSplitStrategy stripSplitStrategy) {
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
      stripSplitStrategy: stripSplitStrategy,
      maxSinglePieceLengthMm: maxSinglePieceLengthMm,
      doorwayExtensionMm: doorwayExtensionMm,
      seamWidthAllowanceMm: seamWidthAllowanceMm,
    );
  }
}
