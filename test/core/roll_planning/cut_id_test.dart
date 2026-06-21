import 'package:degrid/core/roll_planning/roll_plan_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCutId', () {
    test('single piece in strip', () {
      expect(
        formatCutId(
          roomLetterIndex: 0,
          stripIndex: 0,
          pieceIndex: 0,
          pieceCountInStrip: 1,
        ),
        'A1',
      );
      expect(
        formatCutId(
          roomLetterIndex: 1,
          stripIndex: 2,
          pieceIndex: 0,
          pieceCountInStrip: 1,
        ),
        'B3',
      );
    });

    test('multiple pieces in strip (cross-join)', () {
      expect(
        formatCutId(
          roomLetterIndex: 0,
          stripIndex: 0,
          pieceIndex: 0,
          pieceCountInStrip: 2,
        ),
        'A1-1',
      );
      expect(
        formatCutId(
          roomLetterIndex: 0,
          stripIndex: 0,
          pieceIndex: 1,
          pieceCountInStrip: 2,
        ),
        'A1-2',
      );
    });
  });

  group('roomLetterIndexInProduct', () {
    test('assigns letters in entry order per product', () {
      final assignments = {0: 0, 2: 0, 5: 1};
      final plannable = {0, 2, 5};

      expect(
        roomLetterIndexInProduct(
          assignments: assignments,
          roomIndex: 0,
          hasPlannableLayout: plannable.contains,
        ),
        0,
      );
      expect(
        roomLetterIndexInProduct(
          assignments: assignments,
          roomIndex: 2,
          hasPlannableLayout: plannable.contains,
        ),
        1,
      );
      expect(
        roomLetterIndexInProduct(
          assignments: assignments,
          roomIndex: 5,
          hasPlannableLayout: plannable.contains,
        ),
        0,
      );
    });

    test('skips rooms without plannable layout', () {
      final assignments = {0: 0, 1: 0, 2: 0};
      final plannable = {0, 2};

      expect(
        roomLetterIndexInProduct(
          assignments: assignments,
          roomIndex: 2,
          hasPlannableLayout: plannable.contains,
        ),
        1,
      );
      expect(
        roomLetterIndexInProduct(
          assignments: assignments,
          roomIndex: 1,
          hasPlannableLayout: plannable.contains,
        ),
        isNull,
      );
    });
  });
}
