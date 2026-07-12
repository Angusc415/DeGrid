import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/units/unit_converter.dart';
import 'package:degrid/ui/screens/carpet_roll_cut_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the cut sheet updates live when seam/piece overrides change
/// (deep-equality didUpdateWidget, mirroring how the canvas publishes fresh
/// deep copies of its state on every seam-drag move).
void main() {
  // 5000x3500 mm room with a 2000 mm roll laid along X -> 2 strips, 1 seam.
  Room room() => Room(
        name: 'Lounge',
        vertices: const [
          Offset(0, 0),
          Offset(5000, 0),
          Offset(5000, 3500),
          Offset(0, 3500),
        ],
      );

  CarpetProduct product() => CarpetProduct(
        name: 'Twist Pile',
        rollWidthMm: 2000,
        trimAllowanceMm: 75,
      );

  Widget buildSheet({
    Map<int, List<double>> seamOverrides = const {},
    Map<int, double> seamLayDirectionDeg = const {},
    Map<int, List<List<double>>> pieceLengthsOverride = const {},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CarpetRollCutSheet(
          rooms: [room()],
          carpetProducts: [product()],
          roomCarpetAssignments: const {0: 0},
          openings: const [],
          roomCarpetSeamOverrides: seamOverrides,
          roomCarpetSeamLayDirectionDeg: seamLayDirectionDeg,
          roomCarpetStripPieceLengthsOverrideMm: pieceLengthsOverride,
        ),
      ),
    );
  }

  testWidgets('renders cut list for a room with carpet assigned',
      (tester) async {
    await tester.pumpWidget(buildSheet());
    await tester.pumpAndSettle();

    expect(find.text('Cut list'), findsWidgets); // tab + panel header
    expect(find.text('Lounge'), findsOneWidget);
    expect(find.text('Twist Pile'), findsWidgets);
    expect(find.textContaining('2 strips'), findsOneWidget);
    expect(find.textContaining('Seam 1:'), findsOneWidget);
  });

  testWidgets('updating seam override props updates the displayed seam',
      (tester) async {
    await tester.pumpWidget(buildSheet());
    await tester.pumpAndSettle();

    // Simulate a seam drag publish: a fresh widget with deep-copied maps and
    // the seam pinned at 1500 mm (direction locked like the canvas does).
    await tester.pumpWidget(buildSheet(
      seamOverrides: {
        0: [1500.0],
      },
      seamLayDirectionDeg: {0: 0.0},
    ));
    await tester.pumpAndSettle();

    final expected = UnitConverter.formatDistance(1500);
    expect(find.textContaining('Seam 1: $expected'), findsOneWidget);
  });

  testWidgets('updating piece-length override shows split pieces in cut list',
      (tester) async {
    await tester.pumpWidget(buildSheet());
    await tester.pumpAndSettle();

    // No pieces split yet -> rows are labelled per strip only.
    expect(find.text('A1-1'), findsNothing);

    // Strip lengths are 5000 + 2*75 trim = 5150 mm; split strip 1 into two
    // pieces (user dragged an along-run seam), strip 2 stays whole.
    await tester.pumpWidget(buildSheet(
      pieceLengthsOverride: {
        0: [
          [2000.0, 3150.0],
          [5150.0],
        ],
      },
    ));
    await tester.pumpAndSettle();

    expect(find.text('A1-1'), findsOneWidget);
    expect(find.text('A1-2'), findsOneWidget);
    expect(find.textContaining('4 pieces'), findsNothing); // 3 pieces total
    expect(find.textContaining('3 pieces'), findsOneWidget);
    expect(
      find.textContaining(UnitConverter.formatDistance(2000)),
      findsWidgets,
    );
  });

  testWidgets('identical deep-copied props do not change the cut list',
      (tester) async {
    await tester.pumpWidget(buildSheet(
      seamOverrides: {
        0: [1500.0],
      },
      seamLayDirectionDeg: {0: 0.0},
    ));
    await tester.pumpAndSettle();

    final expected = UnitConverter.formatDistance(1500);
    expect(find.textContaining('Seam 1: $expected'), findsOneWidget);

    // Re-publish with equal content in fresh map/list instances (what the
    // canvas does on pan/zoom): sheet must not lose or change its plan.
    await tester.pumpWidget(buildSheet(
      seamOverrides: {
        0: [1500.0],
      },
      seamLayDirectionDeg: {0: 0.0},
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Seam 1: $expected'), findsOneWidget);
    expect(find.textContaining('2 strips'), findsOneWidget);
  });
}
