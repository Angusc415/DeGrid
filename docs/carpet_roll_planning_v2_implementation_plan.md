# Carpet Roll Planning — V2 Implementation Plan (MVP → V2)

**Prerequisites:** MVP complete (Phases 1–6 of [carpet_roll_planning_mvp_implementation_plan.md](carpet_roll_planning_mvp_implementation_plan.md)).

**Reference code:** `roll_planner.dart`, `carpet_layout_options.dart`, `opening.dart`, `carpet_roll_cut_sheet.dart`, `carpet_cut_list_panel.dart`, `plan_canvas.dart`

**V2 scope:**
- Doorway/traffic-aware seam penalties (seams crossing doors penalised more)
- Multiple layout options per room (e.g. Balanced / Cheapest / Fewest seams) with user choice
- Offcut reuse across rooms (use offcut from Room A for Room B when dimensions and product match)
- Pattern repeat applied consistently; seam type metadata (standard / T / cross) for display and export
- Optional: configurable penalty weights (project or company level)

**Out of scope for V2:**
- Full job-level global optimization (V3)
- Aesthetic score (appearance left to user)
- Cross-room “recommended vs cheapest vs best look” comparison at job level (V3)

---

## Phase 1 — Doorway and traffic-aware seam penalties

**Goal:** Seams that cross doorways (or high-traffic openings) get a higher penalty than seams elsewhere; optional “traffic zone” concept.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 1.1 | Per-seam penalty by opening type | Instead of one “room has doors” flag, compute penalty per seam: if seam line intersects a doorway opening, use a dedicated penalty (e.g. `seamPenaltyMmInDoorway`); else use `seamPenaltyMmNoDoors` / `seamPenaltyMmWithDoors` as today. | `carpet_layout_options.dart` (new field), `roll_planner.dart` (`_seamPenalty` → per-seam or pass opening geometry) |
| 1.2 | Seam–opening intersection | Add helper: given room polygon, lay direction, and seam position (perpendicular offset), determine if that seam line crosses any opening (use opening edge geometry + optional buffer). If it crosses an opening with `isDoor == true`, apply doorway penalty. | `roll_planner.dart` or `lib/core/roll_planning/` (e.g. `seam_penalty.dart`) |
| 1.3 | Options and UI | Add `seamPenaltyMmInDoorway` (default higher than `seamPenaltyMmWithDoors`). Optionally: “Traffic zone” as a region or list of openings that count as high-traffic; same penalty. Document in options. | `carpet_layout_options.dart`, `CarpetLayoutOptions.forRoom`, UI where options are built |

**Outcome:** Planner prefers layouts that avoid seams through doorways; estimator can tune doorway penalty.

---

## Phase 2 — Multiple layout options per room

**Goal:** For each room, generate 2–3 candidate layouts (e.g. auto/balanced, minimise cost, minimise seams); user picks one per room.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 2.1 | Generate candidate layouts | In planner, add e.g. `computeLayoutCandidates(room, rollWidthMm, options)` returning `List<StripLayout>`: e.g. [auto, force 0°, force 90°] or [balanced, minMaterial, minSeams]. Reuse existing `computeLayout` with different option overrides (lay direction, seam offset). | `roll_planner.dart` |
| 2.2 | Store selected option per room | Add state: e.g. `roomLayoutVariantIndex` or `roomLayoutChoice` map (roomIndex → index into candidates). Default 0 (first/balanced). Persist or in-memory for session. | App state / project model; passed into cut list and roll sheet |
| 2.3 | UI to choose layout | In cut list card or room/layout settings: dropdown or chips “Balanced / Cheapest / Fewest seams” (or “Option 1, 2, 3”) per room. Rebuild layout from selected candidate; cut list and roll sheet use same choice. | `carpet_cut_list_panel.dart`, and wherever layout options are built |

**Outcome:** Estimator can compare and lock in a preferred layout per room without losing other options.

---

## Phase 3 — Offcut reuse across rooms

**Goal:** When building the roll plan, consider existing offcuts as sources for cuts; assign a cut “from offcut” when dimensions and product match.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 3.1 | Offcut as reusable piece | Extend `RollOffcut` (or add `ReusableOffcut`) with: product id or match key, pile direction, dimensions. When placing cuts, maintain “pool” of offcuts (from previous placements or from same roll). | `carpet_roll_cut_sheet.dart` or `lib/core/roll_planning/offcut.dart` |
| 3.2 | Match and assign | For each room’s cut list, check if any offcut in the pool fits (length ≥ cut length + trim, breadth ≥ strip breadth, same product, pile direction). If yes, mark that cut as “sourced from offcut” and consume that offcut (or reduce its size). | New service or logic in roll planner / roll cut sheet state |
| 3.3 | UI and export | Show “From offcut” on cut card and in roll view when a cut is sourced from an offcut. Export: optional column “Source: roll / offcut”. | `carpet_cut_list_panel.dart`, `carpet_roll_cut_sheet.dart`, CSV export |

**Outcome:** Estimator sees when a cut can be taken from an existing offcut; material and cost reflect reuse.

---

## Phase 4 — Pattern repeat and seam type metadata

**Goal:** Pattern repeat applied everywhere; record and show seam type (standard / T / cross) for each layout.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 4.1 | Pattern repeat audit | Ensure every code path that computes cut length uses `patternRepeatMm` (round up to next repeat). Document in planner and options. Add unit test. | `roll_planner.dart`, `carpet_layout_options.dart`, tests |
| 4.2 | Seam type on layout | When Phase 4 (MVP) T/cross joins are implemented: add to `StripLayout` (or per-seam) a classification: standard seam, T-join, cross join. Populate in planner when generating layouts. | `roll_planner.dart`, `StripLayout` or new `SeamInfo` list |
| 4.3 | Display and export | Show seam type in cut list and roll sheet (e.g. “Seam 1 (T)” or “Cross join”). Export seam type in CSV. | `carpet_cut_list_panel.dart`, `carpet_roll_cut_sheet.dart` |

**Outcome:** Pattern repeat is consistent; installer sees seam type for each join; export supports reporting.

---

## Phase 5 — Configurable penalty weights (optional)

**Goal:** Allow project- or company-level overrides for seam and sliver penalties so different teams can tune “fewer seams vs less waste”.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 5.1 | Override storage | Add a layer above defaults: e.g. project settings or “company profile” holding `seamPenaltyMmNoDoors`, `seamPenaltyMmWithDoors`, `seamPenaltyMmInDoorway`, `sliverPenaltyPerStripMm`. If not set, use `CarpetLayoutOptions` defaults. | Project model or settings service; passed into `CarpetLayoutOptions.forRoom` |
| 5.2 | UI to edit weights | Settings screen or dialog: fields for each penalty (with “Reset to default”). Save to project/company. | Settings UI, plan toolbar, or room/product config |
| 5.3 | Apply in layout | When building `CarpetLayoutOptions`, merge in overrides from project/company so planner and UI use the same weights. | `CarpetLayoutOptions.forRoom`, cut list, roll sheet |

**Outcome:** Companies can tune penalties without code changes; estimator sees consistent costs.

---

## Suggested order of work (V2)

1. **Phase 1** — Doorway/traffic seam penalties (data model, planner, options).
2. **Phase 2** — Multiple layout options per room (candidates + UI choice).
3. **Phase 3** — Offcut reuse (pool, match, assign, UI).
4. **Phase 4** — Pattern repeat audit + seam type metadata (display + export).
5. **Phase 5** — Configurable weights (optional; can be deferred).

---

## File checklist (V2)

| File / area | Phases |
|-------------|--------|
| `lib/core/roll_planning/roll_planner.dart` | 1.1, 1.2, 2.1, 4.1, 4.2 |
| `lib/core/roll_planning/carpet_layout_options.dart` | 1.1, 1.3, 5.1, 5.3 |
| `lib/core/roll_planning/seam_penalty.dart` (optional) | 1.2 |
| `lib/core/roll_planning/offcut.dart` (optional) | 3.1 |
| `lib/ui/screens/carpet_roll_cut_sheet.dart` | 3.1, 3.2, 3.3, 4.3 |
| `lib/ui/screens/carpet_cut_list_panel.dart` | 2.3, 3.3, 4.3 |
| App state / project model | 2.2, 5.1 |
| Settings / config UI | 1.3, 5.2 |
| Tests | 4.1, 3.x |

---

## Dependencies

- **Phase 1** can start as soon as MVP is done (no dependency on other V2 phases).
- **Phase 2** is independent; improves UX before offcut reuse.
- **Phase 3** benefits from stable layout and roll state (MVP + Phase 2).
- **Phase 4** pattern repeat can be done early; seam type metadata depends on MVP Phase 4 (T/cross joins) being implemented.
- **Phase 5** is optional and can be done at any time after options are centralised (MVP Phase 2).

---

## Out of scope for V2 (V3)

- Full **job-level global optimization** (optimize across all rooms and rolls in one pass).
- **“Recommended / Cheapest / Best look”** at job level (compare whole-job plans).
- Aesthetic scoring (remains out of scope).
