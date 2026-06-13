import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/roll_planning/carpet_layout_options.dart';
import 'package:degrid/core/roll_planning/roll_planner.dart';
import 'package:degrid/core/roll_planning/room_strip_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Rectangle [w] x [h] mm with top-left at origin.
  Room rect(double w, double h) => Room(
        vertices: [
          const Offset(0, 0),
          Offset(w, 0),
          Offset(w, h),
          Offset(0, h),
        ],
      );

  group('layDirectionDegFromVariant', () {
    test('maps variant indices to lay directions', () {
      expect(layDirectionDegFromVariant(0), isNull); // Auto
      expect(layDirectionDegFromVariant(1), 0.0);
      expect(layDirectionDegFromVariant(2), 90.0);
    });
  });

  group('computeRoomStripLayout', () {
    final product = CarpetProduct(
      name: 'Test',
      rollWidthMm: 2000,
      trimAllowanceMm: 75,
    );

    test('returns null when roll width is not usable', () {
      final layout = computeRoomStripLayout(
        room: rect(3000, 2000),
        roomIndex: 0,
        product: CarpetProduct(name: 'Bad', rollWidthMm: 0),
        openings: const [],
      );
      expect(layout, isNull);
    });

    test('matches direct CarpetLayoutOptions.forRoom + RollPlanner', () {
      final room = rect(5000, 4000);
      final viaHelper = computeRoomStripLayout(
        room: room,
        roomIndex: 0,
        product: product,
        openings: const [],
      )!;
      final direct = RollPlanner.computeLayout(
        room,
        product.rollWidthMm,
        CarpetLayoutOptions.forRoom(
          roomIndex: 0,
          minStripWidthMm: 100,
          trimAllowanceMm: 75,
        ),
      );
      expect(viaHelper.numStrips, direct.numStrips);
      expect(viaHelper.stripLengthsMm, direct.stripLengthsMm);
      expect(viaHelper.stripWidthsMm, direct.stripWidthsMm);
      expect(viaHelper.layAlongX, direct.layAlongX);
      expect(viaHelper.totalLinearWithWasteMm, direct.totalLinearWithWasteMm);
    });

    test('applies seam overrides', () {
      // 5000x3500, roll 2000, lay along X -> 2 strips; pin seam at 1500.
      final layout = computeRoomStripLayout(
        room: rect(5000, 3500),
        roomIndex: 0,
        product: product,
        openings: const [],
        seamOverrides: [1500],
        layDirectionDeg: 0,
      )!;
      expect(layout.numStrips, 2);
      expect(layout.seamPositionsFromReferenceMm, [1500]);
    });

    test('empty seam override list is treated as no override', () {
      final layout = computeRoomStripLayout(
        room: rect(5000, 4000),
        roomIndex: 0,
        product: product,
        openings: const [],
        seamOverrides: const [],
      )!;
      // Falls back to auto seams at multiples of roll width.
      expect(layout.seamPositionsFromReferenceMm, [2000]);
    });

    test('applies piece-length override; strip lengths become piece sums', () {
      // 3000x1500 fits within roll width -> single strip.
      final base = computeRoomStripLayout(
        room: rect(3000, 1500),
        roomIndex: 0,
        product: product,
        openings: const [],
      )!;
      expect(base.numStrips, 1);

      final override = [
        [2000.0, 1300.0],
      ];
      final layout = computeRoomStripLayout(
        room: rect(3000, 1500),
        roomIndex: 0,
        product: product,
        openings: const [],
        stripPieceLengthsOverride: override,
      )!;
      expect(layout.stripPieceLengthsMm, override);
      expect(layout.stripLengthsMm, [3300.0]);
      expect(layout.pieceLengthsForStrip(0), [2000.0, 1300.0]);
    });

    test('ignores piece-length override when strip count mismatches', () {
      final layout = computeRoomStripLayout(
        room: rect(3000, 1500),
        roomIndex: 0,
        product: product,
        openings: const [],
        // Two strips claimed but the layout has one -> stale override, ignored.
        stripPieceLengthsOverride: [
          [1000.0],
          [2000.0],
        ],
      )!;
      expect(layout.numStrips, 1);
      expect(layout.pieceLengthsForStrip(0), [layout.stripLengthsMm[0]]);
    });

    test('waste percent flows through to totalLinearWithWasteMm', () {
      // Single-piece room: cut length = 3000 + 2*75 = 3150.
      final layout = computeRoomStripLayout(
        room: rect(3000, 1500),
        roomIndex: 0,
        product: product,
        openings: const [],
        settings: const CarpetPlanningSettings(wasteAllowancePercent: 10),
      )!;
      expect(layout.stripLengthsMm, [3150.0]);
      expect(layout.totalLinearWithWasteMm, closeTo(3150.0 * 1.10, 0.001));
    });
  });

  group('strip splitting strategies', () {
    // 7000x1000 fits within roll width -> single strip, cut len 7000 + 150 = 7150,
    // which exceeds the 6000 mm default max piece length.
    const trim = 75.0;
    final longRoom = Room(
      vertices: const [
        Offset(0, 0),
        Offset(7000, 0),
        Offset(7000, 1000),
        Offset(0, 1000),
      ],
    );

    test('never: one piece per strip even beyond max piece length', () {
      final layout = RollPlanner.computeLayout(
        longRoom,
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.never,
        ),
      );
      expect(layout.numStrips, 1);
      expect(layout.pieceLengthsForStrip(0), [7150.0]);
    });

    test('auto: infinitely long roll (no length set) never splits', () {
      // Roll length not set => infinitely long => a long run stays one piece.
      final layout = RollPlanner.computeLayout(
        longRoom,
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.auto,
        ),
      );
      expect(layout.pieceLengthsForStrip(0), [7150.0]);
    });

    test('auto: splits when forced by the physical roll length', () {
      // Roll length 6 m => strip of 7150 mm must be split into pieces <= 6000.
      final layout = RollPlanner.computeLayout(
        longRoom,
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.auto,
          maxSinglePieceLengthMm: 6000,
        ),
      );
      final pieces = layout.pieceLengthsForStrip(0);
      expect(pieces.length, greaterThanOrEqualTo(2));
      for (final p in pieces) {
        expect(p, lessThanOrEqualTo(6000.0));
      }
      // Each extra piece adds 2*trim of material at the new cut junction.
      final expectedTotal = 7150.0 + (pieces.length - 1) * 2 * trim;
      final sum = pieces.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(expectedTotal, 0.001));
      expect(layout.stripLengthsMm[0], closeTo(expectedTotal, 0.001));
    });

    test('auto: does not split below the roll length', () {
      final layout = RollPlanner.computeLayout(
        Room(
          vertices: const [
            Offset(0, 0),
            Offset(4000, 0),
            Offset(4000, 1000),
            Offset(0, 1000),
          ],
        ),
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.auto,
        ),
      );
      expect(layout.pieceLengthsForStrip(0), [4150.0]);
    });

    test('auto: explicit maxSinglePieceLengthMm caps every piece', () {
      final layout = RollPlanner.computeLayout(
        longRoom,
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.auto,
          maxSinglePieceLengthMm: 3000,
        ),
      );
      final pieces = layout.pieceLengthsForStrip(0);
      expect(pieces.length, greaterThanOrEqualTo(3));
      for (final p in pieces) {
        expect(p, lessThanOrEqualTo(3000.0));
      }
    });

    test('preferStripInPieces: splits long runs into at least two pieces', () {
      final layout = RollPlanner.computeLayout(
        Room(
          vertices: const [
            Offset(0, 0),
            Offset(5000, 0),
            Offset(5000, 1000),
            Offset(0, 1000),
          ],
        ),
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.preferStripInPieces,
        ),
      );
      final pieces = layout.pieceLengthsForStrip(0);
      expect(pieces.length, greaterThanOrEqualTo(2));
      // Cut len 5150 + one extra junction (2*trim) = 5300 across the pieces.
      final sum = pieces.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(5150.0 + (pieces.length - 1) * 2 * trim, 0.001));
    });

    test('preferStripInPieces: leaves short runs unsplit', () {
      final layout = RollPlanner.computeLayout(
        Room(
          vertices: const [
            Offset(0, 0),
            Offset(1500, 0),
            Offset(1500, 1000),
            Offset(0, 1000),
          ],
        ),
        2000,
        const CarpetLayoutOptions(
          // Pin direction so the run is 1500 mm (below the 2 m split threshold).
          layDirectionDeg: 0,
          trimAllowanceMm: trim,
          stripSplitStrategy: StripSplitStrategy.preferStripInPieces,
        ),
      );
      expect(layout.pieceLengthsForStrip(0), [1650.0]);
    });

    test('splitting updates totalLinearWithWasteMm with extra trim material', () {
      const waste = 10.0;
      final layout = RollPlanner.computeLayout(
        longRoom,
        2000,
        const CarpetLayoutOptions(
          trimAllowanceMm: trim,
          wasteAllowancePercent: waste,
          stripSplitStrategy: StripSplitStrategy.auto,
          maxSinglePieceLengthMm: 6000,
        ),
      );
      // A split actually happened (roll length forces it).
      expect(layout.pieceLengthsForStrip(0).length, greaterThanOrEqualTo(2));
      final totalLinear =
          layout.stripLengthsMm.fold<double>(0, (a, b) => a + b);
      expect(totalLinear, greaterThan(7150.0)); // includes extra trim
      expect(
        layout.totalLinearWithWasteMm,
        closeTo(totalLinear * (1 + waste / 100), 0.001),
      );
    });
  });

  group('infinite-roll regression (room 6564 x 5436, roll 3600 wide)', () {
    // Real-world case: 3.6 m wide roll with no set length (infinitely long).
    final product = CarpetProduct(name: 'Roll', rollWidthMm: 3600);
    Room room() => Room(
          vertices: const [
            Offset(0, 0),
            Offset(6564, 0),
            Offset(6564, 5436),
            Offset(0, 5436),
          ],
        );

    test('lay left-right uses 2 strips, 1 piece each (no extra cuts)', () {
      final layout = computeRoomStripLayout(
        room: room(),
        roomIndex: 0,
        product: product,
        openings: const [],
        layDirectionDeg: 0, // strips run along X (6564 mm runs)
      )!;
      expect(layout.numStrips, 2);
      expect(layout.totalPieceCount, 2); // one cut per strip, not 4
      for (var i = 0; i < layout.numStrips; i++) {
        expect(layout.pieceLengthsForStrip(i).length, 1);
      }
    });

    test('lay up-down also uses 2 strips, 1 piece each', () {
      final layout = computeRoomStripLayout(
        room: room(),
        roomIndex: 0,
        product: product,
        openings: const [],
        layDirectionDeg: 90, // strips run along Y (5436 mm runs)
      )!;
      expect(layout.numStrips, 2);
      expect(layout.totalPieceCount, 2);
    });
  });

  group('applyStripPieceLengthsOverride', () {
    StripLayout baseLayout() => RollPlanner.computeLayout(
          rect(3000, 1500),
          2000,
          const CarpetLayoutOptions(trimAllowanceMm: 75),
        );

    test('null and empty overrides return layout unchanged', () {
      final layout = baseLayout();
      expect(applyStripPieceLengthsOverride(layout, null), same(layout));
      expect(applyStripPieceLengthsOverride(layout, []), same(layout));
    });

    test('mismatched strip count returns layout unchanged', () {
      final layout = baseLayout();
      final result = applyStripPieceLengthsOverride(layout, [
        [1000.0],
        [2000.0],
      ]);
      expect(result, same(layout));
    });
  });
}
