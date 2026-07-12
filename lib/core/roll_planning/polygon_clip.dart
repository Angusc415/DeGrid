import 'dart:ui';

/// Intersection of a polygon with a horizontal line y = [y].
/// Returns intervals (xMin, xMax) where the polygon overlaps the line.
/// Used for L/T-shaped rooms: one band can intersect the room in multiple disconnected parts.
List<({double start, double end})> intersectPolygonWithHorizontalLine(List<Offset> polygon, double y) {
  if (polygon.length < 3) return [];
  final xs = <double>[];
  final n = polygon.length;
  for (int i = 0; i < n; i++) {
    final v0 = polygon[i];
    final v1 = polygon[(i + 1) % n];
    final d0 = v0.dy - y;
    final d1 = v1.dy - y;
    // Vertices exactly on the line count as the positive side (simulation of
    // simplicity): each true crossing is recorded exactly once and edges lying
    // on the line are skipped, keeping the even-odd interval pairing valid.
    final s0 = d0 >= 0;
    final s1 = d1 >= 0;
    if (s0 != s1) {
      final t = d0 / (d0 - d1);
      xs.add(v0.dx + t * (v1.dx - v0.dx));
    }
  }
  xs.sort();
  final intervals = <({double start, double end})>[];
  for (int i = 0; i + 1 < xs.length; i += 2) {
    if (xs[i + 1] > xs[i]) intervals.add((start: xs[i], end: xs[i + 1]));
  }
  return intervals;
}

/// Intersection of a polygon with a vertical line x = [x].
/// Returns intervals (yMin, yMax) where the polygon overlaps the line.
List<({double start, double end})> intersectPolygonWithVerticalLine(List<Offset> polygon, double x) {
  if (polygon.length < 3) return [];
  final ys = <double>[];
  final n = polygon.length;
  for (int i = 0; i < n; i++) {
    final v0 = polygon[i];
    final v1 = polygon[(i + 1) % n];
    final d0 = v0.dx - x;
    final d1 = v1.dx - x;
    // See horizontal variant: on-line vertices count as the positive side.
    final s0 = d0 >= 0;
    final s1 = d1 >= 0;
    if (s0 != s1) {
      final t = d0 / (d0 - d1);
      ys.add(v0.dy + t * (v1.dy - v0.dy));
    }
  }
  ys.sort();
  final intervals = <({double start, double end})>[];
  for (int i = 0; i + 1 < ys.length; i += 2) {
    if (ys[i + 1] > ys[i]) intervals.add((start: ys[i], end: ys[i + 1]));
  }
  return intervals;
}

/// Clips a polygon to an axis-aligned rectangle using Sutherland-Hodgman.
/// Returns the intersection polygon (may be empty or degenerate).
List<Offset> clipPolygonToRect(List<Offset> polygon, double left, double top, double right, double bottom) {
  if (polygon.length < 3) return [];
  List<Offset> out = List<Offset>.from(polygon);
  // Clip to each edge: left (x >= left), right (x <= right), top (y >= top), bottom (y <= bottom).
  out = _clipToHalfPlane(out, 1, 0, left);   // x >= left
  if (out.length < 3) return [];
  out = _clipToHalfPlane(out, -1, 0, -right); // x <= right
  if (out.length < 3) return [];
  out = _clipToHalfPlane(out, 0, 1, top);    // y >= top
  if (out.length < 3) return [];
  out = _clipToHalfPlane(out, 0, -1, -bottom); // y <= bottom
  return out;
}

/// Result of sweeping a band: a connected region of (polygon ∩ band).
class BandRegion {
  final double left;
  final double top;
  final double right;
  final double bottom;
  const BandRegion(this.left, this.top, this.right, this.bottom);
}

/// Sweeps multiple lines through a band to find all disconnected strip regions.
/// For L/T-shaped rooms, a single band can intersect the room in multiple parts
/// (e.g. vertical and horizontal legs). Returns one region per connected part.
/// [numSamples] lines are used; increase for complex shapes.
List<BandRegion> sweepBandForRegions(
  List<Offset> polygon,
  double left,
  double top,
  double right,
  double bottom,
  bool layAlongX, {
  int numSamples = 12,
}) {
  if (polygon.length < 3) return [];
  final regions = <BandRegion>[];
  final parent = <int>[];
  int nextId = 0;
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }
  void union(int a, int b) {
    a = find(a);
    b = find(b);
    if (a != b) parent[a] = b;
  }
  // Per-sample: list of (interval, regionId)
  List<List<({double start, double end})>> allIntervals = [];
  for (int k = 0; k < numSamples; k++) {
    final t = (k + 0.5) / numSamples;
    final perp = layAlongX
        ? top + t * (bottom - top)
        : left + t * (right - left);
    final raw = layAlongX
        ? intersectPolygonWithHorizontalLine(polygon, perp)
        : intersectPolygonWithVerticalLine(polygon, perp);
    final clamped = <({double start, double end})>[];
    final alongLo = layAlongX ? left : top;
    final alongHi = layAlongX ? right : bottom;
    for (final iv in raw) {
      final s = iv.start.clamp(alongLo, alongHi);
      final e = iv.end.clamp(alongLo, alongHi);
      if (e > s) clamped.add((start: s, end: e));
    }
    allIntervals.add(clamped);
  }
  // Assign ids and union overlapping intervals between consecutive samples.
  final idToBbox = <int, ({double lo, double hi, double perpLo, double perpHi})>{};
  final prevIds = <int>[];
  for (int k = 0; k < numSamples; k++) {
    final perp = layAlongX
        ? top + (k + 0.5) / numSamples * (bottom - top)
        : left + (k + 0.5) / numSamples * (right - left);
    final intervals = allIntervals[k];
    final curIds = <int>[];
    for (final iv in intervals) {
      final id = nextId++;
      parent.add(id);
      curIds.add(id);
      idToBbox[id] = (lo: iv.start, hi: iv.end, perpLo: perp, perpHi: perp);
    }
    for (int i = 0; i < intervals.length; i++) {
      for (int j = 0; j < prevIds.length; j++) {
        final a = intervals[i];
        final b = idToBbox[prevIds[j]]!;
        if (a.start < b.hi && b.lo < a.end) union(curIds[i], prevIds[j]);
      }
    }
    prevIds.clear();
    prevIds.addAll(curIds);
  }
  // Merge bboxes for each root
  final rootToBbox = <int, ({double lo, double hi, double perpLo, double perpHi})>{};
  for (final e in idToBbox.entries) {
    final r = find(e.key);
    final b = rootToBbox[r];
    final v = e.value;
    if (b == null) {
      rootToBbox[r] = v;
    } else {
      rootToBbox[r] = (
        lo: b.lo < v.lo ? b.lo : v.lo,
        hi: b.hi > v.hi ? b.hi : v.hi,
        perpLo: b.perpLo < v.perpLo ? b.perpLo : v.perpLo,
        perpHi: b.perpHi > v.perpHi ? b.perpHi : v.perpHi,
      );
    }
  }
  for (final b in rootToBbox.values) {
    if (layAlongX) {
      regions.add(BandRegion(b.lo, top, b.hi, bottom));
    } else {
      regions.add(BandRegion(left, b.lo, right, b.hi));
    }
  }
  return regions;
}

/// Expands sampled band regions so their along-run bounds partition the band.
///
/// Region bounds from [sweepBandForRegions] come from a finite number of
/// scanlines and can truncate a region's true extent (e.g. angled walls whose
/// extreme point lies between samples). Clipping the room polygon to these
/// expanded cells instead of the sampled bboxes is exact: cell boundaries fall
/// in the empty gaps between disconnected regions, so the Sutherland-Hodgman
/// clip recovers each region's true along-run extent. A single-region band
/// expands to the whole band.
List<BandRegion> expandRegionsToCells(
  List<BandRegion> regions,
  double left,
  double top,
  double right,
  double bottom,
  bool layAlongX,
) {
  if (regions.length <= 1) {
    return regions.isEmpty
        ? regions
        : [BandRegion(left, top, right, bottom)];
  }
  double lo(BandRegion r) => layAlongX ? r.left : r.top;
  double hi(BandRegion r) => layAlongX ? r.right : r.bottom;
  final alongLo = layAlongX ? left : top;
  final alongHi = layAlongX ? right : bottom;
  final sorted = List<BandRegion>.from(regions)
    ..sort((a, b) => lo(a).compareTo(lo(b)));
  final out = <BandRegion>[];
  for (int i = 0; i < sorted.length; i++) {
    final cellLo = i == 0 ? alongLo : (hi(sorted[i - 1]) + lo(sorted[i])) / 2;
    final cellHi = i == sorted.length - 1
        ? alongHi
        : (hi(sorted[i]) + lo(sorted[i + 1])) / 2;
    out.add(layAlongX
        ? BandRegion(cellLo, top, cellHi, bottom)
        : BandRegion(left, cellLo, right, cellHi));
  }
  return out;
}

/// Clip polygon to half-plane: nx*x + ny*y >= c (with (nx,ny) normal).
List<Offset> _clipToHalfPlane(List<Offset> poly, int nx, int ny, double c) {
  final out = <Offset>[];
  final n = poly.length;
  for (int i = 0; i < n; i++) {
    final v0 = poly[i];
    final v1 = poly[(i + 1) % n];
    final d0 = nx * v0.dx + ny * v0.dy - c;
    final d1 = nx * v1.dx + ny * v1.dy - c;
    if (d0 >= 0) out.add(v0);
    if ((d0 >= 0) != (d1 >= 0)) {
      final t = d0 / (d0 - d1);
      out.add(Offset(v0.dx + t * (v1.dx - v0.dx), v0.dy + t * (v1.dy - v0.dy)));
    }
  }
  return out;
}
