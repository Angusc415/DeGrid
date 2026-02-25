import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/geometry/room.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/geometry/opening.dart';
import '../../core/roll_planning/carpet_layout_options.dart';
import '../../core/roll_planning/roll_planner.dart';
import '../../core/units/unit_converter.dart';

/// Phase 4: Cut list panel. Shows per-room strip cut lengths from current layout.
/// No layout changes; read-only view + export.
class CarpetCutListPanel extends StatelessWidget {
  final List<Room> rooms;
  final List<CarpetProduct> carpetProducts;
  final Map<int, int> roomCarpetAssignments;
  final List<Opening> openings;
  final bool useImperial;
  /// When set, rooms with overrides show a "Reset to auto" button.
  final Map<int, List<double>> roomCarpetSeamOverrides;
  final void Function(int roomIndex)? onResetSeamsForRoom;
  /// Room index -> layout variant (0 = Auto, 1 = 0°, 2 = 90°). Default 0.
  final Map<int, int> roomCarpetLayoutVariantIndex;
  final void Function(int roomIndex, int variantIndex)? onLayoutVariantChanged;

  const CarpetCutListPanel({
    super.key,
    required this.rooms,
    required this.carpetProducts,
    required this.roomCarpetAssignments,
    required this.openings,
    this.useImperial = false,
    this.roomCarpetSeamOverrides = const {},
    this.onResetSeamsForRoom,
    this.roomCarpetLayoutVariantIndex = const {},
    this.onLayoutVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? _buildEmpty(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) => entries[index],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut, size: 24),
              const SizedBox(width: 8),
              Text(
                'Cut list',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Strip lengths from current layout. Includes trim.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _exportAndCopy(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy as CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No rooms with carpet assigned.\nAssign products in the Rooms tab.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
        ),
      ),
    );
  }

  List<Widget> _buildEntries() {
    final list = <Widget>[];
    for (final entry in roomCarpetAssignments.entries) {
      final roomIndex = entry.key;
      final productIndex = entry.value;
      if (roomIndex < 0 || roomIndex >= rooms.length) continue;
      if (productIndex < 0 || productIndex >= carpetProducts.length) continue;
      final room = rooms[roomIndex];
      final product = carpetProducts[productIndex];
      if (product.rollWidthMm <= 0) continue;

      final seamOverride = roomCarpetSeamOverrides[roomIndex];
      final variantIndex = roomCarpetLayoutVariantIndex[roomIndex] ?? 0;
      final opts = CarpetLayoutOptions.forRoom(
        roomIndex: roomIndex,
        minStripWidthMm: product.minStripWidthMm ?? 100,
        trimAllowanceMm: product.trimAllowanceMm ?? 75,
        patternRepeatMm: product.patternRepeatMm ?? 0,
        wasteAllowancePercent: 5,
        openings: openings,
        seamPositionsOverrideMm: seamOverride,
        layDirectionDeg: variantIndex == 0 ? null : (variantIndex == 1 ? 0 : 90),
      );
      final candidates = RollPlanner.computeLayoutCandidates(room, product.rollWidthMm, opts);
      final layout = candidates[variantIndex.clamp(0, candidates.length - 1)];
      if (layout.numStrips == 0) continue;

      final minStripMm = product.minStripWidthMm ?? 100;
      final hasSeamOverrides = roomCarpetSeamOverrides.containsKey(roomIndex) &&
          roomCarpetSeamOverrides[roomIndex]!.isNotEmpty;
      list.add(
        _RoomCutListCard(
          roomIndex: roomIndex,
          roomName: room.name ?? 'Room ${roomIndex + 1}',
          product: product,
          layout: layout,
          candidates: candidates,
          selectedVariantIndex: variantIndex,
          onVariantChanged: onLayoutVariantChanged != null ? (v) => onLayoutVariantChanged!(roomIndex, v) : null,
          useImperial: useImperial,
          minStripWidthMm: minStripMm,
          hasSeamOverrides: hasSeamOverrides,
          onResetSeams: onResetSeamsForRoom != null ? () => onResetSeamsForRoom!(roomIndex) : null,
        ),
      );
    }
    return list;
  }

  void _exportAndCopy(BuildContext context) {
    final sb = StringBuffer();
    sb.writeln('room,product,strip,cut_length_mm');
    for (final entry in roomCarpetAssignments.entries) {
      final roomIndex = entry.key;
      final productIndex = entry.value;
      if (roomIndex < 0 || roomIndex >= rooms.length) continue;
      if (productIndex < 0 || productIndex >= carpetProducts.length) continue;
      final room = rooms[roomIndex];
      final product = carpetProducts[productIndex];
      if (product.rollWidthMm <= 0) continue;

      final seamOverride = roomCarpetSeamOverrides[roomIndex];
      final variantIndex = roomCarpetLayoutVariantIndex[roomIndex] ?? 0;
      final opts = CarpetLayoutOptions.forRoom(
        roomIndex: roomIndex,
        minStripWidthMm: product.minStripWidthMm ?? 100,
        trimAllowanceMm: product.trimAllowanceMm ?? 75,
        patternRepeatMm: product.patternRepeatMm ?? 0,
        wasteAllowancePercent: 5,
        openings: openings,
        seamPositionsOverrideMm: seamOverride,
        layDirectionDeg: variantIndex == 0 ? null : (variantIndex == 1 ? 0 : 90),
      );
      final candidates = RollPlanner.computeLayoutCandidates(room, product.rollWidthMm, opts);
      final layout = candidates[variantIndex.clamp(0, candidates.length - 1)];
      final roomName = room.name ?? 'Room ${roomIndex + 1}';
      final productName = product.name.replaceAll(',', ' ');
      for (var i = 0; i < layout.stripLengthsMm.length; i++) {
        sb.writeln('$roomName,$productName,${i + 1},${layout.stripLengthsMm[i].round()}');
      }
    }
    final csv = sb.toString();
    Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cut list copied to clipboard (CSV)'),
          duration: Duration(seconds: 2),
        ),
      );
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cut list CSV'),
          content: SingleChildScrollView(
            child: SelectableText(csv),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}

class _RoomCutListCard extends StatelessWidget {
  final int roomIndex;
  final String roomName;
  final CarpetProduct product;
  final StripLayout layout;
  final List<StripLayout> candidates;
  final int selectedVariantIndex;
  final void Function(int variantIndex)? onVariantChanged;
  final bool useImperial;
  final double minStripWidthMm;
  final bool hasSeamOverrides;
  final VoidCallback? onResetSeams;

  const _RoomCutListCard({
    required this.roomIndex,
    required this.roomName,
    required this.product,
    required this.layout,
    required this.candidates,
    required this.selectedVariantIndex,
    this.onVariantChanged,
    required this.useImperial,
    required this.minStripWidthMm,
    this.hasSeamOverrides = false,
    this.onResetSeams,
  });

  static const List<String> _variantLabels = ['Auto', '0°', '90°'];

  String _formatSeamPositions(StripLayout layout) {
    final positions = layout.seamPositionsFromReferenceMm;
    if (positions.isEmpty) return '';
    return List.generate(positions.length, (i) {
      final dist = UnitConverter.formatDistance(positions[i], useImperial: useImperial);
      return 'Seam ${i + 1}: $dist from ${layout.referenceEdgeLabel}';
    }).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final trimMm = product.trimAllowanceMm ?? 75;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              roomName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              product.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text(
              'Lay: ${layout.layAngleDeg == 0 ? "0° (horizontal)" : "90° (vertical)"} · ${layout.numStrips} strips',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
            ),
            if (onVariantChanged != null && candidates.length > 1) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: List.generate(candidates.length.clamp(0, 3), (i) {
                  final selected = selectedVariantIndex == i;
                  return ChoiceChip(
                    label: Text(_variantLabels[i], style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : null)),
                    selected: selected,
                    onSelected: (_) => onVariantChanged!(i),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'Cost: ${UnitConverter.formatDistance(layout.scoreCostMm, useImperial: useImperial)}'
              '${layout.totalLinearWithWasteMm != null && layout.totalLinearMm > 0 ? " · Waste: ${((layout.totalLinearWithWasteMm! - layout.totalLinearMm) / layout.totalLinearMm * 100).toStringAsFixed(1)}%" : ""}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                  ),
            ),
            if (hasSeamOverrides && onResetSeams != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onResetSeams,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset seams to auto'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Includes trim: ${trimMm.round()} mm each end',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
            ),
            if (layout.numStrips > 1) ...[
              const SizedBox(height: 6),
              Text(
                'Seam positions (from ${layout.referenceEdgeLabel}):',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.85),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatSeamPositions(layout),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(0.8),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  children: [
                    _tableHeader(context, '#'),
                    _tableHeader(context, 'Cut length'),
                    _tableHeader(context, 'Note'),
                  ],
                ),
                ...List.generate(layout.stripLengthsMm.length, (i) {
                  final len = layout.stripLengthsMm[i];
                  final isSliver = layout.isSliverAt(i, minStripWidthMm);
                  final widthMm = i < layout.stripWidthsMm.length
                      ? layout.stripWidthsMm[i]
                      : product.rollWidthMm;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          UnitConverter.formatDistance(len, useImperial: useImperial),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          isSliver ? 'Sliver ${widthMm.round()} mm' : '—',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontStyle: isSliver ? FontStyle.italic : null,
                                color: isSliver
                                    ? Theme.of(context).colorScheme.error.withOpacity(0.9)
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${UnitConverter.formatDistance(layout.totalLinearWithWasteMm ?? layout.totalLinearMm, useImperial: useImperial)} linear',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            // Full roll view: scrollable, drag to reorder cuts (no overlap)
            const SizedBox(height: 12),
            _RollCutDiagram(
              stripLengthsMm: layout.stripLengthsMm,
              useImperial: useImperial,
              roomKey: '$roomIndex-${layout.stripLengthsMm.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(BuildContext context, String label) {
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

/// Full roll view: scrollable bar with cut segments; drag to reorder (no overlap).
/// Segments are placed consecutively; reordering only changes cut order.
class _RollCutDiagram extends StatefulWidget {
  final List<double> stripLengthsMm;
  final bool useImperial;
  /// Key to reset order when room/layout changes (e.g. '$roomIndex-${length}').
  final String roomKey;

  const _RollCutDiagram({
    required this.stripLengthsMm,
    required this.useImperial,
    required this.roomKey,
  });

  @override
  State<_RollCutDiagram> createState() => _RollCutDiagramState();
}

class _RollCutDiagramState extends State<_RollCutDiagram> {
  /// Order of strips on the roll: _order[i] = original strip index at position i.
  late List<int> _order;

  static const double _minSegmentWidthPx = 44.0;
  static const double _barHeight = 40.0;
  static const double _pxPerMm = 0.06; // ~60px per m so roll scrolls

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.stripLengthsMm.length, (i) => i);
  }

  @override
  void didUpdateWidget(covariant _RollCutDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomKey != widget.roomKey ||
        oldWidget.stripLengthsMm.length != widget.stripLengthsMm.length) {
      _order = List.generate(widget.stripLengthsMm.length, (i) => i);
    }
  }

  void _reorder(int fromOrderIndex, int toOrderIndex) {
    if (fromOrderIndex == toOrderIndex) return;
    setState(() {
      final item = _order.removeAt(fromOrderIndex);
      final insertIndex = toOrderIndex > fromOrderIndex ? toOrderIndex - 1 : toOrderIndex;
      _order.insert(insertIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stripLengthsMm.isEmpty) return const SizedBox.shrink();
    final totalMm = widget.stripLengthsMm.fold<double>(0, (a, b) => a + b);
    if (totalMm <= 0) return const SizedBox.shrink();

    // Segment widths: proportional to length so full roll is visible and scrolls
    final segmentWidths = <double>[];
    for (final stripIndex in _order) {
      final len = widget.stripLengthsMm[stripIndex];
      final w = (len * _pxPerMm).clamp(_minSegmentWidthPx, double.infinity);
      segmentWidths.add(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Roll cut — drag segments to reorder',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.85),
              ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _barHeight + 4,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < _order.length; i++) ...[
                  _buildDropTarget(i),
                  _buildSegment(
                    context,
                    orderIndex: i,
                    stripIndex: _order[i],
                    widthPx: segmentWidths[i],
                  ),
                ],
                _buildDropTarget(_order.length),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (int i = 0; i < _order.length; i++)
              Text(
                '${i + 1}→${_order[i] + 1}: ${UnitConverter.formatDistance(widget.stripLengthsMm[_order[i]], useImperial: widget.useImperial)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.9),
                    ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropTarget(int insertAt) {
    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        final draggedOrderIndex = details.data;
        if (draggedOrderIndex >= 0 && draggedOrderIndex < _order.length) {
          _reorder(draggedOrderIndex, insertAt);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlight = candidateData.isNotEmpty;
        return Container(
          width: 8,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isHighlight
                ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required int orderIndex,
    required int stripIndex,
    required double widthPx,
  }) {
    final len = widget.stripLengthsMm[stripIndex];
    final label = UnitConverter.formatDistance(len, useImperial: widget.useImperial);
    return LongPressDraggable<int>(
      data: orderIndex,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: widthPx.clamp(60, 120),
          height: _barHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Text(
            '${stripIndex + 1}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _segmentContent(context, stripIndex, widthPx),
      ),
      child: _segmentContent(context, stripIndex, widthPx),
    );
  }

  Widget _segmentContent(BuildContext context, int stripIndex, double widthPx) {
    final len = widget.stripLengthsMm[stripIndex];
    final label = UnitConverter.formatDistance(len, useImperial: widget.useImperial);
    return Container(
      width: widthPx,
      height: _barHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: stripIndex.isEven
            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
            : Theme.of(context).colorScheme.primary.withOpacity(0.5),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Tooltip(
        message: 'Strip ${stripIndex + 1}: $label — long-press to move',
        child: Text(
          '${stripIndex + 1}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }
}
