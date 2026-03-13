# Implementation Plan: Drag Seam to Reposition (MeasureSquare-style)

## Can it be done? **Yes.**

The app **already supports** dragging a carpet seam and having cuts update automatically. The missing piece for “like MeasureSquare” is that **seam drag only starts on web** and only when **pan mode** is on. Below is what exists, what’s missing, and a concrete implementation plan.

---

## Current behavior (what already works)

1. **Data model**
   - **Seam overrides**: `_roomCarpetSeamOverrides` (plan_canvas) stores per-room lists of seam positions in mm from the reference edge (top or left, depending on strip direction).
   - **RollPlanner** uses `CarpetLayoutOptions.seamPositionsOverrideMm` when set; it uses these positions as strip boundaries and recomputes strip lengths. So **moving a seam → updating overrides → layout/cuts update** is already implemented.

2. **Hit-test**
   - `_findSeamAtScreenPosition(screenPos)` returns `(roomIndex, seamIndex)` for the seam line nearest the point (within ~14px), or `null`. Works for all rooms that have carpet and at least 2 strips.

3. **Drag flow (web only today)**
   - **Start**: On **web**, in **pan mode**, on pointer down with **left button** (`e.buttons == 1`), if the pointer hits a seam:
     - Current seam positions are copied into `_roomCarpetSeamOverrides` for that room (if not already there).
     - `_draggingSeamRoomIndex` and `_draggingSeamIndex` are set.
   - **Move**: On pointer move, if a seam is being dragged:
     - New position is computed from pointer world position (perpendicular to strip direction).
     - Clamped between previous and next seam (min gap 50 mm) and between room bounds.
     - `_roomCarpetSeamOverrides[roomIndex][seamIndex]` is updated; `setState` runs so canvas, cut list, and roll sheet all rebuild with new cuts.
   - **End**: On pointer up, `_draggingSeamRoomIndex` and `_draggingSeamIndex` are cleared.

4. **Persistence**
   - Seam overrides are saved in the project (`roomCarpetSeamOverridesJson`) and restored on load.

So: **drag seam → overrides update → cuts change** is already implemented and works on web when in pan mode.

---

## Gaps (why it may not feel “like MeasureSquare”)

| Gap | Description |
|-----|-------------|
| **1. Web-only start** | Seam drag **start** is gated by `kIsWeb && e.buttons == 1`. On desktop (macOS/Windows) and mobile, pointer down on a seam does not start a drag, so the feature appears missing. |
| **2. Pan mode required** | User must be in “pan” mode (not “draw”). If the default or common mode is draw, users never discover seam drag. |
| **3. No visual affordance** | No cursor change over seams, no “drag to move seam” hint, and hit area is a fixed ~14px. Works but is easy to miss. |
| **4. Touch on mobile** | On web, touch often sends `e.buttons == 0`; the current check excludes that, so touch-to-drag may not start on some devices. |

---

## Implementation plan

### Phase 1: Enable seam drag on all platforms (minimal change)

**Goal:** Seam drag works on desktop and web (and, where pointer events are delivered, on mobile) without requiring web.

1. **Start drag on any platform when a seam is hit (pan mode, no draft)**
   - **File:** `lib/ui/canvas/plan_canvas.dart`
   - **Where:** `Listener.onPointerDown`, block that currently does “Seam drag: in pan mode, check for seam hit”.
   - **Change:** Remove the `kIsWeb` requirement and allow `e.buttons == 1 || e.buttons == 0` so both mouse (left button) and touch (buttons 0) can start the drag.
   - **Logic:** Keep: `_isPanMode && _draftRoomVertices == null`, hit = `_findSeamAtScreenPosition(e.localPosition)`, then same setState that copies seam positions into overrides and sets `_draggingSeamRoomIndex` / `_draggingSeamIndex`.

2. **Ensure pointer move/up still run on non-web**
   - The existing `onPointerMove` and `onPointerUp` handlers already handle seam drag without checking `kIsWeb`; they only check `_draggingSeamRoomIndex != null`. No change needed unless your stack swallows pointer events on non-web (then ensure the same Listener receives move/up).

3. **Non-web gesture conflict (scale gesture)**
   - On non-web, `GestureDetector.onScaleStart` runs for the same pointer. If the scale recognizer wins, it might prevent the Listener from seeing move/up, or the scale might start a pan. Options:
     - **A)** When a seam is hit on pointer down, set a flag (e.g. `_seamDragPointerId = e.pointer`) and in `onScaleStart` / `onScaleUpdate`, if that pointer is the focal point and we have `_draggingSeamRoomIndex != null`, don’t perform pan/zoom and let the Listener drive seam drag (may require passing pointer id through or checking that the active pointer is the one we captured).
     - **B)** Or start seam drag from `onScaleStart` on non-web when in pan mode and `_findSeamAtScreenPosition(details.localFocalPoint) != null`, and do the move in `onScaleUpdate` and end in `onScaleEnd` (same clamp/update logic as today, but using scale gesture coordinates). Then seam drag is consistent across web (Listener) and non-web (GestureDetector).

   **Recommendation:** Prefer **B** for non-web: in `onScaleStart`, if `details.pointerCount == 1` and `_isPanMode` and `_draftRoomVertices == null` and `_findSeamAtScreenPosition(details.localFocalPoint) != null`, start seam drag (copy to overrides, set `_draggingSeamRoomIndex`/`_draggingSeamIndex`). In `onScaleUpdate`, if `_draggingSeamRoomIndex != null`, apply the same position/clamp/update logic using `details.localFocalPoint` and return without panning. In `onScaleEnd`, clear the drag state. That way one code path (Listener) handles web, another (GestureDetector) handles non-web, both calling the same “update seam position” logic.

**Deliverable:** User can drag a seam on web (mouse/touch) and on desktop/mobile (touch or mouse) when in pan mode; cuts and roll sheet update as they drag.

---

### Phase 2: Discoverability and UX (optional)

1. **Cursor**
   - When hovering over a seam (and in pan mode), set cursor to a resize or move cursor (e.g. `SystemMouseCursors.resizeUpDown` or `resizeLeftRight` depending on strip direction). Use `_findSeamAtScreenPosition` in the same hover path that already updates `_hoveredVertex` (e.g. in `onPointerMove` when `e.buttons == 0`). Set a `_hoveredSeam` (roomIndex, seamIndex) or reuse hover state; in `build`, wrap the canvas in `MouseRegion` and set `cursor: _hoveredSeam != null ? ... : SystemMouseCursors.basic`.

2. **Hit area**
   - Increase hit slop in `_findSeamAtScreenPosition` from 14px to ~20–24px so seams are easier to grab (optional; 14px may be enough).

3. **Tooltip / hint**
   - When a room has carpet and multiple strips, show a short tooltip or hint the first time: “Drag seam lines to reposition; cuts update automatically.” (Could be a one-time hint or a small “?” near the room actions.)

4. **Visual feedback while dragging**
   - You already have `_draggingSeamRoomIndex` / `_draggingSeamIndex`; the painter can draw the active seam in a different color/weight if desired (optional).

---

### Phase 3: Edge cases and polish (optional)

1. **Min strip width**
   - RollPlanner uses `_minStripWidthForOverrideMm` (e.g. 50 mm) when validating overrides. Ensure the UI clamp (prev + 50, next - 50) matches so the planner never receives invalid positions.

2. **Reset seams**
   - “Reset seams to auto” already exists (cut list panel / room actions). Ensure it clears `_roomCarpetSeamOverrides` for that room and that roll sheet and canvas both refresh.

3. **Undo/redo**
   - If the app has undo/redo, consider including seam override changes in history so “drag seam” is undoable (may require adding seam overrides to the history state snapshot if not already there).

---

## Summary

| Item | Status / Action |
|------|-----------------|
| Can drag-seam be done? | **Yes.** Core is already there: overrides → RollPlanner → cuts update. |
| Why it might seem broken | Seam drag **start** is web-only and requires pan mode. |
| Phase 1 | Enable seam drag on all platforms: allow non-web + touch (buttons 0) in Listener **and** implement seam-drag start/move/end in scale gesture on non-web so one path doesn’t steal the pointer. |
| Phase 2 | Cursor over seam, optional larger hit area, tooltip/hint. |
| Phase 3 | Clamp/validation alignment, “reset seams” behavior, undo/redo for overrides. |

Implementing **Phase 1** is enough for “drag a seam and have cuts update automatically” to work everywhere; Phases 2–3 make it easier to find and use.
