import 'package:flutter/material.dart';
import '../../core/geometry/room.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/geometry/opening.dart';
import '../../core/roll_planning/carpet_layout_options.dart';
import '../../core/roll_planning/roll_planner.dart';
import '../../core/units/unit_converter.dart';
import 'carpet_cut_list_panel.dart';

// --- Roll plan data (visual packing board) ---

/// A single cut piece: one strip for a room. Identified by cutId (e.g. A1, B2).
class RollCutPiece {
  final String cutId;
  final int roomIndex;
  final String roomName;
  final int rollLaneIndex; // which roll lane this cut belongs to (same room+product)
  final CarpetProduct product;
  final int stripIndex;
  final double lengthMm;
  final double trimMm;
  final double breadthMm; // strip width
  final bool isSliver;
  final double? patternRepeatMm;
  /// Room polygon in mm for single-piece template cuts. Null for strip cuts.
  final List<Offset>? roomShapeVerticesMm;
  /// Lay direction for single-piece: true = strips run along x. Used to transform room shape.
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
    this.patternRepeatMm,
    this.roomShapeVerticesMm,
    this.layAlongX,
  });
}

/// One roll lane on the board. Single roll = one lane for all rooms' cuts.
class RollLaneData {
  final int rollIndex;
  final Room? room; // null for combined roll
  final CarpetProduct product;
  final StripLayout? layout; // null for combined; used only for roll length hint
  /// Total linear mm of all cuts on this roll (for default length when no product length).
  final double totalLinearMm;

  RollLaneData({
    required this.rollIndex,
    this.room,
    required this.product,
    this.layout,
    required this.totalLinearMm,
  });

  double get rollWidthMm => product.rollWidthMm > 0 ? product.rollWidthMm : 4000;
  /// Length of the roll (along the roll) in mm. Used as the horizontal scale so cuts are shown to scale.
  /// When product has no roll length, use at least the roll width (e.g. 3660mm) so the bar represents a real roll.
  double get rollLengthMm {
    if (product.rollLengthM != null && product.rollLengthM! > 0) {
      return product.rollLengthM! * 1000;
    }
    final minLength = rollWidthMm; // e.g. 3660mm – roll is at least as long as it is wide
    return (totalLinearMm * 1.2).clamp(minLength, double.infinity);
  }
}

/// 2D placement on the roll: (alongMm, perpMm). Along = roll length axis, perp = roll width axis.
typedef RollCutPlacement = Offset;

/// Remaining piece on a roll lane after placed cuts (tail from end of last cut to end of roll).
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

/// State for the roll planning board: all cuts, lanes, placements, selection.
class RollPlanState {
  final List<RollCutPiece> allCuts;
  final List<RollLaneData> lanes;
  /// cutId -> 2D position (dx = alongMm, dy = perpMm). Absent = unplaced.
  final Map<String, RollCutPlacement> placements;
  final String? selectedCutId;
  final bool cutListExpanded;
  /// Sum of layout cost (material + seam + sliver) for all rooms, for summary display.
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
        .where((c) => c.rollLaneIndex == rollIndex && placements.containsKey(c.cutId))
        .toList()
      ..sort((a, b) {
        final pa = placements[a.cutId]!;
        final pb = placements[b.cutId]!;
        final cmp = pa.dx.compareTo(pb.dx);
        return cmp != 0 ? cmp : pa.dy.compareTo(pb.dy);
      });
  }

  double totalLinearMm() =>
      allCuts.fold<double>(0, (s, c) => s + c.lengthMm);

  double wasteMmForLane(int rollIndex) {
    final placed = placedCutsOnLane(rollIndex);
    if (placed.isEmpty) return 0;
    final lane = lanes[rollIndex];
    final rollArea = lane.rollLengthMm * lane.rollWidthMm;
    final usedArea = placed.fold<double>(0, (s, c) => s + c.lengthMm * c.breadthMm);
    return ((rollArea - usedArea) / lane.rollWidthMm).clamp(0, double.infinity);
  }

  /// Offcuts (remaining tail) per lane: from end of rightmost cut to end of roll, full width.
  List<RollOffcut> offcuts() {
    final out = <RollOffcut>[];
    for (final lane in lanes) {
      final placed = placedCutsOnLane(lane.rollIndex);
      final rollWidth = lane.rollWidthMm;
      final endAlong = placed.isEmpty
          ? 0.0
          : placed.fold<double>(0, (m, c) {
              final e = placements[c.cutId]!.dx + c.lengthMm;
              return e > m ? e : m;
            });
      final tailLength = (lane.rollLengthMm - endAlong).clamp(0.0, double.infinity);
      if (tailLength > 0) {
        out.add(RollOffcut(
          rollIndex: lane.rollIndex,
          startAlongMm: endAlong,
          lengthMm: tailLength,
          breadthMm: rollWidth,
        ));
      }
    }
    return out;
  }

  /// 2D axis-aligned overlap: cut A at (ax,ay) size (aLength, aBreadth) vs B.
  bool _cutsOverlap(RollCutPiece a, RollCutPiece b, RollLaneData lane) {
    final pa = placements[a.cutId]!;
    final pb = placements[b.cutId]!;
    final aRight = pa.dx + a.lengthMm;
    final aBottom = pa.dy + a.breadthMm;
    final bRight = pb.dx + b.lengthMm;
    final bBottom = pb.dy + b.breadthMm;
    return pa.dx < bRight && pb.dx < aRight && pa.dy < bBottom && pb.dy < aBottom;
  }

  int get overlapCount {
    int n = 0;
    for (final lane in lanes) {
      final placed = placedCutsOnLane(lane.rollIndex);
      for (int i = 0; i < placed.length; i++) {
        for (int j = i + 1; j < placed.length; j++) {
          if (_cutsOverlap(placed[i], placed[j], lane)) n++;
        }
      }
    }
    return n;
  }

  /// Cut IDs that overlap another cut on their lane.
  Set<String> overlappingCutIds() {
    final out = <String>{};
    for (final lane in lanes) {
      final placed = placedCutsOnLane(lane.rollIndex);
      for (int i = 0; i < placed.length; i++) {
        for (int j = 0; j < placed.length; j++) {
          if (i == j) continue;
          if (_cutsOverlap(placed[i], placed[j], lane)) {
            out.add(placed[i].cutId);
            out.add(placed[j].cutId);
          }
        }
      }
    }
    return out;
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
      placements: placements ?? Map.from(this.placements),
      selectedCutId: clearSelection ? null : (selectedCutId ?? this.selectedCutId),
      cutListExpanded: cutListExpanded ?? this.cutListExpanded,
      totalScoreCostMm: totalScoreCostMm ?? this.totalScoreCostMm,
    );
  }
}

/// Bottom sheet (pull-up tab) showing cut list first; "Roll cut" button shows roll board.
/// Opened from the bottom-center Cuts tab.
class CarpetRollCutSheet extends StatefulWidget {
  final List<Room> rooms;
  final List<CarpetProduct> carpetProducts;
  final Map<int, int> roomCarpetAssignments;
  final List<Opening> openings;
  final Map<int, List<double>> roomCarpetSeamOverrides;
  final Map<int, int> roomCarpetLayoutVariantIndex;
  final void Function(int roomIndex, int variantIndex)? onLayoutVariantChanged;
  final bool useImperial;
  final ScrollController? scrollController;
  final void Function(int roomIndex)? onResetSeamsForRoom;

  const CarpetRollCutSheet({
    super.key,
    required this.rooms,
    required this.carpetProducts,
    required this.roomCarpetAssignments,
    required this.openings,
    this.roomCarpetSeamOverrides = const {},
    this.roomCarpetLayoutVariantIndex = const {},
    this.onLayoutVariantChanged,
    this.useImperial = false,
    this.scrollController,
    this.onResetSeamsForRoom,
  });

  /// Call from editor: showModalBottomSheet with this as child.
  static void show(
    BuildContext context, {
    required List<Room> rooms,
    required List<CarpetProduct> carpetProducts,
    required Map<int, int> roomCarpetAssignments,
    required List<Opening> openings,
    Map<int, List<double>> roomCarpetSeamOverrides = const {},
    Map<int, int> roomCarpetLayoutVariantIndex = const {},
    void Function(int roomIndex, int variantIndex)? onLayoutVariantChanged,
    bool useImperial = false,
    void Function(int roomIndex)? onResetSeamsForRoom,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => CarpetRollCutSheet(
          rooms: rooms,
          carpetProducts: carpetProducts,
          roomCarpetAssignments: roomCarpetAssignments,
          openings: openings,
          roomCarpetSeamOverrides: roomCarpetSeamOverrides,
          roomCarpetLayoutVariantIndex: roomCarpetLayoutVariantIndex,
          onLayoutVariantChanged: onLayoutVariantChanged,
          useImperial: useImperial,
          scrollController: scrollController,
          onResetSeamsForRoom: onResetSeamsForRoom,
        ),
      ),
    );
  }

  @override
  State<CarpetRollCutSheet> createState() => _CarpetRollCutSheetState();
}

enum _SheetView { cutList, rollCut }

class _CarpetRollCutSheetState extends State<CarpetRollCutSheet> {
  _SheetView _view = _SheetView.cutList;
  RollPlanState? _planState;
  /// Local copy of layout variant so the sheet updates when user changes it without waiting for parent rebuild.
  late Map<int, int> _layoutVariantIndex;

  @override
  void initState() {
    super.initState();
    _layoutVariantIndex = Map<int, int>.from(widget.roomCarpetLayoutVariantIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildPlanState());
  }

  @override
  void didUpdateWidget(covariant CarpetRollCutSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomCarpetLayoutVariantIndex != widget.roomCarpetLayoutVariantIndex) {
      _layoutVariantIndex = Map<int, int>.from(widget.roomCarpetLayoutVariantIndex);
    }
    if (oldWidget.rooms != widget.rooms ||
        oldWidget.roomCarpetAssignments != widget.roomCarpetAssignments ||
        oldWidget.carpetProducts != widget.carpetProducts) {
      _rebuildPlanState();
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
    for (final e in widget.roomCarpetAssignments.entries) {
      final ri = e.key;
      final pi = e.value;
      if (ri < 0 || ri >= widget.rooms.length || pi < 0 || pi >= widget.carpetProducts.length) continue;
      final room = widget.rooms[ri];
      final product = widget.carpetProducts[pi];
      if (product.rollWidthMm <= 0) continue;
      final variantIndex = _layoutVariantIndex[ri] ?? 0;
      final opts = CarpetLayoutOptions.forRoom(
        roomIndex: ri,
        minStripWidthMm: product.minStripWidthMm ?? 100,
        trimAllowanceMm: product.trimAllowanceMm ?? 75,
        patternRepeatMm: product.patternRepeatMm ?? 0,
        wasteAllowancePercent: 5,
        openings: widget.openings,
        seamPositionsOverrideMm: widget.roomCarpetSeamOverrides[ri],
        layDirectionDeg: variantIndex == 0 ? null : (variantIndex == 1 ? 0 : 90),
      );
      final layout = RollPlanner.computeLayout(room, product.rollWidthMm, opts);
      if (layout.numStrips > 0) {
        list.add(_RoomWithCarpet(roomIndex: ri, room: room, product: product, layout: layout));
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
    double alongPos = 0;
    for (int li = 0; li < list.length; li++) {
      final r = list[li];
      final roomName = r.room.name ?? 'Room ${r.roomIndex + 1}';
      final letter = String.fromCharCode(65 + li);
      for (int si = 0; si < r.layout.stripLengthsMm.length; si++) {
        final lengthMm = r.layout.stripLengthsMm[si];
        totalLinear += lengthMm;
        final cutId = '$letter${si + 1}';
        final breadthMm = si < r.layout.stripWidthsMm.length
            ? r.layout.stripWidthsMm[si]
            : r.product.rollWidthMm;
        final isSliver = r.layout.isSliverAt(si, r.product.minStripWidthMm ?? 100);
        allCuts.add(RollCutPiece(
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
          roomShapeVerticesMm: r.layout.isSinglePiece ? r.layout.roomShapeVerticesMm : null,
          layAlongX: r.layout.isSinglePiece ? r.layout.layAlongX : null,
        ));
        placements[cutId] = Offset(alongPos, 0);
        alongPos += lengthMm;
      }
    }
    final totalScoreCostMm = list.fold<double>(0, (s, r) => s + r.layout.scoreCostMm);
    final lanes = [
      RollLaneData(
        rollIndex: 0,
        product: first.product,
        totalLinearMm: totalLinear,
      ),
    ];
    setState(() {
      _planState = RollPlanState(
        allCuts: allCuts,
        lanes: lanes,
        placements: placements,
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

  void _applyPlacementDelta(String cutId, double deltaAlongMm, double deltaPerpMm) {
    if (_planState == null) return;
    final p = _planState!.placements[cutId];
    if (p == null) return;
    final piece = _planState!.allCuts.where((c) => c.cutId == cutId).firstOrNull;
    if (piece == null) return;
    final lane = _planState!.lanes[piece.rollLaneIndex];
    final maxAlong = (lane.rollLengthMm - piece.lengthMm).clamp(0.0, double.infinity);
    final maxPerp = (lane.rollWidthMm - piece.breadthMm).clamp(0.0, double.infinity);
    final newAlong = (p.dx + deltaAlongMm).clamp(0.0, maxAlong).toDouble();
    final newPerp = (p.dy + deltaPerpMm).clamp(0.0, maxPerp).toDouble();
    _updatePlacement(cutId, Offset(newAlong, newPerp));
  }

  void _removeFromRoll(String cutId) {
    if (_planState == null) return;
    final next = Map<String, RollCutPlacement>.from(_planState!.placements);
    next.remove(cutId);
    setState(() => _planState = _planState!.copyWith(placements: next, clearSelection: true));
  }

  void _placeOnRoll(String cutId) {
    if (_planState == null) return;
    final piece = _planState!.allCuts.where((c) => c.cutId == cutId).firstOrNull;
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
  }

  void _toggleCutListExpanded() {
    setState(() => _planState = _planState?.copyWith(cutListExpanded: !(_planState!.cutListExpanded)) ?? _planState);
  }

  @override
  Widget build(BuildContext context) {
    final list = _roomsWithCarpet;
    if (list.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(context),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No rooms with carpet assigned. Assign products in the Rooms panel.'),
          ),
        ],
      );
    }
    // Cut list view (default when sheet is pulled up)
    if (_view == _SheetView.cutList) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Cut list',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    if (_planState == null || _planState!.allCuts.isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildPlanState());
                    }
                    setState(() => _view = _SheetView.rollCut);
                  },
                  icon: const Icon(Icons.straighten, size: 20),
                  label: const Text('Roll cut'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CarpetCutListPanel(
              rooms: widget.rooms,
              carpetProducts: widget.carpetProducts,
              roomCarpetAssignments: widget.roomCarpetAssignments,
              openings: widget.openings,
              useImperial: widget.useImperial,
              roomCarpetSeamOverrides: widget.roomCarpetSeamOverrides,
              roomCarpetLayoutVariantIndex: _layoutVariantIndex,
              onLayoutVariantChanged: _onLayoutVariantChanged,
              onResetSeamsForRoom: widget.onResetSeamsForRoom,
            ),
          ),
        ],
      );
    }
    // Roll cut view
    if (_planState == null || _planState!.allCuts.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _view = _SheetView.cutList),
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text('Cut list'),
                ),
                const Spacer(),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.all(24), child: Text('Loading roll plan…')),
        ],
      );
    }
    final plan = _planState!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _view = _SheetView.cutList),
                icon: const Icon(Icons.list, size: 20),
                label: const Text('Cut list'),
              ),
              const Spacer(),
            ],
          ),
        ),
        _SummaryBar(
          plan: plan,
          useImperial: widget.useImperial,
          onAutoPlace: _autoPlaceAll,
          onExport: () => _exportCutSheet(context, plan),
        ),
        _OffcutsSection(plan: plan, useImperial: widget.useImperial),
        const Divider(height: 1),
        // Roll board: main focus, full width left to right
        Expanded(
          flex: 4,
          child: _RollBoard(
            plan: plan,
            useImperial: widget.useImperial,
            overlappingCutIds: plan.overlappingCutIds(),
            onPlacementChanged: _updatePlacement,
            onPlacementDelta: _applyPlacementDelta,
            onSelectCut: _selectCut,
            selectedCutId: plan.selectedCutId,
          ),
        ),
        const Divider(height: 1),
        // Tray and Inspector: compact row below the roll
        Flexible(
          flex: 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _UnplacedTray(
                  unplaced: plan.unplacedCuts,
                  useImperial: widget.useImperial,
                  onSelectCut: _selectCut,
                  selectedCutId: plan.selectedCutId,
                ),
              ),
              Container(width: 1, color: Theme.of(context).dividerColor),
              Expanded(
                child: _CutInspector(
                  plan: plan,
                  useImperial: widget.useImperial,
                  onRemoveFromRoll: _removeFromRoll,
                  onPlaceOnRoll: _placeOnRoll,
                  onClearSelection: () => _selectCut(null),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _CutListSection(
          plan: plan,
          useImperial: widget.useImperial,
          expanded: plan.cutListExpanded,
          onToggleExpanded: _toggleCutListExpanded,
          onSelectCut: _selectCut,
          selectedCutId: plan.selectedCutId,
        ),
      ],
    );
  }

  void _exportCutSheet(BuildContext context, RollPlanState plan) {
    // CSV: cuts then offcuts
    final sb = StringBuffer();
    sb.writeln('Cut ID,Room,Length (m),Start along (m),Start perp (m),Roll');
    for (final c in plan.allCuts) {
      final pos = plan.placements[c.cutId];
      final roll = pos != null ? (plan.lanes[c.rollLaneIndex].room?.name ?? plan.lanes[c.rollLaneIndex].product.name) : '';
      sb.writeln('${c.cutId},${c.roomName},${c.lengthMm / 1000},${pos != null ? pos.dx / 1000 : ""},${pos != null ? pos.dy / 1000 : ""},$roll');
    }
    final offcuts = plan.offcuts();
    if (offcuts.isNotEmpty) {
      sb.writeln();
      sb.writeln('Offcut,Lane,Length (m),Breadth (m),Start along (m)');
      for (final o in offcuts) {
        sb.writeln('Remaining,${o.rollIndex},${o.lengthMm / 1000},${o.breadthMm / 1000},${o.startAlongMm / 1000}');
      }
    }
    // TODO: share or copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export: ${plan.allCuts.length} cuts${offcuts.isNotEmpty ? ', ${offcuts.length} offcut(s)' : ''}. Copy from console or add share.')),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// --- Redesigned panels ---

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
    final wastePct = total > 0 && plan.lanes.isNotEmpty
        ? (plan.lanes.map((l) => plan.wasteMmForLane(l.rollIndex)).fold<double>(0, (a, b) => a + b) / total * 100)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            'Total: ${UnitConverter.formatDistance(total, useImperial: useImperial)} linear',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Text(
            'Cost: ${UnitConverter.formatDistance(plan.totalScoreCostMm, useImperial: useImperial)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Text('Waste: ${wastePct.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 16),
          Text('Placed: $placed/$totalCuts', style: Theme.of(context).textTheme.bodySmall),
          if (overlaps > 0) ...[
            const SizedBox(width: 8),
            Text('Warnings: $overlaps overlap(s)', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
          const Spacer(),
          TextButton.icon(onPressed: onAutoPlace, icon: const Icon(Icons.refresh, size: 18), label: const Text('Auto place')),
          const SizedBox(width: 8),
          TextButton.icon(onPressed: onExport, icon: const Icon(Icons.download, size: 18), label: const Text('Export')),
        ],
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
    if (offcuts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.9),
                ),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: offcuts.map((o) {
                return Text(
                  'Lane ${o.rollIndex}: ${UnitConverter.formatDistance(o.lengthMm, useImperial: useImperial)} × ${UnitConverter.formatDistance(o.breadthMm, useImperial: useImperial)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollBoard extends StatelessWidget {
  final RollPlanState plan;
  final bool useImperial;
  final Set<String> overlappingCutIds;
  final void Function(String cutId, RollCutPlacement pos) onPlacementChanged;
  final void Function(String cutId, double deltaAlongMm, double deltaPerpMm)? onPlacementDelta;
  final void Function(String? cutId) onSelectCut;
  final String? selectedCutId;

  const _RollBoard({
    required this.plan,
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
        final rollHeightPx = (rollWidthMm / rollLengthMm * availWidth).clamp(_minRollHeightPx, 200.0).toDouble();
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
                        onTap: () => onSelectCut(c.cutId),
                        onDragEnd: (double deltaAlongMm, double deltaPerpMm) {
                          if (onPlacementDelta != null) {
                            onPlacementDelta!(c.cutId, deltaAlongMm, deltaPerpMm);
                          } else {
                            final p = plan.placements[c.cutId]!;
                            final maxAlong = (rollLengthMm - c.lengthMm).clamp(0.0, double.infinity);
                            final maxPerp = (rollWidthMm - c.breadthMm).clamp(0.0, double.infinity);
                            final newAlong = (p.dx + deltaAlongMm).clamp(0.0, maxAlong).toDouble();
                            final newPerp = (p.dy + deltaPerpMm).clamp(0.0, maxPerp).toDouble();
                            onPlacementChanged(c.cutId, Offset(newAlong, newPerp));
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
      Paint()..color = fillColor..style = PaintingStyle.fill,
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
  final VoidCallback onTap;
  final void Function(double deltaAlongMm, double deltaPerpMm) onDragEnd;

  const _HorizontalCutBlock({
    required this.piece,
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
    required this.onTap,
    required this.onDragEnd,
  });

  @override
  State<_HorizontalCutBlock> createState() => _HorizontalCutBlockState();
}

class _HorizontalCutBlockState extends State<_HorizontalCutBlock> {
  Widget _buildBlockContent(BuildContext context, double widthPx, double heightPx) {
    final shape = widget.piece.roomShapeVerticesMm;
    final layAlongX = widget.piece.layAlongX ?? true;

    final fillColor = widget.isSliver
        ? Colors.amber.shade200
        : (widget.piece.stripIndex.isEven
            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
            : Theme.of(context).colorScheme.primary.withOpacity(0.7));
    final borderColor = widget.isOverlap
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
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
                  UnitConverter.formatDistance(widget.piece.lengthMm, useImperial: widget.useImperial),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
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
        boxShadow: widget.isSliver ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 4)] : null,
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
            UnitConverter.formatDistance(widget.piece.lengthMm, useImperial: widget.useImperial),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftPx = (widget.startOffset.dx * widget.pxPerMmAlong).clamp(4.0, widget.rollWidthPx - 4);
    final topPx = (widget.startOffset.dy * widget.pxPerMmPerp).clamp(4.0, widget.rollHeightPx - 4);
    final widthPx = (widget.piece.lengthMm * widget.pxPerMmAlong).clamp(widget.minBlockWidthPx, double.infinity);
    final heightPx = (widget.piece.breadthMm * widget.pxPerMmPerp).clamp(widget.minBlockHeightPx, widget.rollHeightPx - 8);
    return Positioned(
      left: leftPx,
      top: 4 + topPx,
      width: widthPx,
      height: heightPx,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (d) {
          final deltaAlongMm = (d.delta.dx / widget.pxPerMmAlong).toDouble();
          final deltaPerpMm = (d.delta.dy / widget.pxPerMmPerp).toDouble();
          widget.onDragEnd(deltaAlongMm, deltaPerpMm);
        },
        child: _buildBlockContent(context, widthPx, heightPx),
      ),
    );
  }
}

class _UnplacedTray extends StatelessWidget {
  final List<RollCutPiece> unplaced;
  final bool useImperial;
  final void Function(String? cutId) onSelectCut;
  final String? selectedCutId;

  const _UnplacedTray({
    required this.unplaced,
    required this.useImperial,
    required this.onSelectCut,
    this.selectedCutId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Unplaced',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: unplaced.isEmpty
                ? Center(
                    child: Text(
                      'All cuts placed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: unplaced.length,
                    itemBuilder: (context, i) {
                      final c = unplaced[i];
                      return ListTile(
                        dense: true,
                        title: Text(c.cutId),
                        subtitle: Text(
                          '${UnitConverter.formatDistance(c.lengthMm, useImperial: useImperial)} · ${c.roomName}${c.roomShapeVerticesMm != null ? ' (room shape)' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        selected: selectedCutId == c.cutId,
                        onTap: () => onSelectCut(c.cutId),
                      );
                    },
                  ),
          ),
        ],
      ),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Center(
          child: Text(
            'Select a cut',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    final c = plan.allCuts.where((x) => x.cutId == cutId).firstOrNull;
    if (c == null) return const SizedBox.shrink();
    final pos = plan.placements[cutId];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cut Inspector', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _row('Cut ID', c.cutId),
            _row('Room', c.roomName),
            if (c.roomShapeVerticesMm != null) _row('Type', 'Template cut (room shape)'),
            _row('Length', UnitConverter.formatDistance(c.lengthMm, useImperial: useImperial)),
            _row('Trim', '+${UnitConverter.formatDistance(c.trimMm, useImperial: useImperial)} each end'),
            if (c.patternRepeatMm != null) _row('Pattern', '${c.patternRepeatMm! / 1000} m'),
            _row('Status', pos != null ? 'Placed' : 'Unplaced'),
            if (pos != null) _row('Position', '${UnitConverter.formatDistance(pos.dx, useImperial: useImperial)} × ${UnitConverter.formatDistance(pos.dy, useImperial: useImperial)}'),
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
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _CutListSection extends StatelessWidget {
  final RollPlanState plan;
  final bool useImperial;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(String? cutId) onSelectCut;
  final String? selectedCutId;

  const _CutListSection({
    required this.plan,
    required this.useImperial,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelectCut,
    this.selectedCutId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_more : Icons.expand_less),
                const SizedBox(width: 8),
                Text('Cut list', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        if (expanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(0.6),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(0.8),
                  3: FlexColumnWidth(0.8),
                  4: FlexColumnWidth(0.6),
                },
                children: [
                  TableRow(
                    children: [
                      _th(context, 'ID'),
                      _th(context, 'Room'),
                      _th(context, 'Length'),
                      _th(context, 'Start'),
                      _th(context, 'Status'),
                    ],
                  ),
                  ...plan.allCuts.map((c) {
                    final pos = plan.placements[c.cutId];
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: GestureDetector(
                            onTap: () => onSelectCut(c.cutId),
                            child: Text(c.cutId, style: TextStyle(fontWeight: selectedCutId == c.cutId ? FontWeight.bold : null)),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(c.roomName)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(UnitConverter.formatDistance(c.lengthMm, useImperial: useImperial))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(pos != null ? '${UnitConverter.formatDistance(pos.dx, useImperial: useImperial)}, ${UnitConverter.formatDistance(pos.dy, useImperial: useImperial)}' : '—')),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(pos != null ? 'Placed' : 'Unplaced', style: TextStyle(fontSize: 11, color: pos != null ? null : Theme.of(context).colorScheme.error))),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _th(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
            ),
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

/// Roll of carpet with cuts positioned on it; drag cuts along the roll (no overlap).
/// Positions are in mm from roll start; drag updates position with validation.
class RollCutView extends StatefulWidget {
  final String roomName;
  final CarpetProduct product;
  final List<double> stripLengthsMm;
  final bool useImperial;
  final String roomKey;

  const RollCutView({
    super.key,
    required this.roomName,
    required this.product,
    required this.stripLengthsMm,
    required this.useImperial,
    required this.roomKey,
  });

  @override
  State<RollCutView> createState() => _RollCutViewState();
}

class _RollCutViewState extends State<RollCutView> {
  /// For each cut: (stripIndex, lengthMm, startMm on roll). No overlap; within roll length.
  late List<({int stripIndex, double lengthMm, double startMm})> _cuts;

  static const double _pxPerMmLength = 0.08; // roll length (horizontal) in pixels per mm
  static const double _pxPerMmWidth = 0.022; // roll width (vertical) so 3660mm → ~80px
  static const double _minSegmentWidthPx = 40.0;
  static const double _minRollHeightPx = 56.0;
  static const double _maxRollHeightPx = 120.0;

  /// Roll width in mm (full width of carpet, e.g. 3660).
  double get _rollWidthMm => widget.product.rollWidthMm > 0 ? widget.product.rollWidthMm : 4000;

  /// Height in px of the roll strip (represents full carpet width).
  double get _rollHeightPx => (_rollWidthMm * _pxPerMmWidth).clamp(_minRollHeightPx, _maxRollHeightPx);

  double get _rollLengthMm {
    if (widget.product.rollLengthM != null && widget.product.rollLengthM! > 0) {
      return widget.product.rollLengthM! * 1000;
    }
    final sum = widget.stripLengthsMm.fold<double>(0, (a, b) => a + b);
    return sum * 1.1; // 10% extra so cuts can be spaced
  }

  @override
  void initState() {
    super.initState();
    _resetCuts();
  }

  @override
  void didUpdateWidget(covariant RollCutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomKey != widget.roomKey ||
        oldWidget.stripLengthsMm.length != widget.stripLengthsMm.length) {
      _resetCuts();
    }
  }

  void _resetCuts() {
    double pos = 0;
    _cuts = [];
    for (int i = 0; i < widget.stripLengthsMm.length; i++) {
      final len = widget.stripLengthsMm[i];
      _cuts.add((stripIndex: i, lengthMm: len, startMm: pos));
      pos += len;
    }
  }

  /// Clamp startMm so cut doesn't overlap others and stays in [0, rollLength - length].
  double _clampStart(int cutIndex, double newStart) {
    final len = _cuts[cutIndex].lengthMm;
    final rollLen = _rollLengthMm;
    newStart = newStart.clamp(0.0, (rollLen - len).clamp(0.0, double.infinity));
    // Snap out of overlaps: repeatedly nudge to nearest gap until no overlap
    for (int pass = 0; pass < _cuts.length + 1; pass++) {
      bool anyOverlap = false;
      for (int j = 0; j < _cuts.length; j++) {
        if (j == cutIndex) continue;
        final a = _cuts[j].startMm;
        final b = a + _cuts[j].lengthMm;
        if (newStart < b && newStart + len > a) {
          anyOverlap = true;
          final snapBefore = (a - len).clamp(0.0, rollLen - len);
          final snapAfter = b.clamp(0.0, rollLen - len);
          newStart = (newStart - snapBefore).abs() <= (newStart - snapAfter).abs() ? snapBefore : snapAfter;
        }
      }
      if (!anyOverlap) break;
    }
    return newStart.clamp(0.0, (rollLen - len).clamp(0.0, double.infinity));
  }

  void _moveCut(int cutIndex, double deltaMm) {
    final c = _cuts[cutIndex];
    final newStart = _clampStart(cutIndex, c.startMm + deltaMm);
    if ((newStart - c.startMm).abs() < 0.1) return;
    setState(() {
      _cuts[cutIndex] = (stripIndex: c.stripIndex, lengthMm: c.lengthMm, startMm: newStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stripLengthsMm.isEmpty) return const SizedBox.shrink();
    final rollLenMm = _rollLengthMm;
    final rollLengthPx = (rollLenMm * _pxPerMmLength).clamp(280.0, double.infinity);
    final rollH = _rollHeightPx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.roomName} — ${widget.product.name}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.9),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Roll: ${UnitConverter.formatDistance(_rollWidthMm, useImperial: widget.useImperial)} wide × ${UnitConverter.formatDistance(rollLenMm, useImperial: widget.useImperial)} long. Drag cuts along the roll.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 12),
        // Roll = full width of carpet (height) × length (horizontal, scrollable)
        SizedBox(
          height: rollH + 8,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: rollLengthPx,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Roll (full carpet width strip)
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Container(
                      width: rollLengthPx,
                      height: rollH,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade200,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.brown.shade400),
                      ),
                    ),
                  ),
                  // Cuts on top (each cut spans full roll width = full height)
                  for (int i = 0; i < _cuts.length; i++)
                    _buildDraggableCut(context, i, rollLengthPx, rollLenMm, rollH),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (int i = 0; i < _cuts.length; i++)
              Text(
                '${_cuts[i].stripIndex + 1}: ${UnitConverter.formatDistance(_cuts[i].lengthMm, useImperial: widget.useImperial)} @ ${UnitConverter.formatDistance(_cuts[i].startMm, useImperial: widget.useImperial)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDraggableCut(BuildContext context, int cutIndex, double rollLengthPx, double rollLenMm, double rollHeightPx) {
    final c = _cuts[cutIndex];
    final leftPx = (c.startMm / rollLenMm * rollLengthPx).clamp(0.0, rollLengthPx - 4);
    final widthPx = (c.lengthMm / rollLenMm * rollLengthPx).clamp(_minSegmentWidthPx, double.infinity);

    return Positioned(
      left: leftPx,
      top: 4,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) {
          final deltaMm = (rollLenMm / rollLengthPx) * d.delta.dx;
          _moveCut(cutIndex, deltaMm);
        },
        child: Container(
          width: widthPx,
          height: rollHeightPx,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cutIndex.isEven
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : Theme.of(context).colorScheme.primary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
          child: Tooltip(
            message: 'Strip ${c.stripIndex + 1}: ${UnitConverter.formatDistance(c.lengthMm, useImperial: widget.useImperial)} — drag along roll',
            child: Text(
              '${c.stripIndex + 1}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
