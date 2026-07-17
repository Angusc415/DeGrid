import 'dart:math' as math;

import '../geometry/carpet_product.dart';
import '../models/project.dart';
import '../roll_planning/roll_planner.dart';
import '../roll_planning/room_strip_layout.dart';

/// One line of a job quote. [amount] is null when the matching rate is not
/// set — the quantity still appears so the estimator can price it by hand.
class QuoteLine {
  final String label;
  final String detail;
  final double? amount;

  const QuoteLine({
    required this.label,
    required this.detail,
    this.amount,
  });
}

/// A complete job quote derived from a project's take-off.
class JobQuote {
  final List<QuoteLine> lines;
  final double subtotal;
  final double gstPercent;
  final double gstAmount;
  final double total;

  /// False when one or more lines have no rate — the total is a partial sum.
  final bool fullyPriced;

  const JobQuote({
    required this.lines,
    required this.subtotal,
    required this.gstPercent,
    required this.gstAmount,
    required this.total,
    required this.fullyPriced,
  });

  bool get isEmpty => lines.isEmpty;
}

String _money(double v) => v.toStringAsFixed(2);

String _qty(double v, String unit) {
  var text = v.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return '$text $unit';
}

/// Builds a job quote from a saved project: carpet per product (ordered
/// linear metres from the same layout engine as the cut sheet), underlay,
/// gripper (perimeter minus doorway openings), door bars (one per doorway,
/// mirrored pairs counted once), labour, and GST.
///
/// Empty when the project has no plannable carpet assignments.
JobQuote buildJobQuote(ProjectModel project) {
  final rates = project.quoteRates;
  final lines = <QuoteLine>[];

  // Rooms with a plannable layout, via the shared entry point so quantities
  // always match the cut sheet.
  final layouts = <int, StripLayout>{};
  for (final e in project.roomCarpetAssignments.entries) {
    final ri = e.key;
    final pi = e.value;
    if (ri < 0 || ri >= project.rooms.length) continue;
    if (pi < 0 || pi >= project.carpetProducts.length) continue;
    final product = project.carpetProducts[pi];
    if (product.rollWidthMm <= 0) continue;
    final variantIndex = project.roomCarpetLayoutVariantIndex[ri] ?? 0;
    final layout = computeRoomStripLayout(
      room: project.rooms[ri],
      roomIndex: ri,
      product: product,
      openings: project.openings,
      seamOverrides: project.roomCarpetSeamOverrides[ri],
      layDirectionDeg: project.roomCarpetSeamLayDirectionDeg[ri] ??
          layDirectionDegFromVariant(variantIndex),
      stripPieceLengthsOverride:
          project.roomCarpetStripPieceLengthsOverrideMm[ri],
      settings: project.carpetPlanningSettings,
    );
    if (layout != null && layout.numStrips > 0) {
      layouts[ri] = layout;
    }
  }
  if (layouts.isEmpty) {
    return const JobQuote(
      lines: [],
      subtotal: 0,
      gstPercent: 0,
      gstAmount: 0,
      total: 0,
      fullyPriced: true,
    );
  }

  var fullyPriced = true;

  // --- Carpet, one line per product (ordered linear metres incl. waste). ---
  final linearByProduct = <int, double>{};
  for (final e in layouts.entries) {
    final pi = project.roomCarpetAssignments[e.key]!;
    final layout = e.value;
    linearByProduct[pi] = (linearByProduct[pi] ?? 0) +
        (layout.totalLinearWithWasteMm ?? layout.totalLinearMm);
  }
  for (final e in linearByProduct.entries) {
    final product = project.carpetProducts[e.key];
    final linearM = e.value / 1000;
    final rollWidthM = product.rollWidthMm / 1000;
    final amount = product.estimatedCostForLinearMm(e.value);
    if (amount == null) fullyPriced = false;
    lines.add(
      QuoteLine(
        label: 'Carpet — ${product.name}',
        detail: '${_qty(linearM, 'lm')} of ${rollWidthM.toStringAsFixed(2)}m roll'
            '${product.costPerSqm != null ? ' @ \$${_money(product.costPerSqm!)}/m²' : ' (no rate set)'}',
        amount: amount,
      ),
    );
  }

  // --- Underlay and labour: carpeted floor area, per product so a product
  // can override the global rate. ---
  final carpetedAreaSqm = layouts.keys
          .map((ri) => project.rooms[ri].areaMm2)
          .fold<double>(0, (a, b) => a + b) /
      1e6;
  final areaByProduct = <int, double>{};
  for (final ri in layouts.keys) {
    final pi = project.roomCarpetAssignments[ri]!;
    areaByProduct[pi] =
        (areaByProduct[pi] ?? 0) + project.rooms[ri].areaMm2 / 1e6;
  }

  // Emits either one aggregate area line (no product override in play) or one
  // line per product (when any assigned product overrides [globalRate]).
  void addAreaLines(
    String label,
    double? globalRate,
    double? Function(CarpetProduct) productRate,
  ) {
    final anyOverride = areaByProduct.keys
        .any((pi) => productRate(project.carpetProducts[pi]) != null);
    if (!anyOverride) {
      if (globalRate == null) fullyPriced = false;
      lines.add(
        QuoteLine(
          label: label,
          detail: '${_qty(carpetedAreaSqm, 'm²')}'
              '${globalRate != null ? ' @ \$${_money(globalRate)}/m²' : ' (no rate set)'}',
          amount: globalRate != null ? carpetedAreaSqm * globalRate : null,
        ),
      );
      return;
    }
    for (final entry in areaByProduct.entries) {
      final product = project.carpetProducts[entry.key];
      final override = productRate(product);
      final rate = override ?? globalRate;
      if (rate == null) fullyPriced = false;
      lines.add(
        QuoteLine(
          label: '$label — ${product.name}',
          detail: '${_qty(entry.value, 'm²')}'
              '${rate != null ? ' @ \$${_money(rate)}/m²' : ' (no rate set)'}'
              '${override != null ? ' (product rate)' : ''}',
          amount: rate != null ? entry.value * rate : null,
        ),
      );
    }
  }

  addAreaLines('Underlay', rates.underlayCostPerSqm, (p) => p.underlayCostPerSqm);

  // --- Gripper: perimeter of carpeted rooms minus doorway openings. ---
  var gripperM = 0.0;
  for (final ri in layouts.keys) {
    final verts = _openRing(project.rooms[ri].vertices);
    var perimeterMm = 0.0;
    final edgeLens = <double>[];
    for (var i = 0; i < verts.length; i++) {
      final a = verts[i];
      final b = verts[(i + 1) % verts.length];
      final len = (b - a).distance;
      edgeLens.add(len);
      perimeterMm += len;
    }
    var openingMm = 0.0;
    for (final o in project.openings) {
      if (o.roomIndex != ri) continue;
      if (o.edgeIndex < 0 || o.edgeIndex >= edgeLens.length) continue;
      openingMm += math.min(o.widthMm, edgeLens[o.edgeIndex]);
    }
    gripperM += math.max(0, perimeterMm - openingMm) / 1000;
  }
  {
    final rate = rates.gripperCostPerM;
    if (rate == null) fullyPriced = false;
    lines.add(
      QuoteLine(
        label: 'Gripper',
        detail: '${_qty(gripperM, 'm')} (perimeter less doorways)'
            '${rate != null ? ' @ \$${_money(rate)}/m' : ' (no rate set)'}',
        amount: rate != null ? gripperM * rate : null,
      ),
    );
  }

  // --- Door bars: one per doorway touching a carpeted room; a mirrored
  // pair (shared wall, same linkId) is one physical doorway. ---
  final countedLinkIds = <String>{};
  var doorBars = 0;
  for (final o in project.openings) {
    if (!layouts.containsKey(o.roomIndex)) continue;
    final linkId = o.linkId;
    if (linkId != null) {
      if (!countedLinkIds.add(linkId)) continue;
    }
    doorBars++;
  }
  if (doorBars > 0) {
    final rate = rates.doorBarCostEach;
    if (rate == null) fullyPriced = false;
    lines.add(
      QuoteLine(
        label: 'Door bars',
        detail: '$doorBars doorway${doorBars == 1 ? '' : 's'}'
            '${rate != null ? ' @ \$${_money(rate)} each' : ' (no rate set)'}',
        amount: rate != null ? doorBars * rate : null,
      ),
    );
  }

  // --- Labour. ---
  addAreaLines('Installation', rates.labourCostPerSqm, (p) => p.labourCostPerSqm);

  final subtotal = lines.fold<double>(0, (s, l) => s + (l.amount ?? 0));
  final gstAmount =
      rates.includeGst ? subtotal * rates.gstPercent / 100 : 0.0;
  return JobQuote(
    lines: lines,
    subtotal: subtotal,
    gstPercent: rates.includeGst ? rates.gstPercent : 0,
    gstAmount: gstAmount,
    total: subtotal + gstAmount,
    fullyPriced: fullyPriced,
  );
}

List<T> _openRing<T>(List<T> vertices) =>
    vertices.length > 1 && vertices.first == vertices.last
        ? vertices.sublist(0, vertices.length - 1)
        : vertices;
