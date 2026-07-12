import 'package:flutter_test/flutter_test.dart';
import 'package:degrid/core/export/cut_sheet_entries.dart';
import 'package:degrid/core/export/pdf_export.dart';
import 'package:degrid/core/geometry/carpet_product.dart';
import 'package:degrid/core/geometry/room.dart';
import 'package:degrid/core/models/project.dart';
import 'package:degrid/core/quote/job_quote.dart';
import 'package:degrid/core/quote/quote_rates.dart';

/// Simple test to verify PDF export works.
/// 
/// Run with: flutter test test/pdf_export_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF export creates valid PDF with sample rooms', () async {
    // Create sample rooms for testing
    final rooms = [
      Room(
        vertices: [
          const Offset(0, 0),      // Bottom-left
          const Offset(5000, 0),   // Bottom-right (5m)
          const Offset(5000, 4000), // Top-right (5m x 4m)
          const Offset(0, 4000),   // Top-left
        ],
        name: 'Living Room',
      ),
      Room(
        vertices: [
          const Offset(5000, 0),    // Bottom-left
          const Offset(8000, 0),    // Bottom-right (3m)
          const Offset(8000, 3000), // Top-right (3m x 3m)
          const Offset(5000, 3000), // Top-left
        ],
        name: 'Kitchen',
      ),
    ];

    // Test metric export
    final pdfBytesMetric = await PdfExportService.exportToPdf(
      rooms: rooms,
      useImperial: false,
      projectName: 'Test Project - Metric',
      includeGrid: true,
    );

    expect(pdfBytesMetric, isNotNull);
    expect(pdfBytesMetric.length, greaterThan(0));
    expect(pdfBytesMetric[0], 0x25); // PDF files start with '%PDF'
    expect(pdfBytesMetric[1], 0x50);
    expect(pdfBytesMetric[2], 0x44);
    expect(pdfBytesMetric[3], 0x46);

    // Test imperial export
    final pdfBytesImperial = await PdfExportService.exportToPdf(
      rooms: rooms,
      useImperial: true,
      projectName: 'Test Project - Imperial',
      includeGrid: false,
    );

    expect(pdfBytesImperial, isNotNull);
    expect(pdfBytesImperial.length, greaterThan(0));
    expect(pdfBytesImperial[0], 0x25); // PDF files start with '%PDF'

    // Test empty project
    final pdfBytesEmpty = await PdfExportService.exportToPdf(
      rooms: [],
      useImperial: false,
      projectName: 'Empty Project',
    );

    expect(pdfBytesEmpty, isNotNull);
    expect(pdfBytesEmpty.length, greaterThan(0));
    expect(pdfBytesEmpty[0], 0x25); // PDF files start with '%PDF'

  });

  test('PDF export renders cut sheet and quote pages', () async {
    final project = ProjectModel(
      name: 'Quoted Project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      rooms: [
        Room(name: 'Lounge', vertices: const [
          Offset(0, 0),
          Offset(5000, 0),
          Offset(5000, 4000),
          Offset(0, 4000),
        ]),
      ],
      carpetProducts: [
        CarpetProduct(name: 'Twist', rollWidthMm: 3600, costPerSqm: 30),
      ],
      roomCarpetAssignments: const {0: 0},
      quoteRates: const QuoteRates(
        underlayCostPerSqm: 8,
        gripperCostPerM: 5,
        doorBarCostEach: 25,
        labourCostPerSqm: 12,
      ),
    );

    final cutSheetData = buildPdfCutSheetData(project);
    final quote = buildJobQuote(project);
    expect(quote.isEmpty, isFalse);

    final pdfBytes = await PdfExportService.exportToPdf(
      rooms: project.rooms,
      useImperial: false,
      projectName: project.name,
      carpetCuts: cutSheetData.cuts,
      carpetOffcuts: cutSheetData.offcuts,
      quote: quote,
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(0));
    expect(pdfBytes[0], 0x25); // '%PDF'
  });
}
