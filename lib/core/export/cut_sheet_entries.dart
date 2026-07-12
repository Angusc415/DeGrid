import '../models/project.dart';
import '../roll_planning/roll_plan_models.dart';
import '../roll_planning/roll_planner.dart';
import '../roll_planning/room_strip_layout.dart';

/// One row of the PDF carpet cut sheet.
class PdfCutSheetEntry {
  final String cutId;
  final String roomName;
  final String productName;
  final double lengthMm;
  final double breadthMm;
  final String note;

  const PdfCutSheetEntry({
    required this.cutId,
    required this.roomName,
    required this.productName,
    required this.lengthMm,
    required this.breadthMm,
    this.note = '',
  });
}

/// Builds carpet cut-sheet rows for a saved project, using the same shared
/// layout path as the canvas/cut list so the PDF always matches the app.
/// Empty when the project has no carpet assignments.
List<PdfCutSheetEntry> buildPdfCutSheetEntries(ProjectModel project) {
  final entries = <PdfCutSheetEntry>[];
  final layouts = <int, StripLayout?>{};

  StripLayout? layoutFor(int ri) => layouts.putIfAbsent(ri, () {
        if (ri < 0 || ri >= project.rooms.length) return null;
        final pi = project.roomCarpetAssignments[ri];
        if (pi == null || pi < 0 || pi >= project.carpetProducts.length) {
          return null;
        }
        final product = project.carpetProducts[pi];
        if (product.rollWidthMm <= 0) return null;
        final variantIndex = project.roomCarpetLayoutVariantIndex[ri] ?? 0;
        return computeRoomStripLayout(
          room: project.rooms[ri],
          roomIndex: ri,
          product: product,
          openings: project.openings,
          seamOverrides: project.roomCarpetSeamOverrides[ri],
          layDirectionDeg: project.roomCarpetSeamLayDirectionDeg[ri] ??
              layDirectionDegFromVariant(variantIndex),
          stripSplitStrategy: project.stripSplitStrategy,
          stripPieceLengthsOverride:
              project.roomCarpetStripPieceLengthsOverrideMm[ri],
          settings: project.carpetPlanningSettings,
        );
      });

  for (final e in project.roomCarpetAssignments.entries) {
    final ri = e.key;
    final pi = e.value;
    if (ri < 0 || ri >= project.rooms.length) continue;
    if (pi < 0 || pi >= project.carpetProducts.length) continue;
    final layout = layoutFor(ri);
    if (layout == null || layout.numStrips == 0) continue;
    final letterIndex = roomLetterIndexInProduct(
      assignments: project.roomCarpetAssignments,
      roomIndex: ri,
      hasPlannableLayout: (r) => (layoutFor(r)?.numStrips ?? 0) > 0,
    );
    if (letterIndex == null) continue;

    final room = project.rooms[ri];
    final product = project.carpetProducts[pi];
    final roomName = room.name ?? 'Room ${ri + 1}';
    final minStripMm = product.minStripWidthMm ?? 100;
    final rollLengthMm =
        product.rollLengthM != null ? product.rollLengthM! * 1000 : null;

    for (var si = 0; si < layout.stripLengthsMm.length; si++) {
      final pieces = layout.pieceLengthsForStrip(si);
      final isSliver = layout.isSliverAt(si, minStripMm);
      final widthMm = si < layout.stripWidthsMm.length
          ? layout.stripWidthsMm[si]
          : product.rollWidthMm;
      for (var piIdx = 0; piIdx < pieces.length; piIdx++) {
        final len = pieces[piIdx];
        final notes = <String>[
          if (isSliver) 'Sliver',
          if (rollLengthMm != null && len > rollLengthMm) 'Exceeds roll',
        ];
        entries.add(
          PdfCutSheetEntry(
            cutId: formatCutId(
              roomLetterIndex: letterIndex,
              stripIndex: si,
              pieceIndex: piIdx,
              pieceCountInStrip: pieces.length,
            ),
            roomName: roomName,
            productName: product.name,
            lengthMm: len,
            breadthMm: widthMm,
            note: notes.join(', '),
          ),
        );
      }
    }
  }
  return entries;
}
