import 'package:flutter_test/flutter_test.dart';

import 'package:degrid/core/export/cut_sheet_entries.dart';
import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/models/project.dart';
import 'package:degrid/core/roll_planning/carpet_layout_options.dart';
import 'package:degrid/core/roll_planning/roll_plan_models.dart';

void main() {
  CarpetProduct product({double? rollLengthM}) => CarpetProduct(
        name: 'Twist',
        rollWidthMm: 3600,
        rollLengthM: rollLengthM,
      );

  RollCutPiece cut(String id, double lengthMm, double breadthMm) =>
      RollCutPiece(
        cutId: id,
        roomIndex: 0,
        roomName: 'Lounge',
        rollLaneIndex: 0,
        product: product(),
        stripIndex: 0,
        lengthMm: lengthMm,
        trimMm: 75,
        breadthMm: breadthMm,
        isSliver: false,
      );

  RollPlanState state(
    List<RollCutPiece> cuts,
    Map<String, Offset> placements,
  ) =>
      RollPlanState(
        allCuts: cuts,
        lanes: [
          RollLaneData(
            rollIndex: 0,
            product: product(),
            totalLinearMm:
                cuts.fold<double>(0, (s, c) => s + c.lengthMm),
          ),
        ],
        placements: placements,
      );

  group('usedRollLengthMm', () {
    test('nested cuts consume the roll once', () {
      final cuts = [cut('A1', 5000, 3600), cut('B1', 4000, 1500)];
      // B1 nested beside A1 (fits neither... breadths 3600+1500 > 3600, so
      // place B1 after A1): used = 9000. If B1 were nested at same along
      // range, used would be 5000.
      final sequential = state(cuts, {
        'A1': const Offset(0, 0),
        'B1': const Offset(5000, 0),
      });
      expect(sequential.usedRollLengthMm(0), 9000);

      final narrowCuts = [cut('A1', 5000, 2000), cut('B1', 4000, 1500)];
      final nested = state(narrowCuts, {
        'A1': const Offset(0, 0),
        'B1': const Offset(0, 2000),
      });
      expect(nested.usedRollLengthMm(0), 5000);
    });
  });

  group('sideOffcuts', () {
    test('reports the free strip beside narrow cuts', () {
      final cuts = [cut('A1', 5000, 2000)];
      final s = state(cuts, {'A1': const Offset(0, 0)});
      final sides = s.sideOffcuts();
      expect(sides, hasLength(1));
      expect(sides.single.lengthMm, 5000);
      expect(sides.single.breadthMm, closeTo(1600, 0.001));
      expect(sides.single.startAlongMm, 0);
    });

    test('full-width cuts leave no side offcut', () {
      final cuts = [cut('A1', 5000, 3600)];
      final s = state(cuts, {'A1': const Offset(0, 0)});
      expect(s.sideOffcuts(), isEmpty);
    });

    test('clusters overlapping cuts and uses the max occupied breadth', () {
      final cuts = [cut('A1', 5000, 2000), cut('A2', 3000, 3000)];
      // A2 overlaps A1's along range, occupying more breadth.
      final s = state(cuts, {
        'A1': const Offset(0, 0),
        'A2': const Offset(4000, 0),
      });
      final sides = s.sideOffcuts();
      expect(sides, hasLength(1));
      expect(sides.single.breadthMm, closeTo(600, 0.001));
      expect(sides.single.lengthMm, closeTo(7000, 0.001));
    });
  });

  group('planning settings JSON round-trip', () {
    test('all fields survive toJson/fromJson', () {
      const settings = CarpetPlanningSettings(
        wasteAllowancePercent: 7.5,
        seamPenaltyMmNoDoors: 111,
        seamPenaltyMmWithDoors: 222,
        seamPenaltyMmInDoorway: 333,
        doorwayExtensionMm: 45,
        seamWidthAllowanceMm: 40,
        sliverPenaltyPerStripMm: 444,
        stripSplitStrategy: StripSplitStrategy.preferStripInPieces,
      );
      final restored =
          CarpetPlanningSettings.fromJson(settings.toJson());
      expect(restored, settings);
    });

    test('missing keys fall back to defaults', () {
      final restored = CarpetPlanningSettings.fromJson(const {
        'wasteAllowancePercent': 10.0,
      });
      expect(restored.wasteAllowancePercent, 10.0);
      expect(restored.doorwayExtensionMm,
          const CarpetPlanningSettings().doorwayExtensionMm);
    });
  });

  group('buildPdfCutSheetEntries', () {
    test('produces one row per cut piece with matching IDs', () {
      final projectModel = ProjectModel(
        name: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: [
          Room(
            name: 'Lounge',
            vertices: const [
              Offset(0, 0),
              Offset(5000, 0),
              Offset(5000, 4000),
              Offset(0, 4000),
            ],
          ),
        ],
        carpetProducts: [product()],
        roomCarpetAssignments: const {0: 0},
        carpetPlanningSettings: const CarpetPlanningSettings(
          doorwayExtensionMm: 0,
        ),
      );
      final entries = buildPdfCutSheetEntries(projectModel);
      // 5000x4000 room, 3600 roll -> 2 strips; auto direction picks the
      // cheaper 90 deg lay (two 4000+150 cuts instead of two 5000+150).
      expect(entries, hasLength(2));
      expect(entries[0].cutId, 'A1');
      expect(entries[1].cutId, 'A2');
      expect(entries[0].roomName, 'Lounge');
      expect(entries[0].lengthMm, closeTo(4150, 0.5));
    });

    test('narrow cuts report an estimated side offcut', () {
      final projectModel = ProjectModel(
        name: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: [
          Room(
            name: 'Hall',
            vertices: const [
              Offset(0, 0),
              Offset(5000, 0),
              Offset(5000, 4000),
              Offset(0, 4000),
            ],
          ),
        ],
        carpetProducts: [product()],
        roomCarpetAssignments: const {0: 0},
        carpetPlanningSettings: const CarpetPlanningSettings(
          doorwayExtensionMm: 0,
        ),
      );
      final data = buildPdfCutSheetData(projectModel);
      // 90 deg lay: strips 3600 + 1400 wide; the 1400 strip leaves a
      // 2200mm-wide side offcut, the full-width strip leaves none.
      expect(data.offcuts, hasLength(1));
      expect(data.offcuts.single.breadthMm, closeTo(2200, 0.5));
      expect(data.offcuts.single.fromCutId, 'A2');
    });

    test('empty when no carpet assignments', () {
      final projectModel = ProjectModel(
        name: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: const [],
      );
      expect(buildPdfCutSheetEntries(projectModel), isEmpty);
    });
  });
}
