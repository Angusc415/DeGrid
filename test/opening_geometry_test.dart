import 'dart:ui';

import 'package:degrid/core/geometry/opening.dart';
import 'package:degrid/core/geometry/opening_geometry.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edgesAreSharedReversed detects reversed shared wall', () {
    final a = (a: const Offset(0, 0), b: const Offset(1000, 0));
    final b = (a: const Offset(1000, 0), b: const Offset(0, 0));
    expect(edgesAreSharedReversed(a, b), isTrue);
  });

  test('mirrorOffsetOnEdge reverses offset along same-length edge', () {
    const edgeLen = 3000.0;
    final primary = Opening(
      roomIndex: 0,
      edgeIndex: 0,
      offsetMm: 500,
      widthMm: 900,
    );
    final mirrored = mirrorOffsetOnEdge(edgeLen, primary);
    expect(mirrored, 3000 - 500 - 900);
  });

  test('syncMirroredOpenings adds partner on shared edge', () {
    final rooms = [
      Room(vertices: [Offset.zero, const Offset(2000, 0), const Offset(2000, 1500), const Offset(0, 1500), Offset.zero]),
      Room(vertices: [const Offset(2000, 0), const Offset(4000, 0), const Offset(4000, 1500), const Offset(2000, 1500), const Offset(2000, 0)]),
    ];
    final openings = <Opening>[
      Opening(
        roomIndex: 0,
        edgeIndex: 1,
        offsetMm: 400,
        widthMm: 820,
        isDoor: true,
      ),
    ];
    final synced = syncMirroredOpenings(rooms, openings);
    expect(synced.length, 2);
    expect(synced.every((o) => o.linkId != null), isTrue);
    final mirror = synced.firstWhere((o) => o.roomIndex == 1);
    expect(mirror.edgeIndex, 3);
    expect(mirror.widthMm, 820);
  });

  test('wallAlignHint orders setbacks along host wall corners', () {
    final hint = wallAlignHint(
      roomIndex: 1,
      edgeIndex: 0,
      cornerStartMm: const Offset(0, 0),
      cornerEndMm: const Offset(3000, 0),
      gapStartMm: const Offset(500, 0),
      gapEndMm: const Offset(1400, 0),
      hostWall: true,
    );
    expect(hint, isNotNull);
    expect(hint!.hostWall, isTrue);
    expect(hint.segBeforeMm, closeTo(500, 0.1));
    expect(hint.openingWidthMm, closeTo(900, 0.1));
    expect(hint.segAfterMm, closeTo(1600, 0.1));
  });

  test('findAlignTargetWall finds shared neighbour edge', () {
    final rooms = [
      Room(vertices: [
        Offset.zero,
        const Offset(2000, 0),
        const Offset(2000, 1000),
        const Offset(0, 1000),
        Offset.zero,
      ]),
      Room(vertices: [
        const Offset(2000, 0),
        const Offset(4000, 0),
        const Offset(4000, 1000),
        const Offset(2000, 1000),
        const Offset(2000, 0),
      ]),
    ];
    final target = findAlignTargetWall(rooms, 0, 1, tolMm: 100);
    expect(target?.roomIndex, 1);
    expect(target?.edgeIndex, 3);
  });

  test('computeRoomMoveSnap pulls plain room to host wall with door', () {
    final rooms = [
      Room(vertices: [
        Offset.zero,
        const Offset(1990, 0),
        const Offset(1990, 1000),
        const Offset(0, 1000),
        Offset.zero,
      ]),
      Room(vertices: [
        const Offset(2000, 0),
        const Offset(4000, 0),
        const Offset(4000, 1000),
        const Offset(2000, 1000),
        const Offset(2000, 0),
      ]),
    ];
    final openings = <Opening>[
      Opening(
        roomIndex: 1,
        edgeIndex: 3,
        offsetMm: 400,
        widthMm: 820,
        isDoor: true,
      ),
    ];
    final snap = computeRoomMoveSnap(
      movingRoomIndex: 0,
      movingVertsAtStart: rooms[0].vertices,
      baseDelta: const Offset(15, 0),
      rooms: rooms,
      openings: openings,
    );
    expect(snap.delta.dx, closeTo(10, 2));
    expect(snap.alignHints, isNotEmpty);
    expect(snap.alignHints.first.roomIndex, 1);
  });

  test('findMovingEdgeNearestHostWall picks wall approaching doorway', () {
    final moved = [
      Offset.zero,
      const Offset(1990, 0),
      const Offset(1990, 1000),
      const Offset(0, 1000),
    ];
    const hostWall = (a: Offset(2000, 0), b: Offset(2000, 1000));
    final nearest = findMovingEdgeNearestHostWall(moved, hostWall);
    expect(nearest?.edgeIndex, 1);
    expect(nearest!.score, lessThan(100));
  });
}
