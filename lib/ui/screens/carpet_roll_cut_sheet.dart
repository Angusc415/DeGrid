import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import '../../core/export/csv.dart';
import '../../core/geometry/room.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/geometry/opening.dart';
import '../../core/models/project.dart';
import '../../core/quote/job_quote.dart';
import '../../core/quote/quote_rates.dart';
import '../../core/quote/staircase.dart';
import '../../core/roll_planning/carpet_layout_options.dart';
import '../../core/roll_planning/roll_plan_models.dart';
import '../../core/roll_planning/roll_planner.dart';
import '../../core/roll_planning/room_strip_layout.dart';
import '../../core/units/unit_converter.dart';
import 'carpet_cut_list_panel.dart';

/// Bottom sheet (pull-up tab) showing cut list first; "Roll cut" button shows roll board.
/// Opened from the bottom-center Cuts tab.
class CarpetRollCutSheet extends StatefulWidget {
  final List<Room> rooms;
  final List<CarpetProduct> carpetProducts;
  final Map<int, int> roomCarpetAssignments;
  final List<Opening> openings;
  final Map<int, List<double>> roomCarpetSeamOverrides;

  /// When a room has seam overrides, locked strip direction (0 or 90). Use so moving seam doesn't flip direction.
  final Map<int, double> roomCarpetSeamLayDirectionDeg;
  final Map<int, int> roomCarpetLayoutVariantIndex;
  final void Function(int roomIndex, int variantIndex)? onLayoutVariantChanged;

  /// User-adjustable planning settings (waste %, seam penalties).
  final CarpetPlanningSettings carpetPlanningSettings;
  final void Function(CarpetPlanningSettings)? onCarpetPlanningSettingsChanged;
  final Map<int, List<List<double>>> roomCarpetStripPieceLengthsOverrideMm;

  /// Pricing rates for the live Quote tab. When [QuoteRates.hasAnyRates] is
  /// false, the tab prompts the user to set rates in project settings.
  final QuoteRates quoteRates;

  /// Carpeted staircases priced into the live Quote tab.
  final List<Staircase> staircases;
  final bool useImperial;
  final void Function(int roomIndex)? onResetSeamsForRoom;

  /// When set, roll cut + cut list views are filtered to rooms
  /// that share the same carpet product as this room.
  final int? selectedRoomIndex;

  /// Cut highlighted on roll board, cut list, and floor plan.
  final String? selectedCutId;

  /// Called when the user selects or clears a cut.
  final void Function(String? cutId, int? roomIndex)? onSelectedCutChanged;

  /// Called when the user drags the top handle; [deltaDy] is the pointer delta in pixels.
  final void Function(double deltaDy)? onResizeDrag;

  /// Called when the user taps the top handle (toggle height).
  final VoidCallback? onToggleHeight;

  const CarpetRollCutSheet({
    super.key,
    required this.rooms,
    required this.carpetProducts,
    required this.roomCarpetAssignments,
    required this.openings,
    this.roomCarpetSeamOverrides = const {},
    this.roomCarpetSeamLayDirectionDeg = const {},
    this.roomCarpetLayoutVariantIndex = const {},
    this.onLayoutVariantChanged,
    this.carpetPlanningSettings = const CarpetPlanningSettings(),
    this.onCarpetPlanningSettingsChanged,
    this.roomCarpetStripPieceLengthsOverrideMm = const {},
    this.quoteRates = const QuoteRates(),
    this.staircases = const [],
    this.useImperial = false,
    this.onResetSeamsForRoom,
    this.selectedRoomIndex,
    this.selectedCutId,
    this.onSelectedCutChanged,
    this.onResizeDrag,
    this.onToggleHeight,
  });

  /// Call from editor: showModalBottomSheet with this as child.
  static void show(
    BuildContext context, {
    required List<Room> rooms,
    required List<CarpetProduct> carpetProducts,
    required Map<int, int> roomCarpetAssignments,
    required List<Opening> openings,
    Map<int, List<double>> roomCarpetSeamOverrides = const {},
    Map<int, double> roomCarpetSeamLayDirectionDeg = const {},
    Map<int, int> roomCarpetLayoutVariantIndex = const {},
    void Function(int roomIndex, int variantIndex)? onLayoutVariantChanged,
    bool useImperial = false,
    void Function(int roomIndex)? onResetSeamsForRoom,
    int? selectedRoomIndex,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => CarpetRollCutSheet(
        rooms: rooms,
        carpetProducts: carpetProducts,
        roomCarpetAssignments: roomCarpetAssignments,
        openings: openings,
        roomCarpetSeamOverrides: roomCarpetSeamOverrides,
        roomCarpetSeamLayDirectionDeg: roomCarpetSeamLayDirectionDeg,
        roomCarpetLayoutVariantIndex: roomCarpetLayoutVariantIndex,
        onLayoutVariantChanged: onLayoutVariantChanged,
        useImperial: useImperial,
        onResetSeamsForRoom: onResetSeamsForRoom,
        selectedRoomIndex: selectedRoomIndex,
      ),
    );
  }

  @override
  State<CarpetRollCutSheet> createState() => _CarpetRollCutSheetState();
}

class _CarpetRollCutSheetState extends State<CarpetRollCutSheet> {
  RollPlanState? _planState;

  /// Local copy of layout variant so the sheet updates when user changes it without waiting for parent rebuild.
  late Map<int, int> _layoutVariantIndex;

  @override
  void initState() {
    super.initState();
    _layoutVariantIndex = Map<int, int>.from(
      widget.roomCarpetLayoutVariantIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildPlanState());
  }

  @override
  void didUpdateWidget(covariant CarpetRollCutSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(
      oldWidget.roomCarpetLayoutVariantIndex,
      widget.roomCarpetLayoutVariantIndex,
    )) {
      _layoutVariantIndex = Map<int, int>.from(
        widget.roomCarpetLayoutVariantIndex,
      );
    }
    // Compare by value (the editor publishes fresh copies on every canvas
    // change): rebuild the roll plan only when layout-relevant data actually
    // changed, so unrelated canvas interactions (pan/zoom) don't reset the
    // roll board, while seam drags still update the plan live per move.
    if (_layoutInputsChanged(oldWidget)) {
      _rebuildPlanState();
    } else if (oldWidget.selectedCutId != widget.selectedCutId &&
        _planState != null) {
      _syncSelectedCutFromWidget();
    }
  }

  void _syncSelectedCutFromWidget() {
    final id = widget.selectedCutId;
    setState(() {
      if (_planState == null) return;
      if (id == null) {
        _planState = _planState!.copyWith(clearSelection: true);
      } else if (_planState!.allCuts.any((c) => c.cutId == id)) {
        _planState = _planState!.copyWith(selectedCutId: id);
      }
    });
  }

  bool _layoutInputsChanged(CarpetRollCutSheet old) {
    return !_roomsEquals(old.rooms, widget.rooms) ||
        !mapEquals(old.roomCarpetAssignments, widget.roomCarpetAssignments) ||
        !_productsEquals(old.carpetProducts, widget.carpetProducts) ||
        !_openingsEquals(old.openings, widget.openings) ||
        !_mapOfListEquals(
          old.roomCarpetSeamOverrides,
          widget.roomCarpetSeamOverrides,
        ) ||
        !mapEquals(
          old.roomCarpetSeamLayDirectionDeg,
          widget.roomCarpetSeamLayDirectionDeg,
        ) ||
        !mapEquals(
          old.roomCarpetLayoutVariantIndex,
          widget.roomCarpetLayoutVariantIndex,
        ) ||
        old.carpetPlanningSettings != widget.carpetPlanningSettings ||
        !_mapOfNestedListEquals(
          old.roomCarpetStripPieceLengthsOverrideMm,
          widget.roomCarpetStripPieceLengthsOverrideMm,
        ) ||
        old.selectedRoomIndex != widget.selectedRoomIndex;
  }

  static bool _roomsEquals(List<Room> a, List<Room> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
      if (!listEquals(a[i].vertices, b[i].vertices)) return false;
    }
    return true;
  }

  static bool _productsEquals(List<CarpetProduct> a, List<CarpetProduct> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final p = a[i];
      final q = b[i];
      if (p.name != q.name ||
          p.rollWidthMm != q.rollWidthMm ||
          p.rollLengthM != q.rollLengthM ||
          p.costPerSqm != q.costPerSqm ||
          p.patternRepeatMm != q.patternRepeatMm ||
          p.minStripWidthMm != q.minStripWidthMm ||
          p.trimAllowanceMm != q.trimAllowanceMm) {
        return false;
      }
    }
    return true;
  }

  static bool _openingsEquals(List<Opening> a, List<Opening> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final p = a[i];
      final q = b[i];
      if (p.roomIndex != q.roomIndex ||
          p.edgeIndex != q.edgeIndex ||
          p.offsetMm != q.offsetMm ||
          p.widthMm != q.widthMm ||
          p.isDoor != q.isDoor) {
        return false;
      }
    }
    return true;
  }

  static bool _mapOfListEquals(
    Map<int, List<double>> a,
    Map<int, List<double>> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final other = b[e.key];
      if (other == null || !listEquals(e.value, other)) return false;
    }
    return true;
  }

  static bool _mapOfNestedListEquals(
    Map<int, List<List<double>>> a,
    Map<int, List<List<double>>> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final other = b[e.key];
      if (other == null || other.length != e.value.length) return false;
      for (var i = 0; i < e.value.length; i++) {
        if (!listEquals(e.value[i], other[i])) return false;
      }
    }
    return true;
  }

  static String _formatPercent(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  /// Dialog for adjustable planning settings: waste allowance plus advanced
  /// seam penalty tuning (mm-equivalent cost per seam).
  Future<void> _showPlanningSettingsDialog(BuildContext context) async {
    final settings = widget.carpetPlanningSettings;
    final wasteController = TextEditingController(
      text: _formatPercent(settings.wasteAllowancePercent),
    );
    final doorwayExtensionController = TextEditingController(
      text: settings.doorwayExtensionMm.round().toString(),
    );
    final seamAllowanceController = TextEditingController(
      text: settings.seamWidthAllowanceMm.round().toString(),
    );
    final noDoorsController = TextEditingController(
      text: settings.seamPenaltyMmNoDoors.round().toString(),
    );
    final withDoorsController = TextEditingController(
      text: settings.seamPenaltyMmWithDoors.round().toString(),
    );
    final inDoorwayController = TextEditingController(
      text: settings.seamPenaltyMmInDoorway.round().toString(),
    );
    final sliverPenaltyController = TextEditingController(
      text: settings.sliverPenaltyPerStripMm.round().toString(),
    );
    final updated = await showDialog<CarpetPlanningSettings>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planning settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wasteController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Waste allowance (%)',
                  hintText: 'e.g. 5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doorwayExtensionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carpet into doorways (mm)',
                  hintText: 'e.g. 35 = half wall; 0 = off',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seamAllowanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Seam width allowance (mm per seamed edge)',
                  hintText: 'e.g. 40; 0 = off',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  'Advanced: seam penalties',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Cost per seam (mm-equivalent); higher = fewer seams',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                children: [
                  TextField(
                    controller: noDoorsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Per seam — room without doors',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: withDoorsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Per seam — room with doors',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inDoorwayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Per seam crossing a doorway',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sliverPenaltyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Per sliver strip (narrower than minimum)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final waste = double.tryParse(wasteController.text.trim());
              final doorwayExt =
                  double.tryParse(doorwayExtensionController.text.trim());
              final seamAllowance =
                  double.tryParse(seamAllowanceController.text.trim());
              final noDoors = double.tryParse(noDoorsController.text.trim());
              final withDoors =
                  double.tryParse(withDoorsController.text.trim());
              final inDoorway =
                  double.tryParse(inDoorwayController.text.trim());
              final sliverPenalty =
                  double.tryParse(sliverPenaltyController.text.trim());
              Navigator.pop(
                ctx,
                settings.copyWith(
                  wasteAllowancePercent:
                      waste != null && waste >= 0 && waste <= 100
                          ? waste
                          : null,
                  doorwayExtensionMm:
                      doorwayExt != null && doorwayExt >= 0 && doorwayExt <= 500
                          ? doorwayExt
                          : null,
                  seamWidthAllowanceMm: seamAllowance != null &&
                          seamAllowance >= 0 &&
                          seamAllowance <= 300
                      ? seamAllowance
                      : null,
                  seamPenaltyMmNoDoors:
                      noDoors != null && noDoors >= 0 ? noDoors : null,
                  seamPenaltyMmWithDoors:
                      withDoors != null && withDoors >= 0 ? withDoors : null,
                  seamPenaltyMmInDoorway:
                      inDoorway != null && inDoorway >= 0 ? inDoorway : null,
                  sliverPenaltyPerStripMm:
                      sliverPenalty != null && sliverPenalty >= 0
                          ? sliverPenalty
                          : null,
                ),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (updated != null && updated != settings) {
      widget.onCarpetPlanningSettingsChanged?.call(updated);
    }
  }

  void _onLayoutVariantChanged(int roomIndex, int variantIndex) {
    setState(() {
      _layoutVariantIndex[roomIndex] = variantIndex;
    });
    widget.onLayoutVariantChanged?.call(roomIndex, variantIndex);
    _rebuildPlanState();
  }

  List<_RoomWithCarpet> get _roomsWithCarpet {
    final list = <_RoomWithCarpet>[];
    // Decide which carpet product to show on this roll:
    // - If a room is selected, use its assigned product.
    // - Otherwise, pick the product that covers the largest total room area.
    int? selectedProductIndex;
    final selRoom = widget.selectedRoomIndex;
    if (selRoom != null) {
      selectedProductIndex = widget.roomCarpetAssignments[selRoom];
    } else {
      final areaByProduct = <int, double>{};
      for (final e in widget.roomCarpetAssignments.entries) {
        final ri = e.key;
        final pi = e.value;
        if (ri < 0 ||
            ri >= widget.rooms.length ||
            pi < 0 ||
            pi >= widget.carpetProducts.length) {
          continue;
        }
        final room = widget.rooms[ri];
        areaByProduct[pi] = (areaByProduct[pi] ?? 0) + room.areaMm2;
      }
      if (areaByProduct.isNotEmpty) {
        selectedProductIndex = areaByProduct.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }
    }

    for (final e in widget.roomCarpetAssignments.entries) {
      final ri = e.key;
      final pi = e.value;
      if (selectedProductIndex != null && pi != selectedProductIndex) continue;
      if (ri < 0 ||
          ri >= widget.rooms.length ||
          pi < 0 ||
          pi >= widget.carpetProducts.length) {
        continue;
      }
      final room = widget.rooms[ri];
      final product = widget.carpetProducts[pi];
      if (product.rollWidthMm <= 0) {
        continue;
      }
      final variantIndex = _layoutVariantIndex[ri] ?? 0;
      final layout = computeRoomStripLayout(
        room: room,
        roomIndex: ri,
        product: product,
        openings: widget.openings,
        seamOverrides: widget.roomCarpetSeamOverrides[ri],
        layDirectionDeg: widget.roomCarpetSeamLayDirectionDeg[ri] ??
            layDirectionDegFromVariant(variantIndex),
        stripPieceLengthsOverride:
            widget.roomCarpetStripPieceLengthsOverrideMm[ri],
        settings: widget.carpetPlanningSettings,
      );
      if (layout != null && layout.numStrips > 0) {
        list.add(
          _RoomWithCarpet(
            roomIndex: ri,
            room: room,
            product: product,
            layout: layout,
          ),
        );
      }
    }
    return list;
  }

  void _rebuildPlanState() {
    final list = _roomsWithCarpet;
    if (list.isEmpty) {
      setState(() => _planState = null);
      return;
    }
    final allCuts = <RollCutPiece>[];
    final placements = <String, RollCutPlacement>{};
    final first = list.first;
    double totalLinear = 0;

    // Shelf packing: cuts stay in cutting order along the roll, but a narrow
    // cut nests beside an earlier cut when the roll width allows (both fit
    // across the width and the nested cut is no longer than the shelf).
    // Nested cuts consume the roll once, reducing the ordered length.
    final shelfAlongStart = <double>[];
    final shelfLength = <double>[];
    final shelfUsedBreadth = <double>[];
    double nextAlong = 0;
    Offset placeCut(double lengthMm, double breadthMm, double rollWidthMm) {
      for (var s = 0; s < shelfAlongStart.length; s++) {
        if (shelfUsedBreadth[s] + breadthMm <= rollWidthMm + 1e-6 &&
            lengthMm <= shelfLength[s] + 1e-6) {
          final pos = Offset(shelfAlongStart[s], shelfUsedBreadth[s]);
          shelfUsedBreadth[s] += breadthMm;
          return pos;
        }
      }
      final pos = Offset(nextAlong, 0);
      shelfAlongStart.add(nextAlong);
      shelfLength.add(lengthMm);
      shelfUsedBreadth.add(breadthMm);
      nextAlong += lengthMm;
      return pos;
    }

    for (int li = 0; li < list.length; li++) {
      final r = list[li];
      final roomName = r.room.name ?? 'Room ${r.roomIndex + 1}';
      for (int si = 0; si < r.layout.stripLengthsMm.length; si++) {
        final pieceLengths = r.layout.pieceLengthsForStrip(si);
        final breadthMm = si < r.layout.stripWidthsMm.length
            ? r.layout.stripWidthsMm[si]
            : r.product.rollWidthMm;
        final isSliver = r.layout.isSliverAt(
          si,
          r.product.minStripWidthMm ?? 100,
        );
        for (int pi = 0; pi < pieceLengths.length; pi++) {
          final lengthMm = pieceLengths[pi];
          totalLinear += lengthMm;
          final cutId = formatCutId(
            roomLetterIndex: li,
            stripIndex: si,
            pieceIndex: pi,
            pieceCountInStrip: pieceLengths.length,
          );
          allCuts.add(
            RollCutPiece(
              cutId: cutId,
              roomIndex: r.roomIndex,
              roomName: roomName,
              rollLaneIndex: 0,
              product: r.product,
              stripIndex: si,
              lengthMm: lengthMm,
              trimMm: r.product.trimAllowanceMm ?? 75,
              breadthMm: breadthMm,
              isSliver: isSliver,
              patternRepeatMm: r.product.patternRepeatMm,
              roomShapeVerticesMm: r.layout.isSinglePiece
                  ? r.layout.roomShapeVerticesMm
                  : null,
              layAlongX: r.layout.isSinglePiece ? r.layout.layAlongX : null,
            ),
          );
          placements[cutId] =
              placeCut(lengthMm, breadthMm, r.product.rollWidthMm);
        }
      }
    }
    final totalScoreCostMm = list.fold<double>(
      0,
      (s, r) => s + r.layout.scoreCostMm,
    );
    final lane = RollLaneData(
      rollIndex: 0,
      product: first.product,
      totalLinearMm: totalLinear,
    );

    // Preserve the user's manual roll-board arrangement: keep the previous
    // placement for cuts whose ID and length are unchanged; cuts affected by
    // the layout change (new ID or new length) use the freshly seeded position.
    final previous = _planState;
    if (previous != null) {
      final oldLengthById = {
        for (final c in previous.allCuts) c.cutId: c.lengthMm,
      };
      for (final c in allCuts) {
        final oldPlacement = previous.placements[c.cutId];
        final oldLength = oldLengthById[c.cutId];
        if (oldPlacement != null &&
            oldLength != null &&
            (oldLength - c.lengthMm).abs() < 0.01) {
          placements[c.cutId] = oldPlacement;
        }
      }
    }

    // Phase V2-3: simple offcut reuse assignment.
    // Treat the tail length at the end of the roll as available offcut material
    // (roll length minus total cut length), and greedily assign the longest
    // cuts that fit within this length as "from offcut". This is a planning
    // hint only (no offcut inventory is tracked); placements remain unchanged.
    // Only meaningful when the product has a physical roll length — otherwise
    // the lane length is fabricated (totalLinear * 1.2) and the "tail" is fake.
    final availableOffcutLength = lane.hasRealRollLength
        ? (lane.rollLengthMm - totalLinear).clamp(0.0, double.infinity)
        : 0.0;
    final cutsSorted = List<RollCutPiece>.from(allCuts)
      ..sort((a, b) => b.lengthMm.compareTo(a.lengthMm));
    final fromOffcutIds = <String>{};
    double remaining = availableOffcutLength;
    for (final c in cutsSorted) {
      if (c.lengthMm <= remaining) {
        fromOffcutIds.add(c.cutId);
        remaining -= c.lengthMm;
      }
    }
    final annotatedCuts = allCuts
        .map(
          (c) => fromOffcutIds.contains(c.cutId)
              ? c.copyWith(
                  fromOffcut: true,
                  sourceOffcutRollIndex: lane.rollIndex,
                )
              : c,
        )
        .toList();

    final lanes = [lane];
    final candidateId = widget.selectedCutId ?? previous?.selectedCutId;
    final selectedCutId = candidateId != null &&
            annotatedCuts.any((c) => c.cutId == candidateId)
        ? candidateId
        : null;
    setState(() {
      _planState = RollPlanState(
        allCuts: annotatedCuts,
        lanes: lanes,
        placements: placements,
        selectedCutId: selectedCutId,
        cutListExpanded: true,
        totalScoreCostMm: totalScoreCostMm,
      );
    });
  }

  void _updatePlacement(String cutId, RollCutPlacement pos) {
    if (_planState == null) return;
    final next = Map<String, RollCutPlacement>.from(_planState!.placements);
    next[cutId] = pos;
    setState(() => _planState = _planState!.copyWith(placements: next));
  }

  void _applyPlacementDelta(
    String cutId,
    double deltaAlongMm,
    double deltaPerpMm,
  ) {
    if (_planState == null) return;
    final p = _planState!.placements[cutId];
    if (p == null) return;
    final piece = _planState!.allCuts
        .where((c) => c.cutId == cutId)
        .firstOrNull;
    if (piece == null) return;
    final lane = _planState!.lanes[piece.rollLaneIndex];
    final maxAlong = (lane.rollLengthMm - piece.lengthMm).clamp(
      0.0,
      double.infinity,
    );
    final maxPerp = (lane.rollWidthMm - piece.breadthMm).clamp(
      0.0,
      double.infinity,
    );
    final newAlong = (p.dx + deltaAlongMm).clamp(0.0, maxAlong).toDouble();
    final newPerp = (p.dy + deltaPerpMm).clamp(0.0, maxPerp).toDouble();
    _updatePlacement(cutId, Offset(newAlong, newPerp));
  }

  void _removeFromRoll(String cutId) {
    if (_planState == null) return;
    final next = Map<String, RollCutPlacement>.from(_planState!.placements);
    next.remove(cutId);
    setState(
      () => _planState = _planState!.copyWith(
        placements: next,
        clearSelection: true,
      ),
    );
  }

  void _placeOnRoll(String cutId) {
    if (_planState == null) return;
    final piece = _planState!.allCuts
        .where((c) => c.cutId == cutId)
        .firstOrNull;
    if (piece == null) return;
    final lane = _planState!.lanes[piece.rollLaneIndex];
    final rollLength = lane.rollLengthMm;
    final rollWidth = lane.rollWidthMm;
    final placed = _planState!.placedCutsOnLane(piece.rollLaneIndex);
    double alongPos = 0;
    double perpPos = 0;
    double rowBottom = 0;
    for (final c in placed) {
      final p = _planState!.placements[c.cutId]!;
      final endAlong = p.dx + c.lengthMm;
      final endPerp = p.dy + c.breadthMm;
      if (endAlong > alongPos) alongPos = endAlong;
      if (endPerp > rowBottom) rowBottom = endPerp;
    }
    if (alongPos + piece.lengthMm > rollLength && alongPos > 0) {
      alongPos = 0;
      perpPos = rowBottom;
    }
    if (perpPos + piece.breadthMm > rollWidth) perpPos = 0;
    final next = Map<String, RollCutPlacement>.from(_planState!.placements);
    next[cutId] = Offset(alongPos, perpPos);
    setState(() => _planState = _planState!.copyWith(placements: next));
  }

  void _autoPlaceAll() {
    _rebuildPlanState();
  }

  void _selectCut(String? cutId) {
    setState(() {
      if (_planState == null) return;
      _planState = cutId == null
          ? _planState!.copyWith(clearSelection: true)
          : _planState!.copyWith(selectedCutId: cutId);
    });
    int? roomIndex;
    if (cutId != null && _planState != null) {
      for (final c in _planState!.allCuts) {
        if (c.cutId == cutId) {
          roomIndex = c.roomIndex;
          break;
        }
      }
    }
    widget.onSelectedCutChanged?.call(cutId, roomIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _buildContent(context);
    return Material(color: theme.scaffoldBackgroundColor, child: content);
  }

  Widget _buildContent(BuildContext context) {
    final list = _roomsWithCarpet;
    if (list.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(context),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No rooms with carpet assigned. Assign products in the Rooms panel.',
            ),
          ),
        ],
      );
    }
    // When the sheet is very short, only show the header (handle + tabs)
    // to avoid overflow; content becomes visible once the user drags it up.
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(context),
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: const [
                Tab(text: 'Cut list'),
                Tab(text: 'Roll cut'),
                Tab(text: 'Quote'),
              ],
            ),
            if (widget.onCarpetPlanningSettingsChanged != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onCarpetPlanningSettingsChanged != null) ...[
                      Text(
                        'Strip layout:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<StripSplitStrategy>(
                        value: widget.carpetPlanningSettings.stripSplitStrategy,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: StripSplitStrategy.auto,
                            child: Text('Auto'),
                          ),
                          DropdownMenuItem(
                            value: StripSplitStrategy.never,
                            child: Text('One piece per strip'),
                          ),
                          DropdownMenuItem(
                            value: StripSplitStrategy.preferStripInPieces,
                            child: Text('Prefer split when long'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            widget.onCarpetPlanningSettingsChanged!(
                              widget.carpetPlanningSettings
                                  .copyWith(stripSplitStrategy: v),
                            );
                          }
                        },
                      ),
                    ],
                    if (widget.onCarpetPlanningSettingsChanged != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Waste: ${_formatPercent(widget.carpetPlanningSettings.wasteAllowancePercent)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Planning settings',
                        onPressed: () => _showPlanningSettingsDialog(context),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );

        // If there's not enough height for the tab content, just show the header.
        if (constraints.maxHeight < 140) {
          return DefaultTabController(
            length: 3,
            initialIndex: 0,
            child: SingleChildScrollView(child: header),
          );
        }

        // Normal case: header + TabBarView filling remaining space.
        return DefaultTabController(
          length: 3,
          initialIndex: 0,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              header,
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCutListTab(context),
                    _buildRollCutTab(context),
                    _buildQuoteTab(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Tab 0: Cut list — strip lengths per room (filtered by selected room's product).
  Widget _buildCutListTab(BuildContext context) {
    Map<int, int> assignments = widget.roomCarpetAssignments;
    final selRoom = widget.selectedRoomIndex;
    if (selRoom != null) {
      final selProduct = widget.roomCarpetAssignments[selRoom];
      if (selProduct != null) {
        assignments = {
          for (final e in widget.roomCarpetAssignments.entries)
            if (e.value == selProduct) e.key: e.value,
        };
      }
    }
    return CarpetCutListPanel(
      rooms: widget.rooms,
      carpetProducts: widget.carpetProducts,
      roomCarpetAssignments: assignments,
      openings: widget.openings,
      useImperial: widget.useImperial,
      roomCarpetSeamOverrides: widget.roomCarpetSeamOverrides,
      roomCarpetSeamLayDirectionDeg: widget.roomCarpetSeamLayDirectionDeg,
      roomCarpetLayoutVariantIndex: _layoutVariantIndex,
      onLayoutVariantChanged: _onLayoutVariantChanged,
      onResetSeamsForRoom: widget.onResetSeamsForRoom,
      roomCarpetStripPieceLengthsOverrideMm:
          widget.roomCarpetStripPieceLengthsOverrideMm,
      carpetPlanningSettings: widget.carpetPlanningSettings,
      selectedCutId: widget.selectedCutId,
      onSelectCut: widget.onSelectedCutChanged,
    );
  }

  /// Tab 2: Quote — live pricing for the whole job (all rooms/products).
  ///
  /// Builds a lightweight in-memory [ProjectModel] from the sheet's live state
  /// so [buildJobQuote] runs the same path it does for the PDF export.
  Widget _buildQuoteTab(BuildContext context) {
    final quote = buildJobQuote(
      ProjectModel(
        name: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        rooms: widget.rooms,
        openings: widget.openings,
        carpetProducts: widget.carpetProducts,
        roomCarpetAssignments: widget.roomCarpetAssignments,
        roomCarpetSeamOverrides: widget.roomCarpetSeamOverrides,
        roomCarpetSeamLayDirectionDeg: widget.roomCarpetSeamLayDirectionDeg,
        roomCarpetLayoutVariantIndex: _layoutVariantIndex,
        roomCarpetStripPieceLengthsOverrideMm:
            widget.roomCarpetStripPieceLengthsOverrideMm,
        carpetPlanningSettings: widget.carpetPlanningSettings,
        quoteRates: widget.quoteRates,
        staircases: widget.staircases,
      ),
    );
    return _QuotePanel(
      quote: quote,
      hasRates: widget.quoteRates.hasAnyRates,
      useImperial: widget.useImperial,
    );
  }

  /// Tab 1: Roll cut — roll board, tray, inspector.
  /// Uses flex layout inside the TabBarView; the outer sheet decides overall height.
  Widget _buildRollCutTab(BuildContext context) {
    if (_planState == null || _planState!.allCuts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Loading roll plan…'),
        ),
      );
    }
    final plan = _planState!;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _SummaryBar(
          plan: plan,
          useImperial: widget.useImperial,
          onAutoPlace: _autoPlaceAll,
          onExport: () => _exportCutSheet(context, plan),
        ),
        _OffcutsSection(plan: plan, useImperial: widget.useImperial),
        const Divider(height: 1),
        Expanded(
          flex: 5,
          child: _RollBoard(
            plan: plan,
            carpetProducts: widget.carpetProducts,
            useImperial: widget.useImperial,
            overlappingCutIds: plan.overlappingCutIds(),
            onPlacementChanged: _updatePlacement,
            onPlacementDelta: _applyPlacementDelta,
            onSelectCut: _selectCut,
            selectedCutId: plan.selectedCutId,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: _CutInspector(
            plan: plan,
            useImperial: widget.useImperial,
            onRemoveFromRoll: _removeFromRoll,
            onPlaceOnRoll: _placeOnRoll,
            onClearSelection: () => _selectCut(null),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCutSheet(BuildContext context, RollPlanState plan) async {
    // CSV: cuts then offcuts
    final sb = StringBuffer();
    sb.writeln(
      'Cut ID,Room,Length (m),Start along (m),Start perp (m),Roll,Source',
    );
    for (final c in plan.allCuts) {
      final pos = plan.placements[c.cutId];
      final roll = pos != null
          ? (plan.lanes[c.rollLaneIndex].room?.name ??
                plan.lanes[c.rollLaneIndex].product.name)
          : '';
      final source = c.fromOffcut
          ? 'Offcut${c.sourceOffcutRollIndex != null ? ' (lane ${c.sourceOffcutRollIndex})' : ''}'
          : 'Roll';
      sb.writeln(
        '${csvField(c.cutId)},${csvField(c.roomName)},${csvMetres(c.lengthMm)},${pos != null ? csvMetres(pos.dx) : ""},${pos != null ? csvMetres(pos.dy) : ""},${csvField(roll)},${csvField(source)}',
      );
    }
    final offcuts = plan.offcuts();
    final sideOffcuts = plan.sideOffcuts();
    if (offcuts.isNotEmpty || sideOffcuts.isNotEmpty) {
      sb.writeln();
      sb.writeln('Offcut,Lane,Length (m),Breadth (m),Start along (m)');
      for (final o in offcuts) {
        sb.writeln(
          'Tail,${o.rollIndex},${csvMetres(o.lengthMm)},${csvMetres(o.breadthMm)},${csvMetres(o.startAlongMm)}',
        );
      }
      for (final o in sideOffcuts) {
        sb.writeln(
          'Side,${o.rollIndex},${csvMetres(o.lengthMm)},${csvMetres(o.breadthMm)},${csvMetres(o.startAlongMm)}',
        );
      }
    }
    final csv = sb.toString();
    final messenger = ScaffoldMessenger.of(context);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv)),
            name: 'cut_sheet.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: 'Cut sheet',
      ),
    );
    if (result.status == ShareResultStatus.unavailable) {
      await Clipboard.setData(ClipboardData(text: csv));
      messenger.showSnackBar(
        const SnackBar(content: Text('Sharing unavailable — copied CSV to clipboard.')),
      );
    }
  }

  Widget _buildHandle(BuildContext context) {
    final theme = Theme.of(context);
    // Small centered tab that protrudes from the top of the sheet, so canvas
    // corners remain visible. Dragging or tapping this tab resizes the sheet.
    Widget content = Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withAlpha(51),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drag_handle,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                'Cuts — drag to resize',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // If editor provided resize callbacks, wrap handle so it can drive panel height.
    if (widget.onResizeDrag != null || widget.onToggleHeight != null) {
      content = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: widget.onResizeDrag != null
            ? (e) => widget.onResizeDrag!(e.delta.dy)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onToggleHeight,
          child: content,
        ),
      );
    }
    return content;
  }
}

// --- Redesigned panels ---

/// Live job-quote panel: one row per line, then subtotal / GST / total.
/// Prompts for rates when none are set. Unpriced lines show their quantity
/// with an em dash in the amount column.
class _QuotePanel extends StatelessWidget {
  final JobQuote quote;
  final bool hasRates;
  final bool useImperial;

  const _QuotePanel({
    required this.quote,
    required this.hasRates,
    required this.useImperial,
  });

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (quote.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            hasRates
                ? 'No rooms with carpet assigned to quote.'
                : 'No rooms with carpet assigned to quote.\n'
                    'Set prices in Project settings (gear icon) to price the job.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasRates)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quantities only — set prices in Project settings (gear icon) to see a total.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          for (final line in quote.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          line.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    line.amount != null ? _money(line.amount!) : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: line.amount == null ? theme.hintColor : null,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          _totalRow(context, 'Subtotal', _money(quote.subtotal),
              bold: quote.gstAmount == 0),
          if (quote.gstAmount > 0) ...[
            const SizedBox(height: 4),
            _totalRow(context, 'GST (${quote.gstPercent.toStringAsFixed(0)}%)',
                _money(quote.gstAmount)),
          ],
          const SizedBox(height: 6),
          _totalRow(context, 'Total', _money(quote.total),
              bold: true, large: true),
          if (!quote.fullyPriced) ...[
            const SizedBox(height: 10),
            Text(
              'Some lines have no rate set — this total is a partial sum.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value,
      {bool bold = false, bool large = false}) {
    final theme = Theme.of(context);
    final style = (large ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
        ?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final RollPlanState plan;
  final bool useImperial;
  final VoidCallback onAutoPlace;
  final VoidCallback onExport;

  const _SummaryBar({
    required this.plan,
    required this.useImperial,
    required this.onAutoPlace,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final total = plan.totalLinearMm();
    final placed = plan.placements.length;
    final totalCuts = plan.allCuts.length;
    final overlaps = plan.overlapCount;
    // Waste is only meaningful against a physical roll length; without one the
    // lane length is fabricated and the figure would be noise.
    final hasRealRolls = plan.lanes.isNotEmpty &&
        plan.lanes.every((l) => l.hasRealRollLength);
    final wastePct = hasRealRolls && total > 0
        ? (plan.lanes
                  .map((l) => plan.wasteMmForLane(l.rollIndex))
                  .fold<double>(0, (a, b) => a + b) /
              total *
              100)
        : null;
    // Roll length actually consumed (nested cuts share it) — the ordering
    // number. Falls back to the cut total when nothing is placed yet.
    final rollUsed = plan.lanes.isNotEmpty ? plan.usedRollLengthMm(0) : 0.0;
    final orderLength =
        placed == totalCuts && rollUsed > 0 ? rollUsed : total;
    final estimatedCost = plan.lanes.isNotEmpty
        ? plan.lanes[0].product.estimatedCostForLinearMm(orderLength)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cuts: ${UnitConverter.formatDistance(total, useImperial: useImperial)} linear',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (rollUsed > 0) ...[
              const SizedBox(width: 16),
              Text(
                'Roll used: ${UnitConverter.formatDistance(rollUsed, useImperial: useImperial)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (estimatedCost != null) ...[
              const SizedBox(width: 16),
              Text(
                'Est. cost: \$${estimatedCost.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (wastePct != null) ...[
              const SizedBox(width: 16),
              Text(
                'Waste: ${wastePct.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(width: 16),
            Text(
              'Placed: $placed/$totalCuts',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (overlaps > 0) ...[
              const SizedBox(width: 8),
              Text(
                'Warnings: $overlaps overlap(s)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: onAutoPlace,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Auto place'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffcutsSection extends StatelessWidget {
  final RollPlanState plan;
  final bool useImperial;

  const _OffcutsSection({required this.plan, required this.useImperial});

  @override
  Widget build(BuildContext context) {
    final offcuts = plan.offcuts();
    final sideOffcuts = plan.sideOffcuts();
    if (offcuts.isEmpty && sideOffcuts.isEmpty) {
      return const SizedBox.shrink();
    }
    final fromOffcutCount = plan.allCuts.where((c) => c.fromOffcut).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offcuts: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withAlpha(230),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                ...offcuts.map((o) {
                  return Text(
                    'Tail: ${UnitConverter.formatDistance(o.lengthMm, useImperial: useImperial)} × ${UnitConverter.formatDistance(o.breadthMm, useImperial: useImperial)} available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  );
                }),
                ...sideOffcuts.map((o) {
                  return Text(
                    'Side: ${UnitConverter.formatDistance(o.lengthMm, useImperial: useImperial)} × ${UnitConverter.formatDistance(o.breadthMm, useImperial: useImperial)} beside cuts',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  );
                }),
                if (fromOffcutCount > 0)
                  Text(
                    '$fromOffcutCount cut(s) reusable from tail (planning hint)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Distinct colors per carpet product (roll board and unplaced tray).
/// Use index % length so multiple products cycle through the palette.
const List<Color> _productColorPalette = [
  Color(0xFF1976D2), // blue
  Color(0xFF388E3C), // green
  Color(0xFFF57C00), // orange
  Color(0xFF7B1FA2), // purple
  Color(0xFF00796B), // teal (darker than offcut)
  Color(0xFF5D4037), // brown
  Color(0xFF303F9F), // indigo
  Color(0xFFC2185B), // pink
];

int _productColorIndex(
  CarpetProduct product,
  List<CarpetProduct> carpetProducts,
) {
  final i = carpetProducts.indexWhere((p) => p.name == product.name);
  return i >= 0 ? i : 0;
}

Color _productColor(CarpetProduct product, List<CarpetProduct> carpetProducts) {
  return _productColorPalette[_productColorIndex(product, carpetProducts) %
      _productColorPalette.length];
}

class _RollBoard extends StatelessWidget {
  final RollPlanState plan;
  final List<CarpetProduct> carpetProducts;
  final bool useImperial;
  final Set<String> overlappingCutIds;
  final void Function(String cutId, RollCutPlacement pos) onPlacementChanged;
  final void Function(String cutId, double deltaAlongMm, double deltaPerpMm)?
  onPlacementDelta;
  final void Function(String? cutId) onSelectCut;
  final String? selectedCutId;

  const _RollBoard({
    required this.plan,
    required this.carpetProducts,
    required this.useImperial,
    required this.overlappingCutIds,
    required this.onPlacementChanged,
    this.onPlacementDelta,
    required this.onSelectCut,
    this.selectedCutId,
  });

  static const double _minBlockWidthPx = 36;
  static const double _minBlockHeightPx = 24;
  static const double _minRollHeightPx = 80;

  @override
  Widget build(BuildContext context) {
    if (plan.lanes.isEmpty) return const SizedBox.shrink();
    final lane = plan.lanes[0];
    final placed = plan.placedCutsOnLane(0);
    final rollLengthMm = lane.rollLengthMm;
    final rollWidthMm = lane.rollWidthMm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth - 24;
        if (availWidth <= 0) return const SizedBox.shrink();
        final rollHeightPx = (rollWidthMm / rollLengthMm * availWidth)
            .clamp(_minRollHeightPx, 200.0)
            .toDouble();
        final pxPerMmAlong = availWidth / rollLengthMm;
        final pxPerMmPerp = rollHeightPx / rollWidthMm;
        final label = lane.room != null
            ? (lane.room!.name ?? 'Room')
            : '${lane.product.name} — all rooms';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Roll: ${UnitConverter.formatDistance(rollWidthMm, useImperial: useImperial)} × ${UnitConverter.formatDistance(rollLengthMm, useImperial: useImperial)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: availWidth,
                height: rollHeightPx + 8,
                decoration: BoxDecoration(
                  color: Colors.brown.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.brown.shade400, width: 2),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final c in placed)
                      _HorizontalCutBlock(
                        piece: c,
                        productColor: _productColor(c.product, carpetProducts),
                        startOffset: plan.placements[c.cutId]!,
                        rollLengthMm: rollLengthMm,
                        rollWidthMm: rollWidthMm,
                        rollWidthPx: availWidth,
                        rollHeightPx: rollHeightPx,
                        pxPerMmAlong: pxPerMmAlong,
                        pxPerMmPerp: pxPerMmPerp,
                        minBlockWidthPx: _minBlockWidthPx,
                        minBlockHeightPx: _minBlockHeightPx,
                        useImperial: useImperial,
                        isSelected: selectedCutId == c.cutId,
                        isSliver: c.isSliver,
                        isOverlap: overlappingCutIds.contains(c.cutId),
                        isFromOffcut: c.fromOffcut,
                        tooltipMessage: c.fromOffcut
                            ? 'From offcut${c.sourceOffcutRollIndex != null ? ' (lane ${c.sourceOffcutRollIndex})' : ''}'
                            : '${c.cutId} · ${UnitConverter.formatDistance(c.lengthMm, useImperial: useImperial)} × ${UnitConverter.formatDistance(c.breadthMm, useImperial: useImperial)}',
                        onTap: () => onSelectCut(c.cutId),
                        onDragEnd: (double deltaAlongMm, double deltaPerpMm) {
                          if (onPlacementDelta != null) {
                            onPlacementDelta!(
                              c.cutId,
                              deltaAlongMm,
                              deltaPerpMm,
                            );
                          } else {
                            final p = plan.placements[c.cutId]!;
                            final maxAlong = (rollLengthMm - c.lengthMm).clamp(
                              0.0,
                              double.infinity,
                            );
                            final maxPerp = (rollWidthMm - c.breadthMm).clamp(
                              0.0,
                              double.infinity,
                            );
                            final newAlong = (p.dx + deltaAlongMm)
                                .clamp(0.0, maxAlong)
                                .toDouble();
                            final newPerp = (p.dy + deltaPerpMm)
                                .clamp(0.0, maxPerp)
                                .toDouble();
                            onPlacementChanged(
                              c.cutId,
                              Offset(newAlong, newPerp),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints room polygon scaled to fit the block bounds. Used for single-piece template cuts.
class _RoomShapePainter extends CustomPainter {
  final List<Offset> vertices;
  final bool layAlongX;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  _RoomShapePainter({
    required this.vertices,
    required this.layAlongX,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (vertices.length < 3 || size.width <= 0 || size.height <= 0) return;

    double alongLo = vertices[0].dx, alongHi = vertices[0].dx;
    double perpLo = vertices[0].dy, perpHi = vertices[0].dy;
    if (!layAlongX) {
      alongLo = vertices[0].dy;
      alongHi = vertices[0].dy;
      perpLo = vertices[0].dx;
      perpHi = vertices[0].dx;
    }
    for (final v in vertices) {
      final a = layAlongX ? v.dx : v.dy;
      final p = layAlongX ? v.dy : v.dx;
      if (a < alongLo) alongLo = a;
      if (a > alongHi) alongHi = a;
      if (p < perpLo) perpLo = p;
      if (p > perpHi) perpHi = p;
    }
    final alongSpan = (alongHi - alongLo).clamp(1e-6, double.infinity);
    final perpSpan = (perpHi - perpLo).clamp(1e-6, double.infinity);

    Offset toLocal(Offset v) {
      final a = layAlongX ? v.dx : v.dy;
      final p = layAlongX ? v.dy : v.dx;
      final x = (a - alongLo) / alongSpan * size.width;
      final y = (p - perpLo) / perpSpan * size.height;
      return Offset(x, y);
    }

    final path = Path();
    path.moveTo(toLocal(vertices[0]).dx, toLocal(vertices[0]).dy);
    for (int i = 1; i < vertices.length; i++) {
      path.lineTo(toLocal(vertices[i]).dx, toLocal(vertices[i]).dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomShapePainter oldDelegate) {
    return oldDelegate.vertices != vertices ||
        oldDelegate.layAlongX != layAlongX ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

/// Cut block on the roll: positioned at 2D (alongMm, perpMm), draggable in both axes.
class _HorizontalCutBlock extends StatefulWidget {
  final RollCutPiece piece;

  /// Color for this product (roll board); offcut/sliver override still apply.
  final Color? productColor;
  final RollCutPlacement startOffset;
  final double rollLengthMm;
  final double rollWidthMm;
  final double rollWidthPx;
  final double rollHeightPx;
  final double pxPerMmAlong;
  final double pxPerMmPerp;
  final double minBlockWidthPx;
  final double minBlockHeightPx;
  final bool useImperial;
  final bool isSelected;
  final bool isSliver;
  final bool isOverlap;

  /// True when this cut is marked as sourced from an offcut.
  final bool isFromOffcut;

  /// Optional tooltip (e.g. "From offcut (lane 0)" or cut ID + length). Applied inside the block so [Positioned] stays direct child of [Stack].
  final String? tooltipMessage;
  final VoidCallback onTap;
  final void Function(double deltaAlongMm, double deltaPerpMm) onDragEnd;

  const _HorizontalCutBlock({
    required this.piece,
    this.productColor,
    required this.startOffset,
    required this.rollLengthMm,
    required this.rollWidthMm,
    required this.rollWidthPx,
    required this.rollHeightPx,
    required this.pxPerMmAlong,
    required this.pxPerMmPerp,
    required this.minBlockWidthPx,
    required this.minBlockHeightPx,
    required this.useImperial,
    required this.isSelected,
    required this.isSliver,
    required this.isOverlap,
    required this.isFromOffcut,
    this.tooltipMessage,
    required this.onTap,
    required this.onDragEnd,
  });

  @override
  State<_HorizontalCutBlock> createState() => _HorizontalCutBlockState();
}

class _HorizontalCutBlockState extends State<_HorizontalCutBlock> {
  Widget _buildBlockContent(
    BuildContext context,
    double widthPx,
    double heightPx,
  ) {
    final shape = widget.piece.roomShapeVerticesMm;
    final layAlongX = widget.piece.layAlongX ?? true;

    final primary = Theme.of(context).colorScheme.primary;
    final offcutColor = Colors.teal;
    final baseColor = widget.isFromOffcut
        ? offcutColor
        : (widget.productColor ?? primary);
    final fillColor = widget.isSliver
        ? Colors.amber.shade200
        : (widget.piece.stripIndex.isEven
              ? baseColor.withAlpha(128)
              : baseColor.withAlpha(179));
    final borderColor = widget.isOverlap
        ? Theme.of(context).colorScheme.error
        : baseColor;
    final borderWidth = widget.isSelected ? 2.5 : 1.0;

    if (shape != null && shape.length >= 3) {
      return ClipRect(
        child: CustomPaint(
          painter: _RoomShapePainter(
            vertices: shape,
            layAlongX: layAlongX,
            fillColor: fillColor,
            borderColor: borderColor,
            borderWidth: borderWidth,
          ),
          child: Container(
            width: widthPx,
            height: heightPx,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.piece.cutId,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                Text(
                  UnitConverter.formatDistance(
                    widget.piece.lengthMm,
                    useImperial: widget.useImperial,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withAlpha(230),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: widthPx,
      height: heightPx,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: widget.isSliver
            ? [BoxShadow(color: Colors.amber.withAlpha(128), blurRadius: 4)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.piece.cutId,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Text(
            UnitConverter.formatDistance(
              widget.piece.lengthMm,
              useImperial: widget.useImperial,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onPrimary.withAlpha(230),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftPx = (widget.startOffset.dx * widget.pxPerMmAlong).clamp(
      4.0,
      widget.rollWidthPx - 4,
    );
    final topPx = (widget.startOffset.dy * widget.pxPerMmPerp).clamp(
      4.0,
      widget.rollHeightPx - 4,
    );
    final widthPx = (widget.piece.lengthMm * widget.pxPerMmAlong).clamp(
      widget.minBlockWidthPx,
      double.infinity,
    );
    final heightPx = (widget.piece.breadthMm * widget.pxPerMmPerp).clamp(
      widget.minBlockHeightPx,
      widget.rollHeightPx - 8,
    );
    final content = GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (d) {
        final deltaAlongMm = (d.delta.dx / widget.pxPerMmAlong).toDouble();
        final deltaPerpMm = (d.delta.dy / widget.pxPerMmPerp).toDouble();
        widget.onDragEnd(deltaAlongMm, deltaPerpMm);
      },
      child: _buildBlockContent(context, widthPx, heightPx),
    );
    return Positioned(
      left: leftPx,
      top: 4 + topPx,
      width: widthPx,
      height: heightPx,
      child: widget.tooltipMessage != null
          ? Tooltip(message: widget.tooltipMessage!, child: content)
          : content,
    );
  }
}

class _CutInspector extends StatelessWidget {
  final RollPlanState plan;
  final bool useImperial;
  final void Function(String cutId) onRemoveFromRoll;
  final void Function(String cutId) onPlaceOnRoll;
  final VoidCallback onClearSelection;

  const _CutInspector({
    required this.plan,
    required this.useImperial,
    required this.onRemoveFromRoll,
    required this.onPlaceOnRoll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final cutId = plan.selectedCutId;
    if (cutId == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha(77),
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Center(
          child: Text(
            'Select a cut',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    final c = plan.allCuts.where((x) => x.cutId == cutId).firstOrNull;
    if (c == null) return const SizedBox.shrink();
    final pos = plan.placements[cutId];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(77),
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cut Inspector',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _row('Cut ID', c.cutId),
            _row('Room', c.roomName),
            if (c.roomShapeVerticesMm != null)
              _row('Type', 'Template cut (room shape)'),
            _row(
              'Length',
              UnitConverter.formatDistance(
                c.lengthMm,
                useImperial: useImperial,
              ),
            ),
            _row(
              'Width',
              UnitConverter.formatDistance(
                c.breadthMm,
                useImperial: useImperial,
              ),
            ),
            _row(
              'Trim',
              '+${UnitConverter.formatDistance(c.trimMm, useImperial: useImperial)} each end',
            ),
            if (c.patternRepeatMm != null)
              _row('Pattern', '${c.patternRepeatMm! / 1000} m'),
            _row(
              'Status',
              c.fromOffcut
                  ? (pos != null
                        ? 'Placed (from offcut)'
                        : 'Unplaced (from offcut)')
                  : (pos != null ? 'Placed' : 'Unplaced'),
            ),
            if (c.fromOffcut && c.sourceOffcutRollIndex != null)
              _row('Source roll', 'Lane ${c.sourceOffcutRollIndex}'),
            if (pos != null)
              _row(
                'Position',
                '${UnitConverter.formatDistance(pos.dx, useImperial: useImperial)} × ${UnitConverter.formatDistance(pos.dy, useImperial: useImperial)}',
              ),
            if (c.isSliver) _row('Note', 'Sliver'),
            const SizedBox(height: 12),
            if (pos != null)
              TextButton.icon(
                onPressed: () => onRemoveFromRoll(c.cutId),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('Send to tray'),
              ),
            if (pos == null)
              TextButton.icon(
                onPressed: () => onPlaceOnRoll(c.cutId),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Place on roll'),
              ),
            TextButton.icon(
              onPressed: onClearSelection,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Clear selection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _RoomWithCarpet {
  final int roomIndex;
  final Room room;
  final CarpetProduct product;
  final StripLayout layout;
  _RoomWithCarpet({
    required this.roomIndex,
    required this.room,
    required this.product,
    required this.layout,
  });
}
