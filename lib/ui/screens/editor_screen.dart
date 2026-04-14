import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/config/feature_flags.dart';

import '../canvas/plan_canvas.dart';
import '../editor/editor_controller.dart';
import 'carpet_cut_list_panel.dart';
import 'carpet_products_screen.dart';
import 'carpet_roll_cut_sheet.dart';
import 'project_settings_sheet.dart';
import 'room_area_summary_panel.dart';

class EditorScreen extends StatefulWidget {
  final int? projectId;
  final String? projectName;

  const EditorScreen({super.key, this.projectId, this.projectName});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final EditorController _editorController = EditorController();
  bool _isPanelOpen = false;
  double _cutsPanelFraction = 0.08;

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  void _onRoomSelected(int roomIndex) {
    _editorController.selectRoom(roomIndex);
    if (!kIsWeb && _isPanelOpen) {
      Navigator.of(context).pop();
      _isPanelOpen = false;
    }
  }

  void _onRoomDeleted(int roomIndex) {
    _editorController.deleteRoom(roomIndex);
  }

  void _togglePanel(BuildContext scaffoldContext) {
    if (kIsWeb) {
      setState(() {
        _isPanelOpen = !_isPanelOpen;
      });
      return;
    }

    Scaffold.of(scaffoldContext).openEndDrawer();
    setState(() {
      _isPanelOpen = true;
    });
  }

  Map<int, int> _filteredCutListAssignments(EditorViewState state) {
    var assignments = state.roomCarpetAssignments;
    final selectedRoomIndex = state.selectedRoomIndex;
    if (selectedRoomIndex != null) {
      final selectedProduct = assignments[selectedRoomIndex];
      if (selectedProduct != null) {
        return {
          for (final entry in assignments.entries)
            if (entry.value == selectedProduct) entry.key: entry.value,
        };
      }
      return assignments;
    }

    final areaByProduct = <int, double>{};
    for (final entry in assignments.entries) {
      final roomIndex = entry.key;
      final productIndex = entry.value;
      if (roomIndex < 0 ||
          roomIndex >= state.rooms.length ||
          productIndex < 0 ||
          productIndex >= state.carpetProducts.length) {
        continue;
      }
      final room = state.rooms[roomIndex];
      areaByProduct[productIndex] =
          (areaByProduct[productIndex] ?? 0) + room.areaMm2;
    }
    if (areaByProduct.isEmpty) {
      return assignments;
    }

    final bestProductIndex = areaByProduct.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return {
      for (final entry in assignments.entries)
        if (entry.value == bestProductIndex) entry.key: entry.value,
    };
  }

  void _showProjectSettingsSheet(EditorViewState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (ctx) {
        return ProjectSettingsSheet(
          initialWallWidthMm: state.wallWidthMm,
          onWallWidthChanged: _editorController.setWallWidthMm,
          initialDoorThicknessMm: state.doorThicknessMm,
          onDoorThicknessChanged: _editorController.setDoorThicknessMm,
          initialUseImperial: state.useImperial,
          initialShowGrid: state.showGrid,
          onUseImperialChanged: _editorController.setUseImperial,
          onShowGridChanged: _editorController.setShowGrid,
        );
      },
    );
  }

  void _openCarpetProducts(EditorViewState state) {
    if (!kEnableCarpetFeatures) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CarpetProductsScreen(
          initialProducts: state.carpetProducts,
          onProductsChanged: _editorController.setCarpetProducts,
        ),
      ),
    );
  }

  Widget _buildSidePanel(EditorViewState state) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Rooms',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RoomAreaSummaryPanel(
              rooms: state.rooms,
              useImperial: state.useImperial,
              selectedRoomIndex: state.selectedRoomIndex,
              onRoomSelected: _onRoomSelected,
              onRoomDeleted: _onRoomDeleted,
              carpetProducts: kEnableCarpetFeatures ? state.carpetProducts : const [],
              roomCarpetAssignments:
                  kEnableCarpetFeatures ? state.roomCarpetAssignments : const {},
              onCarpetAssigned:
                  kEnableCarpetFeatures ? _editorController.setRoomCarpet : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _editorController,
      builder: (context, child) {
        final state = _editorController.state;
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
                onPressed: () => _showProjectSettingsSheet(state),
              ),
              if (kEnableCarpetFeatures)
                IconButton(
                  icon: const Icon(Icons.layers),
                  tooltip: 'Carpet products',
                  onPressed: () => _openCarpetProducts(state),
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
                  Expanded(
                    child: SafeArea(
                      child: PlanCanvas(
                        projectId: widget.projectId,
                        initialProjectName: widget.projectName,
                        controller: _editorController,
                      ),
                    ),
                  ),
                  if (kIsWeb && _isPanelOpen) _buildSidePanel(state),
                ],
              ),
              if (kEnableCarpetFeatures)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: MediaQuery.of(context).size.height * _cutsPanelFraction,
                  child: CarpetRollCutSheet(
                    rooms: state.rooms,
                    carpetProducts: state.carpetProducts,
                    roomCarpetAssignments: state.roomCarpetAssignments,
                    openings: state.openings,
                    roomCarpetSeamOverrides: state.roomCarpetSeamOverrides,
                    roomCarpetSeamLayDirectionDeg:
                        state.roomCarpetSeamLayDirectionDeg,
                    roomCarpetLayoutVariantIndex:
                        state.roomCarpetLayoutVariantIndex,
                    onLayoutVariantChanged:
                        _editorController.setRoomLayoutVariant,
                    stripSplitStrategy: state.stripSplitStrategy,
                    onStripSplitStrategyChanged:
                        _editorController.setStripSplitStrategy,
                    roomCarpetStripPieceLengthsOverrideMm:
                        state.roomCarpetStripPieceLengthsOverrideMm,
                    useImperial: state.useImperial,
                    onResetSeamsForRoom:
                        _editorController.clearSeamOverridesForRoom,
                    selectedRoomIndex: state.selectedRoomIndex,
                    onResizeDrag: (deltaDy) {
                      final height = MediaQuery.of(context).size.height;
                      final delta = -deltaDy / height;
                      setState(() {
                        _cutsPanelFraction = (_cutsPanelFraction + delta).clamp(
                          0.06,
                          0.92,
                        );
                      });
                    },
                    onToggleHeight: () {
                      setState(() {
                        _cutsPanelFraction = _cutsPanelFraction < 0.5
                            ? 0.7
                            : 0.08;
                      });
                    },
                  ),
                ),
            ],
          ),
          endDrawer: kIsWeb
              ? null
              : Drawer(width: 320, child: _buildSidePanel(state)),
        );
      },
    );
  }
}
