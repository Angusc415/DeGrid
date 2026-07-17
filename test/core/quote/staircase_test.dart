import 'package:flutter_test/flutter_test.dart';

import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/models/project.dart';
import 'package:degrid/core/quote/job_quote.dart';
import 'package:degrid/core/quote/quote_rates.dart';
import 'package:degrid/core/quote/staircase.dart';

void main() {
  group('Staircase', () {
    test('carpet run length and area from steps and dimensions', () {
      const s = Staircase(
        name: 'Main',
        steps: 13,
        goingMm: 250,
        riserMm: 180,
        widthMm: 900,
        nosingMm: 25,
      );
      // per step = 250 + 180 + 25 = 455mm; x13 = 5915mm run.
      expect(s.carpetRunLengthMm, closeTo(5915, 0.001));
      // area = 5.915m x 0.9m = 5.3235 m².
      expect(s.carpetAreaSqm, closeTo(5.3235, 0.0001));
    });

    test('JSON round-trip', () {
      const s = Staircase(
        name: 'Back',
        steps: 8,
        goingMm: 240,
        riserMm: 190,
        widthMm: 1000,
        nosingMm: 20,
        carpetProductIndex: 2,
      );
      final restored = Staircase.fromJson(s.toJson());
      expect(restored.name, 'Back');
      expect(restored.steps, 8);
      expect(restored.goingMm, 240);
      expect(restored.carpetProductIndex, 2);
      expect(restored.carpetAreaSqm, closeTo(s.carpetAreaSqm, 1e-9));
    });
  });

  group('buildJobQuote with stairs', () {
    test('prices stair carpet (incl. waste) and labour per step', () {
      const stair = Staircase(
        name: 'Main',
        steps: 13,
        goingMm: 250,
        riserMm: 180,
        widthMm: 900,
        nosingMm: 25,
        carpetProductIndex: 0,
      );
      final proj = ProjectModel(
        name: 'Stairs',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: const [],
        carpetProducts: [
          CarpetProduct(name: 'Twist', rollWidthMm: 3600, costPerSqm: 30),
        ],
        staircases: const [stair],
        quoteRates: const QuoteRates(
          stairLabourPerStep: 15,
          includeGst: false,
        ),
      );
      final quote = buildJobQuote(proj);
      expect(quote.isEmpty, isFalse);
      final byLabel = {for (final l in quote.lines) l.label: l};

      // Carpet: 5.3235 m² x 1.05 waste x $30/m².
      expect(
        byLabel['Stairs — Main']!.amount,
        closeTo(5.3235 * 1.05 * 30, 0.01),
      );
      // Labour: 13 steps x $15.
      expect(byLabel['Stairs — installation']!.amount, closeTo(13 * 15, 0.01));
      expect(quote.fullyPriced, isTrue);
    });

    test('stair carpet is unpriced when the product has no cost', () {
      const stair = Staircase(name: 'Main', steps: 10, carpetProductIndex: 0);
      final proj = ProjectModel(
        name: 'Stairs',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: const [],
        carpetProducts: [CarpetProduct(name: 'Twist', rollWidthMm: 3600)],
        staircases: const [stair],
        quoteRates: const QuoteRates(stairLabourPerStep: 15),
      );
      final quote = buildJobQuote(proj);
      final byLabel = {for (final l in quote.lines) l.label: l};
      expect(byLabel['Stairs — Main']!.amount, isNull);
      expect(byLabel['Stairs — Main']!.detail, contains('no carpet rate'));
      expect(quote.fullyPriced, isFalse);
    });

    test('empty project with neither rooms nor stairs stays empty', () {
      final proj = ProjectModel(
        name: 'Empty',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        rooms: const [],
      );
      expect(buildJobQuote(proj).isEmpty, isTrue);
    });
  });
}
