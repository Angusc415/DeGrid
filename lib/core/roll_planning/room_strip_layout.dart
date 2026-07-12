import '../geometry/carpet_product.dart';
import '../geometry/opening.dart';
import '../geometry/room.dart';
import 'carpet_layout_options.dart';
import 'roll_planner.dart';

/// Lay direction from a layout variant index: 0 = Auto (null), 1 = 0°, 2 = 90°.
double? layDirectionDegFromVariant(int variantIndex) {
  return variantIndex == 0 ? null : (variantIndex == 1 ? 0.0 : 90.0);
}

/// Computes the strip layout for one room, applying all user adjustments.
///
/// Single shared entry point so the canvas, painter, cut list and roll cut
/// sheet always agree. Wraps [CarpetLayoutOptions.forRoom] +
/// [RollPlanner.computeLayout] and applies the user's along-run piece-length
/// override ([stripPieceLengthsOverride], from dragging along-run seams).
///
/// [layDirectionDeg] should be the seam-locked direction when the room has
/// seam overrides, else derived from the room's layout variant
/// (see [layDirectionDegFromVariant]). Returns null when [product] has no
/// usable roll width.
StripLayout? computeRoomStripLayout({
  required Room room,
  required int roomIndex,
  required CarpetProduct product,
  required List<Opening> openings,
  List<double>? seamOverrides,
  double? layDirectionDeg,
  List<List<double>>? stripPieceLengthsOverride,
  CarpetPlanningSettings settings = const CarpetPlanningSettings(),
}) {
  if (product.rollWidthMm <= 0) return null;
  final opts = CarpetLayoutOptions.forRoom(
    roomIndex: roomIndex,
    minStripWidthMm: product.minStripWidthMm ?? 100,
    trimAllowanceMm: product.trimAllowanceMm ?? 75,
    patternRepeatMm: product.patternRepeatMm ?? 0,
    wasteAllowancePercent: settings.wasteAllowancePercent,
    openings: openings,
    seamPositionsOverrideMm:
        seamOverrides?.isNotEmpty == true ? seamOverrides : null,
    layDirectionDeg: layDirectionDeg,
    seamPenaltyMmNoDoors: settings.seamPenaltyMmNoDoors,
    seamPenaltyMmWithDoors: settings.seamPenaltyMmWithDoors,
    seamPenaltyMmInDoorway: settings.seamPenaltyMmInDoorway,
    stripSplitStrategy: settings.stripSplitStrategy,
    maxSinglePieceLengthMm:
        product.rollLengthM != null ? product.rollLengthM! * 1000 : null,
    doorwayExtensionMm: settings.doorwayExtensionMm,
    seamWidthAllowanceMm: settings.seamWidthAllowanceMm,
    sliverPenaltyPerStripMm: settings.sliverPenaltyPerStripMm,
  );
  final layout = RollPlanner.computeLayout(room, product.rollWidthMm, opts);
  return applyStripPieceLengthsOverride(
    layout,
    stripPieceLengthsOverride,
    wastePercent: settings.wasteAllowancePercent,
  );
}

/// Applies the user's along-run piece-length override to [layout].
///
/// The override is ignored when empty or when its strip count no longer
/// matches the layout (e.g. room geometry or seams changed underneath it).
/// Totals and score fields are recomputed so waste/material stay consistent
/// with the overridden lengths; [wastePercent] defaults to the ratio already
/// baked into the layout.
StripLayout applyStripPieceLengthsOverride(
  StripLayout layout,
  List<List<double>>? override, {
  double? wastePercent,
}) {
  if (override == null ||
      override.isEmpty ||
      override.length != layout.numStrips) {
    return layout;
  }
  final stripLengthsMm =
      override.map((p) => p.fold<double>(0.0, (a, b) => a + b)).toList();
  final newTotal = stripLengthsMm.fold<double>(0.0, (a, b) => a + b);
  final oldTotal = layout.totalLinearMm;
  final wasteFactor = wastePercent != null
      ? 1 + wastePercent / 100
      : (oldTotal > 0 && layout.totalLinearWithWasteMm != null
          ? layout.totalLinearWithWasteMm! / oldTotal
          : 1.0);
  final materialDelta = newTotal - oldTotal;
  return layout.copyWith(
    stripLengthsMm: stripLengthsMm,
    stripPieceLengthsMm: override,
    totalLinearWithWasteMm: layout.totalLinearWithWasteMm != null
        ? newTotal * wasteFactor
        : null,
    scoreMaterialMm: layout.scoreMaterialMm + materialDelta,
    scoreCostMm: layout.scoreCostMm + materialDelta,
  );
}
