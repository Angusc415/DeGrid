import 'package:flutter_test/flutter_test.dart';

import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/geometry/opening.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/models/project.dart';
import 'package:degrid/core/quote/job_quote.dart';
import 'package:degrid/core/quote/quote_rates.dart';
import 'package:degrid/core/roll_planning/carpet_layout_options.dart';

void main() {
  group('QuoteRates', () {
    test('JSON round-trip preserves all fields including nulls', () {
      const rates = QuoteRates(
        underlayCostPerSqm: 8,
        gripperCostPerM: 5,
        doorBarCostEach: null,
        labourCostPerSqm: 12,
        gstPercent: 10,
        includeGst: false,
      );
      final restored = QuoteRates.fromJson(rates.toJson());
      expect(restored, rates);
      expect(restored.doorBarCostEach, isNull);
    });

    test('copyWith clear flags null a rate out', () {
      const rates = QuoteRates(underlayCostPerSqm: 8);
      expect(
        rates.copyWith(clearUnderlayCostPerSqm: true).underlayCostPerSqm,
        isNull,
      );
      expect(rates.hasAnyRates, isTrue);
      expect(const QuoteRates().hasAnyRates, isFalse);
    });
  });

  group('buildJobQuote', () {
    // Room A: 5m x 4m (20 m², perimeter 18m). Room B: 4m x 3m (12 m²,
    // perimeter 14m). Shared doorway (linkId d1, 900mm) plus one unlinked
    // 800mm opening on Room A.
    ProjectModel project({QuoteRates? rates}) => ProjectModel(
          name: 'Quote test',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          rooms: [
            Room(name: 'A', vertices: const [
              Offset(0, 0),
              Offset(5000, 0),
              Offset(5000, 4000),
              Offset(0, 4000),
            ]),
            Room(name: 'B', vertices: const [
              Offset(5000, 0),
              Offset(9000, 0),
              Offset(9000, 3000),
              Offset(5000, 3000),
            ]),
          ],
          openings: [
            Opening(
              roomIndex: 0,
              edgeIndex: 1,
              offsetMm: 1000,
              widthMm: 900,
              linkId: 'd1',
            ),
            Opening(
              roomIndex: 1,
              edgeIndex: 3,
              offsetMm: 1000,
              widthMm: 900,
              linkId: 'd1',
            ),
            Opening(
              roomIndex: 0,
              edgeIndex: 0,
              offsetMm: 3000,
              widthMm: 800,
              isDoor: false,
            ),
          ],
          carpetProducts: [
            CarpetProduct(name: 'Twist', rollWidthMm: 3600, costPerSqm: 30),
          ],
          roomCarpetAssignments: const {0: 0, 1: 0},
          // Doorway extension off for deterministic geometry in expectations.
          carpetPlanningSettings:
              const CarpetPlanningSettings(doorwayExtensionMm: 0),
          quoteRates: rates ??
              const QuoteRates(
                underlayCostPerSqm: 8,
                gripperCostPerM: 5,
                doorBarCostEach: 25,
                labourCostPerSqm: 12,
                gstPercent: 10,
                includeGst: true,
              ),
        );

    test('computes every line and the GST total', () {
      final quote = buildJobQuote(project());
      expect(quote.fullyPriced, isTrue);

      final byLabel = {for (final l in quote.lines) l.label: l};

      // Carpet: A lays 90° (2 x 4150mm), B is a single 4150mm piece;
      // (8300 + 4150) x 1.05 waste = 13072.5mm -> x 3.6m x $30/m².
      expect(
        byLabel['Carpet — Twist']!.amount,
        closeTo(13.0725 * 3.6 * 30, 0.01),
      );

      // Underlay + labour: 32 m² carpeted area.
      expect(byLabel['Underlay']!.amount, closeTo(32 * 8, 0.01));
      expect(byLabel['Installation']!.amount, closeTo(32 * 12, 0.01));

      // Gripper: (18 - 0.9 - 0.8) + (14 - 0.9) = 29.4m.
      expect(byLabel['Gripper']!.amount, closeTo(29.4 * 5, 0.01));

      // Door bars: mirrored pair counts once + one unlinked opening = 2.
      expect(byLabel['Door bars']!.amount, closeTo(2 * 25, 0.01));

      final expectedSubtotal =
          13.0725 * 3.6 * 30 + 32 * 8 + 32 * 12 + 29.4 * 5 + 50;
      expect(quote.subtotal, closeTo(expectedSubtotal, 0.01));
      expect(quote.gstAmount, closeTo(expectedSubtotal * 0.10, 0.01));
      expect(quote.total, closeTo(expectedSubtotal * 1.10, 0.01));
    });

    test('missing rates leave lines unpriced and flag the quote partial', () {
      final quote = buildJobQuote(
        project(rates: const QuoteRates(labourCostPerSqm: 12)),
      );
      expect(quote.fullyPriced, isFalse);
      final byLabel = {for (final l in quote.lines) l.label: l};
      expect(byLabel['Underlay']!.amount, isNull);
      expect(byLabel['Underlay']!.detail, contains('no rate set'));
      expect(byLabel['Installation']!.amount, closeTo(32 * 12, 0.01));
      // Quantities still appear for unpriced lines.
      expect(byLabel['Gripper']!.detail, contains('29.4 m'));
    });

    test('GST can be excluded', () {
      final quote = buildJobQuote(
        project(
          rates: const QuoteRates(labourCostPerSqm: 10, includeGst: false),
        ),
      );
      expect(quote.gstAmount, 0);
      expect(quote.total, quote.subtotal);
    });

    test('empty when no carpet assignments', () {
      final empty = ProjectModel(
        name: 'Empty',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: const [],
      );
      expect(buildJobQuote(empty).isEmpty, isTrue);
    });
  });
}
