# Graph Report - ./lib  (2026-07-03)

## Corpus Check
- 51 files · ~67,234 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1521 nodes · 1789 edges · 36 communities (32 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Plan Canvas Widget|Plan Canvas Widget]]
- [[_COMMUNITY_Drift Database Schema|Drift Database Schema]]
- [[_COMMUNITY_Roll Cut Sheet Screen|Roll Cut Sheet Screen]]
- [[_COMMUNITY_Opening Geometry & Snapping|Opening Geometry & Snapping]]
- [[_COMMUNITY_Roll Plan Models|Roll Plan Models]]
- [[_COMMUNITY_Plan Canvas Painter|Plan Canvas Painter]]
- [[_COMMUNITY_Plan Toolbar|Plan Toolbar]]
- [[_COMMUNITY_Carpet Cut List Panel|Carpet Cut List Panel]]
- [[_COMMUNITY_Projects Screen|Projects Screen]]
- [[_COMMUNITY_App Entry & Widget Declarations|App Entry & Widget Declarations]]
- [[_COMMUNITY_Roll Planner Algorithm|Roll Planner Algorithm]]
- [[_COMMUNITY_Platform IO & Polygon Clipping|Platform IO & Polygon Clipping]]
- [[_COMMUNITY_Widget State Classes|Widget State Classes]]
- [[_COMMUNITY_Project Model|Project Model]]
- [[_COMMUNITY_Editor Screen & Opening Model|Editor Screen & Opening Model]]
- [[_COMMUNITY_Editor Controller|Editor Controller]]
- [[_COMMUNITY_PDF Export|PDF Export]]
- [[_COMMUNITY_Carpet Product & Settings Sheet|Carpet Product & Settings Sheet]]
- [[_COMMUNITY_Carpet Layout Options|Carpet Layout Options]]
- [[_COMMUNITY_Room Area Summary Panel|Room Area Summary Panel]]
- [[_COMMUNITY_Project Service|Project Service]]
- [[_COMMUNITY_Room Strip Layout|Room Strip Layout]]
- [[_COMMUNITY_UndoRedo History Manager|Undo/Redo History Manager]]
- [[_COMMUNITY_Room Transform (RotateSnap)|Room Transform (Rotate/Snap)]]
- [[_COMMUNITY_Plan Viewport|Plan Viewport]]
- [[_COMMUNITY_Unit Converter|Unit Converter]]
- [[_COMMUNITY_Room Geometry Model|Room Geometry Model]]
- [[_COMMUNITY_Drift Table Row Classes|Drift Table Row Classes]]
- [[_COMMUNITY_Drift Table Definitions|Drift Table Definitions]]
- [[_COMMUNITY_Navigation Routes|Navigation Routes]]
- [[_COMMUNITY_AppDatabase Entry Point|AppDatabase Entry Point]]
- [[_COMMUNITY_Custom Painters|Custom Painters]]
- [[_COMMUNITY_Editor View State|Editor View State]]
- [[_COMMUNITY_Background Image IO Stub|Background Image IO Stub]]
- [[_COMMUNITY_Feature Flags|Feature Flags]]
- [[_COMMUNITY_Roll Cut Placement Model|Roll Cut Placement Model]]

## God Nodes (most connected - your core abstractions)
1. `StripSplitStrategy` - 7 edges
2. `AppDatabase` - 6 edges
3. `CarpetPlanningSettings` - 6 edges
4. `CarpetProduct` - 5 edges
5. `PlanCanvasState` - 5 edges
6. `Folder` - 4 edges
7. `Project` - 4 edges
8. `RoomData` - 4 edges
9. `Room` - 4 edges
10. `StripLayout` - 4 edges

## Surprising Connections (you probably didn't know these)
- `PlanCanvasEditorSettingsAccessors` --extends--> `PlanCanvasState`  [EXTRACTED]
  ui/canvas/plan_canvas_editor_settings.dart → ui/canvas/plan_canvas.dart
- `PlanCanvasGeometryHelpers` --extends--> `PlanCanvasState`  [EXTRACTED]
  ui/canvas/plan_canvas_geometry_helpers.dart → ui/canvas/plan_canvas.dart

## Import Cycles
- None detected.

## Communities (36 total, 4 thin omitted)

### Community 0 - "Plan Canvas Widget"
Cohesion: 0.01
Nodes (358): CarpetPlanningSettings get, ../../core/background_image_io.dart, ../../core/geometry/room_transform.dart, dart:async, FocusNode, Offset get, package:file_picker/file_picker.dart, package:flutter/gestures.dart (+350 more)

### Community 1 - "Drift Database Schema"
Cohesion: 0.02
Nodes (110): BoolColumn get, ColumnFilters, ColumnOrderings, _addColumnIfNotExists, backgroundImageJson, backgroundImagePath, carpetProductsJson, carpetWasteAllowancePercent (+102 more)

### Community 2 - "Roll Cut Sheet Screen"
Cohesion: 0.02
Nodes (97): carpet_cut_list_panel.dart, Color, package:share_plus/share_plus.dart, _applyPlacementDelta, _autoPlaceAll, borderColor, borderWidth, build (+89 more)

### Community 3 - "Opening Geometry & Snapping"
Cohesion: 0.02
Nodes (93): ab, addHostHint, apply, baseDelta, best, bestDelta, bestEi, bestScore (+85 more)

### Community 4 - "Roll Plan Models"
Cohesion: 0.03
Nodes (73): bool?, allCuts, anchors, baseWorld, best, bestDist, breadthMm, buildRoomLetterIndicesByProduct (+65 more)

### Community 5 - "Plan Canvas Painter"
Cohesion: 0.03
Nodes (73): ../../core/geometry/opening_geometry.dart, ../../core/models/project.dart, Image?, addDimensionP1World, backgroundImage, backgroundImageState, calibrationP1Screen, calibrationP2Screen (+65 more)

### Community 6 - "Plan Toolbar"
Cohesion: 0.03
Nodes (73): IconData, OverlayEntry?, static const, static final, backgroundImageOpacity, backgroundImageScaleFactor, build, _buildDimensionsRow (+65 more)

### Community 7 - "Carpet Cut List Panel"
Cohesion: 0.04
Nodes (49): ../../core/roll_planning/roll_plan_models.dart, ../../core/roll_planning/room_strip_layout.dart, static const List, _barHeight, build, _buildDropTarget, _buildEmpty, _buildEntries (+41 more)

### Community 8 - "Projects Screen"
Cohesion: 0.04
Nodes (48): ../canvas/viewport.dart, ../../core/database/database.dart, ../../core/export/pdf_export.dart, ../../core/services/project_service.dart, editor_screen.dart, GlobalKey, package:printing/printing.dart, Set (+40 more)

### Community 9 - "App Entry & Widget Declarations"
Cohesion: 0.05
Nodes (44): App, build, app.dart, main, package:flutter/foundation.dart, package:flutter/material.dart, StatelessWidget, TextEditingController (+36 more)

### Community 10 - "Roll Planner Algorithm"
Cohesion: 0.04
Nodes (46): _applyStripSplitting, bboxHeight, bboxMinX, bboxMinY, bboxWidth, _computeBestLayoutForDirection, _computeForDirection, computeLayout (+38 more)

### Community 11 - "Platform IO & Polygon Clipping"
Cohesion: 0.04
Nodes (40): ensureBackgroundImageDir, null, readBackgroundImageBytes, writeBackgroundImageBytes, ensureBackgroundImageDir, readBackgroundImageBytes, writeBackgroundImageBytes, openConnection (+32 more)

### Community 12 - "Widget State Classes"
Cohesion: 0.06
Nodes (41): CarpetProduct, ../../core/geometry/carpet_product.dart, State, StatefulWidget, PlanCanvas, PlanCanvasState, PlanLengthInputPad, _PlanLengthInputPadState (+33 more)

### Community 13 - "Project Model"
Cohesion: 0.05
Nodes (39): backgroundImagePath, BackgroundImageState, carpetProducts, carpetWasteAllowancePercent, copyWith, createdAt, doorThicknessMm, effectiveScaleMmPerPixel (+31 more)

### Community 14 - "Editor Screen & Opening Model"
Cohesion: 0.05
Nodes (35): ../canvas/plan_canvas.dart, carpet_products_screen.dart, carpet_roll_cut_sheet.dart, ChangeNotifier, ../../core/config/feature_flags.dart, edgeIndex, fromJson, isDoor (+27 more)

### Community 15 - "Editor Controller"
Cohesion: 0.06
Nodes (35): ../../core/geometry/opening.dart, EditorViewState get, bind, carpetPlanningSettings, carpetProducts, clearSeamOverridesForRoom, deleteRoom, doorThicknessMm (+27 more)

### Community 16 - "PDF Export"
Cohesion: 0.06
Nodes (31): _addFloorPlanPage, _BoundingBox, _buildHeader, _buildRoomLabelWidget, _buildRoomScheduleTable, _buildScaleLegendClamped, _calculateBoundingBox, _createEmptyPdf (+23 more)

### Community 17 - "Carpet Product & Settings Sheet"
Cohesion: 0.06
Nodes (30): copyWith, costPerSqm, fromJson, listFromJson, listToJson, minStripWidthMm, name, patternRepeatMm (+22 more)

### Community 18 - "Carpet Layout Options"
Cohesion: 0.08
Nodes (24): CarpetLayoutOptions, CarpetPlanningSettings, copyWith, copyWithLayDirection, copyWithStripSplitStrategy, defaultSeamPenaltyMmInDoorway, forRoom, hashCode (+16 more)

### Community 19 - "Room Area Summary Panel"
Cohesion: 0.08
Nodes (23): ../../core/roll_planning/carpet_layout_options.dart, ../../core/roll_planning/roll_planner.dart, ../../core/units/unit_converter.dart, Map, assignedProductIndex, build, carpetProducts, createState (+15 more)

### Community 20 - "Project Service"
Cohesion: 0.10
Nodes (19): createFolder, createProject, _db, deleteFolder, deleteProject, getAllProjects, getFolders, getProject (+11 more)

### Community 21 - "Room Strip Layout"
Cohesion: 0.11
Nodes (17): carpet_layout_options.dart, applyStripPieceLengthsOverride, computeRoomStripLayout, copyWith, layDirectionDegFromVariant, layout, opts, settings (+9 more)

### Community 22 - "Undo/Redo History Manager"
Cohesion: 0.14
Nodes (13): ../../core/geometry/room.dart, static const int, typedef, canRedo, canUndo, _history, _index, maxHistorySize (+5 more)

### Community 23 - "Room Transform (Rotate/Snap)"
Cohesion: 0.17
Nodes (11): cosA, fine, map, nearestRightAngle, rotateVerticesAround, sinA, snapRotationDeg, stepDeg (+3 more)

### Community 24 - "Plan Viewport"
Cohesion: 0.17
Nodes (11): maxMmPerPx, minMmPerPx, mmPerPx, panByScreenDelta, panByWorldDelta, PlanViewport, resetView, screenToWorld (+3 more)

### Community 25 - "Unit Converter"
Cohesion: 0.18
Nodes (10): cmPerM, formatArea, formatDistance, _formatImperial, _formatMetric, mmPerCm, mmPerFoot, mmPerInch (+2 more)

### Community 26 - "Room Geometry Model"
Cohesion: 0.20
Nodes (9): bool get, fromJsonString, isValid, name, Room, toJsonString, vertices, dart:convert (+1 more)

### Community 27 - "Drift Table Row Classes"
Cohesion: 0.33
Nodes (9): DataClass, Insertable, UpdateCompanion, Folder, FoldersCompanion, Project, ProjectsCompanion, RoomData (+1 more)

### Community 28 - "Drift Table Definitions"
Cohesion: 0.40
Nodes (5): @DataClassName, Folders, Projects, Rooms, Table

### Community 29 - "Navigation Routes"
Cohesion: 0.50
Nodes (4): MaterialPageRoute, _openCarpetProducts, _createNewProject, _openProject

### Community 30 - "AppDatabase Entry Point"
Cohesion: 0.67
Nodes (3): _, @DriftDatabase, AppDatabase

### Community 31 - "Custom Painters"
Cohesion: 0.67
Nodes (3): CustomPainter, PlanPainter, _RoomShapePainter

## Knowledge Gaps
- **1279 isolated node(s):** `build`, `null`, `readBackgroundImageBytes`, `writeBackgroundImageBytes`, `ensureBackgroundImageDir` (+1274 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppDatabase` connect `AppDatabase Entry Point` to `Plan Canvas Widget`, `Drift Database Schema`, `Project Service`, `Projects Screen`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `StripSplitStrategy` connect `Carpet Layout Options` to `Plan Canvas Widget`, `Roll Cut Sheet Screen`, `Plan Canvas Painter`, `Carpet Cut List Panel`, `Project Model`, `Editor Controller`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `CarpetPlanningSettings` connect `Carpet Layout Options` to `Plan Canvas Widget`, `Roll Cut Sheet Screen`, `Plan Canvas Painter`, `Carpet Cut List Panel`, `Editor Controller`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `build`, `null`, `readBackgroundImageBytes` to the rest of the system?**
  _1279 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Plan Canvas Widget` be split into smaller, more focused modules?**
  _Cohesion score 0.005571030640668524 - nodes in this community are weakly interconnected._
- **Should `Drift Database Schema` be split into smaller, more focused modules?**
  _Cohesion score 0.018018018018018018 - nodes in this community are weakly interconnected._
- **Should `Roll Cut Sheet Screen` be split into smaller, more focused modules?**
  _Cohesion score 0.02040816326530612 - nodes in this community are weakly interconnected._