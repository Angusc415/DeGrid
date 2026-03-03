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
  /// Cuts panel height as fraction of screen (0.06–0.92). We drive this ourselves so resize is reliable.
  double _cutsPanelFraction = 0.08;

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
                          Builder(
                            builder: (context) {
                              // Filter cut list to rooms that share the same carpet
                              // as the currently selected room, when one is selected.
                              Map<int, int> assignments = _roomCarpetAssignments;
                              if (_selectedRoomIndex != null) {
                                final selProduct = _roomCarpetAssignments[_selectedRoomIndex!];
                                if (selProduct != null) {
                                  assignments = {
                                    for (final e in _roomCarpetAssignments.entries)
                                      if (e.value == selProduct) e.key: e.value,
                                  };
                                }
                              }
                              return CarpetCutListPanel(
                                rooms: _rooms,
                                carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
                                roomCarpetAssignments: assignments,
                                openings: _planCanvasKey.currentState?.openings ?? [],
                                useImperial: _useImperial,
                                roomCarpetSeamOverrides: _planCanvasKey.currentState?.roomCarpetSeamOverrides ?? {},
                                roomCarpetLayoutVariantIndex: _planCanvasKey.currentState?.roomCarpetLayoutVariantIndex ?? {},
                                onLayoutVariantChanged: (roomIndex, v) => _planCanvasKey.currentState?.setRoomLayoutVariant(roomIndex, v),
                                onResetSeamsForRoom: (roomIndex) => _planCanvasKey.currentState?.clearSeamOverridesForRoom(roomIndex),
                              );
                            },
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
          // Cuts panel: height driven by state so drag/tap on the TOP handle resizes it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * _cutsPanelFraction,
            child: CarpetRollCutSheet(
              rooms: _rooms,
              carpetProducts: _planCanvasKey.currentState?.carpetProducts ?? [],
              roomCarpetAssignments: _roomCarpetAssignments,
              openings: _planCanvasKey.currentState?.openings ?? [],
              roomCarpetSeamOverrides: _planCanvasKey.currentState?.roomCarpetSeamOverrides ?? {},
              roomCarpetLayoutVariantIndex: _planCanvasKey.currentState?.roomCarpetLayoutVariantIndex ?? {},
              onLayoutVariantChanged: (roomIndex, v) => _planCanvasKey.currentState?.setRoomLayoutVariant(roomIndex, v),
              useImperial: _useImperial,
              onResetSeamsForRoom: (roomIndex) => _planCanvasKey.currentState?.clearSeamOverridesForRoom(roomIndex),
              selectedRoomIndex: _selectedRoomIndex,
              onResizeDrag: (deltaDy) {
                final h = MediaQuery.of(context).size.height;
                final delta = -deltaDy / h;
                setState(() {
                  _cutsPanelFraction = (_cutsPanelFraction + delta).clamp(0.06, 0.92);
                });
              },
              onToggleHeight: () {
                setState(() {
                  _cutsPanelFraction = _cutsPanelFraction < 0.5 ? 0.7 : 0.08;
                });
              },
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
