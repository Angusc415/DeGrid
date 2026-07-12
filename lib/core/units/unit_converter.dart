/// Utility for converting between measurement units.
/// 
/// Internal storage is always in millimeters (mm) for precision.
/// Display can be in metric (mm/cm) or imperial (ft-in).
class UnitConverter {
  // Conversion constants
  static const double mmPerInch = 25.4;
  static const double mmPerFoot = 304.8; // 12 * 25.4
  static const double mmPerCm = 10.0;
  static const double cmPerM = 100.0;

  /// Format a distance in mm to a human-readable string.
  /// 
  /// [distanceMm] - distance in millimeters
  /// [useImperial] - if true, format as ft-in; if false, format as mm/cm
  static String formatDistance(double distanceMm, {bool useImperial = false}) {
    if (useImperial) {
      return _formatImperial(distanceMm);
    } else {
      return _formatMetric(distanceMm);
    }
  }

  /// Format as imperial (feet and inches to the nearest 1/4").
  ///
  /// Rounds total quarter-inches first, then splits, so 71.9" becomes 6' and
  /// not 5' 12". Quarter-inch precision keeps cut lengths within ~3mm instead
  /// of the ~13mm loss of whole-inch rounding.
  static String _formatImperial(double mm) {
    final totalQuarters = (mm / mmPerInch * 4).round();
    final feet = totalQuarters ~/ 48;
    final quarters = totalQuarters % 48;
    final inches = quarters ~/ 4;
    const fractions = ['', ' 1/4', ' 1/2', ' 3/4'];
    final fraction = fractions[quarters % 4];
    final inchText = '$inches$fraction"';

    if (feet == 0) {
      return inchText;
    } else if (quarters == 0) {
      return "$feet'";
    } else {
      return "$feet' $inchText";
    }
  }

  /// Format as metric: mm under 1m, metres (trade convention) above.
  static String _formatMetric(double mm) {
    if (mm < 1000) {
      return '${mm.round()}mm';
    }
    final m = mm / 1000;
    var text = m.toStringAsFixed(2);
    // Trim trailing zeros: 5.10 -> 5.1, 8.00 -> 8.
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return '${text}m';
  }

  /// Format area in square millimeters to a human-readable string.
  static String formatArea(double areaMm2, {bool useImperial = false}) {
    if (useImperial) {
      // Convert to square feet
      final sqFt = areaMm2 / (mmPerFoot * mmPerFoot);
      if (sqFt < 1) {
        final sqIn = areaMm2 / (mmPerInch * mmPerInch);
        return '${sqIn.round()} sq in';
      } else if (sqFt % 1 == 0) {
        return '${sqFt.round()} sq ft';
      } else {
        return '${sqFt.toStringAsFixed(1)} sq ft';
      }
    } else {
      // Use square meters for large areas, cm² for small
      final sqM = areaMm2 / (cmPerM * cmPerM * mmPerCm * mmPerCm);
      if (sqM >= 1) {
        if (sqM % 1 == 0) {
          return '${sqM.round()} m²';
        } else {
          return '${sqM.toStringAsFixed(2)} m²';
        }
      } else {
        // Use cm² for small areas
        final sqCm = areaMm2 / (mmPerCm * mmPerCm);
        if (sqCm % 1 == 0) {
          return '${sqCm.round()} cm²';
        } else {
          return '${sqCm.toStringAsFixed(1)} cm²';
        }
      }
    }
  }
}
