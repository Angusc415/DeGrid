import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'viewport.dart';
import '../../core/geometry/room.dart';
import '../../core/geometry/opening.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/roll_planning/carpet_layout_options.dart';
import '../../core/roll_planning/roll_planner.dart';
import '../../core/units/unit_converter.dart';
import '../../core/models/project.dart';

/// Immutable data passed to [PlanPainter] for one frame.
class PlanPaintModel {
  final PlanViewport vp;
  final List<Room> completedRooms;
  final List<Offset>? draftRoomVertices;
  final Offset? hoverPositionWorldMm;
  final double? previewLineAngleDeg;
  /// Optional inline alignment guide between the preview endpoint and another vertex.
  final Offset? inlineGuideStartWorld;
  final Offset? inlineGuideEndWorld;
  /// Wall width in millimeters for this project.
  final double wallWidthMm;
  final bool useImperial;
  final bool isDragging;
  final int? selectedRoomIndex;
  final ({int roomIndex, int vertexIndex})? selectedVertex;
  final ({int roomIndex, int vertexIndex})? hoveredVertex;
  final bool showGrid;
  final Offset? calibrationP1Screen;
  final Offset? calibrationP2Screen;
  final bool isMeasureMode;
  final List<Offset> measurePointsWorld;
  final Offset? measureCurrentWorld;
  final bool isAddDimensionMode;
  final Offset? addDimensionP1World;
  final List<({Offset fromMm, Offset toMm})> placedDimensions;
  final bool drawFromStart;
  final ui.Image? backgroundImage;
  final BackgroundImageState? backgroundImageState;
  final List<Opening> openings;
  final ({int roomIndex, int edgeIndex, double edgeLenMm})? pendingDoorEdge;
  final Map<int, int> roomCarpetAssignments;
  final List<CarpetProduct> carpetProducts;
  final Map<int, List<double>> roomCarpetSeamOverrides;

  PlanPaintModel({
    required this.vp,
    List<Room>? completedRooms,
    this.draftRoomVertices,
    this.hoverPositionWorldMm,
    this.previewLineAngleDeg,
    this.inlineGuideStartWorld,
    this.inlineGuideEndWorld,
    required this.wallWidthMm,
    required this.useImperial,
    required this.isDragging,
    this.selectedRoomIndex,
    this.selectedVertex,
    this.hoveredVertex,
    required this.showGrid,
    this.calibrationP1Screen,
    this.calibrationP2Screen,
    this.isMeasureMode = false,
    List<Offset>? measurePointsWorld,
    this.measureCurrentWorld,
    this.isAddDimensionMode = false,
    this.addDimensionP1World,
    List<({Offset fromMm, Offset toMm})>? placedDimensions,
    this.drawFromStart = false,
    this.backgroundImage,
    this.backgroundImageState,
    List<Opening>? openings,
    this.pendingDoorEdge,
    Map<int, int>? roomCarpetAssignments,
    List<CarpetProduct>? carpetProducts,
    Map<int, List<double>>? roomCarpetSeamOverrides,
  })  : completedRooms = completedRooms ?? [],
        measurePointsWorld = measurePointsWorld ?? [],
        placedDimensions = placedDimensions ?? [],
        openings = openings ?? [],
        roomCarpetAssignments = roomCarpetAssignments ?? const {},
        carpetProducts = carpetProducts ?? const [],
        roomCarpetSeamOverrides = roomCarpetSeamOverrides ?? const {};
}

/// Custom painter for the plan canvas (rooms, draft, grid, dimensions, etc.).
class PlanPainter extends CustomPainter {
  final PlanPaintModel m;

  PlanPainter(this.m);

  @override
  void paint(Canvas canvas, Size size) {
    // Wrap entire paint method in try-catch to prevent red screen on errors
    try {
      // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

      // Floor plan background image (world-space: origin + size from effective scale)
      if (m.backgroundImage != null && m.backgroundImageState != null) {
        final scale = m.backgroundImageState!.effectiveScaleMmPerPixel;
        final ox = m.backgroundImageState!.offsetX;
        final oy = m.backgroundImageState!.offsetY;
        final wMm = m.backgroundImage!.width * scale;
        final hMm = m.backgroundImage!.height * scale;
        final tl = m.vp.worldToScreen(Offset(ox, oy));
        final tr = m.vp.worldToScreen(Offset(ox + wMm, oy));
        final br = m.vp.worldToScreen(Offset(ox + wMm, oy + hMm));
        final bl = m.vp.worldToScreen(Offset(ox, oy + hMm));
        final minX = math.min(math.min(tl.dx, tr.dx), math.min(bl.dx, br.dx));
        final minY = math.min(math.min(tl.dy, tr.dy), math.min(bl.dy, br.dy));
        final maxX = math.max(math.max(tl.dx, tr.dx), math.max(bl.dx, br.dx));
        final maxY = math.max(math.max(tl.dy, tr.dy), math.max(bl.dy, br.dy));
        final destRect = Rect.fromLTRB(minX, minY, maxX, maxY);
        final srcRect = Rect.fromLTWH(0, 0, m.backgroundImage!.width.toDouble(), m.backgroundImage!.height.toDouble());
        final paint = Paint()..color = Color.fromRGBO(255, 255, 255, m.backgroundImageState!.opacity);
        canvas.drawImageRect(m.backgroundImage!, srcRect, destRect, paint);
      }

      // Draw completed rooms (filled polygons with outline) first
      // Defensive check: ensure m.completedRooms is a valid, iterable list
      // This handles hot reload issues where the list might become non-iterable or undefined
      try {
        // First check if m.completedRooms exists and is not null/undefined
        if (m.completedRooms == null) {
          debugPrint('Warning: m.completedRooms is null');
          // Continue to draw draft room even if m.completedRooms is null
        } else {
          // Check if it's actually a list and has items
          try {
            final length = m.completedRooms.length;
            if (length > 0) {
              // Use indexed iteration as it's more reliable on web
              for (int i = 0; i < length; i++) {
                try {
                  final room = m.completedRooms[i];
                  if (room != null && room.vertices.isNotEmpty) {
                    _drawRoom(
                      canvas,
                      room,
                      roomIndex: i,
                      isDraft: false,
                      isSelected: i == m.selectedRoomIndex,
                      hasCarpet: m.roomCarpetAssignments.containsKey(i),
                      stripLayout: _getStripLayoutForRoom(i, room),
                    );
                    _drawRoomVertices(canvas, room, roomIndex: i);
                  }
                } catch (e) {
                  // Skip invalid rooms during hot reload
                  debugPrint('Error drawing room at index $i: $e');
                }
              }
            }
          } catch (e) {
            // If we can't access length, try for-in as fallback
            debugPrint('Indexed access failed, trying for-in: $e');
            try {
              int index = 0;
              for (final room in m.completedRooms) {
                try {
                    if (room != null && room.vertices.isNotEmpty) {
                      _drawRoom(
                        canvas,
                        room,
                        roomIndex: index,
                        isDraft: false,
                        isSelected: index == m.selectedRoomIndex,
                        hasCarpet: m.roomCarpetAssignments.containsKey(index),
                        stripLayout: _getStripLayoutForRoom(index, room),
                      );
                      _drawRoomVertices(canvas, room, roomIndex: index);
                      index++;
                    }
                } catch (e) {
                  debugPrint('Error drawing room: $e');
                }
              }
            } catch (e2) {
              debugPrint('For-in also failed: $e2');
            }
          }
        }
      } catch (e) {
        // Handle case where m.completedRooms is not accessible at all (hot reload issue)
        debugPrint('Error accessing m.completedRooms: $e');
      }

      // Draw door-edge interaction points (gap start/end) so users can snap or start drawing from them
      _drawDoorEdgePoints(canvas);

      // Highlight pending door edge and show preview gap when placing a door
      if (m.pendingDoorEdge != null) _drawPendingDoorPreview(canvas);

      // Draw draft room (vertices and lines, with preview)
      try {
        if (m.draftRoomVertices != null && m.draftRoomVertices!.isNotEmpty) {
          _drawDraftRoom(canvas);
        }
      } catch (e) {
        debugPrint('Error drawing draft room: $e');
      }

      // Draw inline alignment guide when snapping a new wall to an existing vertex.
      if (m.draftRoomVertices != null &&
          m.inlineGuideStartWorld != null &&
          m.inlineGuideEndWorld != null) {
        _drawInlineGuide(canvas);
      }

      // Draw grid on top so it is always visible when enabled
      if (m.showGrid && size.width > 0 && size.height > 0) {
        _drawGrid(canvas, size);
      }

      // Placed dimensions (permanent)
      for (final d in m.placedDimensions) {
        final startScreen = m.vp.worldToScreen(d.fromMm);
        final endScreen = m.vp.worldToScreen(d.toMm);
        final distanceMm = (d.toMm - d.fromMm).distance;
        _drawDimension(canvas, startScreen, endScreen, distanceMm, isDashed: true);
      }

      // Measure mode: straight dotted line (2 points) or bent dotted polyline (3+ points)
      if (m.isMeasureMode && (m.measurePointsWorld.isNotEmpty || m.measureCurrentWorld != null)) {
        _drawMeasureLine(canvas);
      }

      // Add dimension mode: preview line from first point to hover
      if (m.isAddDimensionMode && m.addDimensionP1World != null && m.hoverPositionWorldMm != null) {
        final startScreen = m.vp.worldToScreen(m.addDimensionP1World!);
        final endScreen = m.vp.worldToScreen(m.hoverPositionWorldMm!);
        final distanceMm = (m.hoverPositionWorldMm! - m.addDimensionP1World!).distance;
        _drawDimension(canvas, startScreen, endScreen, distanceMm, isTemporary: true);
      } else if (m.isAddDimensionMode && m.addDimensionP1World != null) {
        final p1Screen = m.vp.worldToScreen(m.addDimensionP1World!);
        final dotPaint = Paint()
          ..color = Colors.teal
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1Screen, 6, dotPaint);
      }

      // Calibration overlay (two tapped points + line)
      if (m.calibrationP1Screen != null) {
        final p1 = m.calibrationP1Screen!;
        final paintPts = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1, 6, paintPts);

        if (m.calibrationP2Screen != null) {
          final p2 = m.calibrationP2Screen!;
          canvas.drawCircle(p2, 6, paintPts);
          final linePaint = Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawLine(p1, p2, linePaint);
        }

        // Hint text
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Calibrate: tap 2 points',
            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, const Offset(12, 12));
      }
    } catch (e, stackTrace) {
      // Last resort: draw error message instead of crashing
      debugPrint('Critical error in paint: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Draw a simple error indicator
      final errorPaint = Paint()..color = Colors.red.withOpacity(0.3);
      canvas.drawRect(Offset.zero & size, errorPaint);
      
      // Try to draw text (might fail, but worth trying)
      try {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Rendering error - please restart the app',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(20, 20));
      } catch (_) {
        // Ignore text rendering errors
      }
    }
  }

  /// When placing a door, highlight the selected wall and show a preview gap (center, 900mm).
  void _drawPendingDoorPreview(Canvas canvas) {
    final pending = m.pendingDoorEdge!;
    if (pending.roomIndex < 0 || pending.roomIndex >= m.completedRooms.length) return;
    final room = m.completedRooms[pending.roomIndex];
    final verts = room.vertices;
    if (pending.edgeIndex >= verts.length) return;
    final i1 = (pending.edgeIndex + 1) % verts.length;
    final v0 = verts[pending.edgeIndex];
    final v1 = verts[i1];
    final edgeLen = pending.edgeLenMm;
    if (edgeLen <= 0) return;
    final p0 = m.vp.worldToScreen(v0);
    final p1 = m.vp.worldToScreen(v1);
    final highlightPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p0, p1, highlightPaint);
    const previewWidthMm = 900.0;
    final offsetMm = ((edgeLen - previewWidthMm) / 2).clamp(0.0, edgeLen - previewWidthMm);
    final t0 = offsetMm / edgeLen;
    final t1 = (offsetMm + previewWidthMm) / edgeLen;
    final gapStart = Offset(v0.dx + t0 * (v1.dx - v0.dx), v0.dy + t0 * (v1.dy - v0.dy));
    final gapEnd = Offset(v0.dx + t1 * (v1.dx - v0.dx), v0.dy + t1 * (v1.dy - v0.dy));
    final g0 = m.vp.worldToScreen(gapStart);
    final g1 = m.vp.worldToScreen(gapEnd);
    final gapPaint = Paint()
      ..color = Colors.orange.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(g0, g1, gapPaint);
  }

  /// Draw small handles at each door opening endpoint so they are visible as interaction points.
  void _drawDoorEdgePoints(Canvas canvas) {
    const radius = 5.0;
    final fillPaint = Paint()
      ..color = Colors.brown.shade600
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final o in m.openings) {
      if (o.roomIndex < 0 || o.roomIndex >= m.completedRooms.length) continue;
      final room = m.completedRooms[o.roomIndex];
      final verts = room.vertices;
      if (o.edgeIndex >= verts.length) continue;
      final i1 = (o.edgeIndex + 1) % verts.length;
      final v0 = verts[o.edgeIndex];
      final v1 = verts[i1];
      final edgeLen = (v1 - v0).distance;
      if (edgeLen <= 0) continue;
      final t0 = (o.offsetMm / edgeLen).clamp(0.0, 1.0);
      final t1 = ((o.offsetMm + o.widthMm) / edgeLen).clamp(0.0, 1.0);
      final gapStart = Offset(v0.dx + t0 * (v1.dx - v0.dx), v0.dy + t0 * (v1.dy - v0.dy));
      final gapEnd = Offset(v0.dx + t1 * (v1.dx - v0.dx), v0.dy + t1 * (v1.dy - v0.dy));
      for (final world in [gapStart, gapEnd]) {
        final screen = m.vp.worldToScreen(world);
        canvas.drawCircle(screen, radius, fillPaint);
        canvas.drawCircle(screen, radius, strokePaint);
      }
    }
  }

  void _drawCarpetRollArrow(Canvas canvas, Room room, StripLayout layout) {
    if (layout.numStrips < 1 || layout.rollWidthMm <= 0) return;

    // Simple line arrow: shaft + two lines for arrowhead
    const shaftLenMm = 350.0;
    const headLenMm = 80.0;
    const headWidthMm = 60.0;

    final linePaint = Paint()
      ..color = Colors.brown.shade800.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final angleRad = layout.layAngleDeg * math.pi / 180;
    final cos = math.cos(angleRad);
    final sin = math.sin(angleRad);
    Offset rotate(Offset p) => Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos);

    // Perpendicular extent of room (direction strips are stacked)
    final perpLen = layout.layAlongX ? layout.bboxHeight : layout.bboxWidth;

    for (int i = 0; i < layout.numStrips; i++) {
      final stripStart = i * layout.rollWidthMm;
      final stripEnd = ((i + 1) * layout.rollWidthMm).clamp(0.0, perpLen);
      final stripCenterPerp = (stripStart + stripEnd) / 2;

      final center = layout.layAlongX
          ? Offset(
              layout.bboxMinX + layout.bboxWidth / 2,
              layout.bboxMinY + stripCenterPerp,
            )
          : Offset(
              layout.bboxMinX + stripCenterPerp,
              layout.bboxMinY + layout.bboxHeight / 2,
            );

      // Shaft: base to tip (local coords: base at -shaftLen, tip at +shaftLen)
      final baseWorld = center + rotate(Offset(-shaftLenMm, 0));
      final tipWorld = center + rotate(Offset(shaftLenMm, 0));
      canvas.drawLine(
        m.vp.worldToScreen(baseWorld),
        m.vp.worldToScreen(tipWorld),
        linePaint,
      );

      // Arrowhead: two lines from tip going back and out
      final headL = center + rotate(Offset(shaftLenMm - headLenMm, headWidthMm));
      final headR = center + rotate(Offset(shaftLenMm - headLenMm, -headWidthMm));
      canvas.drawLine(m.vp.worldToScreen(tipWorld), m.vp.worldToScreen(headL), linePaint);
      canvas.drawLine(m.vp.worldToScreen(tipWorld), m.vp.worldToScreen(headR), linePaint);
    }
  }

  void _drawCarpetStrips(Canvas canvas, Room room, StripLayout layout) {
    if (layout.rollWidthMm <= 0 || layout.numStrips < 2) return;
    final verts = room.vertices;
    if (verts.length < 3) return;

    // Blue dotted line = end of each carpet strip width
    final stripPaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Boundaries: use seam positions (from reference); works for both auto and overridden layout.
    final positions = layout.seamPositionsFromReferenceMm;
    for (int i = 0; i < positions.length; i++) {
      final perpOffset = positions[i];
      Offset p1World;
      Offset p2World;
      if (layout.layAlongX) {
        // Strips run horizontal; boundaries are horizontal (constant Y)
        final y = layout.bboxMinY + perpOffset;
        p1World = Offset(layout.bboxMinX, y);
        p2World = Offset(layout.bboxMinX + layout.bboxWidth, y);
      } else {
        // Strips run vertical; boundaries are vertical (constant X)
        final x = layout.bboxMinX + perpOffset;
        p1World = Offset(x, layout.bboxMinY);
        p2World = Offset(x, layout.bboxMinY + layout.bboxHeight);
      }
      final p1Screen = m.vp.worldToScreen(p1World);
      final p2Screen = m.vp.worldToScreen(p2World);
      _drawDashedLine(canvas, p1Screen, p2Screen, stripPaint,
          dashLength: 4, gapLength: 5);
    }
  }

  StripLayout? _getStripLayoutForRoom(int roomIndex, Room room) {
    final productIndex = m.roomCarpetAssignments[roomIndex];
    if (productIndex == null ||
        productIndex < 0 ||
        productIndex >= m.carpetProducts.length) return null;
    final product = m.carpetProducts[productIndex];
    if (product.rollWidthMm <= 0) return null;
    final seamOverride = m.roomCarpetSeamOverrides[roomIndex];
    final opts = CarpetLayoutOptions(
      minStripWidthMm: product.minStripWidthMm ?? 100,
      trimAllowanceMm: product.trimAllowanceMm ?? 75,
      patternRepeatMm: product.patternRepeatMm ?? 0,
      wasteAllowancePercent: 5,
      openings: m.openings,
      roomIndex: roomIndex,
      seamPositionsOverrideMm: seamOverride?.isNotEmpty == true ? seamOverride : null,
    );
    return RollPlanner.computeLayout(room, product.rollWidthMm, opts);
  }

  /// Draw a completed room as wall lines only (no fill). Walls in neutral dark color.
  /// When [hasCarpet] is true, draw a subtle fill to indicate carpet assignment.
  /// When [stripLayout] is provided, draw strip boundary lines.
  void _drawRoom(Canvas canvas, Room room, {
    required int roomIndex,
    required bool isDraft,
    bool isSelected = false,
    bool hasCarpet = false,
    StripLayout? stripLayout,
  }) {
    if (room.vertices.isEmpty) return;

    final screenPoints = room.vertices
        .map((v) => m.vp.worldToScreen(v))
        .toList();

    // Optional carpet tint (light fill) when room has a product assigned
    if (hasCarpet && screenPoints.length >= 3) {
      final path = Path()..addPolygon(screenPoints, true);
      final carpetFill = Paint()
        ..color = Colors.brown.shade100.withOpacity(0.35)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, carpetFill);
    }

    // Strip lines (Phase 3) - draw boundaries between carpet strips
    if (stripLayout != null &&
        stripLayout.numStrips > 1 &&
        room.vertices.length >= 3) {
      _drawCarpetStrips(canvas, room, stripLayout);
    }

    // Roll direction arrow - shows which way to roll the carpet
    if (stripLayout != null && stripLayout.numStrips > 0 && room.vertices.length >= 3) {
      _drawCarpetRollArrow(canvas, room, stripLayout);
    }

    // Outline - visible stroke. Use project wall width in mm, converted to pixels.
    final wallColor = isSelected ? Colors.orange.shade700 : const Color(0xFF2C2C2C);
    final baseStrokePx = (m.wallWidthMm / m.vp.mmPerPx).clamp(1.0, 80.0).toDouble();
    final strokeWidth = isSelected ? baseStrokePx * 1.25 : baseStrokePx;
    final outlinePaint = Paint()
      ..color = wallColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    final n = room.vertices.length;
    for (int i = 0; i < n; i++) {
      final i1 = (i + 1) % n;
      final v0 = room.vertices[i];
      final v1 = room.vertices[i1];
      final p0 = m.vp.worldToScreen(v0);
      final p1 = m.vp.worldToScreen(v1);
      final edgeLenMm = (v1 - v0).distance;
      if (edgeLenMm <= 0) continue;

      Opening? openingOnEdge;
      for (final o in m.openings) {
        if (o.roomIndex == roomIndex && o.edgeIndex == i) {
          openingOnEdge = o;
          break;
        }
      }
      if (openingOnEdge == null) {
        canvas.drawLine(p0, p1, outlinePaint);
        continue;
      }

      final offsetMm = openingOnEdge.offsetMm.clamp(0.0, edgeLenMm);
      final widthMm = openingOnEdge.widthMm.clamp(0.0, edgeLenMm - offsetMm);
      final t0 = offsetMm / edgeLenMm;
      final t1 = (offsetMm + widthMm) / edgeLenMm;
      final gapStart = Offset(v0.dx + t0 * (v1.dx - v0.dx), v0.dy + t0 * (v1.dy - v0.dy));
      final gapEnd = Offset(v0.dx + t1 * (v1.dx - v0.dx), v0.dy + t1 * (v1.dy - v0.dy));
      final gapStartScreen = m.vp.worldToScreen(gapStart);
      final gapEndScreen = m.vp.worldToScreen(gapEnd);

      canvas.drawLine(p0, gapStartScreen, outlinePaint);
      canvas.drawLine(gapEndScreen, p1, outlinePaint);

      if (openingOnEdge.isDoor) {
        final doorPaint = Paint()
          ..color = Colors.brown.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.miter;
        final gapMid = m.vp.worldToScreen(Offset(
          (gapStart.dx + gapEnd.dx) / 2,
          (gapStart.dy + gapEnd.dy) / 2,
        ));
        final gapVec = gapEndScreen - gapStartScreen;
        final radius = (gapVec.distance / 2).clamp(4.0, 40.0);
        final rect = Rect.fromCircle(center: gapMid, radius: radius);
        canvas.drawArc(rect, 0, math.pi / 2, false, doorPaint);
      }
    }

    _drawRoomLabel(canvas, room, screenPoints);
    
    // Draw wall measurements/dimensions
    _drawWallMeasurements(canvas, room, screenPoints);
  }
  
  /// Polygon area centroid – lies inside the polygon (e.g. L-shapes), unlike vertex centroid.
  Offset _getPolygonAreaCentroid(List<Offset> points) {
    if (points.length < 3) return Offset.zero;
    final pts = points.length > 1 && points.first == points.last
        ? points.sublist(0, points.length - 1)
        : points;
    if (pts.length < 3) return pts.first;
    double signedArea = 0;
    double cx = 0;
    double cy = 0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      final cross = pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
      signedArea += cross;
      cx += (pts[i].dx + pts[j].dx) * cross;
      cy += (pts[i].dy + pts[j].dy) * cross;
    }
    signedArea *= 0.5;
    if (signedArea.abs() < 1e-9) {
      double sx = 0, sy = 0;
      for (final p in pts) { sx += p.dx; sy += p.dy; }
      return Offset(sx / pts.length, sy / pts.length);
    }
    cx /= (6 * signedArea);
    cy /= (6 * signedArea);
    return Offset(cx, cy);
  }

  /// Draw room name when set, or the name button (tap to add name) when no name. Area only in sidemenu.
  void _drawRoomLabel(Canvas canvas, Room room, List<Offset> screenPoints) {
    if (screenPoints.length < 3) return;
    final center = _getPolygonAreaCentroid(screenPoints);

    if (room.name != null && room.name!.isNotEmpty) {
      final namePainter = TextPainter(
        text: TextSpan(
          text: room.name!,
          style: const TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      namePainter.layout();
      namePainter.paint(
        canvas,
        Offset(center.dx - namePainter.width / 2, center.dy - namePainter.height / 2),
      );
      return;
    }
    _drawNameButton(canvas, center);
  }
  
  /// Draw area label with prominent background for better visibility.
  void _drawAreaLabel(Canvas canvas, Offset center, String areaText, {double offsetY = 0}) {
    final areaPainter = TextPainter(
      text: TextSpan(
        text: areaText,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    areaPainter.layout();
    
    // Draw background box for better readability
    final padding = 6.0;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - areaPainter.width / 2 - padding,
        center.dy + offsetY - areaPainter.height / 2 - padding,
        areaPainter.width + padding * 2,
        areaPainter.height + padding * 2,
      ),
      const Radius.circular(4),
    );
    
    // Draw white background with slight transparency
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(boxRect, backgroundPaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(boxRect, borderPaint);
    
    // Draw area text
    areaPainter.paint(
      canvas,
      Offset(
        center.dx - areaPainter.width / 2,
        center.dy + offsetY - areaPainter.height / 2,
      ),
    );
  }
  
  /// Draw a clickable button icon for naming/renaming the room.
  void _drawNameButton(Canvas canvas, Offset center) {
    // Draw button background circle
    final buttonPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, buttonPaint);
    
    // Draw button border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 20, borderPaint);
    
    // Draw "+" icon or edit icon (simple plus sign for "add name")
    final iconPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    // Draw plus sign
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      iconPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      iconPaint,
    );
  }

  /// Draw measurements on each wall segment of the room.
  void _drawWallMeasurements(Canvas canvas, Room room, List<Offset> screenPoints) {
    if (room.vertices.length < 2) return;
    
    // Get unique vertices (skip closing vertex if duplicate)
    final uniqueVertices = room.vertices.length > 1 && 
                           room.vertices.first == room.vertices.last
        ? room.vertices.sublist(0, room.vertices.length - 1)
        : room.vertices;
    
    final uniqueScreenPoints = screenPoints.length > 1 && 
                                screenPoints.first == screenPoints.last
        ? screenPoints.sublist(0, screenPoints.length - 1)
        : screenPoints;
    
    if (uniqueVertices.length < 2) return;
    
    // Draw dimension for each wall segment
    for (int i = 0; i < uniqueVertices.length; i++) {
      final j = (i + 1) % uniqueVertices.length;
      final startWorld = uniqueVertices[i];
      final endWorld = uniqueVertices[j];
      final startScreen = uniqueScreenPoints[i];
      final endScreen = uniqueScreenPoints[j];
      
      // Calculate distance in mm
      final distanceMm = (endWorld - startWorld).distance;
      
      // Only draw if wall is long enough to display measurement
      final screenDistance = (endScreen - startScreen).distance;
      if (screenDistance < 50) continue; // Skip very short walls
      
      _drawDimension(canvas, startScreen, endScreen, distanceMm);
    }
  }
  
  /// Draw vertices for a completed room with visual feedback for selection/hover.
  void _drawRoomVertices(Canvas canvas, Room room, {required int roomIndex}) {
    // Use unique vertices (skip closing vertex if duplicate)
    final uniqueVertices = room.vertices.length > 1 && 
                          room.vertices.first == room.vertices.last
        ? room.vertices.sublist(0, room.vertices.length - 1)
        : room.vertices;
    
    for (int vertexIdx = 0; vertexIdx < uniqueVertices.length; vertexIdx++) {
      final vertexScreen = m.vp.worldToScreen(uniqueVertices[vertexIdx]);
      
      // Determine if this vertex is selected or hovered
      final isSelected = m.selectedVertex != null &&
                        m.selectedVertex!.roomIndex == roomIndex &&
                        m.selectedVertex!.vertexIndex == vertexIdx;
      final isHovered = m.hoveredVertex != null &&
                       m.hoveredVertex!.roomIndex == roomIndex &&
                       m.hoveredVertex!.vertexIndex == vertexIdx;
      
      // Draw vertex circle
      final radius = isSelected ? 8.0 : (isHovered ? 7.0 : 6.0);
      final color = isSelected 
          ? Colors.orange 
          : (isHovered ? Colors.orange.withOpacity(0.7) : Colors.blue);
      
      // Outer ring for better visibility
      canvas.drawCircle(
        vertexScreen,
        radius + 1,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      
      // Main vertex circle
      canvas.drawCircle(
        vertexScreen,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      
      // Inner highlight for selected
      if (isSelected) {
        canvas.drawCircle(
          vertexScreen,
          radius * 0.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
      }
    }
  }
  
  /// Draw measure mode: straight dotted line (2 points) or bent dotted polyline (3+ points) with total length.
  void _drawMeasureLine(Canvas canvas) {
    final points = List<Offset>.from(m.measurePointsWorld);
    if (m.measureCurrentWorld != null) points.add(m.measureCurrentWorld!);
    if (points.isEmpty) return;

    final teal = Colors.teal;
    final dotPaint = Paint()..color = teal..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw dots at each point
    for (final p in points) {
      canvas.drawCircle(m.vp.worldToScreen(p), 6, dotPaint);
    }

    if (points.length < 2) return;

    double totalMm = 0;
    final screenPts = points.map((p) => m.vp.worldToScreen(p)).toList();

    // Draw dotted segments between consecutive points
    for (int i = 0; i < screenPts.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      totalMm += (b - a).distance;
      _drawDashedLine(canvas, screenPts[i], screenPts[i + 1], linePaint);
    }

    // Label: total distance
    final measurementText = UnitConverter.formatDistance(totalMm, useImperial: m.useImperial);
    final label = points.length > 2 ? 'Total: $measurementText' : measurementText;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: teal.shade700,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white.withOpacity(0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position label at midpoint of path (or last segment for bent)
    Offset labelPos;
    if (screenPts.length == 2) {
      labelPos = Offset(
        (screenPts[0].dx + screenPts[1].dx) / 2,
        (screenPts[0].dy + screenPts[1].dy) / 2,
      );
    } else {
      labelPos = screenPts.last;
    }
    textPainter.paint(
      canvas,
      labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  /// Draw a dashed/dotted line between two points (for temporary dimension styling).
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      {double dashLength = 5, double gapLength = 4}) {
    final path = Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final segmentLength =
            (distance + dashLength <= metric.length) ? dashLength : metric.length - distance;
        if (segmentLength > 0) {
          final segment = metric.extractPath(distance, distance + segmentLength);
          canvas.drawPath(segment, paint);
        }
        distance += dashLength + gapLength;
      }
    }
  }

  /// Draw a subtle guide line indicating that the preview endpoint is inline
  /// (horizontally or vertically) with another vertex.
  void _drawInlineGuide(Canvas canvas) {
    final startWorld = m.inlineGuideStartWorld;
    final endWorld = m.inlineGuideEndWorld;
    if (startWorld == null || endWorld == null) return;

    final start = m.vp.worldToScreen(startWorld);
    final end = m.vp.worldToScreen(endWorld);

    final paint = Paint()
      ..color = Colors.purpleAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawDashedLine(canvas, start, end, paint, dashLength: 6, gapLength: 4);
  }

  /// Draw a dimension line with measurement text for a wall segment.
  /// When [isTemporary] is true, uses teal color and dotted lines for measure/add-dimension preview.
  /// When [isDashed] is true (e.g. permanent placed dimensions), uses grey color and dotted lines.
  void _drawDimension(Canvas canvas, Offset start, Offset end, double distanceMm, {bool isTemporary = false, bool isDashed = false}) {
    // Calculate midpoint and perpendicular offset for dimension line
    final midpoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final wallVector = end - start;
    final wallLength = wallVector.distance;
    if (wallLength == 0) return;
    
    // Perpendicular direction (rotate 90 degrees)
    final perp = Offset(-wallVector.dy / wallLength, wallVector.dx / wallLength);
    
    // Offset distance from wall (20 pixels)
    final offsetDistance = 20.0;
    final dimensionLineStart = midpoint + perp * offsetDistance;
    final dimensionLineEnd = midpoint - perp * offsetDistance;
    
    final lineColor = isTemporary ? Colors.teal : Colors.grey.withOpacity(0.6);
    final extColor = isTemporary ? Colors.teal.withOpacity(0.6) : Colors.grey.withOpacity(0.4);
    final useDashed = isTemporary || isDashed;
    
    // Draw dimension line (perpendicular to wall)
    final dimLinePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTemporary ? 2 : 1;
    if (useDashed) {
      _drawDashedLine(canvas, dimensionLineStart, dimensionLineEnd, dimLinePaint);
    } else {
      canvas.drawLine(dimensionLineStart, dimensionLineEnd, dimLinePaint);
    }
    
    // Draw extension lines (from wall to dimension line)
    final extLinePaint = Paint()
      ..color = extColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTemporary ? 1 : 0.5;
    if (useDashed) {
      _drawDashedLine(canvas, start, dimensionLineStart, extLinePaint);
      _drawDashedLine(canvas, end, dimensionLineStart, extLinePaint);
    } else {
      canvas.drawLine(start, dimensionLineStart, extLinePaint);
      canvas.drawLine(end, dimensionLineStart, extLinePaint);
    }
    
    // Format measurement text
    final measurementText = UnitConverter.formatDistance(distanceMm, useImperial: m.useImperial);
    
    // Draw measurement text
    final textPainter = TextPainter(
      text: TextSpan(
        text: measurementText,
        style: TextStyle(
          color: isTemporary ? Colors.teal.shade700 : Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    // Position text at dimension line, rotated to match wall angle
    final wallAngle = math.atan2(wallVector.dy, wallVector.dx);
    final textOffset = dimensionLineStart - Offset(textPainter.width / 2, textPainter.height / 2);
    
    canvas.save();
    canvas.translate(textOffset.dx + textPainter.width / 2, textOffset.dy + textPainter.height / 2);
    canvas.rotate(wallAngle);
    canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// Draw visual arc showing the angle between two lines.
  /// [vertexScreen] is the corner point; [prevScreen] and [nextScreen] are the two adjacent points.
  /// Arc is drawn from the first line to the second line so it always connects both.
  void _drawAngleArc(Canvas canvas, Offset vertexScreen, Offset prevScreen, Offset nextScreen, double angleDeg) {
    final toPrev = prevScreen - vertexScreen;
    final toNext = nextScreen - vertexScreen;
    final d1 = math.sqrt(toPrev.dx * toPrev.dx + toPrev.dy * toPrev.dy);
    final d2 = math.sqrt(toNext.dx * toNext.dx + toNext.dy * toNext.dy);
    if (d1 < 1e-6 || d2 < 1e-6) return;
    
    // Normalize direction vectors (pointing away from vertex along each line)
    final dir1 = Offset(toPrev.dx / d1, toPrev.dy / d1);
    final dir2 = Offset(toNext.dx / d2, toNext.dy / d2);
    
    // Angles in radians: direction of each line from the vertex
    final angle1 = math.atan2(dir1.dy, dir1.dx);
    final angle2 = math.atan2(dir2.dy, dir2.dx);
    
    // Sweep from angle1 to angle2 (normalized to (-π, π]) so the arc connects both lines exactly
    double sweep = angle2 - angle1;
    while (sweep > math.pi) sweep -= 2 * math.pi;
    while (sweep < -math.pi) sweep += 2 * math.pi;
    
    final startAngle = angle1;
    
    // Arc radius (visual size)
    const arcRadius = 18.0;
    
    // Create bounding rect for arc (centered at vertex)
    final rect = Rect.fromCircle(center: vertexScreen, radius: arcRadius);
    
    // Draw arc - start at angle1, sweep the correct amount
    final arcPaint = Paint()
      ..color = Colors.blue.shade600.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);
    
    // Draw small lines from vertex to the actual line directions (at arc radius)
    // These lines connect the vertex to where the arc should start/end on the actual lines
    final linePaint = Paint()
      ..color = Colors.blue.shade600.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // Line 1: from vertex along dir1 (first line direction)
    canvas.drawLine(
      vertexScreen,
      Offset(vertexScreen.dx + dir1.dx * arcRadius, vertexScreen.dy + dir1.dy * arcRadius),
      linePaint,
    );
    // Line 2: from vertex along dir2 (second line direction)
    canvas.drawLine(
      vertexScreen,
      Offset(vertexScreen.dx + dir2.dx * arcRadius, vertexScreen.dy + dir2.dy * arcRadius),
      linePaint,
    );
  }

  /// Draw angle label in the space between two lines (at the corner).
  /// [vertexScreen] is the corner point; [prevScreen] and [nextScreen] are the two adjacent points.
  void _drawAngleInCorner(Canvas canvas, Offset vertexScreen, Offset prevScreen, Offset nextScreen, double angleDeg) {
    // Draw visual arc first
    _drawAngleArc(canvas, vertexScreen, prevScreen, nextScreen, angleDeg);
    
    final toPrev = prevScreen - vertexScreen;
    final toNext = nextScreen - vertexScreen;
    final d1 = math.sqrt(toPrev.dx * toPrev.dx + toPrev.dy * toPrev.dy);
    final d2 = math.sqrt(toNext.dx * toNext.dx + toNext.dy * toNext.dy);
    if (d1 < 1e-6 || d2 < 1e-6) return;
    // Bisector from vertex into the corner (between the two segments)
    final out1 = Offset(-toPrev.dx / d1, -toPrev.dy / d1);
    final out2 = Offset(-toNext.dx / d2, -toNext.dy / d2);
    final bisector = Offset(out1.dx + out2.dx, out1.dy + out2.dy);
    final len = math.sqrt(bisector.dx * bisector.dx + bisector.dy * bisector.dy);
    if (len < 1e-6) return;
    const offsetPx = 22.0;
    final pos = Offset(
      vertexScreen.dx + bisector.dx / len * offsetPx,
      vertexScreen.dy + bisector.dy / len * offsetPx,
    );
    final angleText = '${angleDeg.round()}°';
    final textPainter = TextPainter(
      text: TextSpan(
        text: angleText,
        style: TextStyle(
          color: Colors.blue.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white.withOpacity(0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    const pad = 4.0;
    final w = textPainter.width + pad * 2;
    final h = textPainter.height + 2;
    final rect = Rect.fromCenter(center: pos, width: w, height: h);
    canvas.drawRect(rect, Paint()..color = Colors.white.withOpacity(0.95));
    textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2) + const Offset(0, 1));
  }

  /// Draw the draft room with vertices, lines, and preview line to cursor.
  void _drawDraftRoom(Canvas canvas) {
    if (m.draftRoomVertices == null || m.draftRoomVertices!.isEmpty) return;

    final vertices = m.draftRoomVertices!;

    // Draw lines between vertices with measurements
    if (vertices.length > 1) {
      final linePaint = Paint()
        ..color = Colors.blue.shade700.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < vertices.length - 1; i++) {
        final a = m.vp.worldToScreen(vertices[i]);
        final b = m.vp.worldToScreen(vertices[i + 1]);
        canvas.drawLine(a, b, linePaint);
        
        // Draw measurement on each completed segment
        final distanceMm = (vertices[i + 1] - vertices[i]).distance;
        final screenDistance = (b - a).distance;
        if (screenDistance > 50) { // Only draw if segment is long enough
          _drawDimension(canvas, a, b, distanceMm);
        }
      }

      // Draw angle at each interior corner: second segment relative to first, 0–180° either way
      for (int i = 1; i < vertices.length - 1; i++) {
        final prev = m.vp.worldToScreen(vertices[i - 1]);
        final vert = m.vp.worldToScreen(vertices[i]);
        final next = m.vp.worldToScreen(vertices[i + 1]);
        final dir1 = Offset(vertices[i].dx - vertices[i - 1].dx, vertices[i].dy - vertices[i - 1].dy);
        final dir2 = Offset(vertices[i + 1].dx - vertices[i].dx, vertices[i + 1].dy - vertices[i].dy);
        final l1 = math.sqrt(dir1.dx * dir1.dx + dir1.dy * dir1.dy);
        final l2 = math.sqrt(dir2.dx * dir2.dx + dir2.dy * dir2.dy);
        if (l1 >= 1e-6 && l2 >= 1e-6) {
          final angle1 = math.atan2(dir1.dy, dir1.dx);
          final angle2 = math.atan2(dir2.dy, dir2.dx);
          double diffRad = angle2 - angle1;
          while (diffRad < 0) diffRad += 2 * math.pi;
          while (diffRad >= 2 * math.pi) diffRad -= 2 * math.pi;
          double angleDeg = diffRad * (180.0 / math.pi);
          if (angleDeg > 180.0) angleDeg = 360.0 - angleDeg;
          // Display complementary angle (e.g. 9° → 171°)
          angleDeg = 180.0 - angleDeg;
          _drawAngleInCorner(canvas, vert, prev, next, angleDeg);
        }
      }
    }

    // Draw preview line from current drawing endpoint to cursor
    if (m.hoverPositionWorldMm != null && vertices.isNotEmpty) {
      final lastWorld = m.drawFromStart ? vertices.first : vertices.last;
      final lastScreen = m.vp.worldToScreen(lastWorld);
      final hoverScreen = m.vp.worldToScreen(m.hoverPositionWorldMm!);
      final distanceMm = (m.hoverPositionWorldMm! - lastWorld).distance;
      
      final previewPaint = Paint()
        ..color = Colors.blue.shade700.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      // Solid preview line (more visible than dashed)
      canvas.drawLine(lastScreen, hoverScreen, previewPaint);
      
      if (m.previewLineAngleDeg != null && vertices.length >= 2) {
        final prevWorld = m.drawFromStart ? vertices[1] : vertices[vertices.length - 2];
        final prevScreen = m.vp.worldToScreen(prevWorld);
        _drawAngleInCorner(canvas, lastScreen, prevScreen, hoverScreen, m.previewLineAngleDeg!);
      }
      
      // Draw live measurement on the preview line
      if (m.isDragging && distanceMm > 10) {
        // Only show if dragging and segment is meaningful length
        final measurementText = UnitConverter.formatDistance(distanceMm, useImperial: m.useImperial);
        
        // Calculate midpoint of preview line
        final midpoint = Offset(
          (lastScreen.dx + hoverScreen.dx) / 2,
          (lastScreen.dy + hoverScreen.dy) / 2,
        );
        
        // Draw measurement text with background
        final textPainter = TextPainter(
          text: TextSpan(
            text: measurementText,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              backgroundColor: Colors.white.withOpacity(0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        
        textPainter.layout();
        
        // Position text at midpoint, rotated to match line angle
        final lineVector = hoverScreen - lastScreen;
        final lineAngle = math.atan2(lineVector.dy, lineVector.dx);
        
        canvas.save();
        canvas.translate(midpoint.dx, midpoint.dy);
        canvas.rotate(lineAngle);
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
      
      // Draw visual feedback for snapped grid point
      // Outer highlight circle (subtle)
      final gridHighlightPaint = Paint()
        ..color = Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hoverScreen, 8, gridHighlightPaint);
      
      // Inner snap indicator (more visible)
      final snapIndicatorPaint = Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hoverScreen, 4, snapIndicatorPaint);
    }

    // Draw vertices as circles
    final vertexPaint = Paint()..color = Colors.blue;
    final startVertexPaint = Paint()..color = Colors.green; // First vertex (first placed) is green
    final drawingFromIndex = m.drawFromStart ? 0 : vertices.length - 1;

    for (int i = 0; i < vertices.length; i++) {
      final screenPos = m.vp.worldToScreen(vertices[i]);
      final paint = (i == 0) ? startVertexPaint : vertexPaint;
      canvas.drawCircle(screenPos, 5, paint);
    }

    // Indicator for "drawing from" vertex: ring + slight emphasis
    if (vertices.length >= 1) {
      final fromScreen = m.vp.worldToScreen(vertices[drawingFromIndex]);
      final ringPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(fromScreen, 9, ringPaint);
      final innerPaint = Paint()..color = Colors.orange.withOpacity(0.3);
      canvas.drawCircle(fromScreen, 7, innerPaint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // World-space grid: spacing scales so ~50–80px between lines on screen
    final targetScreenSpacingPx = 60.0;
    final targetWorldSpacingMm = targetScreenSpacingPx * m.vp.mmPerPx;
    final niceSpacings = [1.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0];
    double gridMm = niceSpacings.last;
    for (final spacing in niceSpacings) {
      if (spacing >= targetWorldSpacingMm * 0.5) {
        gridMm = spacing;
        break;
      }
    }

    final screenSpacingPx = gridMm / m.vp.mmPerPx;
    // Scale stroke with zoom: thinner when zoomed in (dense grid), slightly thicker when zoomed out
    final strokeWidth = (screenSpacingPx / 80).clamp(0.5, 2.0).toDouble();

    final topLeftW = m.vp.screenToWorld(Offset.zero);
    final bottomRightW = m.vp.screenToWorld(Offset(size.width, size.height));
    final minX = math.min(topLeftW.dx, bottomRightW.dx) - gridMm;
    final maxX = math.max(topLeftW.dx, bottomRightW.dx) + gridMm;
    final minY = math.min(topLeftW.dy, bottomRightW.dy) - gridMm;
    final maxY = math.max(topLeftW.dy, bottomRightW.dy) + gridMm;

    double startX = (minX / gridMm).floor() * gridMm;
    double startY = (minY / gridMm).floor() * gridMm;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (double x = startX; x <= maxX; x += gridMm) {
      final a = m.vp.worldToScreen(Offset(x, minY));
      final b = m.vp.worldToScreen(Offset(x, maxY));
      canvas.drawLine(a, b, gridPaint);
    }
    for (double y = startY; y <= maxY; y += gridMm) {
      final a = m.vp.worldToScreen(Offset(minX, y));
      final b = m.vp.worldToScreen(Offset(maxX, y));
      canvas.drawLine(a, b, gridPaint);
    }
  }
  
  /// Format grid spacing as a readable label (e.g., "1 cm", "1 m")
  String _formatGridLabel(double gridMm) {
    if (gridMm >= 10000) {
      return '${(gridMm / 1000).toStringAsFixed(0)} m';
    } else if (gridMm >= 1000) {
      return '${(gridMm / 1000).toStringAsFixed(1)} m';
    } else if (gridMm >= 100) {
      return '${(gridMm / 10).toStringAsFixed(0)} cm';
    } else if (gridMm >= 10) {
      return '${gridMm.toStringAsFixed(0)} cm';
    } else if (gridMm >= 1) {
      return '${gridMm.toStringAsFixed(0)} mm';
    } else {
      return '${(gridMm * 10).toStringAsFixed(0)} mm';
    }
  }

  @override
  bool shouldRepaint(covariant PlanPainter oldDelegate) => true;
}
