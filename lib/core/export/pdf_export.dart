import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../geometry/room.dart';
import '../units/unit_converter.dart';
import '../../ui/canvas/viewport.dart';

/// Service for exporting floor plans to PDF format.
class PdfExportService {
  // PDF uses points (1/72 inch) as units
  // 1 point = 1/72 inch = 0.3528 mm
  static const double mmPerPoint = 0.3528;
  static const double pointPerMm = 1.0 / mmPerPoint;

  /// Export a floor plan to PDF bytes.
  /// 
  /// [rooms] - List of rooms to export
  /// [useImperial] - Whether to use imperial units for measurements
  /// [projectName] - Name of the project (for header)
  /// [viewport] - Optional viewport for calculating initial scale
  /// [includeGrid] - Whether to include grid lines
  /// 
  /// Returns PDF document as bytes.
  static Future<Uint8List> exportToPdf({
    required List<Room> rooms,
    required bool useImperial,
    required String projectName,
    PlanViewport? viewport,
    bool includeGrid = false,
  }) async {
    if (rooms.isEmpty) {
      // Empty project - create a simple PDF with message
      return _createEmptyPdf(projectName);
    }

    // Calculate bounding box of all rooms
    final bbox = _calculateBoundingBox(rooms);
    
    // Page setup: A4 size in points
    // A4 = 210mm × 297mm = 595.28 × 841.89 points
    const pageWidthPt = 595.28; // A4 width in points
    const pageHeightPt = 841.89; // A4 height in points
    const marginPt = 56.69; // 20mm margin on all sides
    
    final contentWidthPt = pageWidthPt - (marginPt * 2);
    final contentHeightPt = pageHeightPt - (marginPt * 2);
    
    // Calculate scale to fit all rooms on page
    final roomWidthMm = bbox.maxX - bbox.minX;
    final roomHeightMm = bbox.maxY - bbox.minY;
    
    final roomWidthPt = roomWidthMm * pointPerMm;
    final roomHeightPt = roomHeightMm * pointPerMm;
    
    // Scale to fit with padding
    final scaleX = contentWidthPt / roomWidthPt;
    final scaleY = contentHeightPt / roomHeightPt;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to add margin
    
    // Calculate offset to center the floor plan
    final scaledWidthPt = roomWidthPt * scale;
    final scaledHeightPt = roomHeightPt * scale;
    final offsetX = (contentWidthPt - scaledWidthPt) / 2 + marginPt;
    final offsetY = (contentHeightPt - scaledHeightPt) / 2 + marginPt;
    
    // Render floor plan to image first (most reliable approach)
    final imageBytes = await _renderFloorPlanToImage(rooms, bbox, scale, useImperial, includeGrid);
    final pdfImage = pw.MemoryImage(imageBytes);
    
    // Create PDF document
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Floor plan as image (centered on page)
              pw.Positioned(
                left: offsetX,
                top: offsetY,
                child: pw.Image(
                  pdfImage,
                  width: scaledWidthPt,
                  height: scaledHeightPt,
                ),
              ),
              
              // Room labels as text widgets (overlay on image)
              ...rooms.map((room) => _buildRoomLabelWidget(room, bbox, useImperial, scale, offsetX, offsetY)),
              
              // Header with project name
              _buildHeader(projectName, useImperial),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  /// Calculate bounding box of all rooms.
  static _BoundingBox _calculateBoundingBox(List<Room> rooms) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final room in rooms) {
      for (final vertex in room.vertices) {
        minX = minX < vertex.dx ? minX : vertex.dx;
        minY = minY < vertex.dy ? minY : vertex.dy;
        maxX = maxX > vertex.dx ? maxX : vertex.dx;
        maxY = maxY > vertex.dy ? maxY : vertex.dy;
      }
    }
    
    // Add padding
    final padding = 100.0; // 100mm padding
    return _BoundingBox(
      minX: minX - padding,
      minY: minY - padding,
      maxX: maxX + padding,
      maxY: maxY + padding,
    );
  }

  /// Render floor plan to image using Flutter's canvas.
  static Future<Uint8List> _renderFloorPlanToImage(
    List<Room> rooms,
    _BoundingBox bbox,
    double scale,
    bool useImperial,
    bool includeGrid,
  ) async {
    // Calculate image size (in pixels, using high DPI for quality)
    const dpi = 300.0; // High resolution for PDF
    const pixelsPerPoint = dpi / 72.0; // PDF uses 72 DPI
    
    final roomWidthMm = bbox.maxX - bbox.minX;
    final roomHeightMm = bbox.maxY - bbox.minY;
    
    // Image size in pixels (scaled)
    final imageWidthPx = (roomWidthMm * pointPerMm * scale * pixelsPerPoint).round();
    final imageHeightPx = (roomHeightMm * pointPerMm * scale * pixelsPerPoint).round();
    
    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(imageWidthPx.toDouble(), imageHeightPx.toDouble());
    
    // Draw background (white)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), 
        Paint()..color = const Color(0xFFFFFFFF));
    
    // Draw grid if enabled
    if (includeGrid) {
      _drawGridOnCanvas(canvas, size, bbox, scale, pixelsPerPoint);
    }
    
    // Draw each room
    for (final room in rooms) {
      _drawRoomOnCanvas(canvas, room, bbox, size, scale, pixelsPerPoint);
    }
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(imageWidthPx, imageHeightPx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  /// Draw grid on Flutter canvas.
  static void _drawGridOnCanvas(Canvas canvas, Size size, _BoundingBox bbox, double scale, double pixelsPerPoint) {
    const gridSpacingMm = 100.0; // 10cm grid
    final gridSpacingPx = gridSpacingMm * pointPerMm * scale * pixelsPerPoint;
    
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    
    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSpacingPx) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSpacingPx) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  
  /// Draw room on Flutter canvas.
  static void _drawRoomOnCanvas(Canvas canvas, Room room, _BoundingBox bbox, Size size, double scale, double pixelsPerPoint) {
    if (room.vertices.isEmpty) return;
    
    // Convert vertices to canvas coordinates
    final path = Path();
    final points = room.vertices.map((vertex) {
      final x = (vertex.dx - bbox.minX) * pointPerMm * scale * pixelsPerPoint;
      final y = (vertex.dy - bbox.minY) * pointPerMm * scale * pixelsPerPoint;
      return Offset(x, y);
    }).toList();
    
    if (points.isEmpty) return;
    
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    
    // Draw fill
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFE3F2FD)
      ..style = PaintingStyle.fill);
    
    // Draw outline
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  /// Build room line widgets using positioned containers (widget-based approach).
  static List<pw.Widget> _buildRoomLineWidgets(
    Room room,
    _BoundingBox bbox,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    if (room.vertices.isEmpty) return [];
    
    final widgets = <pw.Widget>[];
    
    // Convert vertices to PDF page coordinates
    final points = room.vertices.map((vertex) {
      final x = offsetX + (vertex.dx - bbox.minX) * pointPerMm * scale;
      final y = offsetY + (vertex.dy - bbox.minY) * pointPerMm * scale;
      return PdfPoint(x, y);
    }).toList();
    
    // Draw each edge as a positioned container with border
    for (int i = 0; i < points.length; i++) {
      final next = (i + 1) % points.length;
      final p1 = points[i];
      final p2 = points[next];
      
      // Calculate line length and angle
      final dx = p2.x - p1.x;
      final dy = p2.y - p1.y;
      final length = math.sqrt(dx * dx + dy * dy);
      final angle = math.atan2(dy, dx);
      
      if (length > 0 && p1.x.isFinite && p1.y.isFinite && p2.x.isFinite && p2.y.isFinite) {
        // Create a thin container rotated to form the line
        widgets.add(
          pw.Positioned(
            left: p1.x,
            top: p1.y,
            child: pw.Transform.rotate(
              angle: angle,
              child: pw.Container(
                width: length,
                height: 2, // Line thickness
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1976D2), // Blue
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  /// Draw a room on the PDF canvas with fill, outline, measurements, and label.
  static void _drawRoom(
    PdfGraphics canvas,
    Room room,
    _BoundingBox bbox,
    PdfPoint paintSize,
    bool useImperial,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    if (room.vertices.isEmpty) return;
    
    // Convert vertices to PDF coordinates
    // CustomPaint coordinates are relative to the paint area (0,0 to paintSize)
    final points = room.vertices.map((vertex) {
      // Convert from world coordinates (mm) to PDF points relative to bbox
      // Then scale to fit the paint area
      final x = (vertex.dx - bbox.minX) * pointPerMm * scale;
      final y = (vertex.dy - bbox.minY) * pointPerMm * scale;
      return PdfPoint(x, y);
    }).toList();
    
    // Draw room outline
    if (points.length >= 2) {
      // Set stroke color for outline - use a darker blue for visibility
      canvas.setStrokeColor(PdfColor.fromInt(0xFF1976D2)); // Darker blue
      
      // Draw closed polygon outline
      for (int i = 0; i < points.length; i++) {
        final next = (i + 1) % points.length;
        final p1 = points[i];
        final p2 = points[next];
        
        // Draw the line - ensure coordinates are valid
        if (p1.x.isFinite && p1.y.isFinite && p2.x.isFinite && p2.y.isFinite) {
          canvas.drawLine(p1.x, p1.y, p2.x, p2.y);
        }
      }
    }
    
    // Draw wall measurements
    _drawWallMeasurements(canvas, room, points, bbox, useImperial, paintSize);
  }
  
  /// Draw wall measurements for a room.
  static void _drawWallMeasurements(
    PdfGraphics canvas,
    Room room,
    List<PdfPoint> screenPoints,
    _BoundingBox bbox,
    bool useImperial,
    PdfPoint size,
  ) {
    if (room.vertices.length < 2) return;
    
    // Get unique vertices
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
      final distanceMm = math.sqrt(
        math.pow(endWorld.dx - startWorld.dx, 2) + 
        math.pow(endWorld.dy - startWorld.dy, 2)
      );
      
      // Only draw if wall is long enough
      final screenDistance = math.sqrt(
        math.pow(endScreen.x - startScreen.x, 2) + 
        math.pow(endScreen.y - startScreen.y, 2)
      );
      if (screenDistance < 15) continue; // Skip very short walls
      
      // Calculate midpoint
      final midpoint = PdfPoint(
        (startScreen.x + endScreen.x) / 2,
        (startScreen.y + endScreen.y) / 2,
      );
      
      // Calculate perpendicular direction for dimension line
      final dx = endScreen.x - startScreen.x;
      final dy = endScreen.y - startScreen.y;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length == 0) continue;
      
      final perpX = -dy / length;
      final perpY = dx / length;
      const offset = 8.0; // Offset distance from wall (in points)
      
      final dimStart = PdfPoint(
        midpoint.x + perpX * offset,
        midpoint.y + perpY * offset,
      );
      final dimEnd = PdfPoint(
        midpoint.x - perpX * offset,
        midpoint.y - perpY * offset,
      );
      
      // Draw dimension line (only if within bounds)
      if (dimStart.x >= 0 && dimStart.x <= size.x &&
          dimStart.y >= 0 && dimStart.y <= size.y &&
          dimEnd.x >= 0 && dimEnd.x <= size.x &&
          dimEnd.y >= 0 && dimEnd.y <= size.y) {
        canvas.setStrokeColor(PdfColor.fromInt(0xFF757575)); // Grey
        canvas.drawLine(
          dimStart.x,
          dimStart.y,
          dimEnd.x,
          dimEnd.y,
        );
        
        // Draw extension lines (from wall to dimension line)
        canvas.setStrokeColor(PdfColor.fromInt(0xFFBDBDBD)); // Light grey
        canvas.drawLine(
          startScreen.x,
          startScreen.y,
          dimStart.x,
          dimStart.y,
        );
        canvas.drawLine(
          endScreen.x,
          endScreen.y,
          dimEnd.x,
          dimEnd.y,
        );
      }
      
      // Note: Text rendering in CustomPaint is limited, so measurements
      // will be added as overlay widgets in a future enhancement
    }
  }

  /// Build room label as a text widget (overlay on top of drawing).
  static pw.Widget _buildRoomLabelWidget(Room room, _BoundingBox bbox, bool useImperial, double scale, double offsetX, double offsetY) {
    if (room.vertices.isEmpty) return pw.SizedBox.shrink();
    
    // Calculate centroid
    double centerX = 0;
    double centerY = 0;
    for (final vertex in room.vertices) {
      centerX += vertex.dx;
      centerY += vertex.dy;
    }
    centerX /= room.vertices.length;
    centerY /= room.vertices.length;
    
    // Convert to PDF coordinates (with scale and offset)
    final pdfX = offsetX + (centerX - bbox.minX) * pointPerMm * scale;
    final pdfY = offsetY + (centerY - bbox.minY) * pointPerMm * scale;
    
    String labelText;
    if (room.name != null && room.name!.isNotEmpty) {
      final areaText = UnitConverter.formatArea(room.areaMm2, useImperial: useImperial);
      labelText = '${room.name!}\n$areaText';
    } else {
      final areaText = UnitConverter.formatArea(room.areaMm2, useImperial: useImperial);
      labelText = areaText;
    }
    
    return pw.Positioned(
      left: pdfX - 30, // Approximate centering
      top: pdfY - 8,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Text(
          labelText,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF1976D2), // Darker blue for visibility
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// Draw grid lines on the PDF canvas.
  static void _drawGrid(
    PdfGraphics canvas,
    PdfPoint paintSize,
    _BoundingBox bbox,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    const gridSpacingMm = 100.0; // 10cm grid
    final gridSpacingPt = gridSpacingMm * pointPerMm * scale;
    
    canvas.setStrokeColor(PdfColor.fromInt(0xFFE0E0E0)); // Light grey
    
    // Calculate grid bounds in scaled coordinates
    final widthPt = (bbox.maxX - bbox.minX) * pointPerMm * scale;
    final heightPt = (bbox.maxY - bbox.minY) * pointPerMm * scale;
    
    // Vertical lines
    for (double x = 0; x <= widthPt; x += gridSpacingPt) {
      canvas.drawLine(x, 0, x, heightPt);
    }
    
    // Horizontal lines
    for (double y = 0; y <= heightPt; y += gridSpacingPt) {
      canvas.drawLine(0, y, widthPt, y);
    }
  }

  /// Build header with project name.
  static pw.Widget _buildHeader(String projectName, bool useImperial) {
    return pw.Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            projectName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Units: ${useImperial ? "Imperial (ft/in)" : "Metric (mm/cm)"}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Create an empty PDF for projects with no rooms.
  static Future<Uint8List> _createEmptyPdf(String projectName) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  projectName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'No rooms in this project',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }
}

/// Helper class for bounding box calculations.
class _BoundingBox {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  _BoundingBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}
