import 'package:flutter/material.dart';
import '../../core/geometry/room.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/roll_planning/carpet_layout_options.dart';
import '../../core/roll_planning/roll_planner.dart';
import '../../core/units/unit_converter.dart';

/// A panel that displays a summary of all rooms with their areas.
///
/// Features:
/// - List of all rooms with names and areas
/// - Total area calculation
/// - Room selection/navigation
/// - Sort by name or area
/// - Per-room carpet product assignment (Phase 2)
class RoomAreaSummaryPanel extends StatefulWidget {
  final List<Room> rooms;
  final bool useImperial;
  final int? selectedRoomIndex;
  final Function(int)? onRoomSelected;
  final Function(int)? onRoomDeleted;
  final List<CarpetProduct> carpetProducts;
  final Map<int, int> roomCarpetAssignments;
  final void Function(int roomIndex, int? productIndex)? onCarpetAssigned;

  const RoomAreaSummaryPanel({
    super.key,
    required this.rooms,
    required this.useImperial,
    this.selectedRoomIndex,
    this.onRoomSelected,
    this.onRoomDeleted,
    this.carpetProducts = const [],
    this.roomCarpetAssignments = const {},
    this.onCarpetAssigned,
  });

  @override
  State<RoomAreaSummaryPanel> createState() => _RoomAreaSummaryPanelState();
}

enum _SortOption { name, areaAsc, areaDesc }

class _RoomAreaSummaryPanelState extends State<RoomAreaSummaryPanel> {
  _SortOption _sortOption = _SortOption.name;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Calculate total area
    final totalAreaMm2 = widget.rooms.fold<double>(
      0.0,
      (sum, room) => sum + room.areaMm2,
    );

    // Filter and sort rooms
    final filteredRooms = _getFilteredAndSortedRooms();

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
          // Header
          Container(
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
                    const Icon(Icons.view_list, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Rooms',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Total area display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Area:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        UnitConverter.formatArea(totalAreaMm2, useImperial: widget.useImperial),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search and sort controls
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search rooms...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Sort dropdown
                Row(
                  children: [
                    const Icon(Icons.sort, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<_SortOption>(
                        value: _sortOption,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: _SortOption.name,
                            child: Text('Sort by Name'),
                          ),
                          DropdownMenuItem(
                            value: _SortOption.areaAsc,
                            child: Text('Sort by Area (Smallest)'),
                          ),
                          DropdownMenuItem(
                            value: _SortOption.areaDesc,
                            child: Text('Sort by Area (Largest)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortOption = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Room count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${filteredRooms.length} ${filteredRooms.length == 1 ? 'room' : 'rooms'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
            ),
          ),

          const Divider(),

          // Room list
          Expanded(
            child: filteredRooms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.rooms.isEmpty
                                ? 'No rooms yet'
                                : 'No rooms match your search',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final roomIndex = filteredRooms[index].index;
                      final room = filteredRooms[index].room;
                      final isSelected = widget.selectedRoomIndex == roomIndex;

                      return _RoomListItem(
                        room: room,
                        roomIndex: roomIndex,
                        useImperial: widget.useImperial,
                        isSelected: isSelected,
                        onTap: () => widget.onRoomSelected?.call(roomIndex),
                        onDelete: () => widget.onRoomDeleted?.call(roomIndex),
                        carpetProducts: widget.carpetProducts,
                        assignedProductIndex: widget.roomCarpetAssignments[roomIndex],
                        onCarpetAssigned: widget.onCarpetAssigned != null
                            ? (int? productIndex) => widget.onCarpetAssigned!(roomIndex, productIndex)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_RoomWithIndex> _getFilteredAndSortedRooms() {
    // Create list with indices
    final roomsWithIndices = List.generate(
      widget.rooms.length,
      (index) => _RoomWithIndex(room: widget.rooms[index], index: index),
    );

    // Filter by search query
    final filtered = _searchQuery.isEmpty
        ? roomsWithIndices
        : roomsWithIndices.where((item) {
            final name = item.room.name ?? 'Unnamed Room';
            return name.toLowerCase().contains(_searchQuery);
          }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.name:
          final nameA = a.room.name ?? 'Unnamed Room';
          final nameB = b.room.name ?? 'Unnamed Room';
          return nameA.compareTo(nameB);
        case _SortOption.areaAsc:
          return a.room.areaMm2.compareTo(b.room.areaMm2);
        case _SortOption.areaDesc:
          return b.room.areaMm2.compareTo(a.room.areaMm2);
      }
    });

    return filtered;
  }
}

class _RoomWithIndex {
  final Room room;
  final int index;

  _RoomWithIndex({required this.room, required this.index});
}

class _RoomListItem extends StatelessWidget {
  final Room room;
  final int roomIndex;
  final bool useImperial;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final List<CarpetProduct> carpetProducts;
  final int? assignedProductIndex;
  final void Function(int? productIndex)? onCarpetAssigned;

  const _RoomListItem({
    required this.room,
    required this.roomIndex,
    required this.useImperial,
    required this.isSelected,
    this.onTap,
    this.onDelete,
    this.carpetProducts = const [],
    this.assignedProductIndex,
    this.onCarpetAssigned,
  });

  void _showCarpetPicker(BuildContext context) {
    if (onCarpetAssigned == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Carpet for ${room.name ?? 'Room ${roomIndex + 1}'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              title: const Text('None'),
              leading: Icon(
                assignedProductIndex == null ? Icons.check : Icons.circle_outlined,
                size: 22,
              ),
              onTap: () {
                onCarpetAssigned!(null);
                Navigator.of(context).pop();
              },
            ),
            ...carpetProducts.asMap().entries.map((e) {
              final idx = e.key;
              final product = e.value;
              final isSelected = assignedProductIndex == idx;
              return ListTile(
                title: Text(product.name),
                subtitle: Text('${product.rollWidthMm.round()} mm wide'),
                leading: Icon(
                  isSelected ? Icons.check : Icons.circle_outlined,
                  size: 22,
                ),
                onTap: () {
                  onCarpetAssigned!(idx);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = room.name ?? 'Room ${roomIndex + 1}';
    final areaText = UnitConverter.formatArea(room.areaMm2, useImperial: useImperial);
    final product = assignedProductIndex != null &&
            assignedProductIndex! >= 0 &&
            assignedProductIndex! < carpetProducts.length
        ? carpetProducts[assignedProductIndex!]
        : null;
    final carpetLabel = product?.name ?? 'None';
    StripLayout? stripLayout;
    if (product != null && product.rollWidthMm > 0) {
      final opts = CarpetLayoutOptions(
        minStripWidthMm: product.minStripWidthMm ?? 100,
        trimAllowanceMm: product.trimAllowanceMm ?? 75,
        patternRepeatMm: product.patternRepeatMm ?? 0,
        wasteAllowancePercent: 5,
        roomIndex: roomIndex,
      );
      stripLayout = RollPlanner.computeLayout(room, product.rollWidthMm, opts);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        areaText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.withOpacity(0.7),
                    onPressed: onDelete,
                    tooltip: 'Delete room',
                  ),
              ],
            ),
            if (onCarpetAssigned != null) ...[
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCarpetPicker(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Carpet: $carpetLabel',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        if (stripLayout != null && stripLayout.numStrips > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${stripLayout.numStrips} strips · ${UnitConverter.formatDistance(stripLayout.totalLinearWithWasteMm ?? stripLayout.totalLinearMm, useImperial: useImperial)} linear',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
