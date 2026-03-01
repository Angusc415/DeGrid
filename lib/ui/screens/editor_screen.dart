import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../canvas/plan_canvas.dart';
import '../../core/geometry/room.dart';
import 'room_area_summary_panel.dart';
import 'carpet_products_screen.dart';
import 'carpet_cut_list_panel.dart';
import 'carpet_roll_cut_sheet.dart';
import 'project_settings_sheet.dart';

class EditorScreen extends StatefulWidget {
  final int? projectId;
  final String? projectName;

  const EditorScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<PlanCanvasState> _planCanvasKey = GlobalKey<PlanCanvasState>();
  List<Room> _rooms = [];
  bool _useImperial = false;
  int? _selectedRoomIndex;
  bool _isPanelOpen = false;
  Map<int, int> _roomCarpetAssignments = {};

  void _onRoomsChanged(List<Room> rooms, bool useImperial, int? selectedIndex) {
    setState(() {
      _rooms = rooms;
      _useImperial = useImperial;
      _selectedRoomIndex = selectedIndex;
    });
  }

  void _onRoomCarpetAssignmentsChanged(Map<int, int> assignments) {
    setState(() => _roomCarpetAssignments = assignments);
  }

  void _onRoomSelected(int roomIndex) {
    // Access the state through the GlobalKey
    _planCanvasKey.currentState?.selectRoom(roomIndex);
    setState(() {
      _selectedRoomIndex = roomIndex;
    });
    // Close drawer on mobile after selection
    if (!kIsWeb && _isPanelOpen) {
      Navigator.of(context).pop();
      _isPanelOpen = false;
    }
  }

  void _onRoomDeleted(int roomIndex) {
    // Access the state through the GlobalKey to delete room
    _planCanvasKey.currentState?.deleteRoom(roomIndex);
  }

  void _togglePanel(BuildContext scaffoldContext) {
    if (kIsWeb) {
      // On web, toggle panel visibility
      setState(() {
        _isPanelOpen = !_isPanelOpen;
      });
    } else {
      // On mobile, use drawer
      Scaffold.of(scaffoldContext).openEndDrawer();
      setState(() {
        _isPanelOpen = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName ?? 'New Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Project settings',
            onPressed: () {
              final canvasState = _planCanvasKey.currentState;
              if (canvasState == null) return;
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: false,
                useSafeArea: true,
                builder: (ctx) {
                  return ProjectSettingsSheet(
                    initialWallWidthMm: canvasState.wallWidthMm,
                    onWallWidthChanged: (value) {
                      canvasState.setWallWidthMm(value);
                    },
                    initialDoorThicknessMm: canvasState.doorThicknessMm,
                    onDoorThicknessChanged: (value) {
                      canvasState.setDoorThicknessMm(value);
                    },
                    initialUseImperial: canvasState.useImperial,
                    initialShowGrid: canvasState.showGrid,
                    onUseImperialChanged: (value) {
                      canvasState.setUseImperial(value);
                    },
                    onShowGridChanged: (value) {
                      canvasState.setShowGrid(value);
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: 'Carpet products',
            onPressed: () {
              final products = _planCanvasKey.currentState?.carpetProducts ?? [];
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CarpetProductsScreen(
                    initialProducts: products,
                    onProductsChanged: (list) {
                      _planCanvasKey.currentState?.setCarpetProducts(list);
                    },
                  ),
                ),
              );
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.view_list),
              tooltip: 'Room Summary',
              onPressed: () => _togglePanel(context),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Main canvas area
              Expanded(
                child: SafeArea(
                  child: PlanCanvas(
                key: _planCanvasKey,
                projectId: widget.projectId,
                initialProjectName: widget.projectName,
                onRoomsChanged: _onRoomsChanged,
                onRoomCarpetAssignmentsChanged: _onRoomCarpetAssignmentsChanged,
              ),
            ),
            ),
          // Side panel (web/desktop only, when open)
          if (kIsWeb && _isPanelOpen)
            Container(
              width: 320,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Rooms'),
                        Tab(text: 'Cut list'),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        children: [
                          RoomAreaSummaryPanel(
                            rooms: _rooms,
                            useImperial: _useImperial,
                            selectedRoomIndex: _selectedRoomIndex,
                            onRoomSelected: _onRoomSelected,
                            onRoomDeleted: _onRoomDeleted,
                            carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
                            roomCarpetAssignments: _roomCarpetAssignments,
                            onCarpetAssigned: (roomIndex, productIndex) {
                              _planCanvasKey.currentState?.setRoomCarpet(roomIndex, productIndex);
                            },
                          ),
                          CarpetCutListPanel(
                            rooms: _rooms,
                            carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
                            roomCarpetAssignments: _roomCarpetAssignments,
                            openings: _planCanvasKey.currentState?.openings ?? [],
                            useImperial: _useImperial,
                            roomCarpetSeamOverrides: _planCanvasKey.currentState?.roomCarpetSeamOverrides ?? {},
                            roomCarpetLayoutVariantIndex: _planCanvasKey.currentState?.roomCarpetLayoutVariantIndex ?? {},
                            onLayoutVariantChanged: (roomIndex, v) => _planCanvasKey.currentState?.setRoomLayoutVariant(roomIndex, v),
                            onResetSeamsForRoom: (roomIndex) => _planCanvasKey.currentState?.clearSeamOverridesForRoom(roomIndex),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
          // Bottom-center Cuts tab: pull up to open cut list / roll cut sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        CarpetRollCutSheet.show(
                          context,
                          rooms: _rooms,
                          carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
                          roomCarpetAssignments: _roomCarpetAssignments,
                          openings: _planCanvasKey.currentState?.openings ?? [],
                          roomCarpetSeamOverrides: _planCanvasKey.currentState?.roomCarpetSeamOverrides ?? {},
                          roomCarpetLayoutVariantIndex: _planCanvasKey.currentState?.roomCarpetLayoutVariantIndex ?? {},
                          onLayoutVariantChanged: (roomIndex, v) => _planCanvasKey.currentState?.setRoomLayoutVariant(roomIndex, v),
                          useImperial: _useImperial,
                          onResetSeamsForRoom: (roomIndex) => _planCanvasKey.currentState?.clearSeamOverridesForRoom(roomIndex),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vertical_align_top, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Cuts', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Drawer for mobile
      endDrawer: kIsWeb
          ? null
          : Drawer(
              width: 320,
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Rooms'),
                        Tab(text: 'Cut list'),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        children: [
                          RoomAreaSummaryPanel(
                            rooms: _rooms,
                            useImperial: _useImperial,
                            selectedRoomIndex: _selectedRoomIndex,
                            onRoomSelected: _onRoomSelected,
                            onRoomDeleted: _onRoomDeleted,
                            carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
                            roomCarpetAssignments: _roomCarpetAssignments,
                            onCarpetAssigned: (roomIndex, productIndex) {
                              _planCanvasKey.currentState?.setRoomCarpet(roomIndex, productIndex);
                            },
                          ),
                          CarpetCutListPanel(
                            rooms: _rooms,
                            carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
                            roomCarpetAssignments: _roomCarpetAssignments,
                            openings: _planCanvasKey.currentState?.openings ?? [],
                            useImperial: _useImperial,
                            roomCarpetSeamOverrides: _planCanvasKey.currentState?.roomCarpetSeamOverrides ?? {},
                            roomCarpetLayoutVariantIndex: _planCanvasKey.currentState?.roomCarpetLayoutVariantIndex ?? {},
                            onLayoutVariantChanged: (roomIndex, v) => _planCanvasKey.currentState?.setRoomLayoutVariant(roomIndex, v),
                            onResetSeamsForRoom: (roomIndex) => _planCanvasKey.currentState?.clearSeamOverridesForRoom(roomIndex),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
