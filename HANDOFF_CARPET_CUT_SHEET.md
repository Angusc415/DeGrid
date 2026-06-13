# Handoff: Carpet Cut Sheet Sync, Adjustable Planning, Live Seam Drag

Status snapshot for continuing this task in a fresh AI session.
Plan file: `~/.cursor/plans/carpet_cut_sheet_sync_613a90b2.plan.md` (do not edit it).

## Task summary

Degrid (Flutter floor-plan app), carpet/roll planning polish:

1. Cut sheet must update live while dragging seams on the canvas.
2. Extract shared layout helper so canvas, painter, cut sheet, cut list always match.
3. Make planning adjustable (waste %, trim, strip split strategy, seam penalties, per-room lay variant) and persist where appropriate.
4. Improve offcut/tail visibility; cut list shows pieces per strip.
5. Tests; `flutter test` + `flutter analyze` clean; minimal diffs.

## Key findings (differ from the original task brief)

- **Publishing during seam drag already existed**: `PlanCanvasState.setState` is overridden (`plan_canvas.dart` ~line 300) to call `_publishEditorControllerState` on every `setState`. The real bug was the opposite: `CarpetRollCutSheet.didUpdateWidget` compared maps by identity, and since the publisher deep-copies everything, it rebuilt the roll plan on EVERY canvas interaction (pan/zoom), wiping user roll-board placements.
- **`StripSplitStrategy.auto` could never split**: `_applyStripSplitting` copied `scoreCostMm` unchanged, so the cost-tie branch in `computeLayout` always returned the unsplit layout. Also split pieces got no trim allowance.
- **Painter omitted `stripSplitStrategy`** (canvas paint could diverge from cut sheet).
- **Cut list panel used `computeLayoutCandidates[variantIndex]`**, dropping the seam-locked lay direction for variant 0 (could show opposite direction to canvas).
- **Room vertices are mutated in place** (`plan_canvas_gestures.dart:209`), so the publisher now deep-copies rooms to make value-equality detection valid.

## Work COMPLETED (all edits already in working tree)

1. **`lib/core/roll_planning/carpet_layout_options.dart`**
   - New `CarpetPlanningSettings` class (wasteAllowancePercent + 3 seam penalties, `==`/`hashCode`/`copyWith`).
   - `forRoom()` now accepts `seamPenaltyMmNoDoors` / `seamPenaltyMmWithDoors`.
   - Updated `StripSplitStrategy` enum docs to new semantics.
2. **`lib/core/roll_planning/roll_planner.dart`**
   - `StripLayout.copyWith` added.
   - `_applyStripSplitting(layout, opts, trimAllowance, wastePercent)` rewritten:
     - `never`: unchanged; `auto`: split only when piece exceeds max piece length (hard cap from roll length or 6 m default); `preferStripInPieces`: also split runs >= 2 m into >= 2 pieces.
     - Each extra piece adds `2 * trim` material; `stripLengthsMm`, `totalLinearWithWasteMm`, `scoreMaterialMm`, `scoreCostMm` updated.
   - Both call sites in `computeLayout` simplified to `return _applyStripSplitting(...)` (old cost-tie blocks removed).
3. **`lib/core/roll_planning/room_strip_layout.dart` (NEW)** — shared helper:
   - `computeRoomStripLayout({room, roomIndex, product, openings, seamOverrides, layDirectionDeg, stripSplitStrategy, stripPieceLengthsOverride, settings})`
   - `applyStripPieceLengthsOverride(layout, override)` and `layDirectionDegFromVariant(variantIndex)`.
4. **Helper adopted everywhere** (replaced ~30-line duplicated blocks):
   - `lib/ui/canvas/plan_canvas.dart` `_computeStripLayoutForRoom` (drag/hit-test paths unchanged, they call this).
   - `lib/ui/canvas/plan_painter.dart` `_getStripLayoutForRoom`; `PlanPaintModel` gained `stripSplitStrategy` + `carpetPlanningSettings` fields; `plan_canvas.dart` passes them (gated by `kEnableCarpetFeatures`).
   - `lib/ui/screens/carpet_roll_cut_sheet.dart` `_roomsWithCarpet`.
   - `lib/ui/screens/carpet_cut_list_panel.dart` `_buildEntries` + `_exportAndCopy` (candidates kept only for variant chips, now computed with full opts).
5. **Cut sheet live-sync fix** (`carpet_roll_cut_sheet.dart`):
   - `didUpdateWidget` now uses deep value-equality (`_layoutInputsChanged` + `_roomsEquals`, `_productsEquals`, `_openingsEquals`, `_mapOfListEquals`, `_mapOfNestedListEquals`); also watches `openings`, `selectedRoomIndex`, settings.
   - `_rebuildPlanState` preserves prior placements for cuts with unchanged id+length, and preserves `selectedCutId`.
6. **State plumbing for settings**: `PlanCanvasState._carpetPlanningSettings` + `setCarpetPlanningSettings` accessor (`plan_canvas_editor_settings.dart`, also publishes it; removed redundant double-publish in `setStripSplitStrategy`); `EditorViewState.carpetPlanningSettings`; `EditorController` bind/unbind/method; `editor_screen.dart` passes `carpetPlanningSettings` + `onCarpetPlanningSettingsChanged` into `CarpetRollCutSheet`.
   - Publisher (`_publishEditorControllerState`) now deep-copies rooms (new `Room` instances + copied vertex lists).
7. **Settings UI** (cut sheet header): inline "Waste: X%" label + tune IconButton -> `_showPlanningSettingsDialog` (waste % field + Advanced ExpansionTile with 3 seam-penalty fields). Strip-split dropdown unchanged.
8. **Products screen** (`carpet_products_screen.dart`): added "Trim per cut end (mm)" field; edit dialog now preserves `patternRepeatMm`/`minStripWidthMm` (previously dropped on edit — latent bug fixed).
9. **Cut list panel**: table now one row per PIECE (labels `1-1`, `1-2` matching roll board/CSV), "N strips · M pieces" header line, "Exceeds roll" warning when piece > roll length (relevant for strategy `never`).
10. **Offcuts** (`_OffcutsSection`): renamed to "Roll tail:", shows available tail size + "N cut(s) reusable from tail (planning hint)"; greedy assignment documented in `_rebuildPlanState` comment.
11. **`lib/core/database/database.dart`**: schemaVersion 12 -> 13; new `Projects` columns: `carpetWasteAllowancePercent` (real, default 5), `stripSplitStrategy` (int, default 0), `roomCarpetSeamLayDirectionDegJson`, `roomCarpetLayoutVariantIndexJson`, `roomCarpetStripPieceLengthsJson` (text, nullable); migration `if (from < 13)` uses existing `_addColumnIfNotExists`.
12. `lib/core/config/feature_flags.dart`: `kEnableCarpetFeatures = true` (DEV ONLY — flip back to `false` before finishing).

Last verified checkpoint: `flutter analyze` clean (1 pre-existing info in `test/opening_geometry_test.dart`, not ours) and `flutter test` all passing — BEFORE the database.dart column additions.

## STATUS: ALL WORK COMPLETE (2026-06-10)

The previously listed blocker and remaining work are done:

1. **Codegen**: `database.g.dart` regenerated (schema v13 columns compile).
2. **`lib/core/models/project.dart`**: `ProjectModel` gained `carpetWasteAllowancePercent`, `stripSplitStrategy`, `roomCarpetSeamLayDirectionDeg`, `roomCarpetLayoutVariantIndex`, `roomCarpetStripPieceLengthsOverrideMm` (+ `copyWith`).
3. **`lib/core/services/project_service.dart`**: `getProject` parses the 3 new JSON columns + waste/strategy (strategy index clamped on read); `updateProject`/`saveProject` accept and write all new fields.
4. **`lib/ui/canvas/plan_canvas_persistence.dart`**: `_loadProject` restores lay-direction locks, variants, piece overrides, strategy and waste % (seam penalties remain session-only); `_saveProject` persists them all.
5. **`plan_canvas_room_management.dart`**: room delete now reindexes `_roomCarpetLayoutVariantIndex` and `_roomCarpetStripPieceLengthsOverrideMm` alongside seam overrides.
6. **`plan_canvas.dart`**: `clearSeamOverridesForRoom` and `setRoomLayoutVariant` also drop the room's piece-length override.
7. **Tests**: `test/core/roll_planning/room_strip_layout_test.dart` added (22 tests: helper parity with direct planner calls, seam/piece overrides, override staleness, waste %, all three split strategies, trim-per-piece accounting, max-piece-length caps).
8. **Final state**: `flutter test` 35/35 passing; `flutter analyze` clean (only pre-existing info in `test/opening_geometry_test.dart`); `kEnableCarpetFeatures` reset to `false`. Nothing committed (working tree also contains unrelated pre-existing changes).

## Acceptance criteria (from original task)

- Drag a seam on canvas -> cut list + roll board update while dragging.
- Drag along-run seam to merge pieces -> cut list piece lengths match canvas dashed seams.
- Changing waste %, trim, or strip split strategy updates canvas + cut sheet without restart.
- `flutter test` passes; no new analyzer issues; minimal diffs; flag-gated UI.
