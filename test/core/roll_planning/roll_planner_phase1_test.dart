import 'dart:ui';

import 'package:degrid/core/geometry/opening.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/roll_planning/carpet_layout_options.dart';
import 'package:degrid/core/roll_planning/roll_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RollPlanner Phase 1 — doorway seam penalty', () {
    /// Rectangle 5000×4000 mm. Lay along X → strips horizontal, perp = Y, reference = top (minY=0).
    /// Roll 2000 mm → one seam at 2000 mm from top (horizontal line y=2000).
    Room defaultRoom() => Room(
          vertices: [
            const Offset(0, 0),
            const Offset(5000, 0),
            const Offset(5000, 4000),
            const Offset(0, 4000),
          ],
        );

    test('no openings: seam penalty uses seamPenaltyMmNoDoors', () {
      final room = defaultRoom();
      const rollWidthMm = 2000.0;
      final opts = CarpetLayoutOptions(
        roomIndex: 0,
        openings: const [],
        seamPenaltyMmNoDoors: 100,
        seamPenaltyMmWithDoors: 200,
        seamPenaltyMmInDoorway: 500,
      );
      final layout = RollPlanner.computeLayout(room, rollWidthMm, opts);
      expect(layout.numStrips, 2);
      expect(layout.seamCount, 1);
      // One seam, no doors → 1 * 100
      expect(layout.scoreSeamPenaltyMm, 100);
    });

    test('door on left wall crossing seam: seam penalty uses seamPenaltyMmInDoorway', () {
      // Left wall = edge 3: (0,4000)→(0,0). Door from 1900–2100 mm along edge → segment y 2100–1900. Seam at y=2000 crosses it.
      // Force 0° and pin seam at 2000 mm so it crosses the door (otherwise optimizer moves seam away).
      final room = defaultRoom();
      const rollWidthMm = 2000.0;
      final opts = CarpetLayoutOptions(
        roomIndex: 0,
        layDirectionDeg: 0,
        seamPositionsOverrideMm: [2000],
        openings: [
          Opening(roomIndex: 0, edgeIndex: 3, offsetMm: 1900, widthMm: 200, isDoor: true),
        ],
        seamPenaltyMmNoDoors: 100,
        seamPenaltyMmWithDoors: 200,
        seamPenaltyMmInDoorway: 500,
      );
      final layout = RollPlanner.computeLayout(room, rollWidthMm, opts);
      expect(layout.numStrips, 2);
      expect(layout.seamCount, 1);
      // One seam crossing doorway → 500
      expect(layout.scoreSeamPenaltyMm, 500);
    });

    test('door on top wall not crossing seam: seam penalty uses seamPenaltyMmWithDoors', () {
      // Top edge = edge 0: (0,0)→(5000,0). Door at 0–900 mm along edge (y=0). Seam at y=2000 does not cross.
      final room = defaultRoom();
      const rollWidthMm = 2000.0;
      final opts = CarpetLayoutOptions(
        roomIndex: 0,
        openings: [
          Opening(roomIndex: 0, edgeIndex: 0, offsetMm: 0, widthMm: 900, isDoor: true),
        ],
        seamPenaltyMmNoDoors: 100,
        seamPenaltyMmWithDoors: 200,
        seamPenaltyMmInDoorway: 500,
      );
      final layout = RollPlanner.computeLayout(room, rollWidthMm, opts);
      expect(layout.numStrips, 2);
      expect(layout.seamCount, 1);
      // One seam, room has doors but seam does not cross → 200
      expect(layout.scoreSeamPenaltyMm, 200);
    });

    test('two seams: one crosses doorway, one does not', () {
      // Room 5000×6000, 3 strips with seams at 2000 and 4000. Door on left wall spanning y 3900–4100.
      // Pin seams at 2000 and 4000 so one crosses the door (4000), one does not (2000).
      final r = Room(
        vertices: const [
          Offset(0, 0),
          Offset(5000, 0),
          Offset(5000, 6000),
          Offset(0, 6000),
        ],
      );
      const rollWidthMm = 2000.0;
      final opts = CarpetLayoutOptions(
        roomIndex: 0,
        layDirectionDeg: 0,
        seamPositionsOverrideMm: [2000, 4000],
        openings: [
          Opening(roomIndex: 0, edgeIndex: 3, offsetMm: 1900, widthMm: 200, isDoor: true), // y 4100–3900
        ],
        seamPenaltyMmNoDoors: 100,
        seamPenaltyMmWithDoors: 200,
        seamPenaltyMmInDoorway: 500,
      );
      final layout = RollPlanner.computeLayout(r, rollWidthMm, opts);
      expect(layout.numStrips, 3);
      expect(layout.seamCount, 2);
      // Seam at 2000: does not cross. Seam at 4000: crosses. So 200 + 500 = 700
      expect(layout.scoreSeamPenaltyMm, 700);
    });

    test('opening with isDoor false does not use doorway penalty', () {
      // Room has only non-door openings → hasDoors is false, so seam penalty uses NoDoors (100).
      final room = defaultRoom();
      const rollWidthMm = 2000.0;
      final opts = CarpetLayoutOptions(
        roomIndex: 0,
        openings: [
          Opening(roomIndex: 0, edgeIndex: 3, offsetMm: 1900, widthMm: 200, isDoor: false),
        ],
        seamPenaltyMmNoDoors: 100,
        seamPenaltyMmWithDoors: 200,
        seamPenaltyMmInDoorway: 500,
      );
      final layout = RollPlanner.computeLayout(room, rollWidthMm, opts);
      expect(layout.seamCount, 1);
      expect(layout.scoreSeamPenaltyMm, 100);
    });
  });
}
