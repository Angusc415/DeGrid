import 'dart:math' as math;

import 'package:degrid/core/geometry/room_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rotateVerticesAround', () {
    test('returns a copy when angle is zero', () {
      final verts = [const Offset(0, 0), const Offset(10, 0)];
      final result = rotateVerticesAround(verts, const Offset(5, 5), 0);
      expect(result, equals(verts));
      expect(identical(result, verts), isFalse);
    });

    test('rotates 90 degrees about the center', () {
      // Square centered at (5,5).
      final verts = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];
      final center = const Offset(5, 5);
      final result = rotateVerticesAround(verts, center, math.pi / 2);
      // (0,0) about (5,5) by +90deg -> (10,0).
      expect(result[0].dx, closeTo(10, 1e-9));
      expect(result[0].dy, closeTo(0, 1e-9));
      // (10,0) -> (10,10).
      expect(result[1].dx, closeTo(10, 1e-9));
      expect(result[1].dy, closeTo(10, 1e-9));
    });

    test('pivot point is invariant under rotation', () {
      final pivot = const Offset(3, 7);
      final verts = [pivot, const Offset(20, 20)];
      final result = rotateVerticesAround(verts, pivot, 1.234);
      expect(result[0].dx, closeTo(pivot.dx, 1e-9));
      expect(result[0].dy, closeTo(pivot.dy, 1e-9));
    });

    test('preserves distance from pivot', () {
      final pivot = const Offset(0, 0);
      final p = const Offset(3, 4); // distance 5
      final result = rotateVerticesAround([p], pivot, 0.9);
      expect((result[0] - pivot).distance, closeTo(5, 1e-9));
    });
  });

  group('snapRotationDeg', () {
    test('fine mode returns the raw value', () {
      expect(snapRotationDeg(37.3, fine: true), 37.3);
    });

    test('snaps to nearest 15 degree step', () {
      expect(snapRotationDeg(22, fine: false), 15);
      expect(snapRotationDeg(38, fine: false), 45);
    });

    test('sticks to right angles when close', () {
      expect(snapRotationDeg(88, fine: false), 90);
      expect(snapRotationDeg(91, fine: false), 90);
      expect(snapRotationDeg(-2, fine: false), 0);
      expect(snapRotationDeg(178, fine: false), 180);
    });

    test('does not stick to 90 when outside the sticky band', () {
      // 95 is 5 deg from 90 (> 4 sticky), so it snaps to nearest 15 -> 90.
      expect(snapRotationDeg(95, fine: false), 90);
      // 100 -> nearest 15 step is 105.
      expect(snapRotationDeg(100, fine: false), 105);
    });
  });
}
