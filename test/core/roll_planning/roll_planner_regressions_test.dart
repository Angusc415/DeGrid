import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:degrid/core/export/csv.dart';
import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/geometry/opening.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/roll_planning/carpet_layout_options.dart';
import 'package:degrid/core/roll_planning/roll_plan_models.dart';
import 'package:degrid/core/roll_planning/roll_planner.dart';
import 'package:degrid/core/roll_planning/room_opening_extension.dart';
import 'package:degrid/core/roll_planning/room_strip_layout.dart';
import 'package:degrid/core/units/unit_converter.dart';

void main() {
  group('imperial formatting carries inches into feet', () {
    test('values just under a whole foot round to the next foot', () {
      // 1828 mm = 71.97" -> 6', never 5' 12".
      expect(UnitConverter.formatDistance(1828, useImperial: true), "6'");
      expect(UnitConverter.formatDistance(3657.6, useImperial: true), "12'");
    });

    test('quarter-inch precision for cut lengths', () {
      expect(UnitConverter.formatDistance(1905, useImperial: true), "6' 3\"");
      expect(UnitConverter.formatDistance(254, useImperial: true), '10"');
      // 1911 mm = 75.24" -> 6' 3 1/4".
      expect(
        UnitConverter.formatDistance(1911, useImperial: true),
        "6' 3 1/4\"",
      );
    });
  });

  group('metric formatting uses metres above 1m', () {
    test('trade-style metres, mm below 1m', () {
      expect(UnitConverter.formatDistance(5150), '5.15m');
      expect(UnitConverter.formatDistance(8000), '8m');
      expect(UnitConverter.formatDistance(5100), '5.1m');
      expect(UnitConverter.formatDistance(950), '950mm');
    });
  });

  group('angled walls get exact strip extents', () {
    test('right-triangle room: strips cover the true band extent plus trim',
        () {
      // Right triangle 8000 wide x 7000 deep, roll 3600, lay along X.
      final room = Room(vertices: const [
        Offset(0, 0),
        Offset(8000, 0),
        Offset(0, 7000),
      ]);
      final layout = RollPlanner.computeLayout(
        room,
        3600,
        const CarpetLayoutOptions(layDirectionDeg: 0, trimAllowanceMm: 75),
      );
      expect(layout.numStrips, 2);
      // Band 1 (y 0..3600): widest at y=0 -> extent 8000.
      expect(layout.stripLengthsMm[0], closeTo(8000 + 150, 0.5));
      // Band 2 (y 3600..7000): widest at y=3600 -> 8000*(1-3600/7000).
      expect(
        layout.stripLengthsMm[1],
        closeTo(8000 * (1 - 3600 / 7000) + 150, 0.5),
      );
    });
  });

  group('multi-region bands (deep U-shape)', () {
    // U-shape 9000 x 7000 with notch x[3000,6000] y[0,4000] removed: band 1
    // splits into two disconnected legs, band 2 is one full-width strip.
    Room uRoom() => Room(vertices: const [
          Offset(0, 0),
          Offset(3000, 0),
          Offset(3000, 4000),
          Offset(6000, 4000),
          Offset(6000, 0),
          Offset(9000, 0),
          Offset(9000, 7000),
          Offset(0, 7000),
        ]);

    StripLayout layout() => RollPlanner.computeLayout(
          uRoom(),
          3600,
          const CarpetLayoutOptions(layDirectionDeg: 0, trimAllowanceMm: 0),
        );

    test('strips in the same band share a perpendicular start', () {
      final l = layout();
      expect(l.numStrips, 3);
      expect(l.stripPerpStartsMm, [0.0, 0.0, 3600.0]);
      // Legs start at along 0 and 6000; bottom strip spans from 0.
      expect(l.stripAlongStartsMm[0], closeTo(0, 0.5));
      expect(l.stripAlongStartsMm[1], closeTo(6000, 0.5));
      expect(l.stripAlongStartsMm[2], closeTo(0, 0.5));
      expect(l.stripLengthsMm[0], closeTo(3000, 0.5));
      expect(l.stripLengthsMm[1], closeTo(3000, 0.5));
      expect(l.stripLengthsMm[2], closeTo(9000, 0.5));
    });

    test('seam lines are real band boundaries, not one per strip', () {
      final l = layout();
      // Two legs join the bottom strip along one seam line at 3600; the legs
      // have no seam between each other.
      expect(l.seamCount, 1);
      expect(l.seamPositionsFromReferenceMm, [3600.0]);
      // No fabricated position beyond the room extent (was [3600, 7200]).
      expect(
        l.seamPositionsFromReferenceMm.every((p) => p < 7000),
        isTrue,
      );
    });

    test('stripPerpStartAt/stripAlongStartAt expose per-strip positions', () {
      final l = layout();
      expect(l.stripPerpStartAt(2), 3600.0);
      expect(l.stripAlongStartAt(1), closeTo(6000, 0.5));
    });
  });

  group('piece-length override keeps totals consistent', () {
    Room rect() => Room(vertices: const [
          Offset(0, 0),
          Offset(5000, 0),
          Offset(5000, 3000),
          Offset(0, 3000),
        ]);

    test('totalLinearWithWasteMm reflects the overridden lengths', () {
      final product = CarpetProduct(name: 'p', rollWidthMm: 3600);
      final overridden = computeRoomStripLayout(
        room: rect(),
        roomIndex: 0,
        product: product,
        openings: const [],
        stripPieceLengthsOverride: [
          [4000.0, 4000.0],
        ],
      )!;
      expect(overridden.totalLinearMm, 8000.0);
      expect(overridden.totalLinearWithWasteMm, closeTo(8000.0 * 1.05, 0.001));
      expect(overridden.scoreMaterialMm, closeTo(8000.0, 0.001));
    });
  });

  group('pattern repeat applies to split pieces', () {
    test('forced splits round every piece up to a repeat', () {
      // 9m room, 4m roll length cap, 800mm pattern repeat.
      final room = Room(vertices: const [
        Offset(0, 0),
        Offset(9000, 0),
        Offset(9000, 2000),
        Offset(0, 2000),
      ]);
      final layout = RollPlanner.computeLayout(
        room,
        3600,
        const CarpetLayoutOptions(
          layDirectionDeg: 0,
          trimAllowanceMm: 75,
          patternRepeatMm: 800,
          maxSinglePieceLengthMm: 4000,
        ),
      );
      final pieces = layout.pieceLengthsForStrip(0);
      expect(pieces.length, greaterThan(1));
      for (final p in pieces) {
        expect(p % 800, closeTo(0, 0.001), reason: 'piece $p not on repeat');
        expect(p, lessThanOrEqualTo(4000));
      }
    });
  });

  group('doorway extension', () {
    // 4000x3000 room, door (900 wide) on the right wall. Carpet must run
    // through the doorway to under the closed door.
    Room rect() => Room(vertices: const [
          Offset(0, 0),
          Offset(4000, 0),
          Offset(4000, 3000),
          Offset(0, 3000),
        ]);
    Opening door() => Opening(
          roomIndex: 0,
          edgeIndex: 1, // (4000,0) -> (4000,3000)
          offsetMm: 1000,
          widthMm: 900,
        );

    test('extendRoomThroughOpenings adds an outward tab', () {
      final extended =
          extendRoomThroughOpenings(rect(), [door()], 0, 35);
      expect(extended.vertices.length, rect().vertices.length + 4);
      final maxX = extended.vertices.map((v) => v.dx).reduce(math.max);
      expect(maxX, closeTo(4035, 0.001));
    });

    test('single-piece cut length includes the extension', () {
      final layout = RollPlanner.computeLayout(
        rect(),
        3600,
        CarpetLayoutOptions(
          trimAllowanceMm: 75,
          openings: [door()],
          roomIndex: 0,
          doorwayExtensionMm: 35,
        ),
      );
      expect(layout.isSinglePiece, isTrue);
      // 4000 room + 35 doorway + 2x75 trim.
      expect(layout.stripLengthsMm.single, closeTo(4035 + 150, 0.5));
    });

    test('only the strip containing the door gets longer', () {
      final room = Room(vertices: const [
        Offset(0, 0),
        Offset(5000, 0),
        Offset(5000, 4000),
        Offset(0, 4000),
      ]);
      final layout = RollPlanner.computeLayout(
        room,
        3600,
        CarpetLayoutOptions(
          layDirectionDeg: 0,
          trimAllowanceMm: 75,
          openings: [
            Opening(roomIndex: 0, edgeIndex: 1, offsetMm: 500, widthMm: 900),
          ],
          roomIndex: 0,
          doorwayExtensionMm: 35,
        ),
      );
      expect(layout.numStrips, 2);
      // Door spans y 500..1400 -> band 1 only.
      expect(layout.stripLengthsMm[0], closeTo(5035 + 150, 0.5));
      expect(layout.stripLengthsMm[1], closeTo(5000 + 150, 0.5));
    });

    test('extension off (0) leaves the layout unchanged', () {
      final layout = RollPlanner.computeLayout(
        rect(),
        3600,
        CarpetLayoutOptions(
          trimAllowanceMm: 75,
          openings: [door()],
          roomIndex: 0,
        ),
      );
      expect(layout.stripLengthsMm.single, closeTo(4000 + 150, 0.5));
    });
  });

  group('seam width allowance', () {
    test('grid boundaries step by usable width, not roll width', () {
      final room = Room(vertices: const [
        Offset(0, 0),
        Offset(5000, 0),
        Offset(5000, 7000),
        Offset(0, 7000),
      ]);
      final layout = RollPlanner.computeLayout(
        room,
        3600,
        const CarpetLayoutOptions(
          layDirectionDeg: 0,
          trimAllowanceMm: 0,
          seamWidthAllowanceMm: 50,
        ),
      );
      // First strip covers rollWidth - allowance = 3550.
      expect(layout.seamPositionsFromReferenceMm, [3550.0]);
      expect(layout.stripWidthsMm[0], closeTo(3550, 0.001));
      expect(layout.stripWidthsMm[1], closeTo(3450, 0.001));
    });

    test('allowance 0 keeps the raw roll-width grid', () {
      final room = Room(vertices: const [
        Offset(0, 0),
        Offset(5000, 0),
        Offset(5000, 7000),
        Offset(0, 7000),
      ]);
      final layout = RollPlanner.computeLayout(
        room,
        3600,
        const CarpetLayoutOptions(layDirectionDeg: 0, trimAllowanceMm: 0),
      );
      expect(layout.seamPositionsFromReferenceMm, [3600.0]);
    });
  });

  group('room letters', () {
    test('extend past Z spreadsheet-style', () {
      expect(roomLetterForIndex(0), 'A');
      expect(roomLetterForIndex(25), 'Z');
      expect(roomLetterForIndex(26), 'AA');
      expect(roomLetterForIndex(27), 'AB');
      expect(roomLetterForIndex(51), 'AZ');
      expect(roomLetterForIndex(52), 'BA');
    });
  });

  group('csv helpers', () {
    test('fields with commas and quotes are quoted', () {
      expect(csvField('Lounge, North'), '"Lounge, North"');
      expect(csvField('a "b"'), '"a ""b"""');
      expect(csvField('plain'), 'plain');
    });

    test('metre values are fixed-decimal', () {
      expect(csvMetres(5489.999999999999), '5.490');
      expect(csvMetres(2745), '2.745');
    });
  });
}
