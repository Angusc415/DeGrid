# Carpet Roll Planning — MVP Implementation Plan (Phases)

**Reference code:** `roll_planner.dart`, `carpet_layout_options.dart`, `carpet_product.dart`, `carpet_roll_cut_sheet.dart`, `carpet_cut_list_panel.dart`

**MVP scope:**
- Rectangular + L-shaped rooms, 0° / 90° lay direction
- Standard seam joins by default; **T-joins and cross joins as an option during measure-up** (user allows or disallows)
- Material + seam count scoring (**no aesthetic score** — appearance left to the user)
- Roll plan with simple offcut tracking, manual drag of cuts on roll

---

## Phase 1 — Scoring and layout options

**Goal:** Expose why a layout was chosen (material + seams) and keep options in one place.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 1.1 | Expose layout score components | From `RollPlanner` / `_computeForDirection` (and single-piece path), expose: `totalLinearMm`, `seamCount`, `seamPenaltyMm`, `sliverPenaltyMm`, `cost`. Add to `StripLayout` or a small `LayoutScore` type. | `roll_planner.dart` |
| 1.2 | Document / use penalty weights | Ensure `CarpetLayoutOptions` is the single source for seam/sliver penalties; document. Optionally allow product-level overrides. | `carpet_layout_options.dart`, `carpet_product.dart` |

**Outcome:** UI can show “Total linear”, “Seams”, “Cost (material + seams)” and options are consistent.

---

## Phase 2 — Cut list and roll sheet alignment

**Goal:** Cut list and roll cut sheet use the same layout and options; totals and counts match.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 2.1 | Single source for layout options | Audit and align how `CarpetLayoutOptions` is built in cut list vs roll sheet (openings, roomIndex, seam overrides, product trim/pattern/min strip). Same defaults, same inputs. | `carpet_cut_list_panel.dart`, `carpet_roll_cut_sheet.dart` |
| 2.2 | Show score and waste in UI | In cut list card: show total linear, seam count, waste % (if defined). In roll sheet summary bar: same metrics. Use exposed score from Phase 1. | `carpet_cut_list_panel.dart` (_RoomCutListCard), `carpet_roll_cut_sheet.dart` (_SummaryBar) |

**Outcome:** Estimator sees the same numbers in cut list and roll view; no conflicting totals.

---

## Phase 3 — Simple offcut tracking

**Goal:** After placing cuts on the roll, show what’s left (remaining length / offcuts).

| # | Task | What to do | Where |
|---|------|------------|--------|
| 3.1 | Define offcut / remainder | Introduce a type (e.g. `Offcut` or “tail” per lane): e.g. lengthMm, breadthMm, startAlongMm. Compute from 2D placements: sort cuts by position, then tail after last cut (and optionally gaps) = remaining pieces. | New type in `carpet_roll_cut_sheet.dart` or `lib/core/roll_planning/` |
| 3.2 | Compute and show offcuts | From `RollPlanState` (placements + lanes + cut dimensions), compute offcuts. In roll sheet UI, add “Offcuts” or “Remaining” section listing length (and breadth). | `carpet_roll_cut_sheet.dart` |
| 3.3 | (Optional) Export offcuts in CSV | Add offcuts to existing CSV export (e.g. “Offcut, Lane 0, 1200 mm × 3660 mm”). | `carpet_roll_cut_sheet.dart` or `carpet_cut_list_panel.dart` |

**Outcome:** Estimator sees remaining roll/offcuts after placing cuts; optional CSV for ordering.

---

## Phase 4 — T-joins and cross joins (measure-up option)

**Goal:** User can allow or disallow T-joins and cross joins **during measure-up** (not a future feature).

| # | Task | What to do | Where |
|---|------|------------|--------|
| 4.1 | Add options for join types | Add to options: e.g. `allowTJoins`, `allowCrossJoins` (or single “Allow non-standard joins”). Pass into `CarpetLayoutOptions`. | `carpet_layout_options.dart` |
| 4.2 | UI for allow/disallow | Add control where layout/room options are set (cut list, toolbar, or room/product settings): toggle or checkbox “Allow T-joins” / “Allow cross joins”. | Same UI that builds layout options |
| 4.3 | Planner respects option | When enabled: planner may generate layouts that use T-joins or cross joins where they save material or fit the shape. When disabled: current behaviour (standard parallel-breadth seams only). | `roll_planner.dart` |

**Outcome:** Estimator can turn T-joins and cross joins on or off while doing the job.

---

## Phase 5 — Installer overrides and live metrics

**Goal:** Estimator can override layout; metrics update as they change things.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 5.1 | Lay direction override in UI | Ensure estimator can set “Lay: Auto / 0° / 90°” per room (or product). Pass `layDirectionDeg` into `CarpetLayoutOptions`. Add control if missing. | Cut list panel, roll sheet, or shared layout/room UI |
| 5.2 | Seam override consistency | Verify seam overrides (and “Reset to auto”) are used in both cut list and roll sheet so moving seams on the plan updates the roll view. | Audit only; fix if any path ignores overrides |
| 5.3 | Live waste and seam count | When user changes seams or lay direction, waste % and seam count update immediately in both cut list and roll sheet. Use same layout and waste definition. | `carpet_cut_list_panel.dart`, `carpet_roll_cut_sheet.dart` |

**Outcome:** Full override control; live feedback on waste and seams.

---

## Phase 6 — Documentation and tests

**Goal:** MVP behaviour is documented; critical logic is tested.

| # | Task | What to do | Where |
|---|------|------------|--------|
| 6.1 | Document MVP behaviour | Short “Carpet planning (MVP)” section: in scope (rect + L, 0°/90°, standard seams + T/cross as option, material+seam scoring, roll plan, offcuts, manual drag); appearance left to user (no aesthetic score). | App or developer docs |
| 6.2 | (Optional) Unit tests | Tests for `RollPlanner.computeLayout` (e.g. rect room strip count/cost; L-room multiple strips). Tests for offcut computation from placements. | `test/` |

**Outcome:** Clear scope and regression safety for scoring and offcuts.

---

## Suggested order of work

1. **Phase 1** — Scoring (1.1, 1.2) so UI can show cost and components.
2. **Phase 2** — Alignment (2.1, 2.2) so cut list and roll sheet match and show score/waste.
3. **Phase 3** — Offcuts (3.1, 3.2; 3.3 optional).
4. **Phase 4** — T-joins / cross joins option (4.1, 4.2, 4.3).
5. **Phase 5** — Overrides and live metrics (5.1, 5.2, 5.3).
6. **Phase 6** — Docs and tests (6.1, 6.2 optional).

---

## File checklist (MVP)

| File | Phases / changes |
|------|-------------------|
| `lib/core/roll_planning/roll_planner.dart` | 1.1 (score), 4.3 (T/cross when enabled) |
| `lib/core/roll_planning/carpet_layout_options.dart` | 1.2, 4.1 |
| `lib/core/geometry/carpet_product.dart` | 1.2 if product overrides |
| `lib/ui/screens/carpet_roll_cut_sheet.dart` | 2.1, 2.2, 3.1, 3.2, 3.3, 5.x |
| `lib/ui/screens/carpet_cut_list_panel.dart` | 2.1, 2.2, 4.2, 5.1, 5.3 |
| Docs | 6.1 |
| Tests | 6.2 |

---

## Out of scope for MVP

- **Aesthetic score** — Not implemented; appearance is left to the user.
- Multiple layout options per room (e.g. Recommended / Cheapest).
- Doorway/traffic-specific seam penalties (beyond “has doors”).
- Offcut reuse across rooms and job-level optimization.
- Configurable company weights UI (fixed weights enough for MVP).
- Seam type metadata (seam vs cross vs T) is in scope when Phase 4 is implemented.

**T-joins and cross joins** are in scope as a **measure-up option** (Phase 4); the user allows or disallows them during the job.
