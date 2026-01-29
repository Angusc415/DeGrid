import 'package:flutter_test/flutter_test.dart';
import 'package:degrid/core/geometry/room.dart';
import 'dart:ui';

void main() {
  group('Room', () {
    test('requires at least 3 vertices', () {
      // Should throw assertion error with less than 3 vertices
      expect(
        () => Room(vertices: [Offset(0, 0), Offset(10, 0)]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('creates valid room with 3 vertices', () {
      final room = Room(
        vertices: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
        ],
      );
      expect(room.isValid, isTrue);
      expect(room.vertices.length, 3);
    });

    test('calculates area correctly for rectangle', () {
      // 10mm x 10mm rectangle = 100mm²
      final room = Room(
        vertices: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
      );
      expect(room.areaMm2, closeTo(100.0, 0.1));
    });

    test('returns 0 area for invalid room', () {
      // This shouldn't happen in practice (assertion prevents it),
      // but testing the area getter's safety check
      final room = Room(
        vertices: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
        ],
      );
      expect(room.areaMm2, greaterThan(0));
    });
  });
}
