# Graph Report - ./lib  (2026-07-12)

## Corpus Check
- 53 files · ~71,284 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1584 nodes · 1857 edges · 45 communities (39 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Plan Canvas Widget & Gestures|Plan Canvas Widget & Gestures]]
- [[_COMMUNITY_Drift Database Schema|Drift Database Schema]]
- [[_COMMUNITY_Opening Geometry & Wall Snapping|Opening Geometry & Wall Snapping]]
- [[_COMMUNITY_Roll Cut Sheet Screen|Roll Cut Sheet Screen]]
- [[_COMMUNITY_Roll Plan Models|Roll Plan Models]]
- [[_COMMUNITY_Plan Canvas Painter|Plan Canvas Painter]]
- [[_COMMUNITY_Plan Toolbar|Plan Toolbar]]
- [[_COMMUNITY_Roll Planner Algorithm|Roll Planner Algorithm]]
- [[_COMMUNITY_Projects Screen & PDF Export Entry|Projects Screen & PDF Export Entry]]
- [[_COMMUNITY_Carpet Cut List Panel|Carpet Cut List Panel]]
- [[_COMMUNITY_PDF Cut Sheet Entries|PDF Cut Sheet Entries]]
- [[_COMMUNITY_Project Model|Project Model]]
- [[_COMMUNITY_Editor Controller|Editor Controller]]
- [[_COMMUNITY_Opening Model & Editor Wiring|Opening Model & Editor Wiring]]
- [[_COMMUNITY_PDF Export|PDF Export]]
- [[_COMMUNITY_Room Area Summary Panel|Room Area Summary Panel]]
- [[_COMMUNITY_Carpet Layout Options & Planning Settings|Carpet Layout Options & Planning Settings]]
- [[_COMMUNITY_Polygon Clip & Band Sweep|Polygon Clip & Band Sweep]]
- [[_COMMUNITY_Background Image & DB Platform IO|Background Image & DB Platform IO]]
- [[_COMMUNITY_Room Strip Layout (Shared Entry Point)|Room Strip Layout (Shared Entry Point)]]
- [[_COMMUNITY_Plan Length Input Pad|Plan Length Input Pad]]
- [[_COMMUNITY_Project Settings Sheet|Project Settings Sheet]]
- [[_COMMUNITY_Carpet Product Model|Carpet Product Model]]
- [[_COMMUNITY_Carpet Products Screen|Carpet Products Screen]]
- [[_COMMUNITY_Plan Floorplan Menu|Plan Floorplan Menu]]
- [[_COMMUNITY_Room Transform (RotateSnap)|Room Transform (Rotate/Snap)]]
- [[_COMMUNITY_Widget State Classes I|Widget State Classes I]]
- [[_COMMUNITY_Plan Viewport|Plan Viewport]]
- [[_COMMUNITY_Unit Converter|Unit Converter]]
- [[_COMMUNITY_Widget Declarations II|Widget Declarations II]]
- [[_COMMUNITY_Room Geometry Model|Room Geometry Model]]
- [[_COMMUNITY_Room Opening Extension (Doorway)|Room Opening Extension (Doorway)]]
- [[_COMMUNITY_Drift Table Row Classes|Drift Table Row Classes]]
- [[_COMMUNITY_App Entry Point|App Entry Point]]
- [[_COMMUNITY_Drift Table Declarations|Drift Table Declarations]]
- [[_COMMUNITY_CSV Export Helpers|CSV Export Helpers]]
- [[_COMMUNITY_EditorProjects Navigation|Editor/Projects Navigation]]
- [[_COMMUNITY_Plan Canvas State Classes|Plan Canvas State Classes]]
- [[_COMMUNITY_Custom Painters|Custom Painters]]
- [[_COMMUNITY_Background Image IO Stub|Background Image IO Stub]]
- [[_COMMUNITY_Feature Flags|Feature Flags]]
- [[_COMMUNITY_Roll Cut Placement Typedef|Roll Cut Placement Typedef]]
- [[_COMMUNITY_Collapsible Toolbar Widget|Collapsible Toolbar Widget]]
- [[_COMMUNITY_Zoom Menu Button Widget|Zoom Menu Button Widget]]
- [[_COMMUNITY_Projects Screen State|Projects Screen State]]

## God Nodes (most connected - your core abstractions)
1. `StripSplitStrategy` - 8 edges
2. `CarpetPlanningSettings` - 8 edges
3. `AppDatabase` - 6 edges
4. `CarpetProduct` - 5 edges
5. `StripLayout` - 5 edges
6. `PlanCanvasState` - 5 edges
7. `Folder` - 4 edges
8. `Project` - 4 edges
9. `RoomData` - 4 edges
10. `Room` - 4 edges

## Surprising Connections (you probably didn't know these)
- `PlanCanvasEditorSettingsAccessors` --extends--> `PlanCanvasState`  [EXTRACTED]
  ui/canvas/plan_canvas_editor_settings.dart → ui/canvas/plan_canvas.dart
- `PlanCanvasGeometryHelpers` --extends--> `PlanCanvasState`  [EXTRACTED]
  ui/canvas/plan_canvas_geometry_helpers.dart → ui/canvas/plan_canvas.dart

## Import Cycles
- None detected.

## Communities (45 total, 6 thin omitted)

### Community 0 - "Plan Canvas Widget & Gestures"
Cohesion: 0.01
Nodes (365): CarpetPlanningSettings get, ../../core/background_image_io.dart, ../../core/geometry/room_transform.dart, dart:async, FocusNode, Offset get, package:file_picker/file_picker.dart, package:flutter/gestures.dart (+357 more)

### Community 1 - "Drift Database Schema"
Cohesion: 0.02
Nodes (113): BoolColumn get, ColumnFilters, ColumnOrderings, _addColumnIfNotExists, backgroundImageJson, backgroundImagePath, carpetPlanningSettingsJson, carpetProductsJson (+105 more)

### Community 2 - "Opening Geometry & Wall Snapping"
Cohesion: 0.02
Nodes (93): ab, addHostHint, apply, baseDelta, best, bestDelta, bestEi, bestScore (+85 more)

### Community 3 - "Roll Cut Sheet Screen"
Cohesion: 0.02
Nodes (86): carpet_cut_list_panel.dart, Color, package:share_plus/share_plus.dart, _applyPlacementDelta, _autoPlaceAll, borderColor, borderWidth, build (+78 more)

### Community 4 - "Roll Plan Models"
Cohesion: 0.03
Nodes (76): bool?, allCuts, anchors, baseWorld, best, bestDist, breadthMm, centerWorld (+68 more)

### Community 5 - "Plan Canvas Painter"
Cohesion: 0.03
Nodes (73): ../../core/geometry/opening_geometry.dart, ../../core/models/project.dart, Image?, addDimensionP1World, backgroundImage, backgroundImageState, calibrationP1Screen, calibrationP2Screen (+65 more)

### Community 6 - "Plan Toolbar"
Cohesion: 0.03
Nodes (73): IconData, OverlayEntry?, static const, static final, backgroundImageOpacity, backgroundImageScaleFactor, build, _buildDimensionsRow (+65 more)

### Community 7 - "Roll Planner Algorithm"
Cohesion: 0.04
Nodes (52): _applyStripSplitting, bboxHeight, bboxMinX, bboxMinY, bboxWidth, _computeBestLayoutForDirection, _computeForDirection, computeLayout (+44 more)

### Community 8 - "Projects Screen & PDF Export Entry"
Cohesion: 0.04
Nodes (50): ../canvas/viewport.dart, ../../core/database/database.dart, ../../core/export/cut_sheet_entries.dart, ../../core/export/pdf_export.dart, ../../core/services/project_service.dart, editor_screen.dart, GlobalKey, package:printing/printing.dart (+42 more)

### Community 9 - "Carpet Cut List Panel"
Cohesion: 0.04
Nodes (50): ../../core/export/csv.dart, ../../core/roll_planning/roll_plan_models.dart, static const List, _barHeight, build, _buildDropTarget, _buildEmpty, _buildEntries (+42 more)

### Community 10 - "PDF Cut Sheet Entries"
Cohesion: 0.04
Nodes (46): _, @DriftDatabase, AppDatabase, breadthMm, buildPdfCutSheetData, buildPdfCutSheetEntries, cutId, entries (+38 more)

### Community 11 - "Project Model"
Cohesion: 0.05
Nodes (40): backgroundImagePath, BackgroundImageState, carpetPlanningSettings, carpetProducts, carpetWasteAllowancePercent, copyWith, createdAt, doorThicknessMm (+32 more)

### Community 12 - "Editor Controller"
Cohesion: 0.05
Nodes (38): @immutable, ../../core/roll_planning/carpet_layout_options.dart, EditorViewState get, Map, bind, carpetPlanningSettings, carpetProducts, clearSeamOverridesForRoom (+30 more)

### Community 13 - "Opening Model & Editor Wiring"
Cohesion: 0.05
Nodes (37): ../canvas/plan_canvas.dart, carpet_products_screen.dart, carpet_roll_cut_sheet.dart, ChangeNotifier, ../../core/config/feature_flags.dart, edgeIndex, fromJson, isDoor (+29 more)

### Community 14 - "PDF Export"
Cohesion: 0.06
Nodes (35): _addFloorPlanPage, _BoundingBox, _buildCutSheetTable, _buildCutSheetTotals, _buildHeader, _buildRoomLabelWidget, _buildRoomScheduleTable, _buildScaleLegendClamped (+27 more)

### Community 15 - "Room Area Summary Panel"
Cohesion: 0.06
Nodes (34): ../../core/geometry/opening.dart, ../../core/geometry/room.dart, ../../core/roll_planning/roll_planner.dart, StripLayout, ../../core/roll_planning/room_strip_layout.dart, ../../core/units/unit_converter.dart, assignedProductIndex, build (+26 more)

### Community 16 - "Carpet Layout Options & Planning Settings"
Cohesion: 0.07
Nodes (28): CarpetLayoutOptions, CarpetPlanningSettings, copyWith, copyWithLayDirection, copyWithStripSplitStrategy, defaultSeamPenaltyMmInDoorway, doorwayExtensionMm, forRoom (+20 more)

### Community 17 - "Polygon Clip & Band Sweep"
Cohesion: 0.07
Nodes (28): alongHi, alongLo, BandRegion, bottom, clipPolygonToRect, _clipToHalfPlane, expandRegionsToCells, find (+20 more)

### Community 18 - "Background Image & DB Platform IO"
Cohesion: 0.09
Nodes (17): ensureBackgroundImageDir, null, readBackgroundImageBytes, writeBackgroundImageBytes, ensureBackgroundImageDir, readBackgroundImageBytes, writeBackgroundImageBytes, openConnection (+9 more)

### Community 19 - "Room Strip Layout (Shared Entry Point)"
Cohesion: 0.10
Nodes (19): carpet_layout_options.dart, applyStripPieceLengthsOverride, computeRoomStripLayout, copyWith, layDirectionDegFromVariant, layout, materialDelta, newTotal (+11 more)

### Community 20 - "Plan Length Input Pad"
Cohesion: 0.12
Nodes (17): package:flutter/foundation.dart, TextEditingController, build, _buildActionButton, _buildNumberButton, _buildNumberPad, child, controller (+9 more)

### Community 21 - "Project Settings Sheet"
Cohesion: 0.12
Nodes (17): build, createState, _doorThicknessMm, initialDoorThicknessMm, initialShowGrid, initialUseImperial, initialWallWidthMm, initState (+9 more)

### Community 22 - "Carpet Product Model"
Cohesion: 0.13
Nodes (14): copyWith, costPerSqm, estimatedCostForLinearMm, fromJson, listFromJson, listToJson, minStripWidthMm, name (+6 more)

### Community 23 - "Carpet Products Screen"
Cohesion: 0.14
Nodes (13): CarpetProduct, ../../core/geometry/carpet_product.dart, _addProduct, build, createState, _deleteProduct, _editProduct, initialProducts (+5 more)

### Community 24 - "Plan Floorplan Menu"
Cohesion: 0.15
Nodes (12): build, isMoveMode, locked, onDelete, onFit, onOpacityChanged, onReset, onToggleLock (+4 more)

### Community 25 - "Room Transform (Rotate/Snap)"
Cohesion: 0.17
Nodes (11): cosA, fine, map, nearestRightAngle, rotateVerticesAround, sinA, snapRotationDeg, stepDeg (+3 more)

### Community 26 - "Widget State Classes I"
Cohesion: 0.23
Nodes (12): State, StatefulWidget, _RollCutDiagram, _RollCutDiagramState, CarpetProductsScreen, _CarpetProductsScreenState, CarpetRollCutSheet, _CarpetRollCutSheetState (+4 more)

### Community 27 - "Plan Viewport"
Cohesion: 0.17
Nodes (11): maxMmPerPx, minMmPerPx, mmPerPx, panByScreenDelta, panByWorldDelta, PlanViewport, resetView, screenToWorld (+3 more)

### Community 28 - "Unit Converter"
Cohesion: 0.18
Nodes (10): cmPerM, formatArea, formatDistance, _formatImperial, _formatMetric, mmPerCm, mmPerFoot, mmPerInch (+2 more)

### Community 29 - "Widget Declarations II"
Cohesion: 0.18
Nodes (11): StatelessWidget, PlanFloorplanContextMenu, PlanDraggableNumberPadWrapper, PlanToolbar, CarpetCutListPanel, _RoomCutListCard, _CutInspector, _OffcutsSection (+3 more)

### Community 30 - "Room Geometry Model"
Cohesion: 0.20
Nodes (9): bool get, fromJsonString, isValid, name, Room, toJsonString, vertices, dart:convert (+1 more)

### Community 31 - "Room Opening Extension (Doorway)"
Cohesion: 0.22
Nodes (8): byEdge, extendRoomThroughOpenings, inside, out, _pointInPolygon, verts, ../geometry/opening.dart, ../geometry/room.dart

### Community 32 - "Drift Table Row Classes"
Cohesion: 0.33
Nodes (9): DataClass, Insertable, UpdateCompanion, Folder, FoldersCompanion, Project, ProjectsCompanion, RoomData (+1 more)

### Community 33 - "App Entry Point"
Cohesion: 0.25
Nodes (6): App, build, app.dart, main, package:flutter/material.dart, ui/screens/projects_screen.dart

### Community 34 - "Drift Table Declarations"
Cohesion: 0.40
Nodes (5): @DataClassName, Folders, Projects, Rooms, Table

### Community 35 - "CSV Export Helpers"
Cohesion: 0.40
Nodes (4): csvField, csvMetres, value, return

### Community 36 - "Editor/Projects Navigation"
Cohesion: 0.50
Nodes (4): MaterialPageRoute, _openCarpetProducts, _createNewProject, _openProject

### Community 37 - "Plan Canvas State Classes"
Cohesion: 0.50
Nodes (4): PlanCanvas, PlanCanvasState, PlanCanvasEditorSettingsAccessors, PlanCanvasGeometryHelpers

### Community 38 - "Custom Painters"
Cohesion: 0.67
Nodes (3): CustomPainter, PlanPainter, _RoomShapePainter

## Knowledge Gaps
- **1332 isolated node(s):** `build`, `null`, `readBackgroundImageBytes`, `writeBackgroundImageBytes`, `ensureBackgroundImageDir` (+1327 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppDatabase` connect `PDF Cut Sheet Entries` to `Plan Canvas Widget & Gestures`, `Drift Database Schema`, `Projects Screen & PDF Export Entry`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `StripSplitStrategy` connect `Carpet Layout Options & Planning Settings` to `Plan Canvas Widget & Gestures`, `Roll Cut Sheet Screen`, `Plan Canvas Painter`, `Carpet Cut List Panel`, `Project Model`, `Editor Controller`, `Room Area Summary Panel`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `CarpetPlanningSettings` connect `Carpet Layout Options & Planning Settings` to `Plan Canvas Widget & Gestures`, `Roll Cut Sheet Screen`, `Plan Canvas Painter`, `Carpet Cut List Panel`, `Project Model`, `Editor Controller`, `Room Area Summary Panel`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **What connects `build`, `null`, `readBackgroundImageBytes` to the rest of the system?**
  _1332 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Plan Canvas Widget & Gestures` be split into smaller, more focused modules?**
  _Cohesion score 0.00546448087431694 - nodes in this community are weakly interconnected._
- **Should `Drift Database Schema` be split into smaller, more focused modules?**
  _Cohesion score 0.017543859649122806 - nodes in this community are weakly interconnected._
- **Should `Opening Geometry & Wall Snapping` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._